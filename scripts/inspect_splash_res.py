"""列出原生闪屏相关资源与源图的像素尺寸（用于判断显示尺寸是否过大）。

显示尺寸 = 图片像素 / 所在 density 桶的缩放系数：
  mdpi 1x, hdpi 1.5x, xhdpi 2x, xxhdpi 3x, xxxhdpi 4x
"""

import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

DENSITY_SCALE = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}


def density_of(folder: str) -> float | None:
    for key, scale in DENSITY_SCALE.items():
        if folder.endswith("-" + key):
            return scale
    return None


print("=== android res: splash / branding / launch / styles ===")
for dirpath, _dirnames, filenames in os.walk(RES):
    folder = os.path.basename(dirpath)
    for name in sorted(filenames):
        low = name.lower()
        if not any(k in low for k in ("splash", "branding", "launch", "styles", "background")):
            continue
        full = os.path.join(dirpath, name)
        rel = os.path.relpath(full, ROOT).replace(os.sep, "/")
        if name.endswith(".png"):
            with Image.open(full) as im:
                w, h = im.size
            scale = density_of(folder)
            extra = ""
            if scale:
                extra = f"   -> {w / scale:.0f} x {h / scale:.0f} dp"
            print(f"{rel}  {w}x{h}  {os.path.getsize(full)}B{extra}")
        else:
            print(rel)

print()
print("=== source assets ===")
IMG = os.path.join(ROOT, "assets", "images")
for name in sorted(os.listdir(IMG)):
    full = os.path.join(IMG, name)
    try:
        with Image.open(full) as im:
            print(f"  assets/images/{name}  {im.size[0]}x{im.size[1]}  {os.path.getsize(full)}B")
    except Exception:
        print(f"  assets/images/{name}  (not an image)")
