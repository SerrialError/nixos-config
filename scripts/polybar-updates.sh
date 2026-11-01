#!/usr/bin/env bash
# Polybar module: show whether GitHub main pins a newer nixpkgs than the
# system that is currently running. CI (.github/workflows/update-lock.yml)
# only pushes a lock bump to main after every host builds with it, so
# "behind main" is the signal that a tested update is ready to apply.
# Click the module to apply it (scripts/system-update.sh).
#
# Only the nixpkgs input is compared; it's where security fixes land.
# Offline or on any error we stay silent rather than showing a false state.
set -euo pipefail

LOCK_URL="https://raw.githubusercontent.com/SerrialError/nixos-config/main/flake.lock"

# The running system's version, e.g. 26.05.20261028.08d3a97: the nixpkgs
# commit date and short rev. Read with builtins only — polybar's service PATH
# has no coreutils (which also rules out the `nixos-version` script).
version=$(</run/current-system/nixos-version) || exit 0
IFS=. read -r _ _ running_date running <<<"$version" || true
[ -n "${running:-}" ] && [ -n "${running_date:-}" ] || exit 0

locked=$(curl -fsSL --max-time 8 "$LOCK_URL" 2>/dev/null \
  | jq -r '.nodes.nixpkgs.locked | "\(.rev) \(.lastModified | strftime("%Y%m%d"))"' 2>/dev/null || true)
read -r latest latest_date <<<"$locked" || true
# No network / bad response: don't render anything.
[ -n "${latest:-}" ] && [ -n "${latest_date:-}" ] || exit 0

# A system built from a newer local lock than main's (a `nix flake update`
# not yet pushed) counts as up to date, not as having updates.
if [[ "$latest" == "$running"* ]] || [ "$running_date" -gt "$latest_date" ]; then
  # Up to date — plain text so the widget is visibly present/healthy.
  echo "%{F#B5BD68}Up to Date%{F-}"
  exit 0
fi

# Updates available — yellow label, mirroring the green up-to-date label above.
echo "%{F#F0C674}Updates Available%{F-}"
