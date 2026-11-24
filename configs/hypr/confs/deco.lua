--------------------
---- DEKORASYON ----
--------------------

local vars = require("confs/vars")

hl.config({
    general = {
        gaps_in  = vars.deco.gapsIn,
        gaps_out = vars.deco.gapsOut,
        border_size = vars.deco.borderSize,

        col = {
            active_border   = { colors = {"rgba(7c709c00)", "rgba(18375800)"}, angle = 90},
            inactive_border = "rgba(59595900)",
        },

        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding       = vars.deco.round,
        rounding_power = vars.deco.roundPwr,

        active_opacity   = vars.deco.activeTrnp,
        inactive_opacity = vars.deco.inactvTrnp,

        shadow = {
            enabled      = false,
            range        = 25,
            render_power = 4,
            color        = 0xDa101010,
        },

        blur = {
            enabled   = true,
            size      = 7,
            passes    = 3,
            vibrancy  = 0.1696,
	    noise     = 0,
	    contrast  = 0,
	    popups    = true,
	    new_optimizations = true,
            ignore_opacity = true,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true,   --If true disables the random hyprland logo / anime girl background. :(
	    disable_splash_rendering = true,
	    allow_session_lock_restore = true, -- Kilit uygulaması ölürse yeni istemci devralabilsin (kurtarma için)
	    animate_manual_resizes = true -- movewindowpixel kayarak gitsin (kilit perdesi)
    },
})


----------------------
---- ANİMASYONLAR ----
----------------------

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("snappy",         { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.05}  } })
hl.curve("soft",           { type = "bezier", points = { {0.25, 0.1},  {0.25, 1}    } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10 * vars.deco.animSpd,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39 * vars.deco.animSpd, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 1 * vars.deco.animSpd, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 1 * vars.deco.animSpd,  bezier = "easeOutQuint",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1 * vars.deco.animSpd, bezier = "soft",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 0.5 * vars.deco.animSpd, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 0.5 * vars.deco.animSpd, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 0.5 * vars.deco.animSpd, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 2 * vars.deco.animSpd, bezier = "quick", style = "fade" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 1.5 * vars.deco.animSpd,    bezier = "quick", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.2 * vars.deco.animSpd,  bezier = "quick",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.2 * vars.deco.animSpd, bezier = "quick" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1 * vars.deco.animSpd, bezier = "quick" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94 * vars.deco.animSpd, bezier = "easeInOutCubic", style = "slidefade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21 * vars.deco.animSpd, bezier = "easeInOutCubic", style = "slidefade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94 * vars.deco.animSpd, bezier = "easeInOutCubic", style = "slidefade" })
-- Özel workspace (SUPER+S): dikey, aşağıdan yukarı
hl.animation({ leaf = "specialWorkspace",    enabled = true, speed = 1.94 * vars.deco.animSpd, bezier = "easeInOutCubic", style = "slidefadevert" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 1.21 * vars.deco.animSpd, bezier = "easeInOutCubic", style = "slidefadevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.94 * vars.deco.animSpd, bezier = "easeInOutCubic", style = "slidefadevert" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7 * vars.deco.animSpd,    bezier = "quick" })
