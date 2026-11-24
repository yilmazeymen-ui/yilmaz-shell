#!/bin/bash

STARTUP_TIMEOUT=30

PIDFILE="$XDG_RUNTIME_DIR/zen_auto.pid"
LOG="$XDG_RUNTIME_DIR/zen_auto.log"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

echo "$(date +%H:%M:%S) start" >> "$LOG"

# Açılmadan önceki Zen pencerelerini not al ki yeni açılanı ayırt edebilelim.
EXISTING=$(hyprctl clients -j | jq -r '[.[] | select(.class == "zen") | .address] | join(",")')

nohup zen-browser --new-window >/dev/null 2>&1 &
echo "$(date +%H:%M:%S) launch zen (mevcut=[$EXISTING])" >> "$LOG"

python3 - "$STARTUP_TIMEOUT" "$LOG" "$EXISTING" << 'EOF'
import json
import os
import socket
import subprocess
import sys
import time

startup_timeout = int(sys.argv[1])
log_path = sys.argv[2]
existing = {a.lower() for a in sys.argv[3].split(",") if a}

def log(msg):
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")

def hypr_clients():
    out = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
    return json.loads(out)

def dispatch(lua_expr):
    subprocess.run(["hyprctl", "dispatch", lua_expr], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def focus_zen(addr):
    dispatch(f"hl.dsp.focus({{ window = 'address:{addr}' }})")

def tile_zen(addr):
    focus_zen(addr)
    dispatch(f"hl.dsp.window.float({{ action = 'disable', window = 'address:{addr}' }})")

def resize_search_bar(addr):
    dispatch(f"hl.dsp.window.resize({{ x = 680, y = 120, window = 'address:{addr}' }})")

def nudge_search_bar(addr):
    # Zen ilk açılışta resize'ı bazen reddediyor ya da floating urlbar'ı yeniden
    # konumlandırmıyor (yarış durumu). 1px'lik gerçek resize olayları Zen'in
    # updateTabsToolbar() hesaplamasını tekrar tetikler.
    import threading
    def run():
        for delay in (0.25, 0.6, 1.2):
            time.sleep(delay)
            dispatch(f"hl.dsp.window.resize({{ x = 680, y = 121, window = 'address:{addr}' }})")
            time.sleep(0.05)
            resize_search_bar(addr)
    threading.Thread(target=run, daemon=True).start()

def close_zen(addr):
    dispatch(f"hl.dsp.window.close({{ window = 'address:{addr}' }})")

def is_initial_title(title):
    t = (title or "").strip()
    if not t:
        return True
    if t in ("Zen Browser", "Yeni Sekme — Zen Browser", "New Tab — Zen Browser"):
        return True
    if t.startswith("about:"):
        return True
    return False

# 1. YENİ Zen penceresinin map olmasını bekle (başka workspace'teki eskileri atla)
start = time.time()
zen_addr = None
init_title = None
while time.time() - start < startup_timeout:
    for c in hypr_clients():
        if c.get("class") == "zen" and c.get("address", "").lower() not in existing:
            zen_addr = c.get("address")
            init_title = c.get("title", "")
            break
    if zen_addr:
        break
    time.sleep(0.1)

if not zen_addr:
    log("zen açılmadı, çıkış")
    sys.exit(0)

zen_hex = zen_addr.lower().removeprefix("0x")
log(f"mapped addr={zen_addr} init={init_title!r}")

# Başlangıçta zaten arama yapılmış / farklı başlık varsa direkt tiled yap
if not is_initial_title(init_title):
    tile_zen(zen_addr)
    log(f"tiled immediately | {init_title!r}")
    sys.exit(0)

# İlk map anındaki min_size kısıtını aşmak için arama çubuğu boyutuna zorla ve ortala
resize_search_bar(zen_addr)
nudge_search_bar(zen_addr)

# 2. Hyprland socket2 üzerinden title değişimi ve odak kaybını dinle
sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
xdg = os.environ.get("XDG_RUNTIME_DIR", "")
sock_path = os.path.join(xdg, "hypr", sig, ".socket2.sock")

zen_focused = True  # Açılışta Hyprland yeni pencereye odak verir

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
    s.connect(sock_path)
    buf = ""
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        buf += chunk.decode("utf-8", errors="replace")
        while "\n" in buf:
            line, buf = buf.split("\n", 1)
            if ">>" not in line:
                continue
            event, data = line.split(">>", 1)

            if event == "closewindow":
                if data.strip().lower() == zen_hex:
                    log("zen kapandı, çıkış")
                    sys.exit(0)

            elif event == "windowtitlev2":
                parts = data.split(",", 1)
                if len(parts) == 2:
                    addr_hex, new_title = parts[0].strip().lower(), parts[1]
                    if addr_hex == zen_hex and not is_initial_title(new_title):
                        tile_zen(zen_addr)
                        log(f"tiled | {new_title!r}")
                        sys.exit(0)

            # Dışarı tıklayınca kapatma windowrules.lua'daki non_consuming
            # mouse:272 bind'i ile yapılır (follow_mouse=1 olduğu için odak
            # değişimine güvenilemez).
EOF
