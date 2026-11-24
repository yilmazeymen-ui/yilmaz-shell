#!/bin/bash
# Kilit perdesi: o anki workspace pencerelerini asagiya kaydirir.
# Compositor manuel tasmayi aninda uyguladigi icin interpolasyonu
# script yapar: her tick'te tum pencerelere goreceli adim (tek eval).
# hide: kaydet -> float -> kademeli asagi -> bekle
# show: kademeli yukari -> float'i geri al (ters sirada)
# fullscreen / pinned / special / unmapped atlanir (oyunlar güvende).
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/my-shell"
STATE_FILE="$STATE_DIR/lockwins.json"
STEP=120
TICK_SLEEP=0.02

write_helpers() {
    cat > "$STATE_DIR/hide.py" <<'EOF'
import json, sys, os
state_file = sys.argv[1]
tickdir = sys.argv[2]
active = os.environ.get("ACTIVE_WS", "")
maxh = int(os.environ.get("MAX_H", "1080"))
step = int(os.environ.get("STEP", "120"))
clients = json.load(sys.stdin)
rec = []
floats = []
downs = {}  # tick -> [lua lines]
for c in clients:
    ws = c.get("workspace", {})
    if str(ws.get("id", "")) != str(active):
        continue
    if str(ws.get("name", "")).startswith("special:"):
        continue
    if not c.get("mapped", True):
        continue
    if c.get("fullscreen", 0) != 0 or c.get("pinned", False):
        continue
    addr = c.get("address", "")
    if not addr:
        continue
    floating = bool(c.get("floating", False))
    x, y = c.get("at", [0, 0])
    rec.append({"address": addr, "floating": floating, "x": x, "y": y})
    if not floating:
        floats.append(f'hl.dispatch(hl.dsp.window.float({{action="enable", window="address:{addr}"}}))')
    dist = maxh + 80 - y
    k = 0
    while dist > 0:
        s = min(step, dist)
        downs.setdefault(k, []).append(f'hl.dispatch(hl.dsp.window.move({{x=0, y={s}, relative=true, window="address:{addr}"}}))')
        dist -= s
        k += 1
json.dump(rec, open(state_file, "w"))
if floats:
    open(f"{tickdir}/tick_float.lua", "w").write("\n".join(floats) + "\n")
maxt = max(downs) if downs else -1
for k in range(maxt + 1):
    open(f"{tickdir}/tick_{k:02d}.lua", "w").write("\n".join(downs[k]) + "\n")
print(maxt + 1)
EOF
    cat > "$STATE_DIR/show.py" <<'EOF'
import json, sys, os
state_file = sys.argv[1]
tickdir = sys.argv[2]
step = int(os.environ.get("STEP", "120"))
clients = json.load(sys.stdin)
try:
    rec = json.load(open(state_file))
except Exception:
    rec = []
live = {c.get("address"): c for c in clients}
ups = {}  # tick -> [lua lines]
unfloat = []
for r in reversed(rec):
    c = live.get(r["address"])
    if c is None:
        continue
    addr = r["address"]
    cx, cy = c.get("at", [r["x"], r["y"]])
    dist = cy - r["y"]
    k = 0
    while dist > 0:
        s = min(step, dist)
        ups.setdefault(k, []).append(f'hl.dispatch(hl.dsp.window.move({{x=0, y=-{s}, relative=true, window="address:{addr}"}}))')
        dist -= s
        k += 1
    if not r["floating"]:
        unfloat.append(f'hl.dispatch(hl.dsp.window.float({{action="disable", window="address:{addr}"}}))')
maxt = max(ups) if ups else -1
for k in range(maxt + 1):
    open(f"{tickdir}/tick_{k:02d}.lua", "w").write("\n".join(ups[k]) + "\n")
if unfloat:
    open(f"{tickdir}/tick_unfloat.lua", "w").write("\n".join(unfloat) + "\n")
print(maxt + 1)
EOF
}

run_ticks() {
    # $1 = tick dizini ; sirayla eval + kisa bekleme
    local d="$1" f
    for f in "$d"/tick_*.lua; do
        [ -f "$f" ] || continue
        case "$f" in
            *tick_unfloat.lua) continue ;;
        esac
        hyprctl eval "$(cat "$f")" >/dev/null 2>&1
        sleep "$TICK_SLEEP"
    done
    if [ -f "$d/tick_unfloat.lua" ]; then
        hyprctl eval "$(cat "$d/tick_unfloat.lua")" >/dev/null 2>&1
    fi
}

hide() {
    mkdir -p "$STATE_DIR"
    write_helpers
    local tickdir="$STATE_DIR/ticks_hide"
    rm -rf "$tickdir"
    mkdir -p "$tickdir"
    # Bayat kayit varsa once sessizce geri getir
    if [ -f "$STATE_FILE" ]; then
        show_quiet
        sleep 0.2
    fi
    local active maxh nticks
    active=$(hyprctl activeworkspace -j 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))' 2>/dev/null)
    [ -z "$active" ] && return 0
    maxh=$(hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys; print(max([m.get("height",1080) for m in json.load(sys.stdin)] + [1080]))' 2>/dev/null || echo 1080)
    export ACTIVE_WS="$active" MAX_H="$maxh" STEP
    nticks=$(hyprctl clients -j 2>/dev/null | python3 "$STATE_DIR/hide.py" "$STATE_FILE" "$tickdir")
    # Float adimi ayri eval (tek layout hesabi), sonra kademeler
    if [ -f "$tickdir/tick_float.lua" ]; then
        hyprctl eval "$(cat "$tickdir/tick_float.lua")" >/dev/null 2>&1
        sleep 0.05
    fi
    (cd "$tickdir" && run_ticks "$tickdir")
    sleep 0.15
}

show_quiet() {
    local tickdir="$STATE_DIR/ticks_show"
    rm -rf "$tickdir"
    mkdir -p "$tickdir"
    export STEP
    hyprctl clients -j 2>/dev/null | python3 "$STATE_DIR/show.py" "$STATE_FILE" "$tickdir" >/dev/null
    (cd "$tickdir" && run_ticks "$tickdir")
    rm -f "$STATE_FILE"
}

show() {
    [ -f "$STATE_FILE" ] || return 0
    mkdir -p "$STATE_DIR"
    write_helpers
    show_quiet
}

case "${1:-}" in
    hide) hide ;;
    show) show ;;
    *) echo "kullanim: $0 {hide|show}" >&2; exit 2 ;;
esac
