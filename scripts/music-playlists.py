#!/usr/bin/env python3
"""Sort the beets library into themed playlists.

Reads ~/.local/share/beets/library.db (read-only) and writes one .m3u per
playlist to two places:

  ~/Music/Playlists/            paths relative to the playlist file; Syncthing
                                carries these to the server, where Navidrome
                                auto-imports them
  ~/.local/share/mpd/playlists/ paths relative to ~/Music, for mpd / ncmpcpp /
                                rmpc

The library is mostly YouTube/TikTok singles with no genre tags, so each track
is classified from its title and artist: first whether it is an *edit*
(slowed, sped up, hoodtrap, edit audio, mashup, ...), then, for originals,
which genre its artist belongs to. Rerun after every import (the `bi` / `ba`
aliases do this). Files under ~/Music/Playlists are regenerated wholesale, so
don't hand-edit them — change the rules here instead.

  music-playlists           write the playlists, print a summary
  music-playlists --report  also list unclassified originals and duplicates
"""

import re
import sqlite3
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

HOME = Path.home()
MUSIC = HOME / "Music"
DB = HOME / ".local/share/beets/library.db"
OUT_LIB = MUSIC / "Playlists"
OUT_MPD = HOME / ".local/share/mpd/playlists"

# Short TikTok clips: anything under this many seconds that's an edit lands in
# "TikTok Edits", and nothing under DRIVE_MIN goes in "Drive".
CLIP_MAX = 80
DRIVE_MIN = 120


def norm(s):
    """Fold styled unicode (𝙎𝙇𝙊𝙒𝙀𝘿, ｓｌｏｗｅｄ) to plain lowercase ASCII-ish."""
    s = unicodedata.normalize("NFKC", s or "")
    return s.casefold()


def rx(*parts):
    return re.compile("|".join(parts))


# --- edit detection (title, plus artist where uploaders put it there) -------

SLOWED = rx(
    r"slow(ed|d)\b",
    r"slowed",
    r"\bslow ?(instrumental|loop|version|down version)",
    r"ultra slow\b",
    r"superslowed",
    r"reverb",
    r"s l o w e d",
    r"daycore",
    r"anti-? ?nightcore",
    r"pitched down",
    r"muffled",
    r"432 ?hz",
)
SPED = rx(r"sped", r"speed ?up", r"nightcore", r"nigthcore", r"speedcore", r"pitched\]")
PHONK = rx(
    r"phonk",
    r"\bfonk",
    r"\bdrift\b",
    r"\bfunk\b",
    r"\bfunk[ao]?\b",
    r"hard ?tekk",
    r"hartekk",
    r"heavytekk",
    r"ballintekk",
    r"jumptekk",
    r"hardstyle",
    r"jumpstyle",
    r"montagem",
    r"automotivo",
    r"\bmtg\b",
    r"cafajeste",
    r"brazil",
    r"brasil",
    r"beat (bolha|vapo|modinha|das trevas)",
    r"vapo vapo",
    r"piquezin|pikezin|pique d",
    r"ritmo (golden|dos cria)",
    r"sequ[eê]ncia",
    r"memphis",
    r"\bmc (delux|osen|lan|wm|gw|theus|niack|denny|myres)",
)
CLUB = rx(
    r"jersey",
    r"hood ?trap",
    r"\bzess",
    r"\bnola\b",
    r"bounce",
    r"\bjerk\b",
    r"litefeet",
    r"synthclub",
    r"drill remix",
    r"mylancore",
    r"karmatrap",
    r"\bshoulder bop",
)
BEATS = rx(
    r"type beat",
    r"instrumental",
    r"\binstru\b",
    r"[\[(]free[\])]",
    r"free for profit",
    r"[\[(]sold[\])]",
    r"\(beat\)",
)
CLIP = rx(
    r"edit audio",
    r"audio edit",
    r"\[ ?edit",
    r"\bedit\b(?! version)",
    r"#edit",
    r"best (part|bit|moment|version)",
    r"loop",
    r"chorus only",
    r"\bamv\b",
    r"tik ?tok",
    r"till the first chorus",
    r"just the vibepart",
    r"evangelion",
    r"berserk",
    r"\boc mv\b",
    r"animation",
    r"music vedio",
    r"johan liebert",
    r"ken kaneki",
    r"gigachad|sigma",
    r"deadpool",
    r"addams family",
    r"adult swim",
    r"mini mep",
    r"thaisub",
    r"stellaris",
    r"\(with sfx\)",
    r"prince of egypt",
    r"\| love i know",
)
# Anything else that marks a track as not-the-original-recording.
ALTERED = rx(
    r"remix",
    r"\brmx\b",
    r"\bmix\b",
    r"mixx",
    r"mashup",
    r"\bflip\b",
    r"\bremake\b",
    r"\bcover\b",
    r"lo-?fi",
    r"\b8d\b",
    r"bass ?boost",
    r"\bextended\b",
    r"\bversion\b",
    r"\bver\.",
    r"\bvers\.",
    r"\bversão\b",
    r"\bv\d\b",
    r"glitch",
    r" x ",
    r" × ",
    r"\bvs\.? ",
    r"\bbut (it'?s|hoodtrap)",
    r"\bremaster",  # fine for oldies, but keeps reuploads out of Drive
    r"\bfan made",
    r"\bmeme\b",
    r"\bthumbnail\b",
    r"\blyrics?\b",
    r"alt intro",
    r"\(.*(prod\.?|reprod).*remix",
)
# Words above that are harmless in these specific contexts.
NOT_ALTERED = rx(
    r"taylor'?s version",
    r"twin ver",
    r"radio edit",
    r"dance version",
    r"\(mono( version)?\)",
    r"\(\d{4} -? ?remaster",
    r"double shot version",
    r"\bremaster(ed)? version\)",
    r"orchestral intro version",
    r"extended intro version",
    r"special version",
)

