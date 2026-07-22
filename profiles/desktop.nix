# Shared graphical-desktop profile: i3 + polybar on X11, SDDM, PipeWire,
# docker/libvirt, the full desktop package set, and home-manager for connor.
# Imported by both hosts/desktop (NVIDIA workstation) and hosts/laptop.
# Host-specific bits (GPU driver, storage mounts, hostname, stateVersion,
# agenix identity) stay in each host's default.nix.
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    inherit (config.nixpkgs) config;
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

  # UEFI boot on both machines. The desktop adds NVIDIA kernel params on top.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;
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

  # Enable Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  hardware.xpadneo.enable = true;
  services.blueman.enable = true;
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
      "connor" = import ../home.nix;
    };
    backupFileExtension = "backup";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    obs-studio
    libreoffice
    gnucash
    claude-monitor
    heroic
    gdb
    polkit_gnome
    gimp
    vscode
    prismlauncher
    grayjay
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
    pkgs-unstable.t3code
    # AI coding CLIs / git tooling
    cursor-cli
    opencode
    github-desktop
    pkgs-unstable.grok-cli # only packaged in nixpkgs-unstable
    openrocket
    chromium
    sddm-astronaut # the themeConfig-overridden theme from the let-block above
    pavucontrol
    wineWowPackages.stable
    winetricks
    element-desktop
    dconf
    alsa-utils
    pkgs-unstable.pear-desktop # only packaged in nixpkgs-unstable
    nicotine-plus
    networkmanagerapplet
    blueman
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
    code-cursor
    floorp-bin
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    clang
    sioyek
    qalculate-qt
    age
    ssh-to-age
    bitwarden-desktop
    (pkgs.discord.override {
      # remove any overrides that you don't want
      withOpenASAR = true;
      withVencord = true;
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
    nixfmt-rfc-style # formatter for this repo
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
    plugins = with pkgs.xfce; [
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
