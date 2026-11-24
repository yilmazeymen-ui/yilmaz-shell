#!/bin/bash
# ============================================================
#  apply_theme.sh — Duvar kağıdı + renk teması uygular
#
#  Kullanım:
#    apply_theme.sh <wallpaper_yolu>   veya
#    apply_theme.sh                    (vars/bg dosyasından okur)
#
#  Her duvar kağıdının kendi paleti vardır:
#    ~/.config/hypr/vars/palettes/<dosya_adı>.sh
#  Paleti üretmek için:  gen_palette.sh <wallpaper_yolu>
#  (bu script wal'ı asla otomatik çalıştırmaz).
# ============================================================

set -euo pipefail

CONF_DIR="${HOME}/.config"
HYPR_DIR="${CONF_DIR}/hypr"
VARS_DIR="${HYPR_DIR}/vars"
PALETTES_DIR="${VARS_DIR}/palettes"
DEFAULT_COLORS_FILE="${VARS_DIR}/colors.sh"
BG_FILE="${VARS_DIR}/bg"

# Wallpaper yolunu belirle (argüman yoksa son seçilen)
WALLPAPER="${1:-}"
if [ -z "$WALLPAPER" ] && [ -f "$BG_FILE" ]; then
    WALLPAPER="$(cat "$BG_FILE")"
fi

if [ -z "$WALLPAPER" ]; then
    echo "Hata: wallpaper belirtilmedi ve vars/bg boş" >&2
    exit 1
fi

# Wallpaper adına göre palet dosyası bul
WALLPAPER_NAME="$(basename "$WALLPAPER")"
PALETTE_FILE="${PALETTES_DIR}/${WALLPAPER_NAME}.sh"

if [ ! -f "$PALETTE_FILE" ]; then
    # Palet yoksa otomatik üret (wal ile). Mevcut palete dokunulmaz.
    echo "Palet bulunamadı, üretiliyor: $PALETTE_FILE"
    "${HYPR_DIR}/scripts/gen_palette.sh" "$WALLPAPER" || true
fi

if [ -f "$PALETTE_FILE" ]; then
    COLORS_FILE="$PALETTE_FILE"
else
    COLORS_FILE="$DEFAULT_COLORS_FILE"
fi

# Simple F-22 referansına göre color4/color16'yı düzelt (color12/foreground korunur)
# Palet dosyasına kalıcı olarak işlenir; Simple F-22'nin kendisine dokunulmaz.
if [ -f "$COLORS_FILE" ] && [ "$(basename "$COLORS_FILE")" != "Simple F-22.png.sh" ]; then
    "${HYPR_DIR}/scripts/apply_f22_delta.sh" "$COLORS_FILE" || true
fi

# Renk dosyasını yükle
if [ ! -f "$COLORS_FILE" ]; then
    echo "Hata: $COLORS_FILE bulunamadı" >&2
    exit 1
fi
# shellcheck source=~/.config/hypr/vars/colors.sh
source "$COLORS_FILE"

echo "Palet kaynağı: $COLORS_FILE"

# Duvar kağıdından ana vurgu rengi üret (quickshell my-shell için)
if [ -f "$PALETTE_FILE" ]; then
    "${HYPR_DIR}/scripts/gen_dominant.sh" "$PALETTE_FILE" || true
fi

echo "Tema uygulanıyor: $WALLPAPER"

# ------------------------------------------------------------
# 1) Kitty renkleri
# ------------------------------------------------------------
cat > "${CONF_DIR}/kitty/colors/colors.conf" <<EOF
# apply_theme.sh tarafından üretildi
foreground   ${FOREGROUND}
background   ${BACKGROUND}
cursor       ${CURSOR}
cursor_text_color ${BACKGROUND}

color0       ${COLOR0}
color8       ${COLOR8}
color1       ${COLOR1}
color9       ${COLOR9}
color2       ${COLOR2}
color10      ${COLOR10}
color3       ${COLOR3}
color11      ${COLOR11}
color4       ${COLOR4}
color12      ${COLOR12}
color5       ${COLOR5}
color13      ${COLOR13}
color6       ${COLOR6}
color14      ${COLOR14}
color7       ${COLOR7}
color15      ${COLOR15}
color16      ${COLOR16}
EOF

