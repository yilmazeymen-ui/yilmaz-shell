#!/bin/bash
# Duvar kağıtlarını listeler: her satır "tam_yol<TAB>önizleme_yolu".
# Önizleme, XDG thumbnail önbelleğidir (large/256px);
# önbellekte yoksa tam yol verilir (QML küçülterek okur).
# Sıra: find | sort.
DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers"
CACHE="${HOME}/.cache/thumbnails/large"

find "$DIR" -type f | sort | while IFS= read -r f; do
    uri="file://${f}"
    digest=$(printf '%s' "$uri" | md5sum | cut -d' ' -f1)
    thumb="${CACHE}/${digest}.png"
    if [ -f "$thumb" ]; then
        printf '%s\t%s\n' "$f" "$thumb"
    else
        printf '%s\t%s\n' "$f" "$f"
    fi
done
