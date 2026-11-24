#!/bin/bash

hyprshot -m region -o "$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