# --- genre of original recordings, matched against "artist  title" -----------
# Order matters: first match wins.

GENRES = [
    # Originals that are really TikTok-trend songs / edit-channel uploads even
    # though the title doesn't say so: TikTok Edits, never Drive. Listed first
    # so they win over the genre rules below.
    # Cover versions by other artists: Remixes & Mashups, never Drive.
    (
        "covers",
        rx(
            r"teddy specter",
            r"luke muzzic",
            r"marianne beaulieu",
            r"\bsyzz\b",
            r"zavey ?t",
            r"embercole",
            r"dreamsoda",
            r"your anxiety buddy",
            r"emptiness & remyboi",
            r"zuhaib sheikh",
            r"olphenius",
            r"\bcover\b",
        ),
    ),
    (
        "tiktok",
        rx(
            r"rusneus",
            r"\bsad choice",
            r"iron miku",
            r"\bizabella\b",
            r"blumengarten|shirin david",
            r"jack - j97",
            r"рома куприянов",
            r"cakra khan",
            r"anya nami",
            r"izzy escobar",
            r"jasmine sokko",
            r"stela cole",
            r"lord kael",
            r"\bseroa\b",
            r"roxy layne",
            r"crazy town",
            r"dudouniel",
            r"static spectrum",
            r"temper city",
            r"never ?get ?used ?to ?people",
            r"juliana chahayed",
            r"nightshift tv",
        ),
    ),
    (
        "soundtrack",
        rx(
            r"\bost\b",
            r"ruder buster",
            r"inon zur",
            r"masaru yokoyama",
            r"kensuke ushio",
            r"pirates of the caribbean",
            r"black butler",
            r"nicholas britell",
            r"ludwig g[oö]ransson",
            r"james newton howard",
            r"jed kurzel",
            r"yoshihisa hirano",
            r"piero piccioni",
            r"rob dougan",
            r"hampus naeselius",
            r"caleb bryant",
            r"yugo kanno",
            r"succession",
            r"\bgta\b",
            r"gta (iv|4|v|san)",
            r"soviet connection",
            r"theme\b",
            r"soundtrack",
            r"fairy fountain",
            r"lost woods",
            r"ocarina",
            r"mii channel",
            r"godfather",
            r"giorno",
            r"evil morty",
            r"teen titans",
            r"imperial dance warhammer",
            r"underground theme",
            r"sea of thieves",
            r"carnival music",
            r"cel liberation",
            r"\bkyrie\b",
        ),
    ),
    # Classical, neoclassical and solo piano / strings: Classical & Piano,
    # never Drive.
    (
        "classical",
        rx(
            r"vivaldi|mozart|beethoven|\bbach\b|chopin|tcha[ij]kovsk|paganini|brahms|debussy|satie|grieg|dvo[rř][aá]k",
            r"liszt|schubert|handel|händel|verdi|rimsky|czerny|sibelius|ysa[yÿ]e|kreisler|rachmaninoff|pugni|offenbach",
            r"caprices?\b|nocturne|\bwaltz|\bvalse|sonat[ae]|concert[oi]|symphon|\bop\. ?\d|\bbwv\b|\bk\. ?\d|\bkv \d|\brv \d|\bwoo\b",
            r"orchestr|philharmon|string (quartet|quintet|ensemble)|\bminuet|menuet|bagatelle|für elise|moonlight sonata",
            r"clair de lune|gymnop|gnossienne|swan lake|nutcracker|four seasons|l'estate|\bcarmen\b|habanera|peer gynt",
            r"can can|rush e\b|campanella|libertango|palladio|liebestraum|barcarole|blue danube|solfeggietto|chiaroscuro",
            r"hilary hahn|itzhak perlman|yo-yo ma|valentina lisitsa|joshua bell|víkingur|kavakos|soovin kim|inmo yang",
            r"hadelich|esther abrami|max richter|morricone|karaindrou|sakamoto|kosemura|vilde frang|budapest strings",
            r"\bpiano\b|\bcello\b|\bviolin|poviolinist|brosky tsw|\bhakdo\b|joshua kyan aalampour|james quinn|pianza",
            r"paterlini|lucas king|claudio constantini|\brousseau\b|\bkassia\b|rafael krux|enzo corne|ophelia wilde",
            r"juan arenosa|sergey ivanov|jacob's piano|george davidson|oskar schuster|onno kul|morunas|gianluca piacenza",
            r"ian livingstone|\blambert\b|olexandr ignatov|yang y\b|^xuan\b|verbovets|álvaro fernández|murad hüseynov",
            r"robert gromotka|alexander motovilov|jamie duffy|eugene godsoe|etienne balestre|luca minor|siennor",
            r"reinúr selson|\braban\b|lloyd vaan|levi\.sct|leverfall|woodsman|million eyes|jacob lavallee|ryan little",
            r"\bfeinberg\b|anon berg|austin farwell|ana petrovna|adrián berenguer|alexander joseph|nicholas yee",
            r"timeless melodies|immortal music|música clásica|dinnermusic|the hit crew|various artists \(nl\)",
            r"westminster concert|the columbia river players|music for sports|youths in chamber|capella istropolitana",
            r"tonality feel|arachang|serkmusic|lifting dreams|virtual sheet music|rob landes|song song e|very cool tutorials",
            r"aladar mozi|alican süner|håvard gimse|hakan kabil|finghin collins|pio palumbo|charles gerhardt|charles curtis",
            r"junior dos santos|clair de lune\b|prueb270891|déšť|mspianogeek|shin giwon|sir simon rattle|london pops",
            r"andré dussollier|david parry|justus eichhorn|jörg faerber|karl jenkins|kaunas chamber|knua string",
            r"german bach soloists|g\.h\. hat|j\.s\. bach orchestra|metamorphose string|nike hutchisson|luigi piovano",
            r"simon standage|camille thomas|jiaxin lloyd webber|jian wang|scott st\. john|rias orchestra|rotterdam phil",
            r"orchestre symphonique|mariinsky|berliner|academy of st|patrick watson|morelenbaum|fabrizio|penguin piano",
            r"piano fantasia|piano glow|olivia belli|nathan\b(?=.*waves)",
        ),
    ),
    (
        "phonk",
        rx(
            r"interworld",
            r"\bdvrst\b",
            r"playaphonk",
            r"\bnbsplv\b",
            r"ogryzek",
            r"kxllswxtch",
            r"euphxria",
            r"\bwels\b",
            r"sxnstxrm",
            r"hxshxr",
            r"udiennx",
            r"nashi & mc fluup",
            r"vincce",
            r"navjaxx",
            r"narvent",
            r"hensonn",
            r"pr1svx",
            r"miguel angeles",
            r"eternxlkz",
            r"evxrenty",
            r"!nfnx",
            r"zodivk",
            r"natsukxshi",
            r"5admin",
            r"\bty 2048",
            r"eternal raijin",
            r"\bmatx\b",
            r"stakillaz",
            r"lxngvx",
            r"wavemane",
            r"freddie dredd",
            r"\bk3nt4",
            r"\bxvallarix",
            r"satirin",
            r"\bpoodee\b",
            r"onimxru",
            r"novemice",
            r"ariflame",
            r"\bcyrex\b",
            r"forgottenage",
            r"gravechill",
            r"icykillxh",
            r"blxckie|blvkz",
            r"zynyx",
            r"krezus",
            r"kute\b",
            r"\bdj vttt77",
            r"\bdj (ak7|dazai|ezequiel|jow|l7|mazzay|mítico|neguinho|nox|oliver|menor|pbeats|vuiziki|lex v)",
            r"\bmc (levin|lyc4n|caja|rd\b|staff)",
            r"fariasrlk",
            r"lukkas",
            r"\btrxveler",
            r"gp da zl",
            r"tsk\.4",
            r"young madz",
            r"cpski",
            r"llusion",
            r"mr\. varro",
            r"\bxdriangm",
            r"voxelix",
            r"dualidade",
            r"dj remix 27",
            r"rzorblade|r0pss|soakz|stania|vynthr|xaylen|xddフ",
        ),
    ),
    (
        "club",
        rx(
            r"fat papi",
            r"prodshushy",
            r"ziahfyah",
            r"bread beatz",
            r"new magick",
            r"mr flintstone",
            r"tai2talented",
            r"izrosh",
            r"neverbadagain",
            r"prodwhite",
            r"twopiecemadeit",
            r"thiago sub",
            r"kairo keyz",
            r"\bsayso\b",
            r"ilytommy",
            r"lex amarni",
            r"1c3dtea",
            r"hoodtrapjerk",
            r"fazobeats",
            r"cutty vibez",
            r"xatashi",
            r"axaero",
            r"yung kyoto",
            r"supxr",
            r"swisho",
            r"stopthis",
            r"lilbubblegum",
            r"deekay",
            r"foxtune",
            r"jalenrekt",
            r"^vip\b",
            r"salako",
            r"godard",
            r"dj t marq",
            r"jflaxo",
            r"larsimon",
            r"kayarchon",
            r"kay archon",
            r"rj pasin",
            r"ptasinski",
            r"hood trapppa",
            r"imis!",
            r"carpe diem",
            r"stella standingbear",
            r"slevpy808",
            r"ash vanz",
            r"larkin",
            r"kwanli",
            r"fatboibari",
            r"\bfvvk\b",
            r"skyemane",
            r"prodbykowin",
            r"proddbyck",
            r"prodbycpkshawn",
            r"prodbyabnormal",
            r"prodbysaint",
            r"prodbyescobar",
            r"yunmaho",
            r"jiandro",
            r"eclipse",
            r"camdaguapo",
            r"jouvick",
            r"dj taj",
            r"bubajuice",
            r"bxndz",
            r"nexso",
            r"mvntana",
            r"\bdj lilli",
            r"dorthy kosmicki|mashko",
            r"diamond the body",
            r"deefrmdapote",
            r"donny ying",
            r"bmonster",
            r"studio genius",
            r"xxtristanxo",
            r"\bk-p\b",
            r"zeddy will",
            r"apollo fresh",
            r"#bounceboiiz",
            r"tobee|to₿ee",
            r"rock burwell",
            r"billy marchiafava|anh & billy",
            r"\bshady moon",
            r"22december",
            r"ian asher",
            r"\bfrizk\b",
            r"\bcore5k",
            r"\bhxzz\b",
            r"\bjeyya",
            r"\bj4y\b",
            r"\bmark\b",
            r"\btybando",
            r"twentythree",
            r"\bkina\b(?=.*baby you're worth)",
        ),
    ),
    (
        "lofi",
        rx(
            r"lakey inspired",
            r"nujabes",
            r"j dilla",
            r"knxwledge",
            r"freddie joachim",
            r"blue wednesday",
            r"brock berrigan",
            r"\bblossom\b",
            r"medafiziks",
            r"lofi\.samurai",
            r"illstrumentalist",
            r"soulchef",
            r"worldtraveller",
            r"yuni wa",
            r"windows 96",
            r"gibran alcocer",
            r"izzamuzzic",
            r"\bpowfu\b",
            r"shiloh dynasty",
            r"\bkina\b",
            r"mounika",
            r"\bommo\b",
            r"bootleg boy",
            r"yūgen|yugen",
            r"alphasvara",
            r"\bsilo\b",
            r"flying lotus",
            r"madlib",
            r"mf doom",
            r"\br[uů]de\b",
            r"øneheart|oneheart",
            r"\bplenka\b",
            r"baltra",
            r"\bsweeps\b",
            r"trippythakid",
            r"smi\.le",
            r"strings & heart",
            r"tokyo tea room",
            r"\bfkj\b",
            r"rabbitology",
            r"\bw\. ave",
            r"lofi",
            r"\bj\^p\^n\b",
            r"blut own",
            r"blawhitt",
            r"glwzbll",
            r"\bduster\b",
            r"marcelo de carvalho",
            r"chrmbchrmb",
            r"\bd\.?v\.?r\.?s\.?t",
            r"force of nature",
            r"\bthe sunnset",
            r"grant steller|taylor do blues",
            r"monsune",
            r"thegoodvibe|sapientdream",
            r"unnholy",
            r"\bjonjthan",
            r"\bheji\b",
            r"leolide",
            r"\bdkj\b",
            r"yeknom",
            r"\bpasítea|pasitea",
            r"\bcxsper",
            r"aloboi",
            r"lucidbeatz",
            r"adturnup",
        ),
    ),
    (
        "oldies",
        rx(
            r"bee gees",
            r"\bberlin\b",
            r"billy idol",
            r"bobby caldwell",
            r"fleetwood mac",
            r"madonna",
            r"michael jackson",
            r"^player\b",
            r"rick james",
            r"rockwell",
            r"spandau ballet",
            r"\bsting\b",
            r"tears for fears",
            r"^toto\b",
            r"morten harket",
            r"pat deville",
            r"flavio belardo",
            r"^basic\b",
            r"\babba\b",
            r"boney m",
            r"modern talking",
            r"eurythmics",
            r"elton john",
            r"\bwham!",
            r"electric light orchestra",
            r"\bredbone\b(?!.*(slowed|lo-fi))",
            r"gloria gaynor",
            r"bobby mcferrin",
            r"rolling stones",
            r"mungo jerry",
            r"bill withers",
            r"grover washington",
            r"aretha franklin",
            r"james brown",
            r"ray charles",
            r"elvis presley",
            r"dean martin",
            r"sinatra",
            r"nat king cole",
            r"louis armstrong",
            r"little richard",
            r"little eva",
            r"lesley gore",
            r"doris day",
            r"peggy lee",
            r"nina simone",
            r"percy sledge",
            r"roy orbison",
            r"sam cooke",
            r"sam & dave",
            r"smokey robinson",
            r"the supremes",
            r"the temptations",
            r"the turtles",
            r"the platters",
            r"the penguins",
            r"the skyliners",
            r"the ronettes",
            r"mamas & the papas",
            r"isley brothers",
            r"o'jays",
            r"the foundations",
            r"five satins",
            r"five stars",
            r"the coasters",
            r"the chords",
            r"crew cuts",
            r"del-vikings",
            r"chordettes",
            r"andrews sisters",
            r"beach boys",
            r"ink spots",
            r"jerry lee lewis",
            r"harry belafonte",
            r"harry james",
            r"fats domino",
            r"del shannon",
            r"\bdion\b",
            r"connie francis",
            r"chubby checker",
            r"brenton wood",
            r"bobby darin",
            r"bobby day",
            r"bobby hebb",
            r"ben e\. king",
            r"four tops",
            r"frankie valli",
            r"engelbert",
            r"lavern baker",
            r"bertha tillman",
            r"patience & prudence",
            r"vera lynn",
            r"seth macfarlane",
            r"michael bubl[ée]",
            r"matt dusk",
            r"jazzato",
            r"postmodern jukebox",
            r"big 80s guys",
            r"the stranglers",
            r"miki matsubara",
            r"joyce partise",
            r"trade martin",
            r"carlton williams",
            r"shery latrice",
            r"cab calloway",
            r"party tyme",
            r"pied pipers",
            r"8-bit big band",
            r"come and get your love",
            r"nora augustinius",
            r"\bshe & him\b",
            r"spa music",
            r"the overtones",
        ),
    ),
    (
        "electronic",
        rx(
            r"marshmello",
            r"martin garrix",
            r"\bmxrt\b",
            r"avicii",
            r"alan walker",
            r"bag raiders",
            r"daft punk",
            r"david guetta",
            r"fred again",
            r"ges+af+elstein",
            r"crystal castles",
            r"\bm83\b",
            r"hippie sabotage",
            r"aaron smith",
            r"k-391",
            r"chainsmokers",
            r"\bchrystal\b",
            r"mareux",
            r"teddybears",
            r"nightshift tv",
            r"aphex twin",
            r"tesla electro",
            r"caravan palace",
            r"basement jaxx",
            r"static spectrum",
            r"temper city",
            r"\bvessel\b",
            r"\bdj gollum",
            r"gnarls barkley",
            r"pastel ghost",
            r"lebanon hanover",
            r"vantage",
            r"\bark patrol",
            r"maribou state",
        ),
    ),
    (
        "indie",
        rx(
            r"dayglow",
            r"fitz and the tantrums",
            r"portugal\. the man",
            r"\bsyml\b",
            r"the score",
            r"richy mitch",
            r"video days",
            r"unlike pluto",
            r"glass animals",
            r"tame impala",
            r"radiohead",
            r"\bmgmt\b",
            r"mother mother",
            r"current joys",
            r"surf curse",
            r"arctic monkeys",
            r"beach house",
            r"\bdjo\b",
            r"neighbourhood",
            r"cage the elephant",
            r"foster the people",
            r"twenty one pilots",
            r"queens of the stone age",
            r"interpol",
            r"lord huron",
            r"rex orange county",
            r"mac demarco",
            r"beach bunny",
            r"rare occasions",
            r"the wombats",
            r"never ?get ?used ?to ?people",
            r"lots of hands",
            r"little winters",
            r"vacations",
            r"liana flores",
            r"tally ?hall",
            r"october country",
            r"good neighbours",
            r"jack stauber",
            r"\blaufey",
            r"clairo",
            r"\bkaleo\b",
            r"vance joy",
            r"\bhozier\b",
            r"\bbastille\b",
            r"\bfun\.",
            r"\bgotye\b",
            r"crazy town",
            r"bad wolves",
            r"yeah yeah yeahs",
            r"capital cities",
            r"empire of the sun",
            r"mitski",
            r"royal & the serpent",
            r"the stranglers",
            r"videoclub|amour plastique",
            r"princess chelsea",
            r"juliana chahayed",
            r"\byot club",
            r"dominic fike",
            r"\bd4vd\b",
            r"\baurora\b",
            r"lola young",
            r"dudouniel",
            r"\bsurfaces\b",
            r"wallows",
            r"matt maltese",
            r"stephen sanchez",
            r"gigi perez",
            r"rosa linn",
            r"jonah kagen",
            r"\bduster\b",
            r"jagwar twin",
            r"sub urban",
            r"\bmissio\b",
            r"\blp\b",
            r"claire audrin",
            r"tokyo's revenge",
        ),
    ),
    (
        "rnb",
        rx(
            r"olivia dean",
            r"snoh aalegra",
            r"jalen ngonda",
            r"young gun silver fox",
            r"daniel caesar",
            r"steve lacy",
            r"kali uchis",
            r"ravyn lenae",
            r"emotional oranges",
            r"matt martians",
            r"chezile",
            r"elujay",
            r"tommy richman",
            r"\bsza\b",
            r"alex isley",
            r"germinie",
            r"cece natalie",
            r"callmestevieray",
            r"jordyn edmonds",
            r"\bmasego",
            r"joy crookes",
            r"amy winehouse",
            r"teddy swims",
            r"chelsea cutler",
            r"christian french",
            r"\bjmsn\b",
            r"kiera martin",
            r"lovibe",
            r"juju\b",
            r"lord kael",
            r"\bsweetly\b",
            r"\bjoji\b",
            r"mac ayres",
            r"cheriimoya",
            r"trevor daniel",
        ),
    ),
    # Small SoundCloud / meme rap acts: still Hip-Hop & Rap, but kept out of
    # Drive. Listed before "hiphop" so a collab with a big name stays here.
    (
        "ugrap",
        rx(
            r"1nonly",
            r"lil darkie",
            r"\bbones\b",
            r"shotgun willy",
            r"yung craka",
            r"yung nugget",
            r"traqula",
            r"haiti babii",
            r"kenndog",
            r"fakemink",
            r"sam wise",
            r"louis theroux",
            r"mobbs radical",
            r"kyle exum",
            r"j-killz",
            r"asaka",
            r"relic the bully",
            r"michiganmadex2",
            r"benzcountgang",
            r"fly street gang",
            r"cain perez",
            r"fracko",
            r"elliot norlander",
            r"t-choppa",
            r"sethii",
            r"ssgtokyo",
            r"swaizy",
            r"mindset",
            r"knotti",
            r"nick docks",
            r"khalil\?",
            r"lokendero",
            r"ramirez",
            r"babo am mic",
            r"ati242",
            r"bias b",
            r"ciscaux",
            r"freeced",
            r"jae bee",
            r"bloodsplat",
            r"suicidal-idol",
            r"rxseboy",
            r"sxnstxrm",
            r"scriptz",
            r"makaveligodd",
            r"jeremy lost|sg603",
            r"skaykid",
            r"boise boi",
            r"\bduke10kk",
            r"rizzyjamesily",
            r"dxlx|døløvøñ|dølø vøñ",
            r"enemy of the state",
            r"\bkhantrast",
            r"emcee kb",
            r"pryme!",
            r"lil maru",
            r"lil thury",
            r"\bmajorzin",
            r"\bresentvul",
            r"\bvoid\b",
            r"\bta2cute",
            r"\bsplash\.mp3|earl stan",
            r"kiraw",
            r"sansy",
            r"sofast",
            r"wale the sage",
            r"winnin'",
            r"\bheater\b",
            r"\bsoleil\b",
            r"wiss\b",
            r"bank dont close",
            r"\bsupxr",
            r"\bhy?pe\b",
            r"dump truck",
            r"\btrauma\b",
            r"\bthe girl next door",
            r"\bswerved it",
            r"\bdisaster\b",
            r"\bnotcollin",
            r"\bstaysolidrocky",
            r"\bthekidszn",
            r"\byung asho",
            r"\bwillie g",
            r"\bjordan|young n\.k|ytd\b|oroka",
            r"\bpaperboys",
        ),
    ),
    (
        "hiphop",
        rx(
            r"21 savage",
            r"baby keem",
            r"bbno\$",
            r"\bbia\b",
            r"dababy",
            r"\bddg\b",
            r"gunna",
            r"ice cube",
            r"king von",
            r"metro boomin",
            r"playboi carti",
            r"ybn nahmir",
            r"\btyga\b",
            r"notorious b\.?i\.?g|biggie",
            r"s\.l\.a\.b\.",
            r"soulja boy",
            r"ghostemane",
            r"yung lean",
            r"armani white",
            r"goldlink",
            r"rich brian",
            r"rob \$tone",
            r"\bjackboys",
            r"\bshe make it clap",
            r"50 cent",
            r"amin[ée]",
            r"comethazine",
            r"coi leray",
            r"diddy",
            r"\bdmx\b",
            r"doechii",
            r"drake",
            r"earl sweatshirt",
            r"eminem",
            r"\bfuture\b",
            r"j\. cole",
            r"\bjid\b",
            r"kendrick lamar",
            r"lil nas x",
            r"lil tecca",
            r"lil uzi",
            r"lil yachty",
            r"offset",
            r"travis scott",
            r"tyler,? the creator",
            r"roddy ricch",
            r"xxxtentacion",
            r"ynw melly",
            r"trippie redd",
            r"juice wrld",
            r"nipsey hussle",
            r"trae tha truth",
            r"jermaine dupri",
            r"tory lanez",
            r"t-wayne",
            r"famous dex",
            r"ski mask",
            r"lil peep",
            r"mike dimes",
            r"connor price",
            r"kota the friend",
            r"hanumankind",
            r"central cee",
            r"\bdave\b",
            r"nemzzz",
            r"esdeekid",
            r"watsky",
            r"\byame\b",
            r"wok \(prod",
            r"opp stoppa",
            r"\bpaid that price",
            r"\bpimp",
            r"\bkid laroi",
            r"\bpost malone",
            r"\bjack harlow",
            r"\bdon toliver",
            r"\bconnor price",
        ),
    ),
    (
        "pop",
        rx(
            r"ariana grande",
            r"carly rae jepsen",
            r"demi lovato",
            r"\bdido\b",
            r"doja cat",
            r"ellie goulding",
            r"kelly clarkson",
            r"\blorde\b",
            r"pharrell",
            r"\braye\b",
            r"rihanna",
            r"sophie ellis-bextor",
            r"^akon\b",
            r"alessia cara",
            r"alex warren",
            r"ava max",
            r"bella poarch",
            r"benson boone",
            r"billie eilish",
            r"britney spears",
            r"bruno mars",
            r"camila cabello",
            r"chappell roan",
            r"clean bandit",
            r"coldplay",
            r"dua lipa",
            r"fifty fifty",
            r"harry styles",
            r"imagine dragons",
            r"\bjvke\b",
            r"katy perry",
            r"\bkesha\b",
            r"lady gaga",
            r"loreen",
            r"madison beer",
            r"meghan trainor",
            r"melanie martinez",
            r"miley cyrus",
            r"olivia ?rodrigo",
            r"olly murs",
            r"onerepublic",
            r"ros[ée]\b",
            r"sabrina carpenter",
            r"selena gomez",
            r"shawn mendes",
            r"\bsia\b",
            r"taylor swift",
            r"tate mcrae",
            r"the weeknd",
            r"\byuqi\b",
            r"nelly furtado",
            r"robin thicke",
            r"indila",
            r"mae stephens",
            r"john newman",
            r"cat janice",
            r"claire rosinkranz",
            r"\bartemas\b",
            r"paul russell",
            r"stela cole",
            r"nile rodgers",
            r"romeo santos",
            r"shirin david",
            r"makhadzi",
            r"cakra khan",
            r"elliot james reay",
            r"\bjack - j97",
            r"рома куприянов",
            r"izzy escobar",
            r"hudson thames",
            r"\bherex|l7c\b",
            r"roxy layne",
            r"jasmine sokko",
            r"anya nami",
            r"seroa",
            r"\bmae\b",
        ),
    ),
]

