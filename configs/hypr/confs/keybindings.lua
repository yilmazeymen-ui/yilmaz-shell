-----------------------
---- TUŞ ATAMALARI ----
-----------------------

local mainMod = "SUPER"            -- Klavyedeki çöp tuşu
local vars    = require("confs/vars") -- Değişkenler
local scripts = "{{HOME}}/.config/hypr/scripts/"

-- UYGULAMALAR
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(vars.apps.terminal))    	  -- Terminal
hl.bind(mainMod .. " + B", function()                                              -- Tarayıcı (odaktaysa yeni sekme, değilse yeni arama penceresi)
    local win = hl.get_active_window()
    if win and win.class == "zen" then
        hl.dispatch(hl.dsp.send_shortcut({ mods = "ALT", key = "R", window = win }))
    else
        hl.dispatch(hl.dsp.exec_cmd(scripts .. "zen_auto.sh"))
    end
end)
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("lutris"))				  -- Lutris
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))                       	  -- VSCode
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(vars.apps.fileManager))       	  -- Dosya yöneticisi
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())	  -- Pencereyi kapat
hl.bind("Print", hl.dsp.exec_cmd("wayscriber --daemon-action capture_region"))  -- Birleştir: panoya + ~/Resimler/Ekran Görüntüleri (hyprshot dahil `screen_shot.sh` dosyası hâlâ mevcut)
hl.bind("CTRL + F10", hl.dsp.exec_cmd("gromit-mpx"))
hl.bind(mainMod .. " + ALT + A", hl.dsp.exec_cmd("wayscriber --daemon-toggle"))   -- Çizim katmanı ( aç/kapa)
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("wayscriber --light-toggle"))	  -- Çizim passthrough modu
-- hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("com.discordapp.Discord"))	  -- Discord
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("vesktop"))                            -- vencord

-- QUICKSHELL (bar-içi menüler)
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("quickshell -c liquid-glass ipc call bar toggleApps")) -- Uygulama başlatıcı
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("quickshell -c liquid-glass ipc call bar toggleTheme")) -- Bar-içi tema menüsü
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("quickshell -c liquid-glass ipc call bar togglePower")) -- Güç şeridi
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("quickshell -c liquid-glass ipc call bar toggleClipboard")) -- Pano
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("quickshell -c liquid-glass ipc call lock lock"))	-- Oturum kilidi

-- PENCERE YÖNETİMİ
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))

-- YÖNLÜ ODAK (floating üste gelsin diye bring_to_top ile)
hl.bind(mainMod .. " + left", function()
    hl.dispatch(hl.dsp.focus({ direction = "left" }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)
hl.bind(mainMod .. " + right", function()
    hl.dispatch(hl.dsp.focus({ direction = "right" }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)
hl.bind(mainMod .. " + up", function()
    hl.dispatch(hl.dsp.focus({ direction = "up" }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)
hl.bind(mainMod .. " + down", function()
    hl.dispatch(hl.dsp.focus({ direction = "down" }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- FLOATING DAHİL DÖNGÜSEL ODAK (tiled + floating hepsini gezer)
hl.bind(mainMod .. " + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = true, tiled = true, floating = true }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)
hl.bind(mainMod .. " + SHIFT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false, tiled = true, floating = true }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = true, tiled = true, floating = true }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- QUICKSHELL BAR KLAVYE SEÇİMİ
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.exec_cmd("quickshell -c liquid-glass ipc call bar focusLeft"))
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.exec_cmd("quickshell -c liquid-glass ipc call bar focusCenter"))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.exec_cmd("quickshell -c liquid-glass ipc call bar focusRight"))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.exec_cmd("quickshell -c liquid-glass ipc call bar closeFocus"))

-- PENCERE TAKAS (komşu ile swap)
hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.swap({ direction = "down" }))

-- PENCERE BOYUTLANDIRMA (SHIFT + oklar, basılı tutunca tekrarlar)
local resizeStep = 40
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -resizeStep, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = resizeStep, y = 0, relative = true }),  { repeating = true })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -resizeStep, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0, y = resizeStep, relative = true }),  { repeating = true })

-- İNCE AYAR SUBMAP (SUPER+R, oklar/HJKL ile 10px, ESC ile çık)
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    local fine = 10
    hl.bind("left",  hl.dsp.window.resize({ x = -fine, y = 0, relative = true }))
    hl.bind("right", hl.dsp.window.resize({ x = fine, y = 0, relative = true }))
    hl.bind("up",    hl.dsp.window.resize({ x = 0, y = -fine, relative = true }))
    hl.bind("down",  hl.dsp.window.resize({ x = 0, y = fine, relative = true }))
    hl.bind("H", hl.dsp.window.resize({ x = -fine, y = 0, relative = true }))
    hl.bind("L", hl.dsp.window.resize({ x = fine, y = 0, relative = true }))
    hl.bind("K", hl.dsp.window.resize({ x = 0, y = -fine, relative = true }))
    hl.bind("J", hl.dsp.window.resize({ x = 0, y = fine, relative = true }))
    hl.bind("escape", hl.dsp.submap("reset"))
end)

-- DİĞER PENCERE YÖNETİMİ
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.window.center())
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pin())
hl.bind(mainMod .. " + CTRL + J", hl.dsp.layout("togglesplit"))

-- WORKSPACE YÖNETİMİ --

---- Sayı tuşları
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0

    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

---- Numpad
local numpadKeys = {
    "KP_End",   -- 1
    "KP_Down",  -- 2
    "KP_Next",  -- 3
    "KP_Left",  -- 4
    "KP_Begin", -- 5
    "KP_Right", -- 6
    "KP_Home",  -- 7
    "KP_Up",    -- 8
    "KP_Prior", -- 9
    "KP_Insert",-- 10
}

for i , key in ipairs(numpadKeys) do
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

---- Fare
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- ÖZEL WORKSPACE
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.window.move({ workspace = "e+0" }))

-- PENCERE BOYUTLANDIRMA
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- FN Tuşları İle Medya
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause",       hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true, locked = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
