#!/usr/bin/env bash
# Interactive update, launched in a terminal by clicking polybar's "updates"
# module: fast-forward the checkout to GitHub main, build, show the package
# diff, and switch only after confirmation. `host` (the flake attr) is
# prepended by home/polybar.nix.
set -euo pipefail

# sudo and nixos-rebuild live outside the polybar service's minimal PATH.
export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"
repo="$HOME/git/nixos-config"

# Keep the window open so errors can be read.
trap 'echo; read -rp "Press Enter to close." _' EXIT

cd "$repo"
echo "==> Fetching main"
git fetch --quiet https://github.com/SerrialError/nixos-config.git +main:refs/remotes/origin/main
if ! git merge --ff-only --quiet origin/main; then
  echo "Local checkout has diverged from main; resolve it, then run nrs."
  exit 1
fi
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "Note: building with uncommitted local changes:"
  git status --short --untracked-files=no
fi

echo "==> Building .#$host (sudo: the eval reads the root-only agenix keyfile)"
new=$(sudo nix build --impure --no-link --print-out-paths \
  ".#nixosConfigurations.$host.config.system.build.toplevel")

nvd diff /run/current-system "$new"
if [ "$(readlink -f /run/current-system)" = "$new" ]; then
  echo "Already running this generation."
  exit 0
fi

read -rp "Switch to this generation? [y/N] " answer
case "$answer" in
  [yY]*) ;;
  *) echo "Not switched."; exit 0 ;;
esac

# Re-evaluates, but builds nothing: the closure is already in the store.
sudo nixos-rebuild switch --flake ".#$host" --impure
echo "==> Done. A new kernel or driver only takes effect after a reboot."
