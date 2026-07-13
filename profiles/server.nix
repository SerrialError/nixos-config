# Headless server profile: no GUI, hardened SSH, firewall on.
# openssh.enable + key-only auth already come from modules/common.nix.
{ ... }:

{
  services.openssh.settings.PermitRootLogin = "no";

  networking.firewall.enable = true;

  # It's a laptop acting as a server — closing the lid must not suspend it.
  services.logind.settings.Login.HandleLidSwitch = "ignore";
}
