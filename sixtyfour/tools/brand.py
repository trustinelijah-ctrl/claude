#!/usr/bin/env python3
"""Brand assets for 64 from the logo artwork in tools/sources/logo-64.png.

  python3 tools/brand.py App/Resources/Assets.xcassets

Writes:
  Logo.imageset      the mark as a template image (tinted in code: cream, brown or gold)
  AppIcon.appiconset cream mark on the house brown
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

BROWN = (56, 31, 17)        # the logo's own brown, #381F11
CREAM = (242, 232, 216)     # #F2E8D8
HERE = os.path.dirname(os.path.abspath(__file__))


def mark():
    """The logo as a smooth alpha mask, cropped to the artwork, three times the source size."""
    src = Image.open(os.path.join(HERE, 'sources', 'logo-64.png')).convert('RGBA')
    a = np.array(src).astype(np.float32)
    dist = np.abs(a[..., :3] - BROWN).sum(-1)
    alpha = a[..., 3] / 255 * (dist < 90)
    m = Image.fromarray((alpha * 255).astype(np.uint8))
    m = m.crop(m.point(lambda v: 255 if v > 128 else 0).getbbox())
    w, h = m.size
    # The source is hand cut; upscale, smooth the stair-steps, re-threshold with a soft edge.
    big = m.resize((w * 3, h * 3), Image.LANCZOS).filter(ImageFilter.GaussianBlur(3.0))
    arr = np.clip((np.array(big).astype(np.float32) / 255 - 0.5) * 5 + 0.5, 0, 1)
    return Image.fromarray((arr * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))


def write_set(catalog, folder, filename, image, contents):
    d = os.path.join(catalog, folder)
    os.makedirs(d, exist_ok=True)
    image.save(os.path.join(d, filename), optimize=True)
    with open(os.path.join(d, 'Contents.json'), 'w') as fh:
        json.dump(contents, fh, indent=2)


def main(catalog):
    m = mark()
    # Template logo: white with the mark's alpha, 1200 px wide.
    w = 1200
    logo_mask = m.resize((w, round(m.height * w / m.width)), Image.LANCZOS)
    logo = Image.new('RGBA', logo_mask.size, (255, 255, 255, 0))
    logo.putalpha(logo_mask)
    write_set(catalog, 'Logo.imageset', 'Logo.png', logo, {
        "images": [{"filename": "Logo.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "template", "preserves-vector-representation": False},
    })

    # App icon: the cream mark on brown, lit a little from above.
    n = 1024
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / n
    light = np.clip(1 - np.hypot(xx - 0.5, yy - 0.35) * 1.1, 0, 1)[..., None]
    bg = np.array(BROWN, np.float32) * (0.82 + 0.38 * light)
    icon = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8))
    target_w = int(n * 0.70)
    im = m.resize((target_w, round(m.height * target_w / m.width)), Image.LANCZOS)
    x = (n - im.width) // 2
    y = (n - im.height) // 2 + int(n * 0.01)
    icon.paste(Image.new('RGB', im.size, CREAM), (x, y), im)
    write_set(catalog, 'AppIcon.appiconset', 'AppIcon.png', icon, {
        "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    })

    def color(name, rgb):
        d = os.path.join(catalog, f'{name}.colorset')
        os.makedirs(d, exist_ok=True)
        r, g, b = (f"{c / 255:.3f}" for c in rgb)
        with open(os.path.join(d, 'Contents.json'), 'w') as fh:
            json.dump({"colors": [{"idiom": "universal", "color": {"color-space": "srgb",
                       "components": {"red": r, "green": g, "blue": b, "alpha": "1.000"}}}],
                       "info": {"author": "xcode", "version": 1}}, fh, indent=2)
    color('LaunchBackground', BROWN)
    color('BrandBrown', BROWN)
    color('BrandCream', CREAM)
    print('ok')


if __name__ == '__main__':
    main(sys.argv[1])
