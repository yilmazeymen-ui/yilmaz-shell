-- HyprGlass: Kompozitör seviyesinde gerçek zamanlı Liquid Glass efekti
-- Apple Liquid Glass estetiği: berrak cam gövde, belirgin mercek kenar kırılması,
-- Fresnel kenar parlaması + bevel ışık çizgisi + aktif pencere odak ışığı.
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    -- Pencereler: berrak/hafif buzlu cam, belirgin optik mercek kenarı
    hg.preset("liquid_win", {
        inherits = "pomme",
        -- Düşük blur sayesinde mercek kenarı boğulmaz; arkada başka pencere varsa frost devreye girer
        blur_strength = 0.60,
        blur_iterations = 2,
        frost = 0.25,
        frost_blur = 1.5,

        -- Apple tarzı mercek kenar kırılması (geniş içe uzanım + merkez kubbe)
        edge_thickness_px = 52,
        edge_height = 38,
        refraction_strength = 0.65,   -- LENS_REFERENCE_STRENGTH=0.6 için ~2.75x kırılma kazancı
        lens_distortion = 1.45,       -- İç yüzeyde hafif optik cam kubbesi
        chromatic_aberration = 0.35,  -- Yalnızca dik kenarda ince prizma dağılımı
        fresnel_reflection = 0.42,    -- Kenarda çevre yansıması

        -- Kenar parlaması ve bevel (daha yumuşak, beyazlaşmayı azaltan ayar)
        fresnel_strength = 0.25,
        fresnel_tint = 0.50,
        specular_strength = 0.35,
        specular_angle = 335.0,
        bevel_strength = 0.28,
        bevel_size = 2.0,
        bevel_tint = 0.50,
        bevel_angle = 315.0,
        bevel_shadow = 0.25,

        -- Aktif pencere odak kenar ışığı
        focus_light = 0.12,
        focus_light_color = 0xffffff00,

        -- Karartma yerine canlı ve aydınlık cam tonu
        dark = {
            brightness = 0.98,
            contrast = 1.04,
            saturation = 1.18,
            vibrancy = 0.30,
            adaptive_dim = 0.12,
            tint_color = 0xd8e8ff14,
        },
        light = {
            brightness = 1.06,
            contrast = 1.02,
            saturation = 1.15,
            vibrancy = 0.20,
            adaptive_boost = 0.15,
            tint_color = 0xffffff28,
        },
    })

    -- Bar / quickshell öğeleri (Seçenek A): çok şeffaf ve düşük blur,
    -- Quickshell'in kendi shader'ını boğmadan altından geçen pencereleri kırar
    hg.preset("liquid_bar", {
        inherits = "pomme",
        blur_strength = 0.35,
        blur_iterations = 2,

        edge_thickness_px = 18,
        edge_height = 24,
        refraction_strength = 1.5,
        lens_distortion = 0.30,
        chromatic_aberration = 0.25,
        fresnel_reflection = 0.35,

        fresnel_strength = 0.20,
        fresnel_tint = 0.50,
        specular_strength = 0.30,
        specular_angle = 335.0,
        bevel_strength = 0.22,
        bevel_size = 1.4,
        bevel_tint = 0.50,
        bevel_angle = 315.0,
        bevel_shadow = 0.15,

        dark = {
            brightness = 1.04,
            contrast = 1.02,
            saturation = 1.15,
            vibrancy = 0.20,
            adaptive_dim = 0.05,
            tint_color = 0xffffff0a,
        },
        light = {
            brightness = 1.08,
            contrast = 1.02,
            saturation = 1.12,
            vibrancy = 0.15,
            adaptive_boost = 0.10,
            tint_color = 0xffffff18,
        },
    })

    hg.config({
        default_theme = "dark",
        default_preset = "liquid_win",
        layers = {
            enabled = true,
            mask_threshold = 0.12,
        },
    })

    hg.layer("quickshell:liquid-glass", {
        preset = "liquid_bar",
        mask_mode = "contour",
        mask_threshold = 0.12,
        mask_feather = 0.06,
        live_resample = true,
    })
end
