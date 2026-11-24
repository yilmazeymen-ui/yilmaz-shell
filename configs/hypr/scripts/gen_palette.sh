#!/bin/bash
# ============================================================
#  gen_palette.sh — Bir duvar kağıdı için palet dosyası üretir
#
#  Kullanım:
#    gen_palette.sh <wallpaper_yolu>
#
#  wal'ı çalıştırır, üretilen renkleri
#  ~/.config/hypr/vars/palettes/<dosya_adı>.sh dosyasına yazar.
#  Daha sonra istersen o dosyayı elle düzenleyebilirsin.
# ============================================================

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Kullanım: $0 <wallpaper_yolu>" >&2
    exit 1
fi

WALLPAPER="$1"
if [ ! -f "$WALLPAPER" ]; then
    echo "Hata: $WALLPAPER dosyası yok" >&2
    exit 1
fi

PALETTES_DIR="${HOME}/.config/hypr/vars/palettes"
HYPR_SCRIPTS_DIR="${HOME}/.config/hypr/scripts"
mkdir -p "$PALETTES_DIR"
OUT="${PALETTES_DIR}/$(basename "$WALLPAPER").sh"

# Renkleri üret (wal cache'e yazar)
wal -i "$WALLPAPER"

CACHE="${HOME}/.cache/wal/colors.sh"
if [ ! -f "$CACHE" ]; then
    echo "Hata: wal renk üretemedi ($CACHE yok)" >&2
    exit 1
fi

# Renkleri oku (wal küçük harf üretir)
BG=$(grep "^background=" "$CACHE" | cut -d"'" -f2)
FG=$(grep "^foreground=" "$CACHE" | cut -d"'" -f2)
CURSOR=$(grep "^cursor=" "$CACHE" | cut -d"'" -f2)
for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    eval "C$i=\$(grep '^color$i=' \"\$CACHE\" | cut -d\\' -f2)"
done

cat > "$OUT" <<EOF
#!/bin/bash
# ============================================================
#  PALET: $(basename "$WALLPAPER")
#  Duvar kağıdı: $WALLPAPER
#  gen_palette.sh tarafından üretildi. İstersen elle düzenle.
# ============================================================

# --- Tema seçimi (GTK + Kvantum) ----------------------------
GTK_THEME="Gruvbox-B-MB-Dark"
KVANTUM_THEME="gruvbox-kvantum"

# --- Özel / Zemin ---
BACKGROUND='$BG'
FOREGROUND='$FG'
CURSOR='$CURSOR'

# --- Kenarlık renkleri (Hyprland, rgba hex) ---
BORDER1='7c709c98'
BORDER2='18375810'
BORDER_INACTIVE='59595900'

# --- 16 renk paleti ---
COLOR0='${C0}'
COLOR1='${C1}'
COLOR2='${C2}'
COLOR3='${C3}'
COLOR4='${C4}'
COLOR5='${C5}'
COLOR6='${C6}'
COLOR7='${C7}'
COLOR8='${C8}'
COLOR9='${C9}'
COLOR10='${C10}'
COLOR11='${C11}'
COLOR12='${C12}'
COLOR13='${C13}'
COLOR14='${C14}'
COLOR15='${C15}'
COLOR16='${C15}'
EOF

echo "Palet yazıldı: $OUT"

# Simple F-22 referansına göre color4/color16'yı düzelt (color12/foreground korunur)
if [ "$(basename "$OUT")" != "Simple F-22.png.sh" ]; then
    "${HYPR_SCRIPTS_DIR}/apply_f22_delta.sh" "$OUT" || true
fi

# Ana renk (duvar kağıdının baskın tonu) — Quickshell bar buna bağlanır
"${HYPR_SCRIPTS_DIR}/gen_dominant.sh" "$OUT" || true

echo "Şimdi uygulamak için: apply_theme.sh \"$WALLPAPER\""