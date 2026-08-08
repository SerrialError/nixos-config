{ config, pkgs, ... }:

{
  imports = [
    ./alacritty.nix
    ./floorp.nix
    ./gtk.nix
    ./i3.nix
    ./lf.nix
    ./lockscreen.nix
    ./music.nix
    ./polybar.nix
    ./taskwarrior.nix
    ./tmux.nix
  ];
}
