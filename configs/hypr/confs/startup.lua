-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:

hl.on("hyprland.start", function ()
  local hyprglass_so = "{{HOME}}/.local/share/hyprglass/hyprglass.so"
  local f = io.open(hyprglass_so, "r")
  if f then
    f:close()
    hl.exec_cmd("hyprctl plugin load " .. hyprglass_so)
  end
  hl.exec_cmd("quickshell -c liquid-glass")
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("{{HOME}}/.config/hypr/scripts/apply_wallpaper.sh")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("{{HOME}}/.config/hypr/scripts/list_apps.sh > /dev/null") -- Uygulama önbelleğini ısıt
  hl.exec_cmd("systemctl --user restart xdg-desktop-portal-hyprland")
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
  hl.exec_cmd("wayscriber -d")
end)
