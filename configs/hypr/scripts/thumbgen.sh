#!/bin/bash
# Duvar kağıdı dosyaları için XDG thumbnail cache'ini üretir.
# Quickshell WallpaperView önizlemesi için gerekli normal/large/x-large/xx-large
# boyutlarını doğru XDG metadata'sı (Thumb::URI, Thumb::MTime, ...) ile üretir.
DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers"

export DIR
python3 - <<'PY'
import hashlib
import mimetypes
import os
from pathlib import Path

from PIL import Image, ImageOps
from PIL.PngImagePlugin import PngInfo

root = Path(os.environ["DIR"])
cache = Path.home() / ".cache" / "thumbnails"

SIZES = {
    "normal": 128,
    "large": 256,
    "x-large": 512,
    "xx-large": 1024,
}


def is_valid(out: Path, uri: str, mtime: int) -> bool:
    try:
        with Image.open(out) as im:
            text = getattr(im, "text", {})
            return int(text.get("Thumb::MTime", -1)) == mtime and text.get("Thumb::URI") == uri
    except Exception:
        return False


def make_thumb(im: Image.Image, limit: int, out: Path, meta: dict) -> None:
    im = ImageOps.exif_transpose(im)
    im.thumbnail((limit, limit), Image.LANCZOS)
    if im.mode not in ("RGB", "RGBA"):
        im = im.convert("RGB")
    pnginfo = PngInfo()
    for k, v in meta.items():
        pnginfo.add_text(k, str(v))
    pnginfo.add_text("Software", "thumbgen")
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_name(out.name + ".tmp")
    im.save(tmp, "PNG", pnginfo=pnginfo)
    os.replace(tmp, out)


for p in sorted(root.rglob("*")):
    if not p.is_file():
        continue
    try:
        with Image.open(p) as im:
            im.load()
            width, height = im.size
    except Exception:
        continue
    if width == 0 or height == 0:
        continue

    uri = "file://" + str(p)
    digest = hashlib.md5(uri.encode()).hexdigest()
    st = p.stat()
    mtime = int(st.st_mtime)
    mime = mimetypes.guess_type(str(p))[0] or "application/octet-stream"

    meta = {
        "Thumb::URI": uri,
        "Thumb::MTime": mtime,
        "Thumb::Size": st.st_size,
        "Thumb::Mimetype": mime,
    }

    with Image.open(p) as im:
        for dname, limit in SIZES.items():
            out = cache / dname / (digest + ".png")
            if is_valid(out, uri, mtime):
                continue
            make_thumb(im, limit, out, meta)
PY