{ config, pkgs, ... }:

{
  imports = [
    ./alacritty.nix
    ./gtk.nix
    ./i3.nix
    ./lf.nix
    ./polybar.nix
    ./tmux.nix
  ];
}
