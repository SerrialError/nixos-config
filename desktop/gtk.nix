{ config, pkgs, lib, ... }:

{
  # GTK theme configuration
  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-theme-name = "adw-gtk3-dark";
      gtk-icon-theme-name = "Papirus-Dark";
      gtk-cursor-theme-name = "Bibata-Modern-Ice";
      gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
      gtk-menu-images = true;
      gtk-button-images = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-theme-name = "adw-gtk3-dark";
      gtk-icon-theme-name = "Papirus-Dark";
      gtk-cursor-theme-name = "Bibata-Modern-Ice";
    };
  };

  # QT theme configuration
  qt = {
    enable = true;
    platformTheme = {
      name = "gtk";
    };
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # Environment variables for consistent theming
  home.sessionVariables = {
    GTK_THEME = "adw-gtk3-dark";
    QT_STYLE_OVERRIDE = "adwaita-dark";
    QT_QPA_PLATFORMTHEME = lib.mkForce "gtk";
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
    # Icon theme settings
    XDG_ICON_THEME = "Papirus-Dark";
    GTK_ICON_THEME = "Papirus-Dark";
  };

  # Required packages for theming
  home.packages = with pkgs; [
    # GTK themes
    adw-gtk3
    
    # Icon themes
    papirus-icon-theme
    papirus-folders
    hicolor-icon-theme
    adwaita-icon-theme
    bibata-cursors
    
    # Qt themes
    adwaita-qt
    qt5.qtbase
    qt6.qtbase
    
    # Additional theming tools
    lxappearance  # GTK theme switcher
    libsForQt5.qt5ct  # Qt theme switcher
  ];

  # Create a script to customize Papirus folder colors
  home.file.".local/bin/customize-papirus-folders" = {
    text = ''
      #!/usr/bin/env bash
      # Customize Papirus folder colors to match the theme
      papirus-folders -C bluegrey --theme Papirus-Dark
    '';
    executable = true;
  };

  # Run the folder customization script when X session starts
  xsession.initExtra = ''
    $HOME/.local/bin/customize-papirus-folders
  '';
} 