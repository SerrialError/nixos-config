{ config, pkgs, ... }:

{
  imports = [
    ./alacritty.nix
    ./gtk.nix
    ./i3.nix
    ./lf.nix
    ./music.nix
    ./polybar.nix
    ./tmux.nix
  ];
}
