# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      inputs.home-manager.nixosModules.default
      inputs.nix-minecraft.nixosModules.minecraft-servers
      inputs.sops-nix.nixosModules.sops
    ];
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
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sdb";
  boot.loader.grub.useOSProber = true;
  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
  users.extraGroups.docker.members = [ "connor" ];

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
    enable = true;
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
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  # Configure keymap in X11
  services.xserver = {
    videoDrivers = ["nvidia"];
    enable = true;
    windowManager.i3.enable = true;
    xkb.layout = "us";
    xkb.variant = "";
  };
  services.displayManager = {
    sddm.enable = true;
    sddm.theme = "${import ./sddm-theme.nix { inherit pkgs; }}";
    defaultSession = "none+i3";
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.groups.git = {};
  users.users.git = {
    isSystemUser = true;
    group = "git";
    home = "/var/lib/git-server";
    createHome = true;
    shell = "${pkgs.git}/bin/git-shell";
    # The authorized keys will be managed by the systemd service
  };

  # Create a systemd service to set up the authorized keys
  systemd.services.git-authorized-keys = {
    description = "Set up Git user's authorized keys";
    wantedBy = [ "multi-user.target" ];
    after = [ "sops-nix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "git";
      Group = "git";
    };
    script = ''
      # Create .ssh directory if it doesn't exist
      mkdir -p /var/lib/git-server/.ssh
      chmod 700 /var/lib/git-server/.ssh

      # Copy the authorized keys file
      cp ${config.sops.secrets.ssh-auth-keys.path} /var/lib/git-server/.ssh/authorized_keys
      chmod 600 /var/lib/git-server/.ssh/authorized_keys
    '';
  };

  users.users.connor = {
    isNormalUser = true;
    description = "connor-pc";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };
  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      "connor" = import ./home.nix;
    };
    useGlobalPkgs = false;  # Changed to false to allow nixpkgs configuration
    backupFileExtension = "backup";
  };
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
	# accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    # PROS CLI
    (python3Packages.buildPythonPackage rec {
      pname = "pros-cli";
      version = "3.5.5";
      doCheck = false;

      nativeBuildInputs = with python3Packages; [
        pip
        setuptools
        wheel
      ];
      propagatedBuildInputs = with python3Packages; [
        jsonpickle
        pyserial
        tabulate
        cobs
        click
        rich-click
        cachetools
        requests-futures
        semantic-version
        colorama
        pyzmq
        sentry-sdk
        pypng
      ];
      src = fetchFromGitHub {
        owner = "purduesigbots";
        repo = pname;
        rev = "${version}";
        sha256 = "sha256-Lw3NJaFmJFt0g3N+jgmGLG5AMeMB4Tqk3d4mPPWvC/c=";
      };
      postInstall = ''
        echo "${version}" > $out/lib/python3.12/site-packages/version
      '';
    })
    vscode
    prismlauncher
    cups-printers
    nodejs
    obsidian 
    unzip
    docker-compose
    geoclue2
    lxappearance
    openrocket
    libsForQt5.qt5.qtquickcontrols2   
    chromium
    libsForQt5.qt5.qtgraphicaleffects
    pavucontrol
    wineWowPackages.stable
    dconf
    python3Full
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
    stdenv.cc.cc.lib
    gnumake
    cmake
    killall
    mpv
    obs-studio
    python3Packages.pip
    lutris
    code-cursor
    heroic
    floorp
    gcc
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
    alacritty
    mangohud
    xclip  # Add xclip for clipboard support
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };      
  programs.thunar.enable = true;
  programs.steam.enable = true;
  # Ensure Bash is available as a shell
  environment.shells = [ pkgs.bashInteractive ];

  # Configure bash aliases and interactive shell settings
  programs.bash = {
    interactiveShellInit = ''
      alias pros-devshell="nix develop .#default"
    '';
  };
  # List services that you want to enable:

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
  services.minecraft-servers = {
    enable = false;
    eula = true;
    dataDir = "/var/lib/mcservers";

    servers = {
      test-server = {
        enable = true;
        package = pkgs.paperServers.paper-1_21_3;
      };
    };
  };

  # Open ports in the firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 25565 8080 8443 ];
  networking.firewall.allowedUDPPorts = [ 22 25565 8080 8443 ];
  # Or disable the firewall altogether.

  # This value determines the NixOS release from which the default
  # settings for stateful data, like filen locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
