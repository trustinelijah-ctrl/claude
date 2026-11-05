#!/usr/bin/env python3
"""Board surfaces from photo-scanned veneers and stone (Poly Haven, CC0).

Each square is cut from a real veneer scan at a believable scale (a 5 cm square on a
1 m sheet), turned so neighbouring squares run their grain across each other the way
a marquetry board is laid, toned slightly per square, then graded to the theme's
colours so 64 keeps its look. The table around the board is a large, darker cut of a
matching scan. The scans are downloaded into tools/sources/textures (not committed);
CREDITS.md there lists them.

  python3 tools/scanned.py App/Resources/Assets.xcassets [House Walnut Rosewood ...]
"""
import json
import os
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'sources', 'textures')
UA = {'User-Agent': '64-chess-app-texture-build'}
RNG = np.random.default_rng(64)
SQ = 256
N = SQ * 8


def fetch(asset, res='4k'):
    os.makedirs(SRC, exist_ok=True)
    path = os.path.join(SRC, f'{asset}_diff_{res}.jpg')
    if not os.path.exists(path):
        meta = json.load(urllib.request.urlopen(urllib.request.Request(
            f'https://api.polyhaven.com/files/{asset}', headers=UA), timeout=60))
        url = meta['Diffuse'][res]['jpg']['url']
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r, open(path, 'wb') as f:
            f.write(r.read())
    return path


_cache = {}
def scan(asset):
    if asset not in _cache:
        _cache[asset] = np.asarray(Image.open(fetch(asset)).convert('RGB'), dtype=np.float32)
    return _cache[asset]


def grade(img, mean, spread, sat=1.0):
    """Moves an image to a target mean colour, keeping the scan's own light and grain.
    `spread` scales the detail; `sat` keeps (1) or mutes (<1) the scan's own colour shifts."""
    m = img.reshape(-1, 3).mean(0)
    lum = img.mean(-1, keepdims=True)
    lum_m = lum.mean()
    detail = (lum - lum_m) * spread
    chroma = (img - lum) - (m - m.mean())
    out = np.array(mean, np.float32)[None, None, :] + detail + chroma * sat
    return out


def cut(asset, size_px, turn):
    """A square from a random place on the scan, `size_px` of the scan wide, turned."""
    s = scan(asset)
    h, w, _ = s.shape
    y = RNG.integers(0, h - size_px); x = RNG.integers(0, w - size_px)
    tile = Image.fromarray(s[y:y + size_px, x:x + size_px].astype(np.uint8)).resize((SQ, SQ), Image.LANCZOS)
    tile = np.asarray(tile, dtype=np.float32)
    if turn:
        tile = np.rot90(tile)
    if RNG.random() < 0.5:
        tile = tile[::-1, ::-1]
    return tile


