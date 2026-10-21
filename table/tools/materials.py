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
        return colorize(field, (206 + tone, 199 + tone, 185 + tone), (232 + tone, 227 + tone, 216 + tone), 0.5)

    def dark(r, f):
        field = stone(SQ, SQ, RNG, veins=False)
        cleft = value_noise(SQ, SQ, 12, 6, RNG) * 0.08                # faint layered cleft
        tone = RNG.normal(0, 2)
        return colorize(field + cleft, (56 + tone, 58 + tone, 62 + tone), (84 + tone, 87 + tone, 92 + tone), 0.55)

    return board(light, dark, (30, 31, 33))


def shagreen_tile(n, rng):
    """Stingray leather: densely packed raised beads, each catching a little light."""
    img = np.zeros((n, n))
    yy, xx = np.mgrid[0:n, 0:n]
    step = n / 24
    for gy in range(-1, 29):
        for gx in range(-1, 26):
            cx = (gx + 0.5 * (gy % 2)) * step + rng.normal(0, step * 0.13)
            cy = gy * step * 0.87 + rng.normal(0, step * 0.13)
            r = step * rng.uniform(0.47, 0.6)
            glow = rng.uniform(0.7, 1.0)
            x0, x1 = int(max(0, cx - r - 2)), int(min(n, cx + r + 2))
            y0, y1 = int(max(0, cy - r - 2)), int(min(n, cy + r + 2))
            if x0 >= x1 or y0 >= y1:
                continue
            d = np.sqrt((xx[y0:y1, x0:x1] - cx) ** 2 + (yy[y0:y1, x0:x1] - cy) ** 2) / r
            img[y0:y1, x0:x1] = np.maximum(img[y0:y1, x0:x1], np.clip(1 - d ** 2, 0, None) ** 0.7 * glow)
    light = ndimage.gaussian_filter(img, 0.9)
    lit = np.clip(ndimage.shift(light, (1.2, 1.2), order=1) * -0.35 + light, 0, 1)   # beads lit from the upper left
    base = np.array([10, 32, 27], dtype=np.float64)
    bead = np.array([40, 96, 82], dtype=np.float64)
    out = base[None, None] * (1 - lit[..., None]) + bead[None, None] * lit[..., None]
    out += normalize(value_noise(n, n, 3, 3, rng))[..., None] * 7
    return out


def salon_board():
    def light(r, f):
        field = normalize(value_noise(SQ, SQ, 70, 4, RNG)) * 0.3 + normalize(value_noise(SQ, SQ, 4, 4, RNG)) * 0.5
        if (r + f) % 4 == 1:
            field = field.T
        tone = RNG.normal(0, 2.5)
        return colorize(field, (219 + tone, 209 + tone, 188 + tone), (240 + tone, 233 + tone, 218 + tone), 0.42)

    def dark(r, f):
        return shagreen_tile(SQ, RNG) + RNG.normal(0, 2)

    return board(light, dark, (8, 20, 17))


def marble(h, w, rng, scale=1.0):
    """Marble: soft clouds crossed by a few long, wandering veins with soft halos.
    Returns (cloud, vein)."""
    cloud = normalize(value_noise(h, w, 4, 4, rng) + 0.5 * value_noise(h, w, 11, 11, rng))
    turb = (value_noise(h, w, 2, 2, rng) + 0.5 * value_noise(h, w, 5, 5, rng)
            + 0.25 * value_noise(h, w, 12, 12, rng) + 0.1 * value_noise(h, w, 30, 30, rng))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    t = (xx * 0.5 + yy) / (max(h, w) / (1.4 * scale)) + turb * 0.22
    d = np.abs(np.sin(t * np.pi))
    vein = np.exp(-d * 22.0) * 0.9 + np.exp(-d * 5.0) * 0.25          # crisp core, soft halo
    branch_t = (xx - yy * 0.4) / (max(h, w) / (2.3 * scale)) + turb * 0.3 + 0.37
    vein += np.exp(-np.abs(np.sin(branch_t * np.pi)) * 40.0) * 0.35 * (value_noise(h, w, 3, 3, rng) > 0.2)
    return cloud, np.clip(vein, 0, 1)


def marble_square(rng, base_dark, base_light, vein_rgb, vein_strength, contrast=0.4, scale=1.0, big=3):
    cloud, vein = marble(SQ * big, SQ * big, rng, scale)
    oy, ox = rng.integers(0, SQ * (big - 1), 2)
    c = cloud[oy:oy + SQ, ox:ox + SQ]
    v = vein[oy:oy + SQ, ox:ox + SQ][..., None] * vein_strength
    tone = rng.normal(0, 2.5)
    img = colorize(c, tuple(x + tone for x in base_dark), tuple(x + tone for x in base_light), contrast)
    return img * (1 - v) + np.array(vein_rgb, dtype=np.float64)[None, None, :] * v


