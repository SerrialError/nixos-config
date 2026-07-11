# NixOS Configuration

This repository contains my personal NixOS configuration, featuring a customized desktop environment with i3-gaps window manager and Polybar.

## Features

- i3-gaps window manager with custom keybindings
- Polybar status bar with:
  - System tray
  - Workspace management
  - Window title display
  - Temperature monitoring
  - Volume control
  - Date/time display
- Custom GTK and Qt theming
- Random wallpaper selection on startup
- Neovim configuration with LSP support
- Various development tools and applications
- Automatic startup of system tray applications:
  - Network Manager (nm-applet)
  - Bluetooth Manager (blueman-applet)
  - Screenshot Tool (flameshot)

## Prerequisites

- NixOS installed on your system
- Flakes enabled in your Nix configuration
- Home Manager installed

## Installation

1. Clone this repository:
```bash
git clone https://github.com/SerrialError/nixos-config.git /home/connor/git/nixos-config
```

2. Apply the configuration:
```bash
sudo nixos-rebuild switch --flake /home/connor/git/nixos-config#default --impure
```

`--impure` is required because `users.users.*.openssh.authorizedKeys.keyFiles`
reads the agenix-decrypted `/run/agenix/ssh-auth-keys` at evaluation time.

## Configuration Structure

- `configuration.nix`: Main NixOS system configuration
- `home.nix`: Home Manager entrypoint for user-specific settings
- `hardware-configuration.nix`: Hardware-specific configuration
- `wm/`: Window manager modules (i3, polybar)
- `desktop/`: Desktop modules (GTK/Qt theming, lf file manager)
- `home/`: Additional home-manager modules (tmux)
- Neovim is configured via the `nvf` flake input under `programs.nvf` in `home.nix`

## Customization

To customize this configuration:

1. Modify `configuration.nix` for system-wide changes
2. Edit `home.nix` for user-specific settings
3. Add or modify modules in the `wm/`, `desktop/`, or `home/` directories

## Keybindings

- `Mod4 + Return`: Open terminal (Alacritty)
- `Mod4 + q`: Close window
- `Mod4 + Shift + p`: Application launcher (rofi)
- `Mod4 + Shift + d`: Launch Discord
- `Mod4 + Shift + f`: Launch Floorp browser
- `Mod4 + Shift + n`: Change to a random wallpaper

## License

This configuration is provided under the MIT License. Feel free to use and modify it for your own needs. 