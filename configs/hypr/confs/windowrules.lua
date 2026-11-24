--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Quickshell bar/panel blur efekti
hl.layer_rule({
    match = { namespace = "quickshell" },
    blur = true,
    ignore_alpha = 0.5,
})

-- Liquid Glass bar: HyprGlass eklentisi yönettiği için yerleşik Hyprland blur kapalı
hl.layer_rule({
    match = { namespace = "quickshell:liquid-glass" },
    blur = false,
})

-- Ekran köşe overlay'leri: blur bulaşmasın, keskin siyah kalsın.
hl.layer_rule({
    match = { namespace = "quickshell:corner" },
    blur = false,
})

hl.window_rule({
    match = { class = "engine" },
    workspace = "3 silent"
})

hl.window_rule({
    match = { class = "Gromit-mpx" },
    no_blur = true,
    float = true,
    pin = true,
    fullscreen = true,
    opaque = false
})

hl.window_rule({
  name = "OBS",
  match = {
    class = "com.obsproject.Studio"
  },
  float = true,
  size = "1080 700"
})

hl.window_rule({
  name = "zen-float-start",
  match = { class = "zen" },
  float = true,
  size = "680 120",
  move = "620 305",
})

hl.window_rule({
  name = "zen-searchbar-transparent",
  match = { class = "zen", float = true },
  no_blur = true,
  no_shadow = true,
})

hl.window_rule({
  name = "RDR 2",
  match = {
    title = "Red Dead Redemption 2"
  },
  fullscreen = true
})

hl.window_rule({
    name = "zen-blur-fix",
    match = { class = "zen" },
    opacity = "0.999 0.999",
})

-- Zen arama çubuğu modu (Super + B -> zen_auto.sh): küçük floating Zen penceresi
-- açıkken pencere DIŞINA tıklanırsa kapat. Arama yapılınca pencere tiling'e
-- geçtiği için (floating=false) bu kural artık ona dokunmaz.
-- non_consuming: tıklama normal şekilde hedefine iletilmeye devam eder.
local function vec(v)
  if type(v) ~= "table" then return nil end
  return v.x or v[1], v.y or v[2]
end

hl.bind("mouse:272", function()
  local ok, err = pcall(function()
    local cur = hl.get_cursor_pos()
    if not cur then return end
    for _, w in ipairs(hl.get_windows({ class = "zen", floating = true })) do
      local x, y = vec(w.at)
      local sw, sh = vec(w.size)
      if x and sw and sh <= 220 then
        local inside = cur.x >= x and cur.x <= x + sw and cur.y >= y and cur.y <= y + sh
        if not inside then
          hl.dispatch(hl.dsp.window.close({ window = w }))
        end
      end
    end
  end)
  if not ok then print("zen-searchbar click: " .. tostring(err)) end
end, { non_consuming = true })

hl.window_rule({
    name = "lutris",
    match = { class = "net.lutris.Lutris" },
    float = true,
    size = "1270 730"
})

-- Godot proje yöneticisi yüzer, proje editörleri tiling kalır.
-- PM ve editör aynı class (Godot) ve aynı initialTitle'a sahip; ayırt eden tek şey
-- pencere açıldıktan SONRA değişen başlık. float statik bir kural olduğundan başlığı
-- map anında eşleştirir ve sonradan gelen title değişimine tepki veremez; bu yüzden
-- title değişim olayını dinliyoruz.
hl.on("window.title", function(win)
  if not win or win.class ~= "Godot" then return end
  local title = win.title or ""
  if title:match("Proje Yöneticisi") or title:match("Project Manager") then
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = win }))
    hl.dispatch(hl.dsp.window.resize({ x = 1080, y = 700, window = win }))
  else
    hl.dispatch(hl.dsp.window.float({ action = "disable", window = win }))
  end
end)

hl.window_rule({
    name = "ses",
    match = { class = "org.pulseaudio.pavucontrol" },
    float = true,
    size = "1400 600"
})
hl.window_rule({
    name = "LocalSend",
    match = { class = "localsend" },
    float = true,
    size = "730 870"
})

hl.window_rule({
    name = "moon-river-vd",
    match = { class = "steam_app_3392490" },
    float = true,
    size = "1920 1080",
    move = "0 0",
})

hl.window_rule({
    name= "steam",
    match = { class = "steam" },
    move = "625 320"
})

-- TLauncher (Java Swing/JavaFX): blur ve animasyon donmayı tetikler, XWayland'da yüzer aç
hl.window_rule({
    name = "tlauncher-fix",
    match = { class = "TLauncher" },
    float = true,
    no_blur = true,
    no_focus = false,
})

hl.window_rule({
    match = { class = "pardus-pen" },
    no_blur = true,
    float = true
})

hl.window_rule({
    match = { class = "org.kde.plasma-systemmonitor" },
    float = true,
    size = "1270 730"
})

hl.window_rule({
    match = { title = "Analysis" },
    workspace = "3 silent"
})