def marble_board():
    def light(r, f):   # Calacatta: warm white, grey and faint gold veins
        return marble_square(RNG, (222, 218, 210), (246, 243, 236), (150, 140, 124), 0.55)

    def dark(r, f):    # Nero Marquina: deep black with white veins
        return marble_square(RNG, (14, 14, 16), (40, 39, 42), (205, 200, 192), 0.5, contrast=0.5, scale=1.3)

    return board(light, dark, (10, 10, 12))


def rosewood_board():
    def light(r, f):   # quartered sycamore: pale, fine ripple figure
        big = wood(SQ * 3, SQ * 3, RNG, ring_freq=90, warp=0.25, figure=0.25)
        oy, ox = RNG.integers(0, SQ * 2, 2)
        fld = big[oy:oy + SQ, ox:ox + SQ]
        ripple = np.sin(np.mgrid[0:SQ, 0:SQ][1] / SQ * 2 * np.pi * 22 + value_noise(SQ, SQ, 4, 4, RNG) * 3) * 0.12
        if (r + f) % 4 == 1:
            fld = fld.T
        tone = RNG.normal(0, 3)
        return colorize(fld + ripple, (214 + tone, 196 + tone, 166 + tone), (240 + tone, 226 + tone, 200 + tone), 0.35)

    def dark(r, f):    # Santos rosewood: red-brown with strong black streaks
        big = wood(SQ * 3, SQ * 3, RNG, ring_freq=40, warp=0.7, figure=0.6)
        oy, ox = RNG.integers(0, SQ * 2, 2)
        fld = big[oy:oy + SQ, ox:ox + SQ]
        if (r * 3 + f) % 2 == 1:
            fld = fld.T
        tone = RNG.normal(0, 3)
        return colorize(fld, (58 + tone, 22 + tone, 16 + tone), (132 + tone, 62 + tone, 42 + tone), 0.62)

    return board(light, dark, (36, 14, 10))


def midnight_board():
    def light(r, f):   # pearl: pale silver with soft iridescent cloud
        c = normalize(value_noise(SQ, SQ, 5, 5, RNG) + 0.4 * value_noise(SQ, SQ, 14, 14, RNG))
        tint = normalize(value_noise(SQ, SQ, 3, 3, RNG))[..., None]
        img = colorize(c, (196, 202, 212), (232, 236, 242), 0.35)
        return img + tint * np.array([6, -2, 8])[None, None, :]

    def dark(r, f):    # navy lacquer with a fine fleck, like a night sky
        c = normalize(value_noise(SQ, SQ, 4, 4, RNG))
        img = colorize(c, (14, 22, 44), (30, 42, 76), 0.4)
        fleck = np.clip(RNG.standard_normal((SQ, SQ)) - 3.1, 0, None)
        fleck = ndimage.gaussian_filter(fleck, 0.5) * 140
        return img + fleck[..., None] * np.array([0.9, 0.8, 0.55])[None, None, :]

    return board(light, dark, (8, 12, 26))


def rim(kind):
    h, w = 512, 2048
    if kind == 'walnut':
        field = wood(h, w, RNG, ring_freq=26, warp=0.5, figure=0.5)
        return np.clip(colorize(field, (40, 24, 15), (84, 53, 34), 0.55), 0, 255).astype(np.uint8)
    if kind == 'salon':
        field = normalize(value_noise(h, w, 3, 10, RNG)) * 0.7 + normalize(RNG.standard_normal((h, w))) * 0.05
        return np.clip(colorize(field, (9, 18, 15), (24, 38, 33), 0.6), 0, 255).astype(np.uint8)
    if kind == 'marble':
        cloud, vein = marble(h, w, RNG, 2.0)
        img = colorize(cloud, (12, 12, 14), (34, 33, 36), 0.5)
        v = vein[..., None] * 0.35
        return np.clip(img * (1 - v) + 190 * v, 0, 255).astype(np.uint8)
    if kind == 'rosewood':
        field = wood(h, w, RNG, ring_freq=26, warp=0.6, figure=0.5)
        return np.clip(colorize(field, (44, 16, 11), (104, 46, 30), 0.6), 0, 255).astype(np.uint8)
    if kind == 'midnight':
        field = normalize(value_noise(h, w, 3, 10, RNG)) * 0.7 + normalize(RNG.standard_normal((h, w))) * 0.05
        return np.clip(colorize(field, (8, 12, 26), (22, 30, 56), 0.6), 0, 255).astype(np.uint8)
    field = stone(h, w, RNG, veins=False)
    return np.clip(colorize(field, (38, 40, 44), (70, 74, 80), 0.6), 0, 255).astype(np.uint8)


