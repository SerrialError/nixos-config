#!/usr/bin/env bash
# Polybar module: NVIDIA GPU temperature in Fahrenheit.
# nvidia-smi reports Celsius; we convert. The polybar user service has a
# minimal PATH, so call nvidia-smi by its stable system-profile path rather
# than relying on PATH. Silent on any error so the bar stays clean.
set -euo pipefail

smi=/run/current-system/sw/bin/nvidia-smi
[ -x "$smi" ] || exit 0

c=$("$smi" --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || true)
# Guard against non-numeric / empty output (driver asleep, error, etc).
[[ "$c" =~ ^[0-9]+$ ]] || exit 0

f=$((c * 9 / 5 + 32))
# %{F#..} is a polybar color tag; colour "GPU" in primary (#F0C674, mirrors
# colors.primary in home/polybar.nix) to match the yellow CPU/VOL labels.
# Emitting the label from the script (rather than a module format-prefix)
# keeps the module silent when nvidia-smi has no reading -- empty output hides
# the whole thing, prefix included.
echo "%{F#F0C674}GPU%{F-} ${f}°F"
