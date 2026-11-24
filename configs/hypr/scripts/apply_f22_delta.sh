#!/bin/bash
# ============================================================
#  apply_f22_delta.sh — Simple F-22 referansına göre color4/16
#
#  Simple F-22'nin palette ilişkisini referans alır:
#    color12 aynen kalır, color4 buna ORANTILI olur
#    foreground aynen kalır, color16 buna göre olur
#
#  Oran, F-22 paletinden luma bazlı tek t olarak çıkarılır:
#    t4  = 1 - luma(F22.color4)  / luma(F22.color12)
#    t16 = 1 - luma(F22.color16) / luma(F22.foreground)
#  Uygulama (hedef palette, kanal bazlı, 0-255 clamp):
#    new.color4  = new.color12  * (1 - t4 )
#    new.color16 = new.foreground * (1 - t16)
#
#  Kullanım:
#    apply_f22_delta.sh --all
#    apply_f22_delta.sh <palette_dosyası>
#  Simple F-22'nin kendisine dokunulmaz.
# ============================================================

set -euo pipefail

VARS_DIR="${HOME}/.config/hypr/vars"
PALETTES_DIR="${VARS_DIR}/palettes"
F22_FILE="${PALETTES_DIR}/Simple F-22.png.sh"

if [ ! -f "$F22_FILE" ]; then
    echo "Hata: referans palet bulunamadı: $F22_FILE" >&2
    exit 1
fi

# --- F-22 referansından oranları hesapla ---------------------
reff() { grep -m1 "^$1=" "$F22_FILE" | cut -d"'" -f2; }
REF_C12="$(reff COLOR12)"
REF_C4="$(reff COLOR4)"
REF_FG="$(reff FOREGROUND)"
REF_C16="$(reff COLOR16)"

T4="$(python3 - "$REF_C4" "$REF_C12" <<'PY'
import sys
def luma(h):
    h=h.lstrip("#"); r,g,b=(int(h[i:i+2],16) for i in (0,2,4))
    return 0.299*r+0.587*g+0.114*b
a,b=sys.argv[1],sys.argv[2]
v=luma(b)
t=1-(luma(a)/v if v>0 else 0)
t=max(0.0,min(1.0,t))
print(f"{t:.4f}")
PY
)"
T16="$(python3 - "$REF_C16" "$REF_FG" <<'PY'
import sys
def luma(h):
    h=h.lstrip("#"); r,g,b=(int(h[i:i+2],16) for i in (0,2,4))
    return 0.299*r+0.587*g+0.114*b
a,b=sys.argv[1],sys.argv[2]
v=luma(b)
t=1-(luma(a)/v if v>0 else 0)
t=max(0.0,min(1.0,t))
print(f"{t:.4f}")
PY
)"

echo "F-22 referans oranları -> t4=$T4  t16=$T16"

# --- Uygulama: verilen palet dosyasında color4/16 yeniden hesapla ----
apply_file() {
    local file="$1"
    [ -f "$file" ] || return 0
    local base fg c12
    base="$(basename "$file")"
    # Simple F-22'ye dokunma
    [ "$base" = "Simple F-22.png.sh" ] && { echo "atlandı: $base (referans)"; return 0; }
    fg="$(grep -m1 '^FOREGROUND=' "$file" | cut -d"'" -f2)"
    c12="$(grep -m1 '^COLOR12=' "$file" | cut -d"'" -f2)"
    if [ -z "$fg" ] || [ -z "$c12" ]; then
        echo "atlandı (eksik alan): $base"
        return 0
    fi
    new4="$(python3 - "$c12" "$T4" <<'PY'
import sys
h,f=sys.argv[1],float(sys.argv[2])
h=h.lstrip("#"); r,g,b=(int(h[i:i+2],16) for i in (0,2,4))
r=min(255,int(round(r*(1-f)))); g=min(255,int(round(g*(1-f)))); b=min(255,int(round(b*(1-f))))
print("#{:02x}{:02x}{:02x}".format(r,g,b))
PY
)"
    new16="$(python3 - "$fg" "$T16" <<'PY'
import sys
h,f=sys.argv[1],float(sys.argv[2])
h=h.lstrip("#"); r,g,b=(int(h[i:i+2],16) for i in (0,2,4))
r=min(255,int(round(r*(1-f)))); g=min(255,int(round(g*(1-f)))); b=min(255,int(round(b*(1-f))))
print("#{:02x}{:02x}{:02x}".format(r,g,b))
PY
)"
    # Önceki değerler zaten doğruysa yazma (mtime korunur → tema önbelleği bozulmaz)
    local cur4 cur16
    cur4="$(grep -m1 '^COLOR4=' "$file" | cut -d"'" -f2)"
    cur16="$(grep -m1 '^COLOR16=' "$file" | cut -d"'" -f2)"
    if [ "$cur4" = "$new4" ] && [ "$cur16" = "$new16" ]; then
        echo "önbellek korundu: $base (color4/16 zaten güncel)"
        return 0
    fi
    # yedek al (varsa üzerine yazma)
    if [ ! -f "$file.bak" ]; then
        cp "$file" "$file.bak"
    fi
    # dosyayı güncelle (MACOS uyumlu ara-buffer yok; temp kullan)
    local tmp; tmp="$(mktemp)"
    awk -v c4="$new4" -v c16="$new16" '
        /^COLOR4=/ { print "COLOR4=\x27" c4 "\x27"; next }
        /^COLOR16=/ { print "COLOR16=\x27" c16 "\x27"; next }
        { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
    echo "güncellendi: $base  (color4=$new4 color16=$new16, color12/foreground korundu)"
}

# --- Modlar ---
if [ "${1:-}" = "--all" ]; then
    for f in "$PALETTES_DIR"/*.sh; do
        apply_file "$f"
    done
elif [ -n "${1:-}" ]; then
    apply_file "$1"
else
    echo "Kullanım: apply_f22_delta.sh --all | <palette_dosyası>" >&2
    exit 1
fi
