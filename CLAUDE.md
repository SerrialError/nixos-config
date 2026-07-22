# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal NixOS system configuration as a flake. Three hosts:

- `nixosConfigurations.default` (hostname `nixos`) — the desktop: X11 with i3 + polybar on an NVIDIA (Pascal GTX 1080 Ti) machine. **Do not rename this output** — the `nrb`/`nrs` aliases use `.#default`.
- `nixosConfigurations.laptop` (hostname `laptop`) — a laptop running the same graphical desktop as `default` via the shared `profiles/desktop.nix`, minus the NVIDIA driver, storage mounts, and git-shell server (uses the modesetting driver). `hosts/laptop/hardware-configuration.nix` is the real laptop's scan (regenerate if the hardware changes — README "Laptop: bootstrap"). agenix decrypts with the machine's own SSH host key (no `age.identityPaths` override), so the `laptop` recipient in `secrets/secrets.nix` is that machine's host key; rekey if it is ever reinstalled.
- `nixosConfigurations.server` (hostname `server`) — a headless x86_64 laptop home server: Caddy (static site + Vaultwarden reverse proxy), Vaultwarden, Blocky DNS. Its `hosts/server/hardware-configuration.nix` is a **placeholder** until generated on the real machine; `PLACEHOLDER-DOMAIN` / `SERVER-IP-PLACEHOLDER` are meant to be search-and-replaced (see README bootstrap steps).

## Build / apply

```bash
# Apply system + home-manager config (also aliased as the zsh alias `nrs`)
sudo nixos-rebuild switch --flake /home/connor/git/nixos-config#default --impure

# Preview without switching (alias `nrb`)
sudo nixos-rebuild build --flake /home/connor/git/nixos-config#default --impure

# Laptop: build/switch the laptop config (no alias; deploy or run on the laptop)
sudo nixos-rebuild build --flake /home/connor/git/nixos-config#laptop --impure

# Server: build locally (alias `srb`) / deploy over SSH (alias `srs`)
sudo nixos-rebuild build --flake /home/connor/git/nixos-config#server --impure

# Update inputs
nix flake update            # all inputs
nix flake update nvf        # a single input (see nvf note below)
```

`--impure` is **required** for both hosts: `users.users.*.openssh.authorizedKeys.keyFiles` reads the agenix-decrypted `/run/agenix/ssh-auth-keys` at evaluation time (root-only, hence sudo). Rebuilds fail without it, and `nix flake check` cannot work (pure eval).

There is no test suite or linter — validation is `nixos-rebuild build` succeeding for `.#default`, `.#laptop`, and `.#server`.

### Note for Claude Code

`nixos-rebuild` needs `sudo` here (the `--impure` eval reads the root-only agenix keyfile), and `sudo` in this environment prompts for a password on an interactive TTY that Claude cannot answer — so **Claude cannot run `nrs`/`nrb`/`srb` or any `sudo nixos-rebuild` itself**; those will just hang or fail. Instead:

- **Validate changes without sudo** by evaluating the config directly, e.g. `nix eval --impure --expr '(builtins.getFlake "/home/connor/git/nixos-config").nixosConfigurations.default.config…'` (or the `home-manager.users.connor` attrs). This catches Nix eval errors, option typos, and lets you inspect the resulting values.
- **Hand the actual rebuild to the user** — after your edits evaluate cleanly, ask them to run `nrs` (or `nrb` to preview). Do not report a change as "done/working" based on your own build; you can't run one. Wait for the user to confirm the rebuild succeeded before committing.
- **Remote sudo *does* work.** The TTY limit above is specific to the local desktop. When driving another host over SSH, `echo "$PW" | ssh <host> 'sudo -S <cmd>'` works — `sudo -S` reads the password from stdin, no interactive TTY needed. So you *can* run remote rebuilds / `systemctl` on the laptop or server yourself.

### Bringing up a new host (gotchas)

See the README "Bringing up a new host" section for the full flow. The traps that cost time:

