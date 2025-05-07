{ config, pkgs, lib, ... }:

{
  # GTK theme configuration
  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.solarc-gtk-theme;
      name = "SolArc-Dark";
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
      gtk-icon-theme-name = "SolArc-Dark";
      gtk-cursor-theme-name = "Bibata-Modern-Ice";
      gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
      gtk-menu-images = true;
      gtk-button-images = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-theme-name = "adw-gtk3-dark";
      gtk-icon-theme-name = "SolArc-Dark";
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
  };

  # Required packages for theming
  home.packages = with pkgs; [
    # GTK themes
    adw-gtk3
    solarc-gtk-theme
    bibata-cursors
    
    # Qt themes
    adwaita-qt
    qt5.qtbase
    qt6.qtbase
    
    # Additional theming tools
    lxappearance  # GTK theme switcher
    libsForQt5.qt5ct  # Qt theme switcher
  ];
} 