PLAYLISTS = [
    # name, description (printed in the summary)
    ("Drive", "original songs, no edits, >= 2:00 — mainstream hip-hop, pop, indie, electronic, R&B"),
    ("Hip-Hop & Rap", "original recordings"),
    ("Pop", "original recordings"),
    ("Indie & Alternative", "original recordings"),
    ("R&B & Soul", "modern R&B / neo-soul originals"),
    ("Electronic", "original recordings"),
    ("Oldies & Classics", "50s-80s soul, rock 'n' roll, crooners, disco"),
    ("Lo-fi & Chill", "lo-fi, chillhop, ambient"),
    ("Underground & SoundCloud", "originals by artists no genre rule knows"),
    ("Classical & Piano", "classical, neoclassical, solo piano and strings"),
    ("Soundtracks & Themes", "film/TV/game scores and themes, incl. slowed ones"),
    ("Phonk & Brazilian Funk", "phonk, funk, montagem, hardtekk/hardstyle"),
    ("Jersey Club, Jerk & Hoodtrap", "jersey club, jerk, hoodtrap, bounce"),
    ("Slowed + Reverb", "every slowed / reverbed edit"),
    ("Sped Up & Nightcore", "every sped-up / nightcore edit"),
    ("Remixes & Mashups", "remixes, mashups and covers no other playlist took"),
    ("Type Beats & Instrumentals", "instrumentals and producer type beats"),
    ("TikTok Edits", "edit audios, best-part loops and short clips"),
]

