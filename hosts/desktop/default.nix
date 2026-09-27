# Desktop workstation: NVIDIA (Pascal GTX 1080 Ti), extra storage disks, and
# the git-shell server. The shared graphical config (i3, SDDM, packages,
# home-manager) lives in profiles/desktop.nix.
{
  config,
  lib,
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
  # noVNC web client plus a defaults.json (read by vnc.html) defaulting the
  # scaling mode to local scaling, so the whole desktop fits the browser window
  # instead of rendering 1:1 with scrollbars. "remote" would instead resize the
  # live X session itself, which we don't want for a shared desktop.
  #
  # The patch: on macOS/iOS noVNC sends an instant press+release for every key
  # pressed while Cmd is held (Apple drops those key-ups), Shift included — so
  # Cmd+Shift+p reached X as Super+p. Exempting Shift keeps it held, making
  # i3's $mod+Shift bindings work from the iPad (Cmd = $mod via x11vnc -remap).
  novnc = pkgs.novnc.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace core/input/keyboard.js --replace-fail \
        "code !== 'MetaLeft' && code !== 'MetaRight'" \
        "code !== 'MetaLeft' && code !== 'MetaRight' && code !== 'ShiftLeft' && code !== 'ShiftRight'"
    '';
  });
  novnc-web = pkgs.symlinkJoin {
    name = "novnc-web";
    paths = [
      "${novnc}/share/webapps/novnc"
      (pkgs.writeTextDir "defaults.json" (builtins.toJSON { resize = "scale"; }))
    ];
  };
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
  # Taskwarrior TaskChampion sync secret — a single
  # `sync.encryption_secret=<value>` line, `include`d by the taskrc (see
  # home/taskwarrior.nix). Kept out of programs.taskwarrior.config because that
  # is written to the world-readable nix store, and this repo is public. Owned
  # by connor so taskwarrior (a user process) can read it.
  age.secrets.task-sync-secret = {
    file = ../../secrets/task-sync-secret.age;
    owner = "connor";
  };
  # Browser remote desktop: x11vnc shares the live i3 session on :0 and noVNC
  # (websockify serving the web client) proxies to it. x11vnc binds 127.0.0.1
  # only; noVNC listens on all interfaces at :6080 so other LAN machines can
  # open http://<desktop>:6080/vnc.html (VNC password still required). User
  # services bound to graphical-session.target, so they start with the i3
  # session and inherit the XAUTHORITY home-manager's xsession imports into the
  # user manager (x11vnc runs as connor, no root/-auth guessing needed).
  age.secrets.vnc-password = {
    file = ../../secrets/vnc-password.age;
    owner = "connor";
    mode = "0400";
  };
  systemd.user.services.x11vnc = {
    description = "x11vnc sharing the live X session on :0 (localhost only)";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    unitConfig.ConditionUser = "connor";
    serviceConfig = {
      # -passwdfile reads the plaintext password from the file's first line;
      # -noipv6 keeps it off [::1]/[::] so 127.0.0.1:5900 is the only socket.
      # -remap applies only to VNC client input: noVNC on the iPad sends Cmd
      # (and Option) as Alt_L, so this makes Cmd act as i3's $mod (Super)
      # remotely while the desktop's own keyboard is untouched. Option isn't
      # usable as a modifier anyway — iPadOS composes Option+key into ∑/†/¡.
      # -nomodtweak injects keycodes as-is instead of adjusting Shift to match
      # the keysym: with Cmd held iOS reports the unshifted key ("p"), and
      # modtweak would lift the held Shift to type it, breaking $mod+Shift
      # bindings. Safe here since client and host are both US layouts.
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.x11vnc}/bin/x11vnc -display :0 -rfbport 5900"
        "-listen 127.0.0.1 -localhost -noipv6"
        "-passwdfile ${config.age.secrets.vnc-password.path}"
        "-remap Alt_L-Super_L -nomodtweak"
        "-forever -shared"
      ];
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
  systemd.user.services.novnc = {
    description = "noVNC web client + websockify proxy to x11vnc";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [
      "graphical-session.target"
      "x11vnc.service"
    ];
    unitConfig.ConditionUser = "connor";
    serviceConfig = {
      ExecStart = "${pkgs.python3Packages.websockify}/bin/websockify --web ${novnc-web} 0.0.0.0:6080 127.0.0.1:5900";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  # Cloudflare Tunnel `desk`: publishes the noVNC client above at
  # vnc.errormc.net (behind a Cloudflare Access policy). Outbound-only, so no
  # firewall ports. The credentials secret stays root-only: the module runs
  # cloudflared as a DynamicUser and passes the file in via LoadCredential.
  # No cert.pem — that's only needed to create/route tunnels, not run one.
  age.secrets.cloudflared-desk.file = ../../secrets/cloudflared-desk.age;
  services.cloudflared = {
    enable = true;
    tunnels."b5ad1cc1-2472-48fd-84bb-1ce63fd015b1" = {
      credentialsFile = config.age.secrets.cloudflared-desk.path;
      ingress."vnc.errormc.net" = "http://127.0.0.1:6080";
      default = "http_status:404";
    };
  };
  # noVNC for LAN clients. The profile currently disables the firewall, so this
  # only matters if it's re-enabled — kept so 6080 stays reachable then.
  networking.firewall.allowedTCPPorts = [ 6080 ];

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

    # Pin the 580 "Legacy" driver. As of NixOS 26.05 the default nvidia
    # package is 595.71.05, which DROPPED support for this Pascal GTX 1080 Ti
    # ("The 595.71.05 NVIDIA driver will ignore ... No NVIDIA GPU found" →
    # nvidia_modeset fails to load → X starts with no screen → SDDM shows a
    # bare console instead of the greeter). Pascal is now only supported by the
    # 580.xx branch. 25.11 still defaulted to 580, which is why it worked there.
    # Revisit if this card is retired or nixpkgs changes the legacy split.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
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
