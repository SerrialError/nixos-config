#!/usr/bin/env bash
# picom-grayscale-toggle.sh
# Toggles picom grayscale shader (new --window-shader-fg interface) and
# switches wallpaper to an auto-created -gray copy when turning ON,
# and restores the original wallpaper when turning OFF.

set -eu

SHADER="$HOME/git/nixos-config/grayscale.glsl"
STATE_FILE_ORIG="${XDG_RUNTIME_DIR:-$HOME/.cache}/feh-current-original"
PICOM_GRAY_FLAG="${XDG_RUNTIME_DIR:-/tmp}/picom-grayscale"
PICOM_CMD="picom --backend glx"
# optional short delay to let pkill finish
KILL_DELAY=0.12

# helper: create gray copy of a source image and return path
create_gray() {
  src="$1"
  base="${src%.*}"
  ext="${src##*.}"
  gray="${base}-gray.${ext}"

  if [ -f "$gray" ]; then
    printf '%s' "$gray"
    return 0
  fi

  if ! command -v convert >/dev/null 2>&1; then
    echo "ImageMagick 'convert' not found; please install it." >&2
    return 1
  fi

  # create gray copy
  if convert "$src" -colorspace Gray "$gray"; then
    printf '%s' "$gray"
    return 0
  else
    echo "Failed to convert $src to gray" >&2
    return 1
  fi
}

# fallback: snapshot the root window to a temp PNG and return that path
snapshot_root_to_png() {
  tmp="$(mktemp --suffix=.png)"
  # require xwd and convert
  if ! command -v xwd >/dev/null 2>&1 || ! command -v convert >/dev/null 2>&1; then
    echo "xwd or convert missing; cannot snapshot root." >&2
    return 1
  fi
  # capture the root window (this will include panels if they exist)
  xwd -root -silent | convert xwd:- "$tmp"
  printf '%s' "$tmp"
}

# read canonical original wallpaper (non-gray) from state file if present
read_original() {
  if [ -f "$STATE_FILE_ORIG" ]; then
    read -r path < "$STATE_FILE_ORIG"
    [ -n "$path" ] && printf '%s' "$path" && return 0
  fi
  return 1
}

# stop existing picom
pkill -x picom 2>/dev/null || true
sleep "$KILL_DELAY"

if [ -f "$PICOM_GRAY_FLAG" ]; then
  # Currently ON -> turn OFF
  rm -f "$PICOM_GRAY_FLAG"

  # Restart picom plain
  $PICOM_CMD &

  # Restore original wallpaper (if we have it)
  if orig="$(read_original)"; then
    if [ -f "$orig" ]; then
      feh --bg-fill "$orig"
      echo "Wallpaper restored to original: $orig"
    else
      echo "Original wallpaper noted as $orig but file missing. Not restoring." >&2
    fi
  else
    echo "No recorded original wallpaper to restore." >&2
  fi

  echo "Grayscale: OFF"
  exit 0
else
  # Currently OFF -> turn ON
  # ensure shader exists
  if [ ! -f "$SHADER" ]; then
    echo "Grayscale shader not found at $SHADER" >&2
    # still continue to toggle wallpaper if possible
  fi

  touch "$PICOM_GRAY_FLAG"

  # Start picom with shader if shader exists, otherwise start picom normally
  if [ -f "$SHADER" ]; then
    $PICOM_CMD --window-shader-fg "$SHADER" &
  else
    $PICOM_CMD &
  fi

  # Try to read the original wallpaper file
  if orig="$(read_original)"; then
    if [ -f "$orig" ]; then
      # create or reuse gray copy
      if gray=$(create_gray "$orig"); then
        feh --bg-fill "$gray"
        echo "Wallpaper changed to gray: $gray"
      else
        echo "Failed to create gray from $orig; will not change wallpaper." >&2
      fi
    else
      echo "Recorded original $orig not found; taking root snapshot fallback." >&2
      if snap="$(snapshot_root_to_png)"; then
        if gray="$(create_gray "$snap")"; then
          feh --bg-fill "$gray"
          echo "Wallpaper set to grayscale snapshot: $gray"
        fi
      fi
    fi
  else
    # No recorded original; attempt to fallback to snapshot of the root window:
    echo "No recorded original wallpaper state; taking snapshot fallback." >&2
    if snap="$(snapshot_root_to_png)"; then
      if gray="$(create_gray "$snap")"; then
        feh --bg-fill "$gray"
        echo "Wallpaper set to grayscale snapshot: $gray"
      fi
    fi
  fi

  echo "Grayscale: ON"
  exit 0
fi
