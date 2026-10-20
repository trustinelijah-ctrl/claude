#!/usr/bin/env python3
"""Procedural board surfaces for TABLE.

Each theme's playing surface is baked into one image: 64 individually cut squares,
each with its own grain offset, orientation and tone, the way a veneered board is
assembled. A separate rim texture is produced for the frame.

  python3 tools/materials.py App/Resources/Assets.xcassets
"""
import os
import sys
import json
import numpy as np
from scipy import ndimage
from PIL import Image

RNG = np.random.default_rng(7)
SQ = 256            # pixels per square
N = SQ * 8


def value_noise(h, w, gy, gx, rng):
    """Smooth noise: a random lattice of gy x gx upsampled with cubic splines."""
    grid = rng.standard_normal((gy + 3, gx + 3))
    z = ndimage.zoom(grid, ((h + 3 * h / gy) / (gy + 3), (w + 3 * w / gx) / (gx + 3)), order=3)
    oy = int(1.5 * h / gy)
    ox = int(1.5 * w / gx)
    return z[oy:oy + h, ox:ox + w]


def normalize(a):
    a = a - a.mean()
    return a / (np.abs(a).max() + 1e-9)


def wood(h, w, rng, ring_freq=34.0, warp=0.9, figure=0.5):
    """Flat-sawn grain running along x: rings of a warped log, plus pores and figure."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    warp_field = value_noise(h, w, 3, 2, rng) * warp + value_noise(h, w, 8, 4, rng) * warp * 0.25
    t = (yy / h + warp_field * 0.12) * ring_freq
    rings = np.sin(t * 2 * np.pi)
    rings = np.sign(rings) * np.abs(rings) ** 0.9                     # soften latewood
    streaks = value_noise(h, w, 90, 3, rng)                          # long fine streaks
    pores = value_noise(h, w, 260, 14, rng)
    pores = np.clip(pores - 1.3, 0, None)                            # sparse dark flecks
    fig = value_noise(h, w, 4, 6, rng)                               # broad tonal figure
    return normalize(rings) * 0.55 + normalize(streaks) * 0.35 - pores * 0.8 + normalize(fig) * figure


def stone(h, w, rng, veins=True):
    """Fine-grained stone: soft clouds, mineral speckle and optional thin veins."""
    cloud = normalize(value_noise(h, w, 5, 5, rng) + 0.5 * value_noise(h, w, 13, 13, rng))
    speck = rng.standard_normal((h, w))
    speck = ndimage.gaussian_filter(speck, 0.7)
    out = cloud * 0.6 + normalize(speck) * 0.18
    if veins:
        v = value_noise(h, w, 3, 3, rng) + 0.35 * value_noise(h, w, 9, 9, rng)
        vein = np.exp(-np.abs(np.sin(v * 5.0)) * 18.0)              # thin bright lines
        out -= vein * 0.45
    return out


def colorize(field, dark, light, contrast=1.0):
    t = np.clip(0.5 + 0.5 * field * contrast, 0, 1)[..., None]
    dark = np.array(dark, dtype=np.float64)[None, None, :]
    light = np.array(light, dtype=np.float64)[None, None, :]
    return dark + (light - dark) * t


def board(light_fn, dark_fn, gap_rgb):
    """Assemble 64 squares. Light/dark fns return an (SQ, SQ, 3) float image for a square."""
    img = np.zeros((N, N, 3))
    for r in range(8):
        for f in range(8):
            is_light = (r + f) % 2 == 1   # a1 (file 0, rank 0) is dark
            tile = light_fn(r, f) if is_light else dark_fn(r, f)
            y = (7 - r) * SQ
            x = f * SQ
            img[y:y + SQ, x:x + SQ] = tile
    # hairline seams between squares, barely there
    seam = np.ones((N, N))
    for i in range(1, 8):
        seam[i * SQ - 1:i * SQ + 1, :] *= 0.0
        seam[:, i * SQ - 1:i * SQ + 1] *= 0.0
    seam = ndimage.gaussian_filter(seam, 0.6)
    gap = np.array(gap_rgb, dtype=np.float64)[None, None, :]
    img = img * (0.86 + 0.14 * seam[..., None]) + gap * (0.14 * (1 - seam[..., None]))
    return np.clip(img, 0, 255).astype(np.uint8)


def walnut_board():
    def light(r, f):
        big = wood(SQ * 3, SQ * 3, RNG, ring_freq=70, warp=0.35, figure=0.3)
        oy, ox = RNG.integers(0, SQ * 2, 2)
        field = big[oy:oy + SQ, ox:ox + SQ]
        if (r * 3 + f) % 2 == 0:
            field = field.T                                         # alternate grain direction
        tone = RNG.normal(0, 4)
        return colorize(field, (208 + tone, 182 + tone, 142 + tone), (234 + tone, 214 + tone, 178 + tone), 0.38)

    def dark(r, f):
        big = wood(SQ * 3, SQ * 3, RNG, ring_freq=48, warp=0.5, figure=0.45)
        oy, ox = RNG.integers(0, SQ * 2, 2)
        field = big[oy:oy + SQ, ox:ox + SQ]
        if (r * 3 + f) % 2 == 1:
            field = field.T
        tone = RNG.normal(0, 3)
        return colorize(field, (62 + tone, 38 + tone, 25 + tone), (110 + tone, 72 + tone, 47 + tone), 0.5)

    return board(light, dark, (40, 26, 16))


def slate_board():
    def light(r, f):
        field = stone(SQ, SQ, RNG, veins=RNG.random() < 0.7)
        tone = RNG.normal(0, 2.5)
        return colorize(field, (219 + tone, 211 + tone, 196 + tone), (244 + tone, 239 + tone, 228 + tone), 0.5)

    def dark(r, f):
        field = stone(SQ, SQ, RNG, veins=False)
        cleft = value_noise(SQ, SQ, 12, 6, RNG) * 0.08                # faint layered cleft
        tone = RNG.normal(0, 2)
        return colorize(field + cleft, (56 + tone, 58 + tone, 62 + tone), (84 + tone, 87 + tone, 92 + tone), 0.55)

    return board(light, dark, (30, 31, 33))


def rim(kind):
    h, w = 512, 2048
    if kind == 'walnut':
        field = wood(h, w, RNG, ring_freq=26, warp=0.5, figure=0.5)
        return np.clip(colorize(field, (40, 24, 15), (84, 53, 34), 0.55), 0, 255).astype(np.uint8)
    field = stone(h, w, RNG, veins=False)
    return np.clip(colorize(field, (38, 40, 44), (70, 74, 80), 0.6), 0, 255).astype(np.uint8)


def write_imageset(catalog, name, arr, quality=90):
    d = os.path.join(catalog, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    Image.fromarray(arr).save(os.path.join(d, f"{name}.jpg"), quality=quality, subsampling=0, optimize=True)
    with open(os.path.join(d, "Contents.json"), "w") as fh:
        json.dump({"images": [{"filename": f"{name}.jpg", "idiom": "universal"}],
                   "info": {"author": "xcode", "version": 1}}, fh, indent=2)


if __name__ == '__main__':
    catalog = sys.argv[1]
    write_imageset(catalog, "WalnutSurface", walnut_board())
    write_imageset(catalog, "SlateSurface", slate_board())
    write_imageset(catalog, "WalnutRim", rim('walnut'))
    write_imageset(catalog, "SlateRim", rim('slate'))
    print("ok")
