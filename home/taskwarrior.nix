{ pkgs, ... }:

{
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;

    config = {
      news.version = "3.4.0";
      weekstart = "monday";
      dateformat = "Y-M-D";
      verbose = "blank,header,footnote,label,new-id,affected,edit,special,project,sync";
    };
  };

  home.packages = [
    pkgs.taskwarrior-tui
  ];
}
