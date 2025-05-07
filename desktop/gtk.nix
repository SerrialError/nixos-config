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
    gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-theme-name = "adw-gtk3-dark";
      gtk-icon-theme-name = "Papirus-Dark";
      gtk-cursor-theme-name = "Bibata-Modern-Ice";
      gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
      gtk-menu-images = true;
      gtk-button-images = true;
      gtk-primary-button-warps-slider = false;
      gtk-enable-animations = true;
      gtk-enable-event-sounds = true;
      gtk-enable-input-feedback-sounds = true;
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle = "hintfull";
      gtk-xft-rgba = "rgb";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-theme-name = "adw-gtk3-dark";
      gtk-icon-theme-name = "Papirus-Dark";
      gtk-cursor-theme-name = "Bibata-Modern-Ice";
      gtk-primary-button-warps-slider = false;
      gtk-enable-animations = true;
      gtk-enable-event-sounds = true;
      gtk-enable-input-feedback-sounds = true;
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle = "hintfull";
      gtk-xft-rgba = "rgb";
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
    # GTK theme settings
    GTK_THEME = "adw-gtk3-dark";
    GTK2_RC_FILES = lib.mkForce "${pkgs.gnome-themes-extra}/share/themes/Adwaita/gtk-2.0/gtkrc:${pkgs.gnome-themes-extra}/share/themes/Adwaita-dark/gtk-2.0/gtkrc";
    GTK_DATA_PREFIX = lib.mkForce "${pkgs.gnome-themes-extra}";
    GTK_USE_PORTAL = "1";
    GTK_IM_MODULE = "ibus";
    GTK_MODULES = "gail:atk-bridge";
    
    # Icon theme settings
    XDG_ICON_THEME = "Papirus-Dark";
    GTK_ICON_THEME = "Papirus-Dark";
    ICON_THEME = "Papirus-Dark";
    
    # Cursor theme settings
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
    
    # QT theme settings
    QT_STYLE_OVERRIDE = "adwaita-dark";
    QT_QPA_PLATFORMTHEME = lib.mkForce "gtk";
    QT_STYLE = "adwaita-dark";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR = "1";
    QT_FONT_DPI = "96";
  };

  # Required packages for theming
  home.packages = with pkgs; [
    # GTK themes
    adw-gtk3
    gnome-themes-extra
    gtk3
    gtk4
    
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
    gsettings-desktop-schemas  # Required for GTK settings
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