GENRE_PLAYLIST = {
    "tiktok": "TikTok Edits",
    "covers": "Remixes & Mashups",
    "classical": "Classical & Piano",
    "hiphop": "Hip-Hop & Rap",
    "ugrap": "Hip-Hop & Rap",
    "pop": "Pop",
    "indie": "Indie & Alternative",
    "rnb": "R&B & Soul",
    "electronic": "Electronic",
    "oldies": "Oldies & Classics",
    "lofi": "Lo-fi & Chill",
    "soundtrack": "Soundtracks & Themes",
    "phonk": "Phonk & Brazilian Funk",
    "club": "Jersey Club, Jerk & Hoodtrap",
}
DRIVE_GENRES = {"hiphop", "pop", "indie", "rnb", "electronic"}


def genre_of(text):
    for genre, pattern in GENRES:
        if pattern.search(text):
            return genre
    return None


def classify(artist, title, length):
    a, t = norm(artist), norm(title)
    both = f"{a}  {t}"
    tags = set()

    slowed = bool(SLOWED.search(t) or re.search(r"s ?l ?o ?w ?e ?d|reverb", a))
    sped = bool(SPED.search(t)) and not re.search(r"anti-? ?nightcore", t)
    phonk = bool(PHONK.search(t))
    club = bool(CLUB.search(t) or CLUB.search(a))
    beats = bool(BEATS.search(t))
    clip = bool(CLIP.search(t))
    altered = bool(ALTERED.search(t)) and not NOT_ALTERED.search(t)
    edit = slowed or sped or phonk or club or beats or clip or altered

    if slowed:
        tags.add("Slowed + Reverb")
    if sped:
        tags.add("Sped Up & Nightcore")
    if phonk:
        tags.add("Phonk & Brazilian Funk")
    if club:
        tags.add("Jersey Club, Jerk & Hoodtrap")
    if beats:
        tags.add("Type Beats & Instrumentals")
    if clip or (edit and length < CLIP_MAX):
        tags.add("TikTok Edits")

    genre = genre_of(both)
    # Soundtrack themes keep their home even when slowed (GTA IV theme etc.),
    # but a hoodtrap "Spectacular Spiderman" is a club track, not a score.
    if genre == "soundtrack" and not (club or phonk or sped):
        tags.add("Soundtracks & Themes")
    # Genre-defining artists (phonk producers, jerk/jersey producers) belong
    # to their genre playlist whether or not the title says so.
    if genre in ("phonk", "club") and not (sped or beats):
        tags.add(GENRE_PLAYLIST[genre])
    if not edit and genre:
        tags.add(GENRE_PLAYLIST[genre])
        if genre in DRIVE_GENRES and length >= DRIVE_MIN:
            tags.add("Drive")
    if edit and not tags:
        tags.add("Remixes & Mashups")
    if not edit and not genre:
        # Original, but by an artist none of the rules know — mostly small
        # SoundCloud rap / plugg / jerk acts.
        tags.add("Underground & SoundCloud")
    return tags, edit, genre