- **agenix keyFiles pre-seed.** On a *fresh* host the first `--impure` eval fails because `authorizedKeys.keyFiles` reads `/run/agenix/ssh-auth-keys` at eval time and that file doesn't exist until agenix has activated once. Break it by deploying from another machine as `root@` (`nixos-rebuild boot` + reboot), or pre-seed the decrypted key to `/run/agenix/ssh-auth-keys` (mode 0600) so the first local build can eval. `/run` is tmpfs — the seed vanishes on reboot and agenix recreates it from the host key.
- **Recipient + rekey before first deploy.** A new host can't decrypt any secret until its SSH *host public* key is a recipient in `secrets/secrets.nix` (and on the secret's `publicKeys`); then `cd secrets && agenix -r`. Host public keys are safe in this public repo; never commit private keys or decrypted payloads.
- **`connor` isn't nix-trusted until this config is live**, so a `connor@ --target-host` push to a stock machine is rejected as unsigned. First deploy as `root@` (or build locally on the target as root); `connor@` works after.
- **First activation: `boot` + reboot, not `switch`.** A live switch across the systemd major version from the install ISO can wedge `switch-to-configuration`, and it also drops the SSH session mid-activation.
- **Git-flake visibility.** `nixos-rebuild --flake .#…` on a git repo only sees tracked/staged files. A new `hosts/<host>/` or an edited `hardware-configuration.nix` that isn't `git add`ed is invisible to the build — `git add` before rebuilding.
- **X `inputClassSections` need an X restart.** X reads InputClass rules only at server start, so changes to `services.xserver.inputClassSections` apply only after a reboot or `systemctl restart display-manager` — a plain rebuild won't. X logs to journald here (`xserver-wrapper[…]`); grep it to confirm a device was matched/ignored.

## Architecture

- **`flake.nix`** — inputs and `nixosConfigurations.{default,laptop,server}`. home-manager is wired in as a NixOS module for the graphical hosts (desktop + laptop), not standalone, so `nixos-rebuild` applies both system and user config in one step; the server has no home-manager.
- **`modules/common.nix`** — baseline shared by all hosts: nix gc/optimise + flakes, allowUnfree, locale/timezone, agenix module + the `ssh-auth-keys` secret, base `connor` user (wheel, zsh, authorized keys), key-only sshd, core CLI packages. When adding config, put it here only if every host wants it.
- **`profiles/desktop.nix`** — the shared graphical desktop imported by both `hosts/desktop` and `hosts/laptop` (and it in turn imports `modules/common.nix`). Holds i3/SDDM/PipeWire, docker/libvirt, portals, the full `environment.systemPackages`, fonts, the `home-manager` block, and the SDDM login screen (`sddm-astronaut` theme; a `sddm-random-background` systemd service copies a random `~/Pictures/wallpapers` image to `/var/lib/sddm-background/background.png` before the display manager starts). `videoDrivers` is deliberately **not** set here — each host sets its own.
- **`hosts/desktop/default.nix`** — desktop-only config on top of the profile: NVIDIA driver + kernel params, the `/mnt/storage` and `/mnt/nvme` mounts, the git-shell server, quickemu SPICE wrappers + `btop-cuda`, `age.identityPaths` (the sops age key), hostname `nixos`, `stateVersion` 25.05.
- **`hosts/laptop/default.nix`** — laptop-only config on top of the profile: `hardware.graphics.enable`, touchpad (libinput), plain `quickemu`/`btop`/`brightnessctl`, hostname `laptop`, `stateVersion` 25.11. No `age.identityPaths` — agenix uses the host SSH key. `hardware-configuration.nix` is the real laptop's scan.
- **`hosts/server/default.nix`** — server system config: GRUB (BIOS laptop), Caddy vhosts, Vaultwarden (localhost:8222, daily `backupDir` backup), Blocky on :53, firewall 80/443/53. The `age.secrets.vaultwarden-env` block stays commented until the secret exists (see README).
- **`profiles/server.nix`** — headless hardening: no root login, firewall on, lid switch ignored.
- **`home.nix`** — the home-manager entrypoint (desktop users). Imports `home/` and holds most user program config inline.
- **`home/`** — per-topic home-manager modules (`alacritty.nix`, `gtk.nix`, `i3.nix`, `lf.nix`, `polybar.nix`, `tmux.nix`), all imported via `home/default.nix`. `lf-icons` is the lf nerd-font glyph map deployed by `lf.nix`.
- **`scripts/`** — shell scripts run by absolute path from the live checkout (i3 keybindings / `xsession.initExtra` reference `$HOME/git/nixos-config/scripts/...`), plus the picom grayscale shader.
- **`secrets/`** — agenix secrets (`.age` files) and `secrets.nix` (recipient public keys).

### Two nixpkgs channels

Stable `nixos-25.11` is the default. `nixpkgs-unstable` is imported inside `hosts/desktop/default.nix` as `pkgs-unstable` (a manually-instantiated import that inherits the system's `nixpkgs.config`). Use `pkgs-unstable.<name>` to pull a single package from unstable (currently only `t3code`).

### home-manager sharing

`home-manager.useGlobalPkgs = true`, so the system's `nixpkgs.config` (allowUnfree, `permittedInsecurePackages`, overlays) is shared with home-manager — do **not** redefine nixpkgs config in `home.nix`.

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
