#!/bin/bash
# ============================================================
#  gen_dominant.sh — Palet dosyasına DOMINANT (ana renk) ekler/günceller
#
#  Kullanım:
#    gen_dominant.sh <palette.sh>          → o palete dominant işler
#    gen_dominant.sh --all                 → tüm paletleri tara
#
#  Palet dosyasındaki "Duvar kağıdı: <yol>" satırından kağıdı bulur,
#  PIL ile 64x64 küçültüp kuantalayıp en "ağırlıklı" rengi seçer:
#  skor = piksel sayısı × (0.15 + doygunluk) — renksiz gölge/göz kütleleri
#  leke yapmasın diye doygunluk kayar. Sonuç palet dosyasına
#  DOMINANT='#RRGGBB' olarak yazılır (yoksa FOREGROUND'dan sonrasına eklenir).
# ============================================================
set -euo pipefail

PALETTES_DIR="${HOME}/.config/hypr/vars/palettes"

process_palette() {
    local PF="$1"
    local WP
    # "Duvar kağıdı: <yol>" satırından kaynak kağıdı bul
    WP=$(sed -n 's/^#  Duvar kağıdı: //p' "$PF" | head -1)
    if [ -z "$WP" ] || [ ! -f "$WP" ]; then
        echo "Atlandı (kağıt bulunamadı): $PF — '$WP'" >&2
        return 0
    fi

    local DOM
    DOM=$(python3 - "$WP" <<'PY'
import colorsys, sys
from PIL import Image

img = Image.open(sys.argv[1]).convert("RGB")
img.thumbnail((64, 64))
counts = {}
for r, g, b in img.getdata():
    r8, g8, b8 = r >> 4, g >> 4, b >> 4          # 4 bit/kanal kuantalama
    key = (r8, g8, b8)
    h, s, v = colorsys.rgb_to_hsv(r8 / 15, g8 / 15, b8 / 15)
    counts[key] = counts.get(key, 0) + 1

import colorsys
# Adaylar: rengi temsil edebilecek kovalar (koyu gölge + soluk gri elenir)
cand = []
for key, c in counts.items():
    h, s, v = colorsys.rgb_to_hsv(key[0] / 15, key[1] / 15, key[2] / 15)
    if s >= 0.10 and 0.22 <= v <= 0.97:
        cand.append((c, key))
if cand:
    # Adaylar içinde: en sık + doygunluk bonusu (ufak ama renkli öbekleri öne alır)
    best, best_score = None, -1.0
    for c, key in cand:
        h, s, v = colorsys.rgb_to_hsv(key[0] / 15, key[1] / 15, key[2] / 15)
        score = c * (0.7 + s)
        if score > best_score:
            best, best_score = key, score
else:
    # Tamamen koyu/soluk imaj: genel ağırlıklı en iyisi
    best, best_score = None, -1.0
    for key, c in counts.items():
        h, s, v = colorsys.rgb_to_hsv(key[0] / 15, key[1] / 15, key[2] / 15)
        score = c * s * v
        if score > best_score:
            best, best_score = key, score

print("#{:02X}{:02X}{:02X}".format(best[0] << 4, best[1] << 4, best[2] << 4))
PY
)

    if [ -z "$DOM" ]; then
        echo "Uyarı ($PF): ana renk hesaplanamadı, dosya değişmedi" >&2
        return 0
    fi

    if grep -q "^DOMINANT=" "$PF"; then
        sed -i "s/^DOMINANT=.*/DOMINANT='${DOM}'/" "$PF"
    else
        if grep -q "^FOREGROUND=" "$PF"; then
            sed -i "/^FOREGROUND=/a DOMINANT='${DOM}'" "$PF"
        else
            printf "DOMINANT='%s'\n" "$DOM" >> "$PF"
        fi
    fi
    echo "DOMINANT='${DOM}' → $(basename "$PF")"
}

if [ "${1:-}" = "--all" ]; then
    for pf in "${PALETTES_DIR}"/*.sh; do
        [ -f "$pf" ] || continue
        [[ "$(basename "$pf")" == *.bak ]] && continue
        process_palette "$pf"
    done
else
    [ -z "${1:-}" ] && { echo "Kullanım: $0 <palette.sh> | --all" >&2; exit 1; }
    process_palette "$1"
fi