def write_imageset(catalog, name, arr, quality=90):
    d = os.path.join(catalog, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    Image.fromarray(arr).save(os.path.join(d, f"{name}.jpg"), quality=quality, subsampling=0, optimize=True)
    with open(os.path.join(d, "Contents.json"), "w") as fh:
        json.dump({"images": [{"filename": f"{name}.jpg", "idiom": "universal"}],
                   "info": {"author": "xcode", "version": 1}}, fh, indent=2)


def field(kind):
    """The board's own surface around the playing grid, filling the whole screen (portrait)."""
    h, w = 2048, 1536
    if kind == 'salon':
        # fine pebbled leather: tiny cells over a slow tonal drift
        cells = value_noise(h, w, 340, 260, RNG)
        drift = normalize(value_noise(h, w, 3, 3, RNG))
        f = normalize(np.abs(cells)) * 0.35 + drift * 0.5
        return np.clip(colorize(f, (9, 20, 17), (24, 41, 35), 0.7), 0, 255).astype(np.uint8)
    if kind == 'walnut':
        f = wood(w, h, RNG, ring_freq=30, warp=0.5, figure=0.5).T     # grain runs along the long side
        return np.clip(colorize(f, (34, 20, 12), (78, 50, 31), 0.55), 0, 255).astype(np.uint8)
    if kind == 'marble':
        cloud, vein = marble(h, w, RNG, 1.2)
        img = colorize(cloud, (10, 10, 12), (30, 29, 32), 0.5)
        v = vein[..., None] * 0.3
        return np.clip(img * (1 - v) + np.array([180, 172, 160])[None, None, :] * v, 0, 255).astype(np.uint8)
    if kind == 'rosewood':
        f = wood(w, h, RNG, ring_freq=28, warp=0.6, figure=0.55).T
        return np.clip(colorize(f, (38, 14, 10), (92, 40, 27), 0.55), 0, 255).astype(np.uint8)
    if kind == 'midnight':
        cells = value_noise(h, w, 340, 260, RNG)
        drift = normalize(value_noise(h, w, 3, 3, RNG))
        f = normalize(np.abs(cells)) * 0.35 + drift * 0.5
        return np.clip(colorize(f, (7, 11, 24), (20, 28, 52), 0.7), 0, 255).astype(np.uint8)
    f = stone(h, w, RNG, veins=False)
    return np.clip(colorize(f, (196, 189, 177), (224, 218, 207), 0.45), 0, 255).astype(np.uint8)


if __name__ == '__main__':
    catalog = sys.argv[1]
    if len(sys.argv) > 2 and sys.argv[2] == 'pro':
        for name, surface in (('Marble', marble_board), ('Rosewood', rosewood_board), ('Midnight', midnight_board)):
            write_imageset(catalog, f"{name}Surface", surface())
            write_imageset(catalog, f"{name}Rim", rim(name.lower()))
            write_imageset(catalog, f"{name}Field", field(name.lower()), quality=88)
        print("ok")
        sys.exit(0)
    if len(sys.argv) > 2 and sys.argv[2] == 'field':
        write_imageset(catalog, "SalonField", field('salon'), quality=88)
        write_imageset(catalog, "WalnutField", field('walnut'), quality=88)
        write_imageset(catalog, "SlateField", field('slate'), quality=88)
        print("ok")
        sys.exit(0)
    if len(sys.argv) > 2 and sys.argv[2] == 'salon':
        write_imageset(catalog, "SalonSurface", salon_board())
        write_imageset(catalog, "SalonRim", rim('salon'))
        grain = (np.clip(RNG.normal(0.5, 0.18, (256, 256)), 0, 1) * 255).astype(np.uint8)
        d = os.path.join(catalog, "Grain.imageset")
        os.makedirs(d, exist_ok=True)
        Image.fromarray(grain, 'L').save(os.path.join(d, "Grain.png"))
        with open(os.path.join(d, "Contents.json"), "w") as fh:
            json.dump({"images": [{"filename": "Grain.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, fh, indent=2)
        print("ok")
        sys.exit(0)
    write_imageset(catalog, "WalnutSurface", walnut_board())
    write_imageset(catalog, "SlateSurface", slate_board())
    write_imageset(catalog, "WalnutRim", rim('walnut'))
    write_imageset(catalog, "SlateRim", rim('slate'))
    print("ok")
