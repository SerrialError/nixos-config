# NixOS Configuration

This repository contains my personal NixOS configurations:

- **`default`** — the desktop: i3-gaps + Polybar on X11/NVIDIA
- **`server`** — a headless laptop home server: Caddy (static site + reverse
  proxy), Vaultwarden, Blocky DNS blocking

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
- SDDM login screen (sddm-astronaut theme) with a random wallpaper each boot
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

## Repo layout

- `flake.nix`: inputs + `nixosConfigurations.{default,server}`
- `hosts/desktop/`: desktop system config (`default.nix`) + hardware scan
- `hosts/server/`: server system config; `hardware-configuration.nix` is a
  **placeholder** until generated on the real machine
- `modules/common.nix`: shared baseline for all hosts (nix gc/settings,
  locale/timezone, agenix wiring, `connor` user + SSH keys, base packages)
- `profiles/server.nix`: headless profile (hardened SSH, firewall, lid ignore)
- `home.nix`: Home Manager entrypoint (desktop users only)
- `home/`: Home-manager modules (alacritty, GTK/Qt theming, i3, lf, polybar, tmux)
- `scripts/`: Wallpaper and picom-grayscale helper scripts (run from the live checkout)
- `secrets/`: agenix secrets + recipient rules (`secrets.nix`)
- Neovim is configured via the `nvf` flake input under `programs.nvf` in `home.nix`

## Server: one-time bootstrap

1. Install NixOS on the laptop from the minimal ISO (partition, `nixos-install`
   with a throwaway config is fine). Make sure `services.openssh` is enabled
   and your key is authorized so you can reach it.
2. On the laptop: `nixos-generate-config` and copy the resulting
   `hardware-configuration.nix` over `hosts/server/hardware-configuration.nix`
   in this repo (replace the placeholder entirely). Check that
   `boot.loader.grub.device` in `hosts/server/default.nix` matches the install
   disk.
3. Grab the server's host key: `cat /etc/ssh/ssh_host_ed25519_key.pub`, paste
   it as the `server` recipient in `secrets/secrets.nix`, add `server` to the
   `publicKeys` of `ssh-auth-keys.age` and `vaultwarden-env.age`, then rekey:
   `cd secrets && agenix -r`.
4. Create the Vaultwarden secret: `cd secrets && agenix -e vaultwarden-env.age`
   with content `ADMIN_TOKEN=<random long string>`, then uncomment the
   `age.secrets.vaultwarden-env` block in `hosts/server/default.nix`.
5. Replace the placeholders: `PLACEHOLDER-DOMAIN` (Caddy/Vaultwarden domains,
   in `hosts/server/default.nix`) and `SERVER-IP-PLACEHOLDER` (the `srs` alias
   in `home.nix`).
6. First deploy from the desktop: `srs` (see below).

## Deploying

From the desktop checkout:

- `nrb` / `nrs` — build / switch the desktop (`.#default`)
- `srb` — build the server closure locally (`.#server`)
- `srs` — build + deploy to the server over SSH
  (`--target-host connor@… --use-remote-sudo`)

`--impure` (baked into the aliases) is required because authorized SSH keys
are read from the agenix-decrypted `/run/agenix/ssh-auth-keys` at eval time —
which is also why the aliases run under sudo.

## Keybindings

- `Mod4 + Return`: Open terminal (Alacritty)
- `Mod4 + q`: Close window
- `Mod4 + Shift + p`: Application launcher (rofi)
- `Mod4 + Shift + d`: Launch Discord
- `Mod4 + Shift + f`: Launch Floorp browser
- `Mod4 + Shift + n`: Change to a random wallpaper

## License

This configuration is provided under the MIT License. Feel free to use and modify it for your own needs. 