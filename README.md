# hyprdots

Hyprland, Quickshell (`liquid-glass`), Kitty, Cava, Btop, Fish ve Fastfetch konfigürasyonlarını sisteme özel donanım/yol bağımlılıklarından arındırarak paylaşmayı, GitHub dalları (branches) üzerinden güncellemeyi ve hedef sistem donanımına göre otomatik kurmayı sağlayan araç.

## Özellikler
- **Temiz Export (`./hyprdots export`):**
  - Sahte ses kartı monitörünü (`HDMI-A-1`), sabit `DP-1` kurallarını ve `audio-restore.sh` bağımlılığını çıkarır; yerine genel otomatik monitör kuralı koyar.
  - `/home/<kullanıcı>` yollarını `{{HOME}}` yer tutucusuna dönüştürür.
  - Nvidia ortam değişkenlerini şablonlar.
  - `.bak`, `.save`, `.git`, `.vscode` ve `fish_variables` gibi dosyaları otomatik dışlar.
- **Dal Bazlı Güncelleme (`./hyprdots update`):**
  - GitHub'a yüklenen yeni bir dalı çeker (`--branch <dal>` veya `--interactive`), istenirse `--apply` ile anında uygular.
- **Donanım Uyarlamalı Kurulum (`./hyprdots install`):**
  - Mevcut `~/.config` dosyalarını `~/.config/.hyprdots-backup/<tarih>/` altına yedekler.
  - Hedef sistemde Nvidia GPU varsa `env.lua` içine Nvidia değişkenlerini ekler, yoksa temiz bırakır (`--nvidia` / `--no-nvidia` ile manuel seçilebilir).

## Kullanım

### Senin İçin (Config Güncelleme & Paylaşma)
```bash
cd ~/Belgeler/hyprdots
./hyprdots export
git checkout -b yeni-tema
git add configs/
git commit -m "yeni tema eklendi"
git push -u origin yeni-tema
```

### Kurulum / Dal Güncelleme
```bash
# Mevcut repodan kurulum
./install.sh

# Belirli bir dalı çekip kurma
./hyprdots update --branch yeni-tema --apply

# Uzak dalları listeleme
./hyprdots branches

# Kurulum öncesi önizleme
./hyprdots install --dry-run
```
