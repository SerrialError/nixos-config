# Laptop: same graphical desktop as the workstation (profiles/desktop.nix) but
# without the NVIDIA driver, extra storage disks, or git-shell server. Uses the
# modesetting driver (works for the test VM's virtio-gpu and for Intel/AMD
# laptop graphics). agenix decrypts with the machine's own SSH host key — no
# age.identityPaths override, so the default host-key identity is used.
{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    # Shared graphical desktop (also pulls in modules/common.nix).
    ../../profiles/desktop.nix
    # On-demand WireGuard client to the home LAN.
    ./wireguard.nix
  ];

  networking.hostName = "laptop";

  # OpenGL wrapper for Intel/AMD (and the VM's virtio-gpu). The desktop leaves
  # this to the NVIDIA module; here we enable it directly.
  hardware.graphics.enable = true;

  # Touchpad support (harmless in the VM; real hardware on the laptop).
  services.libinput.enable = true;

  # Let the video group write panel brightness so polybar's backlight module
  # can scroll-to-adjust. /sys/class/backlight/*/brightness is root-owned by
  # default; this chgrps it to video and adds group-write on device add.
  # connor is in the video group (profiles/desktop.nix). brightnessctl (in the
  # i3 keybindings) works via logind and doesn't need this, but polybar writes
  # sysfs directly.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';

  # The built-in trackpad (I2C HID "CRQ1080…", exposed as both a Touchpad and a
  # Mouse node) is physically broken and fires spurious input, so tell X to
  # ignore both of its nodes. The external USB mouse and keyboard are unaffected.
  services.xserver.inputClassSections = [
    ''
      Identifier "disable-broken-trackpad"
      MatchProduct "CRQ1080"
      Option "Ignore" "on"
    ''
  ];

  # Local VM management, same as the desktop but without the NVIDIA SPICE
  # workaround wrappers (plain quickemu works on non-NVIDIA graphics).
  environment.systemPackages = with pkgs; [
    quickemu
    quickgui
    btop # plain btop (no CUDA; the desktop uses btop-cuda for its NVIDIA GPU)
    brightnessctl # backlight control (bound in i3 on the real laptop)
  ];

  # Close the lid -> suspend, on battery or AC. The in-session locker
  # (home/lockscreen.nix: xss-lock + betterlockscreen) registers a logind sleep
  # inhibitor, so the screen locks *before* the machine sleeps and the laptop
  # demands the password on resume. Contrast the server, which ignores the lid.
  #
  # HoldoffTimeoutSec: after every resume logind ignores lid events for this
  # long (systemd default 30s, intended for dock detection). At the 30s default,
  # closing the lid again within half a minute of waking did nothing — no
  # suspend, no lock — so a quick close/reopen left the desktop unlocked. Shrink
  # it to 2s so a second lid-close reliably suspends-and-locks; 2s still covers a
  # spurious lid event fired at the instant of resume.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HoldoffTimeoutSec = "2s";
  };

  # Laptop power management (Intel). powerManagement.enable pulls in the suspend
  # hooks; thermald does Intel thermal throttling; upower exposes battery state
  # (polybar/notifications); TLP tunes CPU scaling per AC/battery for battery
  # life. TLP owns cpufreq here, so don't also set powerManagement.cpuFreqGovernor.
  powerManagement.enable = true;
  services.thermald.enable = true;
  services.upower.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
    };
  };

  users.users.connor.description = "connor-laptop";

  # Keep connor's user manager (user@1000.service) running even when nobody is
  # logged into the GUI, so the home-manager Syncthing service syncs whenever
  # the laptop is powered on -- not only while someone is logged in. Without
  # this, at the SDDM greeter user@1000 tears down and the desktop sees the
  # laptop as a disconnected Syncthing peer. (The desktop doesn't need this: it
  # stays logged into i3, so its user manager is always alive.)
  users.users.connor.linger = true;

  # Fresh install from the 25.11-era channel; leave at first-install release.
  system.stateVersion = "25.11";
}
