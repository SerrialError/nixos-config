#!/usr/bin/env bash
# random-wallpaper.sh
# Pick a random wallpaper (skip files ending with -gray) and set it with feh.
# Also write the chosen original (non-gray) path to a runtime state file
# so the grayscale toggle knows what to grayify / restore.

set -eu

WALLPAPER_DIR="${1:-$HOME/Pictures/wallpapers}"
STATE_FILE="${XDG_RUNTIME_DIR:-$HOME/.cache}/feh-current-original"

PICOM_GRAY_FLAG="${XDG_RUNTIME_DIR:-/tmp}/picom-grayscale"   # used by grayscale toggle

# Find a random non-gray image
WALLPAPER="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
  \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
  ! -iname '*-gray.*' -print0 | shuf -n1 -z | tr -d '\0')"

if [ -z "$WALLPAPER" ]; then
  echo "No wallpaper found in $WALLPAPER_DIR" >&2
  exit 1
fi

# Write canonical original (non-gray) to state file
mkdir -p "$(dirname "$STATE_FILE")"
printf '%s\n' "$WALLPAPER" > "$STATE_FILE"

# Set wallpaper (if grayscale mode is OFF, this will be the visible wallpaper)
feh --bg-fill "$WALLPAPER"

# If grayscale mode is currently ON (picom shader state file exists),
# create or use the -gray file and set that instead so wallpaper remains gray.
if [ -f "$PICOM_GRAY_FLAG" ]; then
  # call helper inline to make gray and set it
  make_gray_and_set() {
    src="$1"
    if [ ! -f "$src" ]; then
      echo "Source wallpaper missing: $src" >&2
      return 1
    fi

    base="${src%.*}"
    ext="${src##*.}"
    gray="${base}-gray.${ext}"

    if [ ! -f "$gray" ]; then
      if ! command -v convert >/dev/null 2>&1; then
        echo "ImageMagick convert not found; cannot create gray wallpaper." >&2
        return 1
      fi
      echo "Creating gray wallpaper: $gray"
      if ! convert "$src" -colorspace Gray "$gray"; then
        echo "convert failed for $src" >&2
        return 1
      fi
    fi

    feh --bg-fill "$gray"
  }

  make_gray_and_set "$WALLPAPER" || true
fi

echo "Random wallpaper set: $WALLPAPER"
