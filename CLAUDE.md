# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal NixOS system configuration as a flake. Single host: `nixosConfigurations.default` (hostname `nixos`), an X11 desktop with i3 + polybar on an NVIDIA (Pascal GTX 1080 Ti) machine.

## Build / apply

```bash
# Apply system + home-manager config (also aliased as the fish abbr `nrs`)
sudo nixos-rebuild switch --flake /home/connor/git/nixos-config#default --impure

# Preview without switching
sudo nixos-rebuild build --flake /home/connor/git/nixos-config#default --impure

# Update inputs
nix flake update            # all inputs
nix flake update nvf        # a single input (see nvf workaround note below)
```

`--impure` is **required**: `users.users.*.openssh.authorizedKeys.keyFiles` reads the agenix-decrypted `/run/agenix/ssh-auth-keys` at evaluation time. Rebuilds fail without it.

There is no test suite or linter — validation is `nixos-rebuild build` succeeding.

## Architecture

- **`flake.nix`** — inputs and the single `nixosConfigurations.default`. home-manager is wired in as a NixOS module here (not standalone), so `nixos-rebuild` applies both system and user config in one step.
- **`configuration.nix`** — all system-level config (boot, hardware, services, `environment.systemPackages`, users). Also configures the `home-manager` block.
- **`home.nix`** — the home-manager entrypoint. Imports the per-topic modules and holds most user program config inline.
- **`wm/`** (`i3.nix`, `polybar.nix`), **`desktop/`** (`gtk.nix`, `lf.nix`) — topic modules imported by `home.nix`.
- **`secrets/`** — agenix secrets (`.age` files) and `secrets.nix` (recipient public keys).

Note: `home/` (`default.nix`, `tmux.nix`) is **not imported** by anything — it's dead/legacy. `home.nix` is the live user config.

### Two nixpkgs channels

Stable `nixos-25.11` is the default. `nixpkgs-unstable` is imported inside `configuration.nix` as `pkgs-unstable` (a manually-instantiated import that inherits the system's `nixpkgs.config`). Use `pkgs-unstable.<name>` to pull a single package from unstable (currently only `t3code`).

### home-manager sharing

`home-manager.useGlobalPkgs = true`, so the system's `nixpkgs.config` (allowUnfree, `permittedInsecurePackages`, overlays) is shared with home-manager — do **not** redefine nixpkgs config in `home.nix`. The same `home.nix` is imported for two users: `connor` (zsh, primary) and `nixosvmtest` (bash, VM test account).

### Editor

Neovim is managed by **nvf** (`inputs.nvf`), configured under `programs.nvf` in `home.nix` — not raw init.lua. There's a temporary `vim.maps = { ... }` workaround block in that config (a shim bug in the pinned nvf rev); the inline comment says to delete it after `nix flake update nvf`.

## Secrets (agenix)

- Age identity: `/home/connor/.config/sops/age/keys.txt` (`age.identityPaths`).
- Recipients live in `secrets/secrets.nix`; edit/rekey secrets with the `agenix` CLI (installed in `systemPackages`) run from the `secrets/` dir.
- `ssh-auth-keys.age` decrypts to `/run/agenix/ssh-auth-keys`, used as `authorizedKeys.keyFiles` for both the `connor` and the `git` (git-shell server) users.

## Conventions

- The tree is formatted with **`nixfmt-rfc-style`** (installed in `systemPackages`). Run `nixfmt *.nix wm/*.nix desktop/*.nix home/*.nix` before committing so diffs stay clean.
- System-wide packages go in `configuration.nix` (`environment.systemPackages`); user-scoped program config goes in `home.nix` or a `wm/`/`desktop/` module.
- Theming is Gruvbox dark throughout (nix-colors `gruvbox-dark-medium`, rofi/zathura/nvf all set to match).
