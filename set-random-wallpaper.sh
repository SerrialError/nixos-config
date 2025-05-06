#!/usr/bin/env bash

# Get a random wallpaper from the wallpapers directory
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | shuf -n 1)

# Set the wallpaper using feh
if [ -n "$WALLPAPER" ]; then
    feh --bg-fill "$WALLPAPER"
fi 