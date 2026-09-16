"""生成原生闪屏（flutter_native_splash）所需的品牌图形资源。

==================== 为什么这么做 ====================
`flutter_native_splash` 2.x **不支持 title 文本参数**（写 title 会直接报错），
所以 Logo 下方的 App 名称只能用 `branding` 图片承载。

Android 输出规则（实测得出，非常关键）：
    屏幕上显示的 dp 尺寸 = 源图像素 / 4
生成器把源图当作 xxxhdpi 源，逐密度写出 drawable-<density>/，因此
「想让屏幕上多大，源图就给 4 倍像素」：
    logo.png 1024px -> splash.png 256dp（占 360dp 屏宽 71%，明显过大）
    想要 120dp      -> 源图 480px

==================== 产出 ====================
  assets/images/splash_lockup.png    Logo + 品牌名 的整组「锁定图」，整块居中显示
                                     （Android 12 以下走 launch_background.xml 路径）
  assets/images/splash_branding.png  仅品牌名，供 Android 12+ Splash API 的 branding 槽位

用法：
    python scripts/gen_splash_assets.py
    dart run flutter_native_splash:create
改尺寸只需调下面的 LOGO_DP / TEXT_DP / GAP_DP 常量后重跑这两条命令。
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ======================= 尺寸规格（单位 dp，源图像素 = dp * 4） =======================
SCALE = 4             # 源图像素 = dp * SCALE
LOGO_DP = 120         # Logo 边长（原 256dp 过大 -> 现占屏宽 33%）
TEXT_DP = 24          # 品牌名墨迹高度（原 54dp 过大）
GAP_DP = 28           # Logo 底边 -> 品牌名顶边 的间距
BRAND_BOTTOM_DP = 24  # Android 12+ branding 距屏幕底部留白（靠底部透明内边距实现）
BRAND_PAD_X_DP = 12   # branding 画布左右各留一点安全边

SS = 4                # 超采样倍数：先按 SS 倍渲染文字再缩小，保证小字边缘锐利

# ======================= 路径与字体 =======================
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO_SRC = os.path.join(ROOT, "assets", "images", "logo.png")
OUT_LOCKUP = os.path.join(ROOT, "assets", "images", "splash_lockup.png")
OUT_BRANDING = os.path.join(ROOT, "assets", "images", "splash_branding.png")

BRAND_TEXT = "微旅途"
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\msyh.ttc",     # 微软雅黑（与 launcher / SplashPage 观感一致）
    r"C:\Windows\Fonts\msyhbd.ttc",
    r"C:\Windows\Fonts\simhei.ttf",
    r"C:\Windows\Fonts\Deng.ttf",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
]

TEXT_COLOR = (255, 255, 255, 255)
SHADOW_COLOR = (0, 0, 0, 60)
SHADOW_OFFSET_DP = 1.2   # 阴影下移量
SHADOW_BLUR_DP = 1.6     # 阴影模糊半径


def dp2px(dp: float) -> int:
    return int(round(dp * SCALE))


def pick_font() -> str:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return path
    raise SystemExit("找不到可用中文字体，请把路径补进 FONT_CANDIDATES")


def ink_bbox(img: Image.Image):
    """返回非透明像素的包围盒（无内容返回 None）"""
    return img.convert("RGBA").split()[-1].getbbox()


def render_brand_text(font_path: str, target_ink_px: int):
    """渲染品牌名，使其「墨迹高度」恰好等于 target_ink_px。

    返回 (composed, ink_rect)：
      composed  —— 带柔和阴影的 RGBA 图
      ink_rect  —— 纯白文字在 composed 内的包围盒，作为排版锚点（阴影不算入）

    实现要点：在 SS 倍尺度下渲染 -> 量墨迹 -> 按比例修正字号 -> 收敛后缩小 SS 倍。
    文字统一用 anchor="mm" 画在画布正中，因此墨迹在画布内天然居中。
    """
    target_ss = target_ink_px * SS
    canvas = target_ss * 6  # 足够大，避免试算字号时被裁切
    size = target_ss        # 初始猜测

    for _ in range(5):
        font = ImageFont.truetype(font_path, size)
        probe = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        ImageDraw.Draw(probe).text((canvas // 2, canvas // 2), BRAND_TEXT, font=font,
                                   fill=TEXT_COLOR, anchor="mm")
        box = ink_bbox(probe)
        if box is None:
            size = int(size * 1.5)
            continue
        got = box[3] - box[1]
        if abs(got - target_ss) <= max(2, target_ss // 60):
            break
        size = max(8, int(round(size * target_ss / got)))

    font = ImageFont.truetype(font_path, size)
    probe = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    ImageDraw.Draw(probe).text((canvas // 2, canvas // 2), BRAND_TEXT, font=font,
                               fill=TEXT_COLOR, anchor="mm")
    box = ink_bbox(probe)
    ink_w, ink_h = box[2] - box[0], box[3] - box[1]

    # 画布 = 墨迹 + 四周留白（给阴影空间）。文字居中 => ink_rect = (p, p, p+ink_w, p+ink_h)
    p = int(max(SHADOW_OFFSET_DP, SHADOW_BLUR_DP) * SCALE * SS) + 4
    lay = (ink_w + p * 2, ink_h + p * 2)
    ctr = (lay[0] / 2, lay[1] / 2)

    shadow_layer = Image.new("RGBA", lay, (0, 0, 0, 0))
    ImageDraw.Draw(shadow_layer).text(ctr, BRAND_TEXT, font=font,
                                      fill=SHADOW_COLOR, anchor="mm")
    shadow = shadow_layer.filter(ImageFilter.GaussianBlur(SHADOW_BLUR_DP * SCALE * SS))
    shadow = shadow.transform(
        shadow.size, Image.AFFINE,
        (1, 0, 0, 0, 1, -SHADOW_OFFSET_DP * SCALE * SS),
        resample=Image.BICUBIC,
    )

    text_layer = Image.new("RGBA", lay, (0, 0, 0, 0))
    ImageDraw.Draw(text_layer).text(ctr, BRAND_TEXT, font=font,
                                    fill=TEXT_COLOR, anchor="mm")

    # 阴影在下、文字在上：文字最后合成，保证笔画是纯白不发灰
    composed = Image.alpha_composite(shadow, text_layer)

    ssize = (max(1, lay[0] // SS), max(1, lay[1] // SS))
    composed = composed.resize(ssize, Image.LANCZOS)
    ink_only = text_layer.resize(ssize, Image.LANCZOS)
    ib = ink_bbox(ink_only)
    if ib is None:
        raise SystemExit("品牌名渲染失败（墨迹为空），请检查字体文件")
    return composed, ib


def main() -> int:
    if not os.path.exists(LOGO_SRC):
        raise SystemExit(f"缺少源 logo: {LOGO_SRC}")

    font_path = pick_font()
    print(f"字体: {font_path}")

    # ---- Logo ----
    logo_px = dp2px(LOGO_DP)
    logo = Image.open(LOGO_SRC).convert("RGBA").resize((logo_px, logo_px), Image.LANCZOS)

    # ---- 品牌名 ----
    text_img, ib = render_brand_text(font_path, dp2px(TEXT_DP))
    ink_w, ink_h = ib[2] - ib[0], ib[3] - ib[1]
    print(f"品牌名墨迹: {ink_w}x{ink_h}px -> {ink_w / SCALE:.1f} x {ink_h / SCALE:.1f} dp")

    # ---- 1) 锁定图：Logo 在上、品牌名在下，整块居中 ----
    gap_px = dp2px(GAP_DP)
    canvas_w = max(logo_px, text_img.width)
    # 让文字图底边贴住画布底边，从而「墨迹底 = logo_px + gap + ink_h」
    canvas_h = logo_px + gap_px - ib[1] + text_img.height
    lockup = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    lockup.alpha_composite(logo, ((canvas_w - logo_px) // 2, 0))
    lockup.alpha_composite(text_img, ((canvas_w - text_img.width) // 2, logo_px + gap_px - ib[1]))
    lockup.save(OUT_LOCKUP)
    print(f"写出 {os.path.relpath(OUT_LOCKUP, ROOT)}  {canvas_w}x{canvas_h}px -> "
          f"{canvas_w / SCALE:.0f} x {canvas_h / SCALE:.0f} dp"
          f"（Logo {LOGO_DP}dp + 间距 {GAP_DP}dp + 文字 {TEXT_DP}dp）")

    # ---- 2) 仅品牌名（Android 12+ branding 槽位）----
    pad_x = dp2px(BRAND_PAD_X_DP)
    bw = max(text_img.width, (ib[2] - ib[0]) + pad_x * 2)
    # 底部留白做成透明内边距：branding 以 gravity=bottom 贴屏底，于是文字距屏底 = BRAND_BOTTOM_DP
    bh = ib[3] + dp2px(BRAND_BOTTOM_DP)
    branding = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    branding.alpha_composite(text_img, ((bw - text_img.width) // 2, 0))
    branding.save(OUT_BRANDING)
    print(f"写出 {os.path.relpath(OUT_BRANDING, ROOT)}  {bw}x{bh}px -> "
          f"{bw / SCALE:.0f} x {bh / SCALE:.0f} dp（文字距底部 {BRAND_BOTTOM_DP}dp）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
