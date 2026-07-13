# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal NixOS system configuration as a flake. Two hosts:

- `nixosConfigurations.default` (hostname `nixos`) — the desktop: X11 with i3 + polybar on an NVIDIA (Pascal GTX 1080 Ti) machine. **Do not rename this output** — the `nrb`/`nrs` aliases use `.#default`.
- `nixosConfigurations.server` (hostname `server`) — a headless x86_64 laptop home server: Caddy (static site + Vaultwarden reverse proxy), Vaultwarden, Blocky DNS. Its `hosts/server/hardware-configuration.nix` is a **placeholder** until generated on the real machine; `PLACEHOLDER-DOMAIN` / `SERVER-IP-PLACEHOLDER` are meant to be search-and-replaced (see README bootstrap steps).

## Build / apply

```bash
# Apply system + home-manager config (also aliased as the zsh alias `nrs`)
sudo nixos-rebuild switch --flake /home/connor/git/nixos-config#default --impure

# Preview without switching (alias `nrb`)
sudo nixos-rebuild build --flake /home/connor/git/nixos-config#default --impure

# Server: build locally (alias `srb`) / deploy over SSH (alias `srs`)
sudo nixos-rebuild build --flake /home/connor/git/nixos-config#server --impure

# Update inputs
nix flake update            # all inputs
nix flake update nvf        # a single input (see nvf note below)
```

`--impure` is **required** for both hosts: `users.users.*.openssh.authorizedKeys.keyFiles` reads the agenix-decrypted `/run/agenix/ssh-auth-keys` at evaluation time (root-only, hence sudo). Rebuilds fail without it, and `nix flake check` cannot work (pure eval).

There is no test suite or linter — validation is `nixos-rebuild build` succeeding for **both** `.#default` and `.#server`.

## Architecture

- **`flake.nix`** — inputs and `nixosConfigurations.{default,server}`. home-manager is wired in as a NixOS module for the desktop only (not standalone), so `nixos-rebuild` applies both system and user config in one step; the server has no home-manager.
- **`modules/common.nix`** — baseline shared by all hosts: nix gc/optimise + flakes, allowUnfree, locale/timezone, agenix module + the `ssh-auth-keys` secret, base `connor` user (wheel, zsh, authorized keys), key-only sshd, core CLI packages. When adding config, put it here only if every host wants it.
- **`hosts/desktop/default.nix`** — all desktop system config (boot, hardware, services, `environment.systemPackages`, users). Also configures the `home-manager` block and the SDDM login screen (`sddm-astronaut` theme; a `sddm-random-background` systemd service copies a random `~/Pictures/wallpapers` image to `/var/lib/sddm-background/background.png` before the display manager starts).
- **`hosts/server/default.nix`** — server system config: GRUB (BIOS laptop), Caddy vhosts, Vaultwarden (localhost:8222, daily `backupDir` backup), Blocky on :53, firewall 80/443/53. The `age.secrets.vaultwarden-env` block stays commented until the secret exists (see README).
- **`profiles/server.nix`** — headless hardening: no root login, firewall on, lid switch ignored.
- **`home.nix`** — the home-manager entrypoint (desktop users). Imports `home/` and holds most user program config inline.
- **`home/`** — per-topic home-manager modules (`alacritty.nix`, `gtk.nix`, `i3.nix`, `lf.nix`, `polybar.nix`, `tmux.nix`), all imported via `home/default.nix`. `lf-icons` is the lf nerd-font glyph map deployed by `lf.nix`.
- **`scripts/`** — shell scripts run by absolute path from the live checkout (i3 keybindings / `xsession.initExtra` reference `$HOME/git/nixos-config/scripts/...`), plus the picom grayscale shader.
- **`secrets/`** — agenix secrets (`.age` files) and `secrets.nix` (recipient public keys).

### Two nixpkgs channels

Stable `nixos-25.11` is the default. `nixpkgs-unstable` is imported inside `hosts/desktop/default.nix` as `pkgs-unstable` (a manually-instantiated import that inherits the system's `nixpkgs.config`). Use `pkgs-unstable.<name>` to pull a single package from unstable (currently only `t3code`).

### home-manager sharing

`home-manager.useGlobalPkgs = true`, so the system's `nixpkgs.config` (allowUnfree, `permittedInsecurePackages`, overlays) is shared with home-manager — do **not** redefine nixpkgs config in `home.nix`. The same `home.nix` is imported for two users: `connor` (zsh, primary) and `nixosvmtest` (bash, VM test account).

### Editor

Neovim is managed by **nvf** (`inputs.nvf`), configured under `programs.nvf` in `home.nix` — not raw init.lua. There's a `vim.maps = { ... }` block of empty categories in that config: nvf's `vim.maps` → `vim.keymaps` migration shim reads every `vim.maps.*` sub-option (which upstream declares with no default) while resolving option priority, so eval **fails** unless all categories are defined. Defining them is what emits the "`vim.maps.*` deprecated" warnings on every rebuild — those are cosmetic and cannot be removed from config (verified: `mkForce`/empty-`keymaps` overrides don't help, because the read happens during priority discharge, before overrides apply). Leave the block until a future nvf gives `vim.maps.*` a `{}` default, then it can go.

## Secrets (agenix)

- Age identity on the desktop: `/home/connor/.config/sops/age/keys.txt` (`age.identityPaths` in `hosts/desktop`). The server uses agenix's default identity (its host SSH keys) — its host key must be added as a recipient and secrets rekeyed before first deploy.
- Recipients live in `secrets/secrets.nix`; edit/rekey secrets with the `agenix` CLI (installed in `systemPackages`) run from the `secrets/` dir.
- `ssh-auth-keys.age` decrypts to `/run/agenix/ssh-auth-keys`, used as `authorizedKeys.keyFiles` for the `connor` user on all hosts and the `git` (git-shell server) user on the desktop.
- `vaultwarden-env.age` (ADMIN_TOKEN for the server) is declared in `secrets.nix` but not yet created.

## Conventions

- The tree is formatted with **`nixfmt-rfc-style`** (installed in `systemPackages`). Run `nixfmt` on touched `.nix` files before committing so diffs stay clean.
- System-wide packages go in the host's `default.nix` (or `modules/common.nix` if all hosts want them); user-scoped program config goes in `home.nix` or a `home/` module.
- Theming is Gruvbox dark throughout (nix-colors `gruvbox-dark-medium`, rofi/zathura/nvf all set to match).
