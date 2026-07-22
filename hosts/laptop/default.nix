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
  ];

  networking.hostName = "laptop";

  # OpenGL wrapper for Intel/AMD (and the VM's virtio-gpu). The desktop leaves
  # this to the NVIDIA module; here we enable it directly.
  hardware.graphics.enable = true;

  # Touchpad support (harmless in the VM; real hardware on the laptop).
  services.libinput.enable = true;

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

  users.users.connor.description = "connor-laptop";

  # Fresh install from the 25.11-era channel; leave at first-install release.
  system.stateVersion = "25.11";
}
