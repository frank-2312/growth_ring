"""从 design/app_icon_source.jpg 生成 Android 启动器图标。

为什么不用 flutter_launcher_icons：
它把整张图当 foreground 塞进 108dp 画布，安全区只有中间 66dp，
这张图最外圈的年轮会被系统裁掉。这里手动控制缩放比例与边缘羽化，
让图案完整落在安全区内、且方形边界与背景色无缝。

用法：
    python tool/make_icons.py
"""

from __future__ import annotations

import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "design", "app_icon_source.jpg")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Android 自适应图标：108dp 画布，72dp 可见区，66dp 安全区。
# 图案本身占原图约 89%，缩到 76% 后直径约 66dp，正好落在安全区边界上——
# 既饱满又不会被裁圆切到最外环。
FOREGROUND_RATIO = 0.76

LEGACY_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

FOREGROUND_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

IOS_ICONS = [
    ("Icon-App-20x20@1x", 20), ("Icon-App-20x20@2x", 40), ("Icon-App-20x20@3x", 60),
    ("Icon-App-29x29@1x", 29), ("Icon-App-29x29@2x", 58), ("Icon-App-29x29@3x", 87),
    ("Icon-App-40x40@1x", 40), ("Icon-App-40x40@2x", 80), ("Icon-App-40x40@3x", 120),
    ("Icon-App-60x60@2x", 120), ("Icon-App-60x60@3x", 180),
    ("Icon-App-76x76@1x", 76), ("Icon-App-76x76@2x", 152),
    ("Icon-App-83.5x83.5@2x", 167),
    ("Icon-App-1024x1024@1x", 1024),
]


def load_square() -> Image.Image:
    """居中裁成正方形。原图 1653x1672，差 19px，直接裁掉底部。"""
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return im.crop((left, top, left + side, top + side))


def pattern_radius(im: Image.Image) -> float:
    """米白年轮的最远像素到中心的距离。用来区分「图案」与「底色」。"""
    side = im.size[0]
    c = side / 2
    px = im.load()
    max_r = 0.0
    for y in range(0, side, 2):
        for x in range(0, side, 2):
            r, g, b = px[x, y]
            if 0.299 * r + 0.587 * g + 0.114 * b > 110:
                d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
                if d > max_r:
                    max_r = d
    return max_r


def ring_color(im: Image.Image, r_in: float, r_out: float) -> tuple[int, int, int]:
    """图案外那一圈环带的中位色 —— 这才是真正的「纸底色」。"""
    side = im.size[0]
    c = side / 2
    px = im.load()
    samples: list[tuple[int, int, int]] = []
    for y in range(0, side, 2):
        for x in range(0, side, 2):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if r_in <= d <= r_out:
                samples.append(px[x, y])
    if not samples:
        return (34, 31, 28)

    def med(i: int) -> int:
        vals = sorted(s[i] for s in samples)
        return vals[len(vals) // 2]

    return (med(0), med(1), med(2))


def flatten_background(
    im: Image.Image, radius: float, bg: tuple[int, int, int]
) -> Image.Image:
    """把图案之外的区域压成纯 bg 色。

    自适应图标的前景层是个正方形，如果它自带的暗色纹理和背景色有差异，
    系统裁成圆形后就能看到一圈方形接缝。这里直接把外面涂平，从根上消除接缝。
    """
    side = im.size[0]
    c = side / 2
    px = im.load()
    inner = radius * 1.01
    outer = radius * 1.07
    for y in range(side):
        for x in range(side):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= inner:
                continue
            if d >= outer:
                px[x, y] = bg
            else:
                t = (d - inner) / (outer - inner)
                r, g, b = px[x, y]
                px[x, y] = (
                    int(r + (bg[0] - r) * t),
                    int(g + (bg[1] - g) * t),
                    int(b + (bg[2] - b) * t),
                )
    return im


def main() -> None:
    sq = load_square()

    # 找出年轮的实际半径，把图案外的区域压成统一底色。
    # 不做这步，自适应图标被裁成圆形时能看到一圈方形接缝。
    radius = pattern_radius(sq)
    bg = ring_color(sq, radius * 1.06, radius * 1.22)
    sq = flatten_background(sq, radius, bg)
    hex_bg = "#{:02X}{:02X}{:02X}".format(*bg)
    print(f"源图裁切后: {sq.size}, 图案半径: {radius:.0f}px, 底色: {hex_bg}")

    # 1. 传统图标（Android 7 及以下、以及部分启动器）
    for folder, size in LEGACY_SIZES.items():
        out_dir = os.path.join(RES, folder)
        os.makedirs(out_dir, exist_ok=True)
        icon = sq.resize((size, size), Image.LANCZOS)
        icon.save(os.path.join(out_dir, "ic_launcher.png"), "PNG", optimize=True)
        print(f"  legacy {folder}/ic_launcher.png  {size}x{size}")

    # 2. 自适应图标前景层：图案缩到 72%，居中
    for folder, canvas in FOREGROUND_SIZES.items():
        out_dir = os.path.join(RES, folder)
        os.makedirs(out_dir, exist_ok=True)
        inner = int(round(canvas * FOREGROUND_RATIO))
        art = sq.resize((inner, inner), Image.LANCZOS).convert("RGBA")
        layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        offset = (canvas - inner) // 2
        layer.paste(art, (offset, offset), art)
        layer.save(
            os.path.join(out_dir, "ic_launcher_foreground.png"), "PNG", optimize=True
        )
        print(f"  fg     {folder}/ic_launcher_foreground.png  {canvas}x{canvas}")

    # 3. 自适应图标描述文件 + 背景色
    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background" />\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
            "</adaptive-icon>\n"
        )
    print("  mipmap-anydpi-v26/ic_launcher.xml")

    values_dir = os.path.join(RES, "values")
    os.makedirs(values_dir, exist_ok=True)
    with open(os.path.join(values_dir, "ic_launcher_background.xml"), "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            f'    <color name="ic_launcher_background">{hex_bg}</color>\n'
            "</resources>\n"
        )
    print(f"  values/ic_launcher_background.xml  {hex_bg}")

    # 4. iOS（有 xcassets 才写，避免路径不存在时报错）
    ios_dir = os.path.join(
        ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    if os.path.isdir(ios_dir):
        for name, size in IOS_ICONS:
            icon = sq.resize((size, size), Image.LANCZOS)
            icon.save(os.path.join(ios_dir, f"{name}.png"), "PNG", optimize=True)
        print(f"  ios {len(IOS_ICONS)} 个尺寸")

    print("完成。")


if __name__ == "__main__":
    main()
