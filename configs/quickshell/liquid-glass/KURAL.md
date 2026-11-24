# Liquid Glass — Tasarım ve Geliştirme Kuralları

Bu belge, `{{HOME}}/.config/quickshell/liquid-glass` konfigürasyonunun görsel bütünlüğünü, `1920x1080` keskinliğini ve klavye odaklı akıcılığını korumak için uyulması gereken temel kuralları tanımlar.

---

## 1. Cam Mimarisi ("No-Stack" Kuralı)
- **Cam üstüne cam koyma:** Ana yüzeyler yalnızca [GlassSurface.qml](components/GlassSurface.qml) (`ShaderEffect`) kullanır. Adaların içindeki modüllerde (`ActiveWindow`, `Clock`, `Media`, `Network`, `Volume`, `Tray`) ikincil cam kutuları/çerçeveleri oluşturulmaz; yalnızca aktif çalışma alanı ve hover durumları için hafif saydam dolgu (`rgba(255, 255, 255, 0.09–0.18)`) kullanılır.
- **Yüzen adalar:** Bar elemanları tek bir koyu şerit yerine birbirinden bağımsız yüzen cam adalar halinde tutulur ki arka plandaki duvar kağıdı adaların arasından doğrudan görünsün.

---

## 2. Shader ve Kenar Keskinliği (`1920x1080`, `scale: 1`)
- **Düz `Rectangle.border` kullanma:** `1x` DPI'da yuvarlatılmış `Rectangle` kenarlıkları çift anti-alias veya köşe kırılması yaratır. Kenar yumuşatma ve ışık yansıması yalnızca [liquid_glass.frag](shaders/liquid_glass.frag) içindeki `sdRoundedBox` + Fresnel hesabı ile yapılır.
- **Shader değişikliği sonrası derleme zorunludur:** [liquid_glass.frag](shaders/liquid_glass.frag) dosyası her düzenlendiğinde aşağıdaki komutla `.qsb` yeniden derlenmelidir:
  ```bash
  /usr/lib/qt6/bin/qsb --qt6 \
    -o {{HOME}}/.config/quickshell/liquid-glass/shaders/liquid_glass.frag.qsb \
    {{HOME}}/.config/quickshell/liquid-glass/shaders/liquid_glass.frag
  ```
- **Çift tam sayı hizalama (`evenPx`):** `1080p` ekranda `anchors.centerIn` kullanılan tüm modül ve adaların `implicitWidth` değerleri `theme.evenPx(...)` ile çift tam sayıya yuvarlanır; `.5 px` konumlandırma kesinlikle yapılmaz.
- **Hyprland `ignore_alpha` dengesi:** [windowrules.lua](file://{{HOME}}/.config/hypr/confs/windowrules.lua) içindeki `quickshell:liquid-glass` kuralı `ignore_alpha = 0.28` olarak kalmalıdır. Shader'ın iç opaklığı (`~0.62+`) bu eşiğin üstünde tutularak iç kısım bulanıklaştırılırken, `0.0–0.28` arasındaki dış anti-alias piksellerinde bulanık hale oluşması önlenir.

---

## 3. Renk, Tipografi ve Hareket
- **Renk paleti:** [Theme.qml](Theme.qml) dışına hardcoded renk eklenmez. Tüm tema ve cam shader renkleri aktif duvar kağıdı paletinden (`~/.config/hypr/vars/bg` → `~/.config/hypr/vars/palettes/<kağıt>.sh`) canlı türetilir; varsayılan/fallback referansı `"orman çizim.png"` paletidir (`#5ABCC8` vurgu, `#EBB079` uyarı). Yazı tipi `Hurmit Nerd Font` (`12 / 13 / 14 px`, rakamlarda `tnum`) olarak sabitlenir.
- **Dikkat dağıtmayan hareket:** Yaylı (`Bounce`) eğriler ve sürekli döngüsel animasyonlar kullanılmaz. Durum geçişleri `110–150 ms` aralığında `Easing.OutCubic` ile yapılır. Sol ve sağ bar adalarındaki kapsayıcısına sığmayan uzun isimler (`ActiveWindow`, `Media`, `Network`) normalde `...` ile sabit durur ve yalnızca fare ilgili bar adasının üzerine getirildiğinde [MarqueeText.qml](components/MarqueeText.qml) ile kayar.

---

## 4. Klavye Odaklılık ve Fare Desteği
- **Odağı çalma:** Bar normal durumda `focusable: false` kalır. İleride eklenecek açılır menüler/paneller yalnızca açıkken `HyprlandFocusGrab` ve `Escape` ile odak alır.
- **Hyprland Lua uyumu:** Henüz oluşmamış çalışma alanlarına geçişte klasik `workspace N` yerine `hyprctl dispatch hl.dsp.focus({ workspace = N })` kullanılır.
- **Fare erişilebilirliği:** Her modül klavye kısayollarına ek olarak tıklama, sağ tık ve tekerlek (`onWheel`) etkileşimini desteklemeye devam eder.
