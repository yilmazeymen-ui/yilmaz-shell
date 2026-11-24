#!/bin/bash

BG_FILE="{{HOME}}/.config/hypr/vars/bg"

for _ in $(seq 1 20); do
    if hyprctl hyprpaper listactive >/dev/null 2>&1; then
        break
    fi
    sleep 0.25
done

BG=$(cat "$BG_FILE")

if [ -z "$BG" ]; then
    exit 0
fi

~/.config/hypr/scripts/apply_theme.sh "$BG"
