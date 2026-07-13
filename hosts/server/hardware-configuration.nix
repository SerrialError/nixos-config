# !!! PLACEHOLDER — NOT REAL HARDWARE CONFIG !!!
#
# Replace this entire file with the output of `nixos-generate-config`
# run on the server laptop during install:
#
#   nixos-generate-config --root /mnt
#   cp /mnt/etc/nixos/hardware-configuration.nix hosts/server/
#
# The filesystem below is a fake by-label device that only exists so the
# flake evaluates; deploying this file to real hardware will NOT boot.
# (The GRUB bootloader config lives in hosts/server/default.nix so it
# survives replacing this file.)
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
