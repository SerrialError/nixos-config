#!/usr/bin/env bash
# Polybar module: show whether the nixpkgs channel has advanced past the
# revision pinned in flake.lock. If it has, `nix flake update` / a rebuild
# would pull newer packages, so we surface that as "updates available".
#
# The channel branch (e.g. nixos-25.11) only advances after Hydra passes,
# so comparing the locked rev against the channel head is the right signal.
# Offline or on any error we stay silent rather than showing a false state.
set -euo pipefail

FLAKE_DIR="$HOME/git/nixos-config"
LOCK="$FLAKE_DIR/flake.lock"

[ -r "$LOCK" ] || exit 0

locked=$(jq -r '.nodes.nixpkgs.locked.rev' "$LOCK" 2>/dev/null || true)
ref=$(jq -r '.nodes.nixpkgs.original.ref' "$LOCK" 2>/dev/null || true)
if [ -z "$locked" ] || [ -z "$ref" ]; then
  exit 0
fi

latest=$(curl -fsSL --max-time 8 "https://channels.nixos.org/$ref/git-revision" 2>/dev/null || true)
# No network / bad response: don't render anything.
[ -n "$latest" ] || exit 0

if [ "$locked" = "$latest" ]; then
  # Up to date — render nothing to keep the bar clean.
  exit 0
fi

# Updates available.
echo "%{F#F0C674}%{F-} updates"
