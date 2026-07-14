# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

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
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # home-manager module is already imported via flake.nix's modules list;
    # agenix wiring, locale/tz, base packages, connor user, sshd baseline:
    ../../modules/common.nix
  ];
  # Add additional storage mounts
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-label/storage";
    fsType = "ext4";
    options = [
      "noatime"
      "nodiratime"
      "discard"
    ];
  };

  fileSystems."/mnt/nvme" = {
    device = "/dev/nvme0n1p1";
    fsType = "ext4";
    options = [
      "noatime"
      "nodiratime"
      "discard"
    ];
  };
  age.identityPaths = [ "/home/connor/.config/sops/age/keys.txt" ];
  # secret file itself is declared in modules/common.nix; the desktop shares
  # it with the git-shell user
  age.secrets.ssh-auth-keys = {
    owner = "git";
    mode = "0440"; # Read-only for owner and group
  };
  # Personal password notes (replaces ~/password.txt). User-readable only.
  age.secrets.passwords = {
    file = ../../secrets/passwords.age;
    owner = "connor";
    mode = "0400";
  };
  # Laptop SSH identity (serrialerror@outlook.com). Deployed to /run/agenix so
  # the desktop's own ~/.ssh/id_ed25519 is left untouched; offered as extra
  # IdentityFiles below.
  age.secrets.laptop-id-ed25519 = {
    file = ../../secrets/laptop-id-ed25519.age;
    owner = "connor";
    mode = "0400";
  };
  age.secrets.laptop-id-rsa = {
    file = ../../secrets/laptop-id-rsa.age;
    owner = "connor";
    mode = "0400";
  };
  # Offer the laptop identities only to the home server, which trusts them.
  # Scoped to a Host block (not global) so they aren't tried against every
  # host — a global IdentityFile forces ssh to decrypt the passphrased RSA
  # key just to derive its public key on unrelated connections like GitHub.
  # Set via extraConfig so the runtime /run/agenix paths stay plain strings —
  # the path-typed knownHostsFiles/IdentityFile options would try to import them
  # into the store at eval, before agenix has deployed them.
  # The trailing `Host *` resets scope: NixOS prepends extraConfig to
  # ssh_config, so without it the generated lines that follow (e.g. the
  # libvirt ssh-proxy Include) would be captured by the Host block above.
  programs.ssh.extraConfig = ''
    Host 192.168.1.245
      IdentityFile ${config.age.secrets.laptop-id-ed25519.path}
      IdentityFile ${config.age.secrets.laptop-id-rsa.path}

    Host *
  '';

  nixpkgs.config.permittedInsecurePackages = [
    "electron-36.9.5"
    "electron-39.8.10"
  ];
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
  ];
  networking.hostName = "nixos"; # Define your hostname.
  # Enable networking
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

  # Configure keymap in X11
  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    windowManager.i3.enable = true;
    xkb.layout = "us";
    xkb.variant = "";
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
  # hardware.graphics = {
  # enable = true;                                 # turn on the NixOS OpenGL wrapper system
  # };
  hardware.nvidia = {

    # Modesetting is required.
    # modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = true;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    # powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    # nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    # package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
  # Define a user account. Don't forget to set a password with 'passwd'.
  users.groups.git = { };
  users.users.git = {
    isSystemUser = true;
    group = "git";
    home = "/var/lib/git-server";
    createHome = true;
    shell = "${pkgs.git}/bin/git-shell";
    openssh.authorizedKeys.keyFiles = [
      config.age.secrets.ssh-auth-keys.path
    ];
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
  # modules/common.nix; desktop-only groups and description here
  users.users.connor = {
    description = "connor-pc";
    extraGroups = [
      "networkmanager"
      "docker"
      "libvirtd"
    ];
  };
  users.users.nixosvmtest = {
    isNormalUser = true;
    createHome = true;
    description = "vm test";
    initialPassword = "test";
    shell = pkgs.bashInteractive;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
  };
  home-manager = {
    useGlobalPkgs = true; # share the system nixpkgs (config + overlays) with HM
    useUserPackages = true; # install HM packages via /etc/profiles (standard on NixOS)
    extraSpecialArgs = { inherit inputs; };
    users = {
      "connor" = import ../../home.nix;
      "nixosvmtest" = import ../../home.nix;
    };
    backupFileExtension = "backup";
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    obs-studio
    claude-monitor
    heroic
    gdb
    polkit_gnome
    gimp
    vscode
    prismlauncher
    cups-printers
    kitty
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
    paraview
    mpi
    alsa-utils
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
    quickemu
    btop-cuda
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

  # OpenSSH baseline (enable, key-only auth) comes from modules/common.nix;
  # the desktop only adds the git-shell restrictions.
  services.openssh.extraConfig = ''
    Match user git
    AllowTcpForwarding no
    AllowAgentForwarding no
    PasswordAuthentication no
    PermitTTY no
    X11Forwarding no
  '';
  services.dbus.enable = true;
  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images

  # Open ports in the firewall.
  networking.firewall.enable = false;
  # networking.firewall.allowedTCPPorts = [ 22 25565 8080 8443 22000 ];
  # networking.firewall.allowedUDPPorts = [ 22 25565 8080 8443 22000 21027 ];
  # Or disable the firewall altogether.

  # This value determines the NixOS release from which the default
  # settings for stateful data, like filen locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
