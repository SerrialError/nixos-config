#!/usr/bin/env bash
# Polybar module: how many installed Flatpaks have an update available.
# Companion to polybar-updates.sh (which tracks the nixpkgs channel). The
# polybar user service has a minimal PATH, so flatpak/awk are put on PATH via
# runtimeInputs in home/polybar.nix. Offline or on any error we stay silent
# rather than render a false state.
set -euo pipefail

# No flatpak installed at all: nothing to report.
command -v flatpak >/dev/null 2>&1 || exit 0

# remote-ls --updates contacts each configured remote and lists the installed
# refs that have a newer commit available (one app id per line when piped, no
# header). A network failure or missing remote exits nonzero -> stay silent.
if ! out=$(flatpak remote-ls --updates --columns=application 2>/dev/null); then
  exit 0
fi

# Count non-blank lines. awk keeps this exit-0 (an empty list is a valid "0"),
# so it does not trip the offline guard above.
count=$(printf '%s\n' "$out" | awk 'NF{c++} END{print c+0}')

if [ "$count" -eq 0 ]; then
  # Up to date — green, mirroring polybar-updates.sh's "Up to Date" state.
  echo "%{F#B5BD68}Flatpak OK%{F-}"
else
  # Updates available — yellow, with the count so it's distinct from the
  # nixpkgs "Updates Available" label sitting next to it in the bar.
  echo "%{F#F0C674}Flatpak: $count%{F-}"
fi
