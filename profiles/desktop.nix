# Shared graphical-desktop profile: i3 + polybar on X11, SDDM, PipeWire,
# docker/libvirt, the full desktop package set, and home-manager for connor.
# Imported by both hosts/desktop (NVIDIA workstation) and hosts/laptop.
# Host-specific bits (GPU driver, storage mounts, hostname, stateVersion,
# agenix identity) stay in each host's default.nix.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  isDesktop = config.networking.hostName == "nixos";
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    inherit (config.nixpkgs) config;
  };
  # t3code's vendored node-pty prebuild (pty.node) needs libstdc++ but has no
  # RPATH (the package sets dontPatchELF), so the backend crashes on start and
  # the desktop window never appears. Wrap the launchers with the C++ runtime
  # on LD_LIBRARY_PATH until nixpkgs#569702 (patchelf fix) lands; drop this
  # then. Re-wrapping the symlinkJoin avoids rebuilding t3code from source.
  t3code = pkgs-unstable.t3code.overrideAttrs (old: {
    buildCommand = old.buildCommand + ''
      for program in "$out/bin"/*; do
        wrapProgram "$program" --prefix LD_LIBRARY_PATH : ${
          pkgs-unstable.lib.makeLibraryPath [ pkgs-unstable.stdenv.cc.cc.lib ]
        }
      done
    '';
  });
  # Vencord 1.15.16 for Discord. Discord moved its web client to rspack on
  # 2026-11-04 and older Vencord (nixpkgs 26.05 and unstable ship 1.15.13)
  # breaks it: the window stays blank ("Uncaught TypeError: i.A is not a
  # constructor"). Mirrors nixpkgs master (19375cd, c4d1afc), which also drops
  # the stray fix-deps.patch; the pnpm deps hash differs from master's because
  # 26.05's pnpm differs. Drop this once 26.05 ships vencord >= 1.15.16.
  vencord = pkgs.vencord.overrideAttrs (
    finalAttrs: old: {
      version = "1.15.16";
      src = pkgs.fetchFromGitHub {
        owner = "Vendicated";
        repo = "Vencord";
        tag = "v${finalAttrs.version}";
        hash = "sha256-aUJubLJpyLAZWiOezqFxPY6oVPgWVPQpajFqrJvrO9U=";
      };
      patches = [ ];
      postPatch = "";
      env = old.env // {
        VENCORD_HASH = finalAttrs.version;
      };
      pnpmDeps = pkgs.fetchPnpmDeps {
        inherit (finalAttrs) pname src;
        pnpm = pkgs.pnpm_11;
        fetcherVersion = 4;
        hash = "sha256-1HcQH0ZZixQvziehIDhyBUB8v5ckufxrS2yUq2BcMVQ=";
      };
    }
  );
  # Always-on T3 Code server (home-manager user unit, desktop only), so phones
  # and other machines can reach it whether or not the desktop app is open.
  # Only one server may own ~/.t3, so this replaces the desktop app's own
  # backend: in the app, turn Settings -> "Local environment" OFF
  # (localEnvironmentEnabled = false in ~/.t3/userdata/desktop-settings.json)
  # and add this server as an environment from a `t3 pair` link. Never run
  # both against ~/.t3: the app's backend (desktop mode) doesn't check for an
  # existing owner.
  #
  # Upstream's `t3 service install` writes a near-identical unit but runs a
  # self-downloaded, self-updating runtime from ~/.t3/runtime; this runs the
  # Nix-managed t3code instead (upstream: "use Nix to update" Nix installs).
  # `t3 start` (unlike `t3 serve`) refuses to start while another server owns
  # the directory, so during the switch-over this just retries until the
  # app's backend is gone. Same address as the app's network-accessible mode
  # (0.0.0.0:3773; the firewall is off here), so paired devices keep working.
  t3codeService = {
    Unit = {
      Description = "T3 Code server (always on, for remote clients)";
      # Keep retrying while the desktop app's backend still owns ~/.t3.
      StartLimitIntervalSec = 0;
    };
    Service = {
      WorkingDirectory = "%h";
      # User units get a minimal PATH; agents need claude, nix, sudo wrappers,
      # etc. (git/gh/codex/rg come from the t3code wrapper itself).
      Environment = [
        "PATH=/run/wrappers/bin:%h/.nix-profile/bin:/etc/profiles/per-user/connor/bin:/run/current-system/sw/bin"
      ];
      ExecStart = "${t3code}/bin/t3 start --mode web --no-browser --host 0.0.0.0 --port 3773 --base-dir %h/.t3";
      Restart = "always";
      RestartSec = 15;
      # As upstream's unit: stop the server first and let it shut its agent
      # children down; one OOM-killed agent must not take the server with it.
      KillMode = "mixed";
      OOMPolicy = "continue";
    };
    Install.WantedBy = [ "default.target" ];
  };
  # Login theme, overridden per the sddm-astronaut NixOS docs. Background
  # points at a file the sddm-random-background service (below) refreshes
  # from ~/Pictures/wallpapers on every boot, so the login screen rotates
  # with the same pool as the in-session wallpaper script.
  sddm-astronaut = pkgs.sddm-astronaut.override {
    themeConfig = {
      Background = "/var/lib/sddm-background/background.png";
    };
  };
  # Claude Desktop from the claude-desktop flake input (built on its pinned
  # unstable). The FHS variant lets MCP servers launched via npx/uvx find
  # their runtimes; update with `nix flake update claude-desktop`. Chromium
  # picks its secret store from XDG_CURRENT_DESKTOP, and i3's "none+i3" makes
  # it fall back to plaintext (no saved sign-in), so point the launcher's
  # CLAUDE_PASSWORD_STORE knob at gnome-keyring explicitly.
  claude-desktop = pkgs.symlinkJoin {
    name = "claude-desktop";
    paths = [ inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-fhs ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude-desktop --set-default CLAUDE_PASSWORD_STORE gnome-libsecret
    '';
  };
in
{
  imports = [
    # agenix wiring, locale/tz, base packages, connor user, sshd baseline:
    ../modules/common.nix
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "electron-36.9.5"
    "electron-39.8.10"
    # CVE-2026-42052 is an XSS in beets' `web` plugin's page generation. We
    # use beets only as a CLI importer (see home/music.nix — no `web` plugin),
    # so the vulnerable surface is never served. Revisit when beets updates.
    "python3.13-beets-2.5.1"
  ];

  # Personal password notes (replaces ~/password.txt), user-readable only.
  # Shared by both graphical hosts so `pw` works on the desktop and the laptop;
  # the `laptop` host key is a recipient of passwords.age in secrets/secrets.nix.
  age.secrets.passwords = {
    file = ../secrets/passwords.age;
    owner = "connor";
    mode = "0400";
  };

  # Shared GitHub SSH key, decrypted to /run/agenix/github-ssh for connor.
  # One key for every graphical host (see secrets/secrets.nix) so git over SSH
  # works identically on desktop and laptop with nothing device-specific to
  # register — its public key just needs to be on the GitHub account once.
  age.secrets.github-ssh = {
    file = ../secrets/github-ssh.age;
    owner = "connor";
    mode = "0400";
  };

  # Use that shared key for github.com. IdentitiesOnly stops ssh from also
  # offering any other keys/agent identities. The trailing `Host *` resets
  # scope so nothing after this block (on the desktop, its own extraConfig for
  # the server key; the generated libvirt Include) is captured by the block.
  programs.ssh.extraConfig = ''
    Host github.com
      IdentityFile /run/agenix/github-ssh
      IdentitiesOnly yes

    Host *
  '';

  # UEFI boot on both machines. The desktop adds NVIDIA kernel params on top.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;
  # WiFi power save (on by default for both hosts' cards) parks incoming
  # packets at the AP until the next beacon/DTIM wake-up, adding 10-200 ms of
  # jitter to every SSH keystroke echo and VNC frame. Costs a little battery on
  # the laptop; worth it for interactive remote sessions.
  networking.networkmanager.wifi.powersave = false;
  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
    # rootless has its own package option; without this it defaults to
    # pkgs.docker (28.x), which nixpkgs now marks as unmaintained/insecure
    package = pkgs.docker_29;
  };
  virtualisation.libvirtd.enable = true;
  users.extraGroups.docker.members = [ "connor" ];

  # Bluetooth (and xpadneo, which forces it on) is laptop-only
  # (hosts/laptop/default.nix).

  # Cap the persistent journal (it had grown to 3+ GiB on the root disk).
  # The server sets its own SystemMaxUse in hosts/server/monitoring.nix.
  services.journald.extraConfig = "SystemMaxUse=1G";

  # Nightly fallback upgrade. flake.lock is bumped by CI (.github/workflows/
  # update-lock.yml) and only lands on main once all three hosts build, so
  # this fast-forwards the local checkout to origin/main and stages the result
  # with `boot`: it takes effect at the next reboot and never changes the
  # running session. The polybar "updates" button applies it immediately.
  # Skips (without failing) when the checkout has local edits, isn't on main,
  # or has unpushed commits, so it can't stage a half-finished config.
  system.autoUpgrade = {
    enable = true;
    operation = "boot";
    flake = "/home/connor/git/nixos-config#${
      if config.networking.hostName == "nixos" then "default" else config.networking.hostName
    }";
    # The eval reads the agenix-decrypted ssh-auth-keys (see modules/common.nix).
    flags = [ "--impure" ];
    # `--upgrade` refreshes nix-channels; the flake lock is the pin here.
    upgrade = false;
    dates = "04:00";
    randomizedDelaySec = "30min";
  };
  systemd.services.nixos-upgrade = {
    # Runs at boot when the 04:00 slot was missed (Persistent=), so keep it
    # out of the way of whatever the machine is doing.
    serviceConfig = {
      Nice = 19;
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
      ExecCondition =
        let
          check = pkgs.writeShellScript "nixos-upgrade-check" ''
            set -u
            repo=/home/connor/git/nixos-config
            git() { ${pkgs.util-linux}/bin/runuser -u connor -- ${pkgs.git}/bin/git -C "$repo" "$@"; }
            # Exit 1 = skip this run (ExecCondition), not a unit failure.
            [ "$(git symbolic-ref --short HEAD)" = main ] || { echo "checkout not on main; skipping"; exit 1; }
            [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "uncommitted changes; skipping"; exit 1; }
            # https, so the root-run unit needs no SSH key (the repo is public).
            git fetch --quiet https://github.com/SerrialError/nixos-config.git +main:refs/remotes/origin/main \
              || { echo "fetch failed; skipping"; exit 1; }
            git merge-base --is-ancestor HEAD origin/main || { echo "unpushed commits; skipping"; exit 1; }
          '';
        in
        "${check}";
    };
    preStart = ''
      ${pkgs.util-linux}/bin/runuser -u connor -- \
        ${pkgs.git}/bin/git -C /home/connor/git/nixos-config merge --ff-only --quiet origin/main
    '';
  };

  services.udisks2.enable = true;
  security.polkit.enable = true;
  security.polkit.adminIdentities = [
    "unix-group:wheel"
  ];
  # Enable Flatpak
  services.flatpak.enable = true;
  # i3 is not a full DE, so portal routing must be named explicitly.
  # `*` (= first matching backend) works with only gtk installed, but `gtk`
  # is the recommended value for a single-backend setup (portals.conf(5)).
  # NetworkMonitor is implemented by the xdg-desktop-portal *frontend* itself
  # (not gtk/kde) and is only used by sandboxed apps; native apps use GLib's
  # GNetworkMonitor → NetworkManager. Do not set GTK_USE_PORTAL=0 to "fix"
  # portal issues — that env is intentional (see home/gtk.nix).
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  security.rtkit.enable = true;
  services.printing = {
    enable = true;
    drivers = [ pkgs.hplip ];
    # Local printing only - not shared to the network.
    listenAddresses = [ "localhost:631" ];
    browsing = false;
    defaultShared = false;
    openFirewall = false;
  };
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true; # Enable JACK support
    wireplumber.enable = true; # Use wireplumber instead of media-session
  };

  # Disable PulseAudio since we're using PipeWire
  services.pulseaudio.enable = false;

  # Configure keymap in X11. videoDrivers is set per-host (NVIDIA on the
  # desktop; the laptop uses the modesetting default).
  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
    xkb.layout = "us";
    xkb.variant = "";
    # The xserver module pulls in xterm unconditionally; nothing here needs it
    # (i3 + text-file opening both use Alacritty).
    excludePackages = [ pkgs.xterm ];
  };
  services.displayManager = {
    defaultSession = "none+i3";
    sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm; # theme is Qt6; don't use the Qt5 sddm
      theme = "sddm-astronaut-theme";
      extraPackages = [ pkgs.kdePackages.qtmultimedia ]; # required by the theme
    };
  };

  # Copy a random wallpaper (jpg/png only — the greeter may lack other image
  # decoders) to the path the sddm theme reads as its background. Runs as root
  # before the display manager so it can read the user's Pictures and write
  # somewhere the sddm greeter can read.
  systemd.services.sddm-random-background = {
    description = "Pick a random SDDM login background";
    wantedBy = [ "display-manager.service" ];
    before = [ "display-manager.service" ];
    path = [
      pkgs.coreutils
      pkgs.findutils
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      dir=/home/connor/Pictures/wallpapers
      out=/var/lib/sddm-background
      [ -d "$dir" ] || exit 0
      mkdir -p "$out"
      pick="$(find "$dir" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
        ! -iname '*-gray.*' | shuf -n1)"
      if [ -n "$pick" ]; then
        install -m 0644 "$pick" "$out/background.png"
      fi
    '';
  };

  systemd.user.services."polkit-gnome-authentication-agent-1" = {
    description = "PolicyKit Authentication Agent";
    after = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  # base user (isNormalUser, zsh, wheel, authorized keys) comes from
  # modules/common.nix; the graphical hosts add these groups. Per-host
  # `description` is set in each host's default.nix.
  users.users.connor.extraGroups = [
    "networkmanager"
    "docker"
    "libvirtd"
    # Backlight write access (laptop): the udev rule in hosts/laptop grants the
    # video group g+w on /sys/class/backlight so polybar's scroll can adjust it.
    "video"
  ];

  home-manager = {
    useGlobalPkgs = true; # share the system nixpkgs (config + overlays) with HM
    useUserPackages = true; # install HM packages via /etc/profiles (standard on NixOS)
    extraSpecialArgs = { inherit inputs; };
    users = {
      "connor" = {
        imports = [ ../home.nix ];
        # Always-on T3 Code server; see the comment on t3codeService above.
        systemd.user.services.t3code = lib.mkIf isDesktop t3codeService;
      };
    };
    backupFileExtension = "backup";
  };

  # Desktop: start connor's user manager at boot, before anyone logs in, so
  # the always-on T3 Code server (t3codeService above) is reachable then too.
  users.users.connor.linger = lib.mkIf isDesktop true;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    obs-studio
    libreoffice
    gnucash
    heroic
    gdb
    polkit_gnome
    gimp
    vscode
    prismlauncher
    # grayjay is installed as a Flatpak (app.grayjay.Grayjay), not here: it is
    # unfree (Source First License) so it is never in the binary cache and would
    # recompile from source (.NET + npm frontend) on every version bump.
    cups-printers
    libnotify
    feh
    qimgv
    caligula # TUI disk imager (local ISO → USB); prefer over Impression
    mupdf
    protonup-ng
    obsidian
    libsecret
    gnome-keyring
    docker-compose
    qemu
    lxappearance
    # AI tools — all pulled from nixpkgs-unstable so they can be updated on their
    # own fast cadence (`nix flake update nixpkgs-unstable`) without bumping the
    # stable system; these CLIs/editors release very frequently. cursor-cli and
    # code-cursor aren't cached (quick binary repackage, not a compile); the rest
    # are cached in unstable.
    t3code # pkgs-unstable.t3code + libstdc++ wrapper (let-block above)
    pkgs-unstable.grok-cli
    pkgs-unstable.claude-monitor
    pkgs-unstable.cursor-cli
    pkgs-unstable.opencode
    pkgs-unstable.code-cursor
    claude-desktop # FHS variant + gnome-keyring wrapper (let-block above)
    github-desktop # git tooling (not AI); stable channel is fine
    openrocket
    chromium
    sddm-astronaut # the themeConfig-overridden theme from the let-block above
    pavucontrol
    # wow64 build (single 64-bit wine that runs 32-bit apps). We use this
    # rather than wineWowPackages.stable because upstream deprecated the classic
    # multilib set, so it is no longer in the binary cache and would recompile
    # from source (mingw cross-compile, tens of minutes) on every wine bump;
    # wineWow64Packages IS cached and downloads instead.
    wineWow64Packages.stable
    winetricks
    element-desktop
    dconf
    alsa-utils
    pkgs-unstable.pear-desktop # only packaged in nixpkgs-unstable
    nicotine-plus
    networkmanagerapplet
    proton-vpn # official Proton VPN GTK app; drives NetworkManager, session in gnome-keyring
    nlohmann_json
    glibc
    flameshot
    flex
    gcc-arm-embedded
    hugo
    dnsmasq
    go
    mpv
    nitch
    lutris
    # floorp-bin is installed by programs.floorp (home/floorp.nix), not here.
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    clang
    sioyek
    qalculate-qt
    age
    ssh-to-age
    bitwarden-desktop
    # Hardware acceleration is OFF (Discord Settings -> Advanced, stored as
    # enableHardwareAcceleration in ~/.config/discord/settings.json, not here):
    # on the NVIDIA 580 driver Discord's GPU process loses its EGL context
    # (EGL_CONTEXT_LOST in the journal) and Chromium falls back to software
    # anyway. It still renders with it on; retry after a Discord/driver bump.
    # (The blank window of 2026-11 was Vencord, not this; see `vencord` above.)
    (pkgs.discord.override {
      withOpenASAR = true;
      withVencord = true;
      inherit vencord;
    })
    mangohud
    xclip # Add xclip for clipboard support
    rofi # Add rofi for application launcher
    desktop-file-utils # Add desktop-file-utils for desktop database management
    adwaita-icon-theme # Add icon theme
    papirus-icon-theme # Add Papirus icon theme
    gtk3 # Add GTK3 for icon support
    pulseaudio # Add pulseaudio for pactl command
    mesa-demos

    # CLI essentials (ripgrep/fd/jq etc. live in modules/common.nix)
    fzf
    zoxide
    eza
    bat

    # Git / dev workflow
    lazygit
    delta # nicer git diffs

    # NixOS quality-of-life
    nix-output-monitor
    nvd # diff system generations after a rebuild
    nixfmt # formatter for this repo (nixfmt-rfc-style is now an alias of this)
    comma # run any nixpkgs binary once: `, <cmd>`

    # i3 / desktop control
    playerctl
    pamixer
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };
  programs.java.enable = true;
  programs.java.package = pkgs.jdk17; # or pkgs.oraclejdk18
  programs.steam.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  programs.seahorse.enable = true;

  programs.virt-manager.enable = true;

  # Run generic dynamically linked Linux binaries (e.g. T3 Code's downloaded
  # t3 runtime in ~/.t3/runtime), which expect /lib64/ld-linux-x86-64.so.2.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
  ];

  # List services that you want to enable:
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  # sddm has its own PAM service; without this the keyring isn't unlocked by
  # the login password and apps prompt "authentication required" after login
  security.pam.services.sddm.enableGnomeKeyring = true;

  services.dbus.enable = true;
  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images

  # Firewall off to match the desktop's LAN-trusted posture. Reconsider for a
  # laptop that roams onto untrusted networks.
  networking.firewall.enable = false;
}