def song_key(artist, title):
    """Title reduced to the song: no "Artist - " prefix, no "(Twin Ver.)"."""
    a, t = norm(artist), norm(title)
    t = re.sub(r"^" + re.escape(a) + r"\s*[-–]\s*", "", t)
    t = re.sub(r"[(\[](twin ver(sion|\.)|\d{4} remaster(ed)?)[)\]]", "", t)
    return re.sub(r"[^\w]+", " ", t).strip()


def same_song(a, b):
    """Same title and within 3 s of each other: a re-download of one file."""
    return a[0] == b[0] and abs(a[1] - b[1]) <= 3


def main():
    report = "--report" in sys.argv[1:]
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    rows = con.execute("SELECT id, path, artist, title, length FROM items").fetchall()

    members = defaultdict(list)
    unclassified = []
    missing = []
    seen = defaultdict(list)
    for item_id, raw_path, artist, title, length in rows:
        path = Path(raw_path.decode() if isinstance(raw_path, bytes) else raw_path)
        # beets stores paths relative to its library directory.
        path = MUSIC / path
        try:
            rel = path.relative_to(MUSIC)
        except ValueError:
            continue
        if rel.parts[0] in ("Audiobooks", "Playlists"):
            continue
        if not path.exists():
            missing.append(str(rel))
            continue
        tags, edit, genre = classify(artist, title, length or 0)
        for tag in tags:
            members[tag].append((norm(artist), norm(title), rel, length or 0))
        if not edit and genre is None:
            unclassified.append(f"{artist} — {title}")
        seen[song_key(artist, title)].append((length or 0, f"{item_id}: {rel}"))

    OUT_LIB.mkdir(parents=True, exist_ok=True)
    OUT_MPD.mkdir(parents=True, exist_ok=True)
    known = {name for name, _ in PLAYLISTS}
    for out in (OUT_LIB, OUT_MPD):
        for old in out.glob("*.m3u"):
            if old.stem in known or out == OUT_LIB:
                old.unlink()

    print(f"{len(rows)} tracks in library")
    for name, desc in PLAYLISTS:
        tracks = sorted(members.get(name, []))
        # One entry per song: drop re-downloads of the same upload.
        uniq, kept = [], []
        for a, t, rel, length in tracks:
            key = (song_key(a, t), length)
            if any(same_song(key, k) for k in kept):
                continue
            kept.append(key)
            uniq.append(rel)
        body = "#EXTM3U\n"
        (OUT_LIB / f"{name}.m3u").write_text(
            body + "".join(f"../{rel}\n" for rel in uniq), encoding="utf-8"
        )
        (OUT_MPD / f"{name}.m3u").write_text(
            "".join(f"{rel}\n" for rel in uniq), encoding="utf-8"
        )
        print(f"  {len(uniq):5}  {name:30} {desc}")

    dupes = []
    for entries in seen.values():
        entries.sort()
        group = [entries[0]]
        for prev, cur in zip(entries, entries[1:]):
            if cur[0] - prev[0] <= 3:
                group.append(cur)
            else:
                if len(group) > 1:
                    dupes.append([f for _, f in group])
                group = [cur]
        if len(group) > 1:
            dupes.append([f for _, f in group])
    if missing:
        # Usually Syncthing renaming an NFD (decomposed-accent) filename that
        # beets wrote to NFC behind beets' back: re-tag the item in NFC.
        print(f"WARNING: {len(missing)} library items have no file on disk (skipped):")
        for rel in missing:
            print(f"  {rel}")
    print(f"{len(unclassified)} original-looking tracks matched no genre (--report lists them)")
    print(f"{len(dupes)} likely duplicate groups (same title, length within 3 s; --report lists them)")
    if report:
        print("\n# Unclassified originals")
        for line in sorted(unclassified, key=str.casefold):
            print(f"  {line}")
        print("\n# Likely duplicates")
        for group in dupes:
            print("  " + "\n    ".join(group))


if __name__ == "__main__":
    main()
