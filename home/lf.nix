{ config, pkgs, ... }:

{
  # Nerd-font glyph map for lf's `icons` setting; without this file lf only
  # shows its plain built-in defaults.
  xdg.configFile."lf/icons".source = ./lf-icons;

  # File manager (lf) configuration
  programs.lf = {
    enable = true;
    commands = {
      dragon-out = ''%${pkgs.dragon-drop}/bin/xdragon -a -x "$fx"'';
      editor-open = "$$EDITOR $f";
      mkdir = ''
        ''${{
          printf "Directory Name: "
          read DIR
          mkdir $DIR
        }}
      '';
      delete = ''
        ''${{
          printf "$fx\n"
          printf "delete? [y/N] "
          read ans
          [ "$ans" = "y" ] && rm -rf $fx
        }}
      '';
    };

    keybindings = {
      "\\\"" = "";
      o = "";
      c = "mkdir";
      "." = "set hidden!";
      "`" = "mark-load";
      "\\'" = "mark-load";
      "<enter>" = "open";
      do = "dragon-out";
      D = "delete";
      "g~" = "cd";
      gh = "cd";
      "g/" = "/";
      ee = "editor-open";
      V = ''$${pkgs.bat}/bin/bat --paging=always --theme=gruvbox "$f"'';
    };

    settings = {
      preview = true;
      hidden = true;
      drawbox = true;
      icons = true;
      ignorecase = true;
    };

    extraConfig =
      let
        # Alacritty has no image protocol, so previews are text-only (pistol).
        previewer = pkgs.writeShellScriptBin "pv.sh" ''
          ${pkgs.pistol}/bin/pistol "$1"
        '';
      in
      ''
        set previewer ${previewer}/bin/pv.sh
      '';
  };
}