def board(light, dark, seam_rgb):
    """light/dark: (asset, scan px per square, mean rgb, spread, sat, invert)."""
    img = np.zeros((N, N, 3), np.float32)
    for r in range(8):
        for f in range(8):
            is_light = (r + f) % 2 == 1
            asset, px, mean, spread, sat, inv = light if is_light else dark
            # Marquetry: light squares run one way, dark squares across them.
            tile = cut(asset, px, turn=(is_light != ((r + f) % 4 < 2)))
            if inv:
                tile = 255 - tile
            tone = RNG.normal(0, 2.2)
            tile = grade(tile, tuple(c + tone for c in mean), spread, sat)
            # each square catches the lamp a touch differently
            tile *= 1 + RNG.normal(0, 0.012)
            y = (7 - r) * SQ; x = f * SQ
            img[y:y + SQ, x:x + SQ] = tile
    # hairline seams where the squares meet, and a whisper of lacquer sheen across the board
    seam = np.ones((N, N), np.float32)
    for i in range(1, 8):
        seam[i * SQ - 1:i * SQ + 1, :] = 0
        seam[:, i * SQ - 1:i * SQ + 1] = 0
    seam = np.asarray(Image.fromarray((seam * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255
    gap = np.array(seam_rgb, np.float32)[None, None, :]
    img = img * (0.82 + 0.18 * seam[..., None]) + gap * (0.18 * (1 - seam[..., None]))
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N
    sheen = np.exp(-(((xx - 0.38) / 0.55) ** 2 + ((yy - 0.3) / 0.45) ** 2))
    img *= (0.965 + 0.06 * sheen)[..., None]
    return np.clip(img, 0, 255).astype(np.uint8)


def table(asset, mean, spread, sat=0.8, px=1600, inv=False):
    """The surface around the board: one big, darker cut, grain along the long side."""
    s = scan(asset)
    h, w, _ = s.shape
    y = RNG.integers(0, h - px); x = RNG.integers(0, w - int(px * 0.75))
    crop = Image.fromarray(s[y:y + px, x:x + int(px * 0.75)].astype(np.uint8)).resize((1536, 2048), Image.LANCZOS)
    a = np.asarray(crop, np.float32)
    if inv:
        a = 255 - a
    a = grade(a, mean, spread, sat)
    yy, xx = np.mgrid[0:2048, 0:1536].astype(np.float32)
    vign = 1 - 0.18 * (((xx / 1536 - 0.5) ** 2 + (yy / 2048 - 0.45) ** 2) * 2.2)
    return np.clip(a * vign[..., None], 0, 255).astype(np.uint8)


def write_imageset(catalog, name, arr, quality=90):
    d = os.path.join(catalog, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        if f.endswith(('.jpg', '.png')):
            os.remove(os.path.join(d, f))
    Image.fromarray(arr).save(os.path.join(d, f"{name}.jpg"), quality=quality, subsampling=0, optimize=True)
    with open(os.path.join(d, "Contents.json"), "w") as fh:
        json.dump({"images": [{"filename": f"{name}.jpg", "idiom": "universal"}],
                   "info": {"author": "xcode", "version": 1}}, fh, indent=2)


# theme: (light square, dark square, seam colour, table)
THEMES = {
    # 64's own board: maple and American walnut, warm and matte, brown table.
    'House': (('white_maple_veneer', 300, (234, 219, 193), 0.55, 0.45, False),
              ('american_walnut_veneer', 300, (124, 82, 52), 0.85, 0.7, False),
              (48, 27, 15), ('brown_leather', (52, 30, 17), 0.7, 0.6)),
    'Walnut': (('white_maple_veneer', 260, (228, 206, 168), 0.9, 0.8, False),
               ('black_walnut_veneer_01', 260, (84, 54, 36), 1.0, 0.9, False),
               (36, 24, 15), ('walnut_veneer', (56, 36, 22), 0.8, 0.8)),
    'Rosewood': (('ash_veneer', 260, (226, 214, 190), 0.85, 0.6, False),
                 ('rosewood_veneer1', 260, (110, 52, 36), 1.0, 1.0, False),
                 (40, 16, 11), ('rosewood_veneer_02', (62, 26, 18), 0.85, 0.9)),
    'Ebony': (('white_maple_veneer', 240, (222, 200, 160), 0.9, 0.8, False),
              ('flamed_black_veneer', 260, (36, 29, 25), 1.1, 0.7, False),
              (14, 11, 10), ('smoked_walnut_veneer', (24, 19, 16), 0.8, 0.6)),
    'Olive': (('ash_veneer', 260, (224, 214, 192), 0.85, 0.6, False),
              ('olive_veneer', 300, (150, 122, 76), 1.0, 0.9, False),
              (40, 32, 18), ('olive_veneer', (52, 42, 26), 0.8, 0.7)),
    # Calacatta and Nero Marquina from one scan: the dark squares are its negative.
    'Marble': (('marble_rock_02', 700, (228, 224, 217), 0.95, 0.15, False),
               ('marble_rock_02', 700, (30, 29, 31), 1.25, 0.1, True),
               (20, 20, 22), ('marble_rock_02', (22, 21, 23), 0.7, 0.1, True)),
}


if __name__ == '__main__':
    catalog = sys.argv[1]
    only = sys.argv[2:] or list(THEMES)
    for name in only:
        light, dark, seam, tbl = THEMES[name]
        write_imageset(catalog, f'{name}Surface', board(light, dark, seam))
        asset, mean, spread, sat, *inv = tbl
        write_imageset(catalog, f'{name}Field', table(asset, mean, spread, sat, inv=bool(inv and inv[0])), quality=88)
        print(name, 'ok', flush=True)
    with open(os.path.join(SRC, 'CREDITS.md'), 'w') as f:
        f.write('# Texture credits\n\nAll scans from Poly Haven (https://polyhaven.com), licensed CC0.\n\n')
        assets = sorted({t[0][0] for t in THEMES.values()} | {t[1][0] for t in THEMES.values()} | {t[3][0] for t in THEMES.values()})
        for a in assets:
            f.write(f'- {a}: https://polyhaven.com/a/{a}\n')
