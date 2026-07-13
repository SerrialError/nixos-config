# Home server: old x86_64 laptop running the website, Vaultwarden and
# Blocky behind Caddy. Deployed from the desktop (see README).
{ ... }:

{
  imports = [
    ./hardware-configuration.nix # PLACEHOLDER until generated on the laptop
    ../../modules/common.nix
    ../../profiles/server.nix
  ];

  networking.hostName = "server";

  # Old BIOS laptop -> GRUB on the disk MBR. Kept here (not in the
  # hardware-configuration.nix placeholder) so it survives replacing that
  # file with the generated one. Adjust the device if the install disk
  # isn't /dev/sda.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # Set at first install; do not change afterwards.
  system.stateVersion = "25.11";
}