# ------------------------------------------------------------
# 2) Hyprland kenarlıkları
# ------------------------------------------------------------
hyprctl eval "hl.config({ general = { col = { active_border = { colors = {\"rgba(${BORDER1})\", \"rgba(${BORDER2})\"}, angle = 90 }, inactive_border = \"rgba(${BORDER_INACTIVE})\" } } })" 2>/dev/null || true

# ------------------------------------------------------------
# 3) Cava gradient renkleri
# ------------------------------------------------------------
CAVA_CONF="${CONF_DIR}/cava/config"
if [ -f "$CAVA_CONF" ]; then
    python3 - "$CAVA_CONF" <<PY
import sys, re
path = sys.argv[1]
with open(path) as f:
    txt = f.read()
colors = ["""${COLOR1}""", """${COLOR2}""", """${COLOR3}""",
          """${COLOR4}""", """${COLOR5}""", """${COLOR6}""",
          """${COLOR7}""", """${COLOR8}"""]
out = []
for line in txt.splitlines():
    m = re.match(r"^\s*;?\s*gradient_color_(\d+)\s*=\s*'([^']*)'", line)
    if m:
        i = int(m.group(1))
        if 1 <= i <= 8:
            out.append(f"gradient_color_{i} = '{colors[i-1]}'")
            continue
    out.append(line)
with open(path, "w") as f:
    f.write("\n".join(out) + "\n")
PY
fi

# ------------------------------------------------------------
# 4) Btop teması
# ------------------------------------------------------------
BTOP_THEME_DIR="${CONF_DIR}/btop/themes"
mkdir -p "$BTOP_THEME_DIR"
cat > "${BTOP_THEME_DIR}/wal.theme" <<EOF
# apply_theme.sh tarafından üretildi
theme[main_bg]="${COLOR0}"
theme[main_fg]="${FOREGROUND}"
theme[title]="${COLOR15}"
theme[hi_fg]="${COLOR5}"
theme[selected_bg]="${COLOR5}"
theme[selected_fg]="${COLOR0}"
theme[inactive_fg]="${COLOR8}"
theme[graph_text]="${FOREGROUND}"
theme[meter_bg]="${COLOR8}"
theme[proc_misc]="${COLOR4}"
theme[cpu_box]="${COLOR12}"
theme[mem_box]="${COLOR10}"
theme[net_box]="${COLOR13}"
theme[proc_box]="${COLOR14}"
theme[div_line]="${COLOR8}"
theme[temp_start]="${COLOR12}"
theme[temp_mid]="${COLOR14}"
theme[temp_end]="${COLOR13}"
theme[cpu_start]="${COLOR12}"
theme[cpu_mid]="${COLOR13}"
theme[cpu_end]="${COLOR5}"
theme[free_start]="${COLOR10}"
theme[free_mid]="${COLOR10}"
theme[free_end]="${COLOR2}"
theme[used_start]="${COLOR5}"
theme[used_mid]="${COLOR13}"
theme[used_end]="${COLOR1}"
theme[download_start]="${COLOR2}"
theme[download_mid]="${COLOR6}"
theme[download_end]="${COLOR1}"
theme[upload_start]="${COLOR14}"
theme[upload_mid]="${COLOR5}"
theme[upload_end]="${COLOR1}"
EOF
# btop.conf içinde wal temasını aktif et
sed -i 's/^color_theme = .*/color_theme = "wal"/' "${CONF_DIR}/btop/btop.conf" 2>/dev/null || true

# ------------------------------------------------------------
# 5) Duvar kağıdını uygula
# ------------------------------------------------------------
echo "$WALLPAPER" > "$BG_FILE"
hyprctl hyprpaper wallpaper ",$WALLPAPER"

# ------------------------------------------------------------
# 6) Servisleri yeniden başlat / yenile
# ------------------------------------------------------------
# Quickshell: paleti palettes/<kağıt>.sh dosyasından canlı izler
# (zemin siyah kalır, ön plan palet FOREGROUND'undan beslenir);
# yeniden başlatma gerekmez (hot-reload kendisi yapar).

# Kitty config reload (SIGUSR1)
pkill -USR1 -x kitty 2>/dev/null || true

echo "Tema uygulandı."