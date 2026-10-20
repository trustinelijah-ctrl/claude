#!/usr/bin/env python3
"""App icon: the ivory king from the 3D set on emerald shagreen, framed by a fine gilt line.
  python3 tools/icon.py App/Resources/Assets.xcassets
(run tools/render3d.py --catalog and tools/materials.py ... salon first)
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def main(catalog):
    s = 1024
    surf = Image.open(os.path.join(catalog, 'SalonSurface.imageset', 'SalonSurface.jpg')).convert('RGB')
    sq = surf.width // 8
    # four shagreen squares, trimmed of their seams, tiled 2 x 2
    tile = Image.new('RGB', (s, s))
    m = int(sq * 0.05)
    for i, (f, rk) in enumerate([(0, 0), (2, 0), (1, 1), (3, 1)]):
        x0, y0 = f * sq + m, (7 - rk) * sq + m
        part = surf.crop((x0, y0, x0 + sq - 2 * m, y0 + sq - 2 * m)).resize((s // 2, s // 2), Image.LANCZOS)
        tile.paste(part, ((i % 2) * s // 2, (i // 2) * s // 2))
    yy, xx = np.mgrid[0:s, 0:s]
    r = np.sqrt((xx - s / 2) ** 2 + (yy - s * 0.42) ** 2) / (s * 0.75)
    light = np.clip(1.15 - r ** 1.6 * 0.9, 0.25, 1.15)[..., None]
    icon = Image.fromarray(np.clip(np.asarray(tile).astype(float) * light, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(icon)
    d.rectangle([84, 84, s - 84, s - 84], outline=(201, 163, 90), width=6)
    d.rectangle([104, 104, s - 104, s - 104], outline=(201, 163, 90), width=2)
    king = Image.open(os.path.join(catalog, 'Pieces', 'piece-white-king.imageset', 'piece-white-king.png')).convert('RGBA')
    size = 820
    king = king.resize((size, size), Image.LANCZOS)
    base_y = 846
    shadow = Image.new('L', (s, s), 0)
    ImageDraw.Draw(shadow).ellipse([s / 2 - 230, base_y - 70, s / 2 + 230, base_y + 70], fill=170)
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    icon.paste((0, 0, 0), (0, 0), shadow)
    icon.paste(king, (int(s / 2 - size / 2), int(base_y - size * 0.81)), king)
    out = os.path.join(catalog, 'AppIcon.appiconset')
    os.makedirs(out, exist_ok=True)
    icon.save(os.path.join(out, 'AppIcon.png'))
    json.dump({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
               "info": {"author": "xcode", "version": 1}}, open(os.path.join(out, 'Contents.json'), 'w'), indent=2)

    def color(name, rgb):
        cd = os.path.join(catalog, f'{name}.colorset')
        os.makedirs(cd, exist_ok=True)
        r, g, b = rgb
        json.dump({"colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {
            "red": f"{r/255:.3f}", "green": f"{g/255:.3f}", "blue": f"{b/255:.3f}", "alpha": "1.000"}}}],
            "info": {"author": "xcode", "version": 1}}, open(os.path.join(cd, 'Contents.json'), 'w'), indent=2)
    color('LaunchBackground', (0x04, 0x08, 0x07))
    color('AccentColor', (0xD6, 0xB2, 0x6B))


if __name__ == '__main__':
    main(sys.argv[1])
