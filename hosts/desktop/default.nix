# Desktop workstation: NVIDIA (Pascal GTX 1080 Ti), extra storage disks, and
# the git-shell server. The shared graphical config (i3, SDDM, packages,
# home-manager) lives in profiles/desktop.nix.
{
  config,
  pkgs,
  ...
}:

let
  # quickemu's default gtk display shows a black screen on this NVIDIA box, so
  # default it to SPICE. Wrapping the package (rather than a shell alias) also
  # covers quickgui, which shells out to the quickemu binary directly. An
  # explicit --display still wins: quickemu's arg loop keeps the last one seen.
  quickemu-spice = pkgs.symlinkJoin {
    name = "quickemu-spice";
    paths = [ pkgs.quickemu ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/quickemu --add-flags "--display spice"
    '';
  };
  # quickgui bakes quickemu's store path into its PATH, so it ignores the
  # systemPackages swap above; override its quickemu input to the wrapper too.
  quickgui-spice = pkgs.quickgui.override { quickemu = quickemu-spice; };
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Shared graphical desktop (also pulls in modules/common.nix).
    ../../profiles/desktop.nix
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
  # Dedicated key for deploying to / logging into the home server, generated
  # locally as ~/.ssh/id_server_ed25519 (passphrase-protected). Scoped to the
  # server Host block so it isn't offered to unrelated hosts like GitHub;
  # IdentitiesOnly stops ssh from also trying the desktop's default key here.
  # Absolute path (not ~) because `srs` runs nixos-rebuild under sudo, so
  # ssh runs as root and ~ would resolve to /root/.ssh where the key isn't;
  # with IdentitiesOnly that would block the agent key and fail with
  # "Permission denied (publickey)". The agent key still matches via the .pub.
  # The trailing `Host *` resets scope: NixOS prepends extraConfig to
  # ssh_config, so without it the generated lines that follow (e.g. the
  # libvirt ssh-proxy Include) would be captured by the Host block above.
  programs.ssh.extraConfig = ''
    Host 192.168.1.245
      IdentityFile /home/connor/.ssh/id_server_ed25519
      IdentitiesOnly yes

    Host *
  '';

  # Bootloader EFI settings come from the shared profile; NVIDIA needs its
  # temp-file path on a writable fs for suspend/resume VRAM save.
  boot.kernelParams = [
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
  ];
  networking.hostName = "nixos"; # Define your hostname.

  # NVIDIA proprietary driver for the GTX 1080 Ti.
  services.xserver.videoDrivers = [ "nvidia" ];
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

  # Desktop-only git-shell server: hosts bare repos, reachable over SSH.
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

  # desktop-only groups (docker/libvirt/networkmanager come from the profile)
  users.users.connor.description = "connor-pc";

  # Quickemu SPICE wrappers (NVIDIA black-screen workaround, see let-block);
  # btop-cuda for GPU monitoring on the 1080 Ti (pulls CUDA — NVIDIA-only).
  environment.systemPackages = [
    quickgui-spice
    quickemu-spice
    pkgs.btop-cuda
  ];

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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like filen locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
