# make-audiobook BOOK.epub [VOICE]
#
# Narrates an EPUB with audiblez (Kokoro TTS) on the GPU and files it as
# per-chapter MP3s under ~/Audiobooks/<Author>/<Title>/, which Syncthing
# carries to the server's Audiobookshelf. Deliberately outside ~/Music, so
# mpd / Navidrome never mix chapters into music. Bypasses beets on purpose:
# MusicBrainz / AcoustID / lastgenre have nothing useful to say about a TTS
# narration.
#
# One MP3 per chapter: Audiobookshelf treats the <Title> folder as one book
# and its files as chapters (ordered by the track-number prefix), and any
# plain player can still navigate them.
#
# Rendering is resumable: chapter WAVs are cached in ~/.cache/audiobooks and
# audiblez skips chapters that already exist, so re-running after an
# interruption picks up where it left off.

epub=$(realpath "${1:?usage: make-audiobook BOOK.epub [VOICE]}")
voice=${2:-af_heart}

tooldir=${XDG_DATA_HOME:-$HOME/.local/share}/uv/tools/audiblez
py=$tooldir/bin/python

# audiblez lives in a uv tool venv (pip wheels run via nix-ld). Torch is
# pinned to the cu126 build: the GTX 1080 is Pascal (sm_61) and newer CUDA
# builds of torch ship no kernels for it.
if [[ ! -x $py ]]; then
  echo "Installing audiblez (first run, ~3 GB)..."
  uv tool install --python 3.12 --python-preference only-managed audiblez \
    --with "torch==2.14.1+cu126" \
    --index https://download.pytorch.org/whl/cu126 --index-strategy unsafe-best-match
  # spaCy models that audiblez/misaki otherwise try to fetch with pip.
  for m in xx_ent_wiki_sm en_core_web_sm; do
    uv pip install --python "$py" \
      "$m @ https://github.com/explosion/spacy-models/releases/download/$m-3.8.0/$m-3.8.0-py3-none-any.whl"
  done
fi

# An inherited LD_LIBRARY_PATH (e.g. from a wrapped launcher) can pull in
# libraries built against a different glibc than our ffmpeg; drop it.
unset LD_LIBRARY_PATH
# libcuda.so comes from the NixOS driver, not the venv; Python calls only.
cuda_env=(env LD_LIBRARY_PATH=/run/opengl-driver/lib)

stem=$(basename "$epub" .epub)
render=${XDG_CACHE_HOME:-$HOME/.cache}/audiobooks/$stem-$voice
mkdir -p "$render"

# audiblez's final M4B step crashes (it unlinks a temp file it never made) and
# isn't used anyway, so its exit status says nothing about the chapter WAVs;
# the manifest step below checks those are all present instead.
"${cuda_env[@]}" "$tooldir/bin/audiblez" "$epub" -v "$voice" -c -o "$render" || true
rm -f "$render/$stem.m4b" "$render/cover" "$render/chapters.txt" "$render/cover.jpg"

# Print "author\ttitle" then one "wav\ttrack title" line per chapter, titles
# taken from the EPUB's table of contents.
manifest=$("${cuda_env[@]}" "$py" -I - "$epub" "$render" "$stem" "$voice" <<'EOF'
import re, sys
from pathlib import Path
import ebooklib
from ebooklib import epub

path, render, stem, voice = sys.argv[1:]
book = epub.read_epub(path, {"ignore_ncx": True})
meta = lambda k: (book.get_metadata("DC", k) or [[""]])[0][0]

titles = {}
def walk(toc):
    for entry in toc:
        if isinstance(entry, tuple):
            entry, children = entry
            walk(children)
        href = getattr(entry, "href", "").split("#")[0]
        # audiblez names WAVs after the item path with "/" -> "_".
        titles.setdefault(href.replace("/", "_"), entry.title)
walk(book.toc)

cover = next(iter(book.get_items_of_type(ebooklib.ITEM_COVER)), None) or next(
    (i for i in book.get_items_of_type(ebooklib.ITEM_IMAGE) if "cover" in i.get_name().lower()), None)
if cover:
    Path(render, "cover.jpg").write_bytes(cover.get_content())

print(f"{meta('creator') or 'Unknown Author'}\t{meta('title') or stem}")
pat = re.compile(re.escape(f"{stem}_chapter_") + rf"(\d+)_{re.escape(voice)}_(.+)\.wav$")
wavs = sorted((int(m[1]), m[2], p) for p in Path(render).glob("*.wav") if (m := pat.match(p.name)))

import contextlib
from audiblez.core import find_document_chapters_and_extract_texts, find_good_chapters
with contextlib.redirect_stdout(sys.stderr):  # stdout is the manifest
    expected = [c for c in find_good_chapters(find_document_chapters_and_extract_texts(book))
                if len(c.extracted_text.strip()) >= 10]
if len(wavs) != len(expected):
    sys.exit(f"Only {len(wavs)}/{len(expected)} chapters rendered; re-run to resume.")
for n, xhtml, p in wavs:
    print(f"{p}\t{titles.get(xhtml) or f'Chapter {n}'}")
EOF
)

IFS=$'\t' read -r author title <<<"$(head -1 <<<"$manifest")"
safe() { tr '/:' '--' <<<"$1"; }
dest="$HOME/Audiobooks/$(safe "$author")/$(safe "$title")"
mkdir -p "$dest"

cover="$render/cover.jpg"
cover_args=()
[[ -s $cover ]] && cover_args=(-i "$cover" -map 0:a -map 1:v -c:v copy -disposition:v attached_pic)

total=$(($(wc -l <<<"$manifest") - 1))
n=0
tail -n +2 <<<"$manifest" | while IFS=$'\t' read -r wav chapter; do
  n=$((n + 1))
  out=$(printf '%s/%02d %s.mp3' "$dest" "$n" "$(safe "$chapter")")
  [[ -s $out ]] && continue
  echo "Encoding $n/$total: $chapter"
  # 64k CBR mono: plenty for 24 kHz speech, and CBR keeps seeking exact in
  # streaming clients.
  ffmpeg -nostdin -loglevel error -y -i "$wav" \
    "${cover_args[@]}" \
    -c:a libmp3lame -b:a 64k -ac 1 -id3v2_version 3 \
    -metadata title="$chapter" -metadata album="$title" \
    -metadata artist="$author" -metadata album_artist="$author" \
    -metadata track="$n/$total" -metadata genre=Audiobook \
    "$out"
done
[[ -s $cover ]] && cp "$cover" "$dest/cover.jpg"

echo "Done: $dest"
echo "Chapter WAVs are cached in $render (safe to delete)."
