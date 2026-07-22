# NixOS Configuration

This repository contains my personal NixOS configurations:

- **`default`** — the desktop: i3-gaps + Polybar on X11/NVIDIA
- **`laptop`** — a laptop running the same graphical desktop as `default`,
  minus the NVIDIA driver, extra storage disks, and git-shell server
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

- `flake.nix`: inputs + `nixosConfigurations.{default,laptop,server}`
- `hosts/desktop/`: desktop system config (`default.nix`) + hardware scan
- `hosts/laptop/`: laptop system config; `hardware-configuration.nix` is the
  real laptop's scan (regenerate if the hardware changes — see below)
- `hosts/server/`: server system config; `hardware-configuration.nix` is a
  **placeholder** until generated on the real machine
- `modules/common.nix`: shared baseline for all hosts (nix gc/settings,
  locale/timezone, agenix wiring, `connor` user + SSH keys, base packages)
- `profiles/desktop.nix`: shared graphical desktop (i3/SDDM/PipeWire, the full
  package set, home-manager) imported by both `hosts/desktop` and `hosts/laptop`
- `profiles/server.nix`: headless profile (hardened SSH, firewall, lid ignore)
- `home.nix`: Home Manager entrypoint (desktop users only)
- `home/`: Home-manager modules (alacritty, GTK/Qt theming, i3, lf, polybar, tmux)
- `scripts/`: Wallpaper and picom-grayscale helper scripts (run from the live checkout)
- `secrets/`: agenix secrets + recipient rules (`secrets.nix`)
- Neovim is configured via the `nvf` flake input under `programs.nvf` in `home.nix`

## Server: one-time bootstrap

Dress-rehearsed against a quickemu VM on the `vm-test` branch; the numbers
below are the order that worked.

1. Install NixOS on the laptop from the **25.11** minimal ISO (partition,
   `nixos-install` with a throwaway config is fine — but match the release:
   live-switching across a systemd major version wedges
   `switch-to-configuration`). Make sure `services.openssh` is enabled and
   your key is authorized **for root as well as connor** — the first deploy
   has to run as `root@` (see step 6).
2. On the laptop: `nixos-generate-config` and copy the resulting
   `hardware-configuration.nix` over `hosts/server/hardware-configuration.nix`
   in this repo (replace the placeholder entirely). Check that
   `boot.loader.grub.device` in `hosts/server/default.nix` matches the install
   disk (and switch to systemd-boot instead if the machine boots EFI).
3. Grab the server's host key: `cat /etc/ssh/ssh_host_ed25519_key.pub`, paste
   it as the `server` recipient in `secrets/secrets.nix`, add `server` to the
   `publicKeys` of `ssh-auth-keys.age` and `vaultwarden-env.age`, then rekey:
   `cd secrets && agenix -r`.
4. Create the Vaultwarden secret: `cd secrets && agenix -e vaultwarden-env.age`
   (interactively — scripted `EDITOR`s corrupt the payload) with content
   `ADMIN_TOKEN=<random long string>`, then uncomment the
   `age.secrets.vaultwarden-env` block in `hosts/server/default.nix`.
5. Replace the placeholders: `PLACEHOLDER-DOMAIN` (Caddy/Vaultwarden domains,
   in `hosts/server/default.nix`) and `SERVER-IP-PLACEHOLDER` (the `srs` alias
   in `home.nix`).
6. First deploy from the desktop **as root**, activating via `boot` + reboot
   rather than a live switch (`nix.settings.trusted-users` isn't live yet, so
   a `connor@` push is rejected as unsigned; and a live switch drops the SSH
   session mid-activation):

   ```bash
   sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild boot \
     --flake .#server --impure --target-host root@<server-ip>
   ssh root@<server-ip> reboot
   ```
7. Every later deploy is just `srs` (see below); root SSH is disabled from now
   on by `profiles/server.nix`.

## Laptop: bootstrap

The `laptop` host is already deployed to the real laptop. These are the steps
that bootstrapped it (and how to re-do them if the machine is reinstalled or the
hardware changes) — the config is hardware-independent apart from
`hardware-configuration.nix` and the host-key recipient in `secrets/secrets.nix`.

1. Install NixOS on the laptop from the **25.11** minimal ISO. Enable
   `services.openssh` and authorize your desktop key **for root as well as
   connor** (the first deploy runs as `root@`).
2. On the laptop: `nixos-generate-config`, then copy the resulting
   `/etc/nixos/hardware-configuration.nix` over
   `hosts/laptop/hardware-configuration.nix` in this repo (replace it entirely).
   If the laptop has non-Intel/AMD graphics that need a specific driver, set
   `services.xserver.videoDrivers` in `hosts/laptop/default.nix` (it defaults to
   modesetting, which covers Intel/AMD and the test VM).
3. Grab the laptop's host key: `cat /etc/ssh/ssh_host_ed25519_key.pub`, paste it
   as the `laptop` recipient in `secrets/secrets.nix` (replacing the VM's key),
   then rekey: `cd secrets && agenix -r`.
4. First deploy from the desktop **as root**, activating via `boot` + reboot
   (a `connor@` push is rejected as unsigned until connor is nix-trusted, and a
   live switch across the systemd version from the install ISO can wedge
   activation):

   ```bash
   sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild boot \
     --flake .#laptop --impure --target-host root@<laptop-ip>
   ssh root@<laptop-ip> reboot
   ```
5. Later deploys go over SSH as connor (`--target-host connor@<laptop-ip>
   --sudo --ask-sudo-password`), or run `nixos-rebuild switch --flake .#laptop
   --impure` locally on the laptop.

## Deploying

From the desktop checkout:

- `nrb` / `nrs` — build / switch the desktop (`.#default`)
- `srb` — build the server closure locally (`.#server`)
- `srs` — build + deploy to the server over SSH
  (`--target-host connor@… --sudo --ask-sudo-password`)

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