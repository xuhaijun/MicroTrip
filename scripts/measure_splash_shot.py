"""量一下原生闪屏截图里 logo / 品牌文字的实际占屏比例，换算成 dp。

用法：python scripts/measure_splash_shot.py <截图路径>
屏幕假设：1080x1920 @ density 480（xxhdpi）=> 360 x 640 dp
"""

import os
import sys
from PIL import Image

SHOT = sys.argv[1] if len(sys.argv) > 1 else None
if not SHOT or not os.path.exists(SHOT):
    print("usage: python scripts/measure_splash_shot.py <screenshot>")
    sys.exit(2)

SCREEN_W_DP = 360.0

im = Image.open(SHOT).convert("RGB")
W, H = im.size
print(f"shot: {SHOT}")
print(f"size: {W} x {H}  (ratio {W / H:.4f})")

px = im.load()


def is_white(p):
    r, g, b = p
    return r > 225 and g > 225 and b > 225


def bbox(x0, y0, x1, y1, pred):
    minx, miny, maxx, maxy = None, None, None, None
    for y in range(y0, y1):
        for x in range(x0, x1):
            if pred(px[x, y]):
                if minx is None or x < minx:
                    minx = x
                if maxx is None or x > maxx:
                    maxx = x
                if miny is None or y < miny:
                    miny = y
                if maxy is None or y > maxy:
                    maxy = y
    return minx, miny, maxx, maxy


# 品牌文字在最底部区域，且为白色
tb = bbox(0, int(H * 0.80), W, H, is_white)
print()
print("=== 底部品牌文字 bbox（白色像素）===")
if tb[0] is not None:
    tw = tb[2] - tb[0] + 1
    th = tb[3] - tb[1] + 1
    print(f"  px: x {tb[0]}..{tb[2]}  y {tb[1]}..{tb[3]}   -> {tw} x {th}")
    print(f"  占屏宽 {tw / W * 100:.1f}%  => {tw / W * SCREEN_W_DP:.1f} dp 宽")
    print(f"  字高 {th / H * 100:.1f}%        => {th / W * SCREEN_W_DP:.1f} dp 高")
    print(f"  距屏底 {H - 1 - tb[3]} px => {(H - 1 - tb[3]) / W * SCREEN_W_DP:.1f} dp")
else:
    print("  (未找到白色文字)")

# logo：中间的高饱和蓝色圆角方块，用「与背景色差异」判定
# 背景 #4FC3F7 = (79,195,247)
BG = (79, 195, 247)


def is_logo(p):
    r, g, b = p
    return abs(r - BG[0]) + abs(g - BG[1]) + abs(b - BG[2]) > 60


lb = bbox(0, int(H * 0.15), W, int(H * 0.75), is_logo)
print()
print("=== 中部 logo bbox（与背景色差异）===")
if lb[0] is not None:
    lw = lb[2] - lb[0] + 1
    lh = lb[3] - lb[1] + 1
    print(f"  px: x {lb[0]}..{lb[2]}  y {lb[1]}..{lb[3]}   -> {lw} x {lh}")
    print(f"  占屏宽 {lw / W * 100:.1f}%  => {lw / W * SCREEN_W_DP:.1f} dp 宽")
    print(f"  占屏高 {lh / H * 100:.1f}%  => {lh / H * SCREEN_W_DP:.1f} dp 高")
else:
    print("  (未找到 logo)")
