#!/bin/bash
# Uygulamaları listeler: her satır "ad<TAB>açıklama<TAB>ikon<TAB>exec<TAB>terminal<TAB>dosya<TAB>keywords"
# .desktop dosyalarından okur (sistem + kullanıcı + flatpak + local). NoDisplay/Hidden olanlar atlanır.
# Sıra: sıralı ve tekil (aynı addan ilk bulunan kazanır).

declare -A SEEN

# İkon dizini: tema adı -> mutlak yol çözümlemesi için tek seferlik indeks.
# (Quickshell'in ikon teması her ortamda çözülmüyor; mutlak yol her zaman çalışır.)
declare -A ICON_INDEX
# Tüm liste üretimi (yavaş: ikon dizini taraması içerir)
generate() {
build_icon_index() {
    # Qt6 (qt6ct) temasını kullan, yoksa Qt5 (qt5ct) temasına düş;
    # ikisi de yoksa breeze, en son hicolor
    local themes=()
    local qt_theme=""
    qt_theme=$(grep -i '^icon_theme=' "$HOME/.config/qt6ct/qt6ct.conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')
    [ -z "$qt_theme" ] && qt_theme=$(grep -i '^icon_theme=' "$HOME/.config/qt5ct/qt5ct.conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')
    [ -n "$qt_theme" ] && themes+=("$qt_theme")
    themes+=("breeze" "hicolor")
    local dirs=()
    for t in "${themes[@]}"; do
        for base in "$HOME/.local/share/icons" "/usr/share/icons"; do
            [ -d "$base/$t" ] && dirs+=("$base/$t")
        done
    done
    dirs+=("/usr/share/pixmaps")
    local f base name
    while IFS= read -r -d '' f; do
        base="${f##*/}"
        name="${base%.*}"
        # İlk bulunan kazanır (tema önceliği + find sırası)
        [ -n "${ICON_INDEX[$name]+x}" ] && continue
        case "$f" in
            *.png|*.svg|*.xpm) ICON_INDEX[$name]="$f" ;;
        esac
    done < <(find "${dirs[@]}" \( -type f -o -type l \) \( -name '*.png' -o -name '*.svg' -o -name '*.xpm' \) -print0 2>/dev/null)
}

resolve_icon() {
    local icon="$1"
    [ -z "$icon" ] && { echo ""; return; }
    # Mutlak yol ya da uzantılı dosya adı
    if [[ "$icon" == /* ]]; then
        [ -f "$icon" ] && { echo "$icon"; return; }
        echo ""
        return
    fi
    if [ -n "${ICON_INDEX[$icon]+x}" ]; then
        echo "${ICON_INDEX[$icon]}"
        return
    fi
    echo ""
}

build_icon_index

for dir in "$HOME/.local/share/applications" "$HOME/.local/share/flatpak/exports/share/applications" "/usr/share/applications" "/usr/local/share/applications" "/var/lib/flatpak/exports/share/applications"; do
    [ -d "$dir" ] || continue
    while IFS= read -r -d '' f; do
        name=""
        name_tr=""
        name_en=""
        name_any=""
        comment=""
        comment_tr=""
        comment_en=""
        keywords=""
        keywords_tr=""
        keywords_en=""
        icon=""
        exec=""
        term="false"
        nodisplay="false"
        hidden="false"
        type="Application"
        # Sadece [Desktop Entry] bölümünü oku
        in_entry=0
        while IFS= read -r line || [ -n "$line" ]; do
            # Baştaki/sondaki boşlukları kırp
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ "$line" == "["* ]] && { [[ "$line" == "[Desktop Entry]" ]] && in_entry=1 || in_entry=0; continue; }
            [ "$in_entry" -eq 1 ] || continue
            key="${line%%=*}"
            val="${line#*=}"
            case "$key" in
                Name) [ -z "$name" ] && name="$val" ;;
                # Yerelleştirilmiş adlar: tr > varsayılan > en > herhangi biri
                Name\[tr*) [ -z "$name_tr" ] && name_tr="$val" ;;
                Name\[en*) [ -z "$name_en" ] && name_en="$val" ;;
                Name\[*) [ -z "$name_any" ] && name_any="$val" ;;
                Comment) [ -z "$comment" ] && comment="$val" ;;
                Comment\[tr*) [ -z "$comment_tr" ] && comment_tr="$val" ;;
                Comment\[en*) [ -z "$comment_en" ] && comment_en="$val" ;;
                Keywords) [ -z "$keywords" ] && keywords="$val" ;;
                Keywords\[tr*) [ -z "$keywords_tr" ] && keywords_tr="$val" ;;
                Keywords\[en*) [ -z "$keywords_en" ] && keywords_en="$val" ;;
                Icon) [ -z "$icon" ] && icon="$val" ;;
                Exec) [ -z "$exec" ] && exec="$val" ;;
                Terminal) term="$val" ;;
                NoDisplay) nodisplay="$val" ;;
                Hidden) hidden="$val" ;;
                Type) type="$val" ;;
            esac
        done < "$f"
        # Dil önceliği: tr > varsayılan (genelde en) > en > herhangi biri
        [ -n "$name_tr" ] && name="$name_tr"
        [ -z "$name" ] && name="$name_en"
        [ -z "$name" ] && name="$name_any"
        [ -n "$comment_tr" ] && comment="$comment_tr"
        [ -z "$comment" ] && comment="$comment_en"
        [ -n "$keywords_tr" ] && keywords="$keywords_tr"
        [ -z "$keywords" ] && keywords="$keywords_en"
        [ "$type" = "Application" ] || continue
        [[ "$nodisplay" == "true" ]] && continue
        [[ "$hidden" == "true" ]] && continue
        [ -z "$name" ] || [ -z "$exec" ] && continue
        # Tekille: aynı addan ilk kazanır
        [ -n "${SEEN[$name]+x}" ] && continue
        SEEN[$name]=1
        icon="$(resolve_icon "$icon")"
        # Sekme karakterleri TSV'yi bozar; kırp
        keywords="${keywords//$'\t'/ }"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$comment" "$icon" "$exec" "$term" "$(basename "$f")" "$keywords"
    done < <(find "$dir" -name '*.desktop' -print0 2>/dev/null | sort -z)
done
} # generate sonu

# ------------------------------------------------------------
# Önbellek: girdiler (.desktop dizinleri, *ct tema ayarları, bu
# script) değişmedikçe hazır listeyi bas, tarama yapma.
# ------------------------------------------------------------
CACHE_DIR="${HOME}/.cache/my-shell"
CACHE_FILE="${CACHE_DIR}/apps-list.tsv"
QT6CT_CONF="${HOME}/.config/qt6ct/qt6ct.conf"
QT5CT_CONF="${HOME}/.config/qt5ct/qt5ct.conf"
USER_APPS="${HOME}/.local/share/applications"
USER_FLATPAK_APPS="${HOME}/.local/share/flatpak/exports/share/applications"
SYS_APPS="/usr/share/applications"
LOCAL_APPS="/usr/local/share/applications"
SYS_FLATPAK_APPS="/var/lib/flatpak/exports/share/applications"

cache_fresh() {
    [ -f "$CACHE_FILE" ] || return 1
    # Önbellekten yeni herhangi bir girdi var mı? (var olmayan yolları ele)
    local watch=()
    for p in "$USER_APPS" "$USER_FLATPAK_APPS" "$SYS_APPS" "$LOCAL_APPS" "$SYS_FLATPAK_APPS" "$QT6CT_CONF" "$QT5CT_CONF" "$0"; do
        [ -e "$p" ] && watch+=("$p")
    done
    [ ${#watch[@]} -eq 0 ] && return 0
    local newer=""
    newer=$(find "${watch[@]}" \
        -newer "$CACHE_FILE" -print -quit 2>/dev/null)
    [ -z "$newer" ]
}

if cache_fresh; then
    cat "$CACHE_FILE"
    exit 0
fi

mkdir -p "$CACHE_DIR"
TMP_FILE="${CACHE_FILE}.tmp.$$"
generate > "$TMP_FILE"
mv -f "$TMP_FILE" "$CACHE_FILE"
cat "$CACHE_FILE"
