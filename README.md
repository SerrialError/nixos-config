# NixOS Configuration

This repository contains my personal NixOS configuration, featuring a customized desktop environment with i3-gaps window manager and Polybar.

## Features

- i3-gaps window manager with custom keybindings
- Polybar status bar with:
  - System tray
  - Workspace management
  - Window title display
  - Battery status
  - Temperature monitoring
  - Volume control
  - Backlight control
  - Date/time display
- Custom GTK and Qt theming
- Random wallpaper selection on startup
- Neovim configuration with LSP support
- Various development tools and applications

## Prerequisites

- NixOS installed on your system
- Flakes enabled in your Nix configuration
- Home Manager installed

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/nixos-config.git /home/connor/git/nixos-config
```

2. Apply the configuration:
```bash
sudo nixos-rebuild switch --flake /home/connor/git/nixos-config#default
```

## Configuration Structure

- `configuration.nix`: Main NixOS system configuration
- `home.nix`: Home Manager configuration for user-specific settings
- `hardware-configuration.nix`: Hardware-specific configuration (not tracked in git)
- `features/`: Directory containing modular configuration components
- `nvim/`: Neovim configuration files

## Customization

To customize this configuration:

1. Modify `configuration.nix` for system-wide changes
2. Edit `home.nix` for user-specific settings
3. Add or modify modules in the `features/` directory

## Keybindings

- `Mod4 + Return`: Open terminal (Alacritty)
- `Mod4 + q`: Close window
- `Mod4 + Shift + p`: Run dmenu
- `Mod4 + Shift + d`: Launch Discord
- `Mod4 + Shift + f`: Launch Floorp browser

## License

This configuration is provided under the MIT License. Feel free to use and modify it for your own needs. 