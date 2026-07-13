# Headless server profile: no GUI, hardened SSH, firewall on.
# openssh.enable + key-only auth already come from modules/common.nix.
{ ... }:

{
  services.openssh.settings.PermitRootLogin = "no";

  # Deploys push locally-built (unsigned) store paths over SSH; the receiving
  # user must be nix-trusted or the copy is rejected. The very first deploy
  # has to target root@ instead (this setting isn't live yet).
  nix.settings.trusted-users = [ "connor" ];

  networking.firewall.enable = true;

  # It's a laptop acting as a server — closing the lid must not suspend it.
  services.logind.settings.Login.HandleLidSwitch = "ignore";
}
