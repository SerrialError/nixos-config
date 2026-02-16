# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      inputs.home-manager.nixosModules.default
      inputs.sops-nix.nixosModules.sops
    ];
  # Add additional storage mounts
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-label/storage";
    fsType = "ext4";
    options = [ "noatime" "nodiratime" "discard" ];
  };

  fileSystems."/mnt/nvme" = {
    device = "/dev/nvme0n1p1";
    fsType = "ext4";
    options = [ "noatime" "nodiratime" "discard" ];
  };
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/connor/.config/sops/age/keys.txt";
  sops.secrets.ssh-auth-keys = { 
    owner = "git";
    mode = "0440";  # Read-only for owner and group
  };
  
  # Make the secrets file available during evaluation
  nix.extraOptions = ''
    extra-sandbox-paths = ${builtins.path { path = ./secrets; name = "secrets"; }}
  '';

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
	"electron-36.9.5"
  ];
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "nixos"; # Define your hostname.
  # Enable networking
  networking.networkmanager.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
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
  security.polkit.debug = true;
  security.polkit.adminIdentities = [
    "unix-group:wheel"
  ];
  # Enable Flatpak
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common.default = "*";
    };
    configPackages = [ pkgs.xdg-desktop-portal-gtk ];
  };


  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  security.rtkit.enable = true;
  services.avahi = {
    enable = false;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };
  services.printing = {
    drivers = [ pkgs.hplip ];
    listenAddresses = [ "*:631" ];
    allowFrom = [ "all" ];
    browsing = true;
    defaultShared = true;
    openFirewall = true;
  };   
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;  # Enable JACK support
    wireplumber.enable = true;  # Use wireplumber instead of media-session
  };

  # Disable PulseAudio since we're using PipeWire
  services.pulseaudio.enable = false;

  # Configure keymap in X11
  services.xserver = {
    enable = true;
    videoDrivers = ["nvidia"];
    displayManager.lightdm.enable = true;
    windowManager.i3.enable = true;
    xkb.layout = "us";
    xkb.variant = "";
  };
  services.displayManager = {
    defaultSession = "none+i3";
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
    # powerManagement.enable = false;

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
  users.groups.git = {};
  users.users.git = {
    isSystemUser = true;
    group = "git";
    home = "/var/lib/git-server";
    createHome = true;
    shell = "${pkgs.git}/bin/git-shell";
    openssh.authorizedKeys.keyFiles = [
      config.sops.secrets.ssh-auth-keys.path
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

  users.users.connor = {
    isNormalUser = true;
    description = "connor-pc";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    openssh.authorizedKeys.keyFiles = [
      config.sops.secrets.ssh-auth-keys.path
    ];
  };
  users.users.nixosvmtest = {
    isNormalUser = true;
    createHome = true;
    description = "vm test";
    initialPassword = "test";
    shell = pkgs.bashInteractive;
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };
  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      "connor" = import ./home.nix;
      "nixosvmtest" = import ./home.nix;
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
	fastfetch
	tmux
	gdb
    polkit_gnome
    gimp
	vscode
    prismlauncher
    cups-printers
    kitty
    libnotify
    feh 
    mupdf
    protonup
    obsidian
	libsecret
	gnome-keyring
    libsForQt5.okular
    unzip
    docker-compose
    lxappearance
    openrocket
    libsForQt5.qt5.qtquickcontrols2   
    chromium
    libsForQt5.qt5.qtgraphicaleffects
    pavucontrol
    wineWowPackages.stable
    winetricks
	element-desktop
	dconf
    paraview
    mpi
    curlFull
    networkmanagerapplet
    blueman
    nlohmann_json
    glibc
    flameshot
    flex
    gcc-arm-embedded
    hugo
    killall
    go
    mpv
    nitch
    lutris
    code-cursor
    floorp
    sops
    clang
    age
    ssh-to-age
    bitwarden
    (pkgs.discord.override {
      # remove any overrides that you don't want
       withOpenASAR = true;
       withVencord = true;
     })       
    rsync
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    mangohud
    xclip  # Add xclip for clipboard support
    rofi    # Add rofi for application launcher
    desktop-file-utils  # Add desktop-file-utils for desktop database management
    adwaita-icon-theme  # Add icon theme
    papirus-icon-theme  # Add Papirus icon theme
    gtk3  # Add GTK3 for icon support
    pulseaudio  # Add pulseaudio for pactl command
    qemu
    quickemu
    btop-cuda
    glxinfo
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

  # Ensure Bash is available as a shell
  environment.shells = [ pkgs.bashInteractive ];
  
  # List services that you want to enable:
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    extraConfig = ''
        Match user git
        AllowTcpForwarding no
        AllowAgentForwarding no
        PasswordAuthentication no
        PermitTTY no
        X11Forwarding no
    '';
  };
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
