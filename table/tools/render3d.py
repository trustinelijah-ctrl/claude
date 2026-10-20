#!/usr/bin/env python3
"""Offline 3D renderer for the TABLE piece set.

Each piece is a signed-distance solid: the lathe profiles from pieces.py are spun into
surfaces of revolution, finials (crown balls, cross, mitre bead) are added as primitives,
the rook's crenels and the bishop's mitre cut are carved out, and the knight's head is
the 2D drawing extruded with rounded edges. Solids are ray-marched with an orthographic
camera looking down at 35 degrees, shaded with a warm key light, cool fill, rim light,
ambient occlusion and a studio environment for reflections, then written as RGBA sprites.

  python3 tools/render3d.py --catalog App/Resources/Assets.xcassets
  python3 tools/render3d.py OUT_DIR [size] [pieces...]   (preview)
"""
import io
import os
import sys

import cairosvg
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import pieces as P  # noqa: E402

ELEV = np.radians(35.0)
HEIGHT_SCALE = 1.16
RADIUS_SCALE = 0.9
FLOOR = 92.0
# Image framing, shared by every sprite so they line up on the board:
# x spans [-50, 50]; camera-plane y spans [PY_MIN, PY_MIN + 100]; the base centre projects to y = 0.
PY_MIN = -19.0

F32 = np.float32


# ------------------------------------------------------------------ profiles

def silhouette_mask(paths, res=2000):
    d = ' '.join(P.svg_path(p) for p in paths)
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{res}" height="{res}" viewBox="0 0 100 100">'
           f'<path d="{d}" fill="#000"/></svg>')
    im = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode()))).split()[-1]
    return np.asarray(im).astype(F32) / 255.0


def profile_from(paths, y_cut=None, res=2000):
    """Radius of a symmetric silhouette as a function of height above the floor."""
    m = silhouette_mask(paths, res) > 0.5
    half = res // 2
    ys = np.arange(res)
    r = np.zeros(res, F32)
    for row in ys:
        xs = np.nonzero(m[row, half:])[0]
        if len(xs):
            r[row] = (xs.max() + 0.5) / res * 100.0
    art_y = (ys + 0.5) / res * 100.0
    if y_cut is not None:
        r[art_y < y_cut] = 0
    height = (FLOOR - art_y) * HEIGHT_SCALE
    order = np.argsort(height)
    r = r[order] * RADIUS_SCALE
    # the raster profile is stepped; smooth it so turned surfaces shade cleanly
    solid = r > 0
    r = np.where(solid, ndimage.gaussian_filter1d(r, 3.0), 0)
    return height[order].astype(F32), r.astype(F32)


class Lathe:
    def __init__(self, heights, radii):
        self.h = heights
        self.r = radii
        nz = np.nonzero(radii > 0)[0]
        self.top = heights[nz.max()]
        self.bottom = max(0.0, heights[nz.min()])

    def radius(self, y):
        return np.interp(y, self.h, self.r, left=0, right=0).astype(F32)

    def sdf(self, x, y, z):
        rho = np.sqrt(x * x + z * z)
        d = (rho - self.radius(y)) * F32(0.62)
        d = np.maximum(d, self.bottom - y)
        d = np.maximum(d, y - self.top)
        return d


def sphere(x, y, z, c, r):
    return np.sqrt((x - c[0]) ** 2 + (y - c[1]) ** 2 + (z - c[2]) ** 2) - r


def box(x, y, z, c, half, round_=0.0):
    qx = np.abs(x - c[0]) - half[0] + round_
    qy = np.abs(y - c[1]) - half[1] + round_
    qz = np.abs(z - c[2]) - half[2] + round_
    outside = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2 + np.maximum(qz, 0) ** 2)
    inside = np.minimum(np.maximum(qx, np.maximum(qy, qz)), 0)
    return outside + inside - round_


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def hy(art_y):
    """Height above the floor of an art-space y coordinate."""
    return (FLOOR - art_y) * HEIGHT_SCALE


# ------------------------------------------------------------------ the solids

def gold_bands(lathe, extra=()):
    """Turned rings that protrude from their neighbours get a gilt band."""
    h, r = lathe.h, lathe.r
    sm = ndimage.gaussian_filter1d(r, 6)
    bands = []
    for i in range(30, len(h) - 30):
        if sm[i] > 3 and sm[i] >= sm[i - 30:i + 30].max() - 1e-4 and sm[i] - min(sm[i - 30], sm[i + 30]) > 0.6:
            if not bands or abs(h[i] - bands[-1]) > 3:
                bands.append(float(h[i]))
    return [b for b in bands if b > 4] + list(extra)


def build(name):
    art = getattr(P, name)()
    if name == 'pawn':
        L = Lathe(*profile_from(art['body'], y_cut=47.6))
        head_r = 9.4
        head_c = hy(48.8) + head_r * 0.82
        def sdf(x, y, z):
            return smin(L.sdf(x, y, z), sphere(x, y, z, (0, head_c, 0), head_r), 1.6)
        return dict(sdf=sdf, bands=gold_bands(L), lathe=L)

    if name == 'rook':
        L = Lathe(*profile_from(art['body']))
        top = L.top
        def sdf(x, y, z):
            d = L.sdf(x, y, z)
            # crenels: six slots cut down from the top of the tower
            ang = np.arctan2(z, x)
            k = np.round((ang - np.pi / 4) / (np.pi / 2)) * (np.pi / 2) + np.pi / 4
            # rotate into the slot frame
            ca, sa = np.cos(-k), np.sin(-k)
            lx = x * ca - z * sa
            lz = x * sa + z * ca
            slot = box(lx, y, lz, (16, top, 0), (4.5, 4.6 * HEIGHT_SCALE, 2.9), 0.5)
            d = np.maximum(d, -slot)
            # hollow the top slightly so the battlement reads as a rim
            well = sphere(x, y, z, (0, top + 24, 0), 27.6)
            return np.maximum(d, -well)
        return dict(sdf=sdf, bands=[b for b in gold_bands(L) if b < top - 14], lathe=L)

    if name == 'bishop':
        L = Lathe(*profile_from(art['body'][1:]))
        bead_y = hy(18.5)
        def sdf(x, y, z):
            d = L.sdf(x, y, z)
            d = smin(d, sphere(x, y, z, (0, bead_y, 0), 3.6), 1.2)
            # the mitre's slanted cut, through the front of the head
            c = (2.0, hy(36.0), 6.0)
            ang = np.radians(-42)
            lx = (x - c[0]) * np.cos(ang) - (y - c[1]) * np.sin(ang)
            ly = (x - c[0]) * np.sin(ang) + (y - c[1]) * np.cos(ang)
            cut = box(lx, ly, z - c[2], (0, 0, 0), (9.5, 0.9, 12), 0.3)
            return np.maximum(d, -cut)
        def finial(x, y, z):
            return sphere(x, y, z, (0, bead_y, 0), 3.6)
        return dict(sdf=sdf, bands=gold_bands(L), lathe=L, finials=finial)

    if name == 'queen':
        L = Lathe(*profile_from(art['body'][5:]))
        top = 22.6
        ring_y = hy(top + 0.6)
        def finial(x, y, z):
            d = sphere(x, y, z, (0, hy(top - 1.0), 0), 3.4)
            for i in range(8):
                a = i * np.pi / 4 + np.pi / 8
                d = np.minimum(d, sphere(x, y, z, (np.cos(a) * 15.6, ring_y, np.sin(a) * 15.6), 2.6))
            return d
        def sdf(x, y, z):
            d = L.sdf(x, y, z)
            # flatten the revolved coronet into a cup, then crown it with balls
            d = np.maximum(d, y - hy(top + 3.4))
            d = smin(d, sphere(x, y, z, (0, hy(top + 2.0), 0), 6.5), 2.5)
            return np.minimum(d, finial(x, y, z))
        return dict(sdf=sdf, bands=gold_bands(L), lathe=L, finials=finial)

    if name == 'king':
        L = Lathe(*profile_from(art['body'], y_cut=8.0 + 13.4))
        cy0 = hy(8.0 + 13.4)
        def finial(x, y, z):
            upright = box(x, y, z, (0, cy0 + 7.0 * HEIGHT_SCALE, 0), (2.4, 7.6 * HEIGHT_SCALE, 2.4), 0.6)
            arms = box(x, y, z, (0, cy0 + 9.6 * HEIGHT_SCALE, 0), (7.0, 2.3 * HEIGHT_SCALE, 2.4), 0.6)
            return np.minimum(upright, arms)
        def sdf(x, y, z):
            d = L.sdf(x, y, z)
            # close the crown with a gentle dome
            d = smin(d, sphere(x, y, z, (0, hy(8.0 + 20.0), 0), 11.5), 2.0)
            d = np.maximum(d, y - hy(8.0 + 14.6))
            return np.minimum(d, finial(x, y, z))
        return dict(sdf=sdf, bands=gold_bands(L), lathe=L, finials=finial)

    if name == 'knight':
        Lb = Lathe(*profile_from([art['body'][0]]))
        head = silhouette_mask([art['body'][1]], 1000) > 0.5
        sd = (ndimage.distance_transform_edt(~head) - ndimage.distance_transform_edt(head)) / 1000 * 100
        sd = sd.astype(F32)
        thick = 7.5
        def head_sdf(x, y, z):
            # back into art space: x right, art y down
            ax = x + 50
            ay = FLOOR - y / HEIGHT_SCALE
            ix = np.clip(ax / 100 * 1000, 0, 999)
            iy = np.clip(ay / 100 * 1000, 0, 999)
            d2 = ndimage.map_coordinates(sd, [iy.ravel(), ix.ravel()], order=1, mode='nearest').reshape(x.shape)
            d2 = d2 * HEIGHT_SCALE * 0.9
            # thicker through the neck and jaw than at the muzzle
            t = thick * (0.80 + 0.30 * np.clip((ax - 18) / 50, 0, 1))
            inset = np.clip(-d2, 0, None)
            # thickness swells from the edge inward: a rounded, hand-carved section
            tz = t * (1 - np.exp(-inset / 3.0))
            # the swell's slope is about t / 3, so step conservatively
            return np.maximum(d2, (np.abs(z) - tz)) * F32(0.34)
        def sdf(x, y, z):
            h = np.maximum(head_sdf(x, y, z), hy(71.0) - y)
            # a short turned stem seats the head on its base, as on the other pieces
            rho = np.sqrt(x * x + z * z)
            r = np.interp(y, [hy(76.5), hy(73.5), hy(70.0)], [17.0, 13.6, 12.2]).astype(F32)
            stem = np.maximum(np.maximum(rho - r, y - hy(70.0)), hy(76.5) - y) * F32(0.45)
            return smin(smin(Lb.sdf(x, y, z), stem, 1.4), h, 2.4)
        # engraved eye, nostril, mane and cheek lines, used to darken the surface
        marks = silhouette_mask(art['cut'], 1000)
        lines = ' '.join(P.svg_path(dl) for dl in art['detail'][:7])
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1000" viewBox="0 0 100 100">'
               f'<path d="{lines}" fill="none" stroke="#000" stroke-width="1.1" stroke-linecap="round"/></svg>')
        strokes = np.asarray(Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode()))).split()[-1]).astype(F32) / 255
        def lookup(img):
            def f(x, y, z):
                ax = np.clip((x + 50) / 100 * 1000, 0, 999)
                ay = np.clip((FLOOR - y / HEIGHT_SCALE) / 100 * 1000, 0, 999)
                return ndimage.map_coordinates(img, [ay.ravel(), ax.ravel()], order=1).reshape(x.shape)
            return f
        return dict(sdf=sdf, bands=[b for b in gold_bands(Lb) if b < hy(76)][-1:], lathe=Lb,
                    engraving=lookup(marks), gilt_lines=lookup(strokes))
    raise ValueError(name)


# ------------------------------------------------------------------ rendering

MATERIALS = {
    'ivory': dict(albedo=(0.97, 0.93, 0.84), spec=0.30, gloss=90, env=0.16, sss=(0.16, 0.11, 0.05), exposure=1.28),
    'ebony': dict(albedo=(0.030, 0.026, 0.024), spec=0.9, gloss=260, env=0.55, sss=(0, 0, 0), exposure=1.0),
}
GOLD = np.array([1.0, 0.76, 0.40], F32)


def env(rx, ry, rz):
    """A dim room with a large warm softbox overhead and a faint window to the left."""
    top = np.clip((ry - 0.35) / 0.5, 0, 1) ** 1.5
    soft = top[..., None] * np.array([1.0, 0.92, 0.80], F32) * 1.6
    window = np.exp(-((rx + 0.75) ** 2 + (ry - 0.1) ** 2 + (rz - 0.2) ** 2) * 6)[..., None] * np.array([0.6, 0.7, 0.85], F32)
    horizon = (np.exp(-ry * ry * 10) * 0.10)[..., None] * np.array([1, 0.9, 0.8], F32)
    return soft + window + horizon


def render(name, material, size=512, ss=2):
    solid = build(name)
    sdf = solid['sdf']
    n = size * ss
    f = np.array([0, -np.sin(ELEV), -np.cos(ELEV)], F32)
    up = np.array([0, np.cos(ELEV), -np.sin(ELEV)], F32)
    right = np.array([1, 0, 0], F32)
    px = (np.arange(n, dtype=F32) + 0.5) / n * 100 - 50
    py = PY_MIN + 100 - (np.arange(n, dtype=F32) + 0.5) / n * 100
    PX, PY = np.meshgrid(px, py)
    ox = PX * right[0] + PY * up[0] - f[0] * 150
    oy = PX * right[1] + PY * up[1] - f[1] * 150
    oz = PX * right[2] + PY * up[2] - f[2] * 150
    t = np.zeros_like(PX)
    hit = np.zeros(PX.shape, bool)
    alive = np.ones(PX.shape, bool)
    for _ in range(260):
        idx = np.nonzero(alive)
        if len(idx[0]) == 0:
            break
        tt = t[idx]
        x = ox[idx] + f[0] * tt
        y = oy[idx] + f[1] * tt
        z = oz[idx] + f[2] * tt
        d = sdf(x, y, z)
        done = d < 0.01
        hit[idx[0][done], idx[1][done]] = True
        far = tt > 320
        t[idx] = tt + np.maximum(d, 0.004)
        stop = done | far
        alive[idx[0][stop], idx[1][stop]] = False

    out = np.zeros((n, n, 4), F32)
    idx = np.nonzero(hit)
    tt = t[idx]
    x = ox[idx] + f[0] * tt
    y = oy[idx] + f[1] * tt
    z = oz[idx] + f[2] * tt
    e = 0.22
    nx = sdf(x + e, y, z) - sdf(x - e, y, z)
    ny = sdf(x, y + e, z) - sdf(x, y - e, z)
    nz = sdf(x, y, z + e) - sdf(x, y, z - e)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-9
    nx, ny, nz = nx / ln, ny / ln, nz / ln

    # ambient occlusion from the distance field
    ao = np.ones_like(x)
    for i, step in enumerate([0.8, 1.8, 3.2, 5.0]):
        dd = sdf(x + nx * step, y + ny * step, z + nz * step)
        ao -= (step - dd) / step * (0.5 ** i) * 0.35
    ao = np.clip(ao, 0.25, 1)
    # the floor occludes the foot
    ao *= np.clip(0.55 + y / 10, 0.55, 1)

    vx, vy, vz = -f[0], -f[1], -f[2]
    ndv = np.clip(nx * vx + ny * vy + nz * vz, 0, 1)
    m = MATERIALS[material]
    alb = np.array(m['albedo'], F32)

    gilt = np.zeros_like(x, bool)
    for b in solid['bands']:
        gilt |= np.abs(y - b) < 0.75 * HEIGHT_SCALE
    if 'finials' in solid:
        gilt |= solid['finials'](x, y, z) < 0.05
    if name == 'king':
        gilt |= y > hy(8.0 + 13.4) + 0.4

    lights = [((-0.55, 0.78, 0.55), (1.00, 0.93, 0.82), 1.15),
              ((0.80, 0.30, 0.45), (0.70, 0.78, 0.95), 0.28),
              ((0.10, 0.45, -0.95), (1.00, 0.95, 0.90), 0.55)]
    col = np.zeros((len(x), 3), F32)
    spec = np.zeros((len(x), 3), F32)
    for (lx, ly, lz), lc, li in lights:
        l = np.array([lx, ly, lz], F32)
        l /= np.linalg.norm(l)
        ndl = nx * l[0] + ny * l[1] + nz * l[2]
        wrap = np.clip((ndl + 0.25) / 1.25, 0, 1)
        hx, hy_, hz = l[0] + vx, l[1] + vy, l[2] + vz
        hl = np.sqrt(hx * hx + hy_ * hy_ + hz * hz)
        ndh = np.clip((nx * hx + ny * hy_ + nz * hz) / hl, 0, 1)
        col += (wrap * li)[:, None] * np.array(lc, F32)[None]
        spec += ((ndh ** m['gloss']) * li * (np.clip(ndl, 0, 1) > 0))[:, None] * np.array(lc, F32)[None]

    # reflections
    rdn = nx * vx + ny * vy + nz * vz
    rx, ry, rz = 2 * rdn * nx - vx, 2 * rdn * ny - vy, 2 * rdn * nz - vz
    refl = env(rx, ry, rz)
    fres = 0.04 + 0.96 * (1 - ndv) ** 5

    diffuse = col * alb[None] * ao[:, None] + 0.10 * alb[None] * ao[:, None]
    subsurface = (1 - ndv)[:, None] ** 2 * np.array(m['sss'], F32)[None]
    dielectric = diffuse + subsurface + spec * m['spec'] + refl * (m['env'] * fres + 0.02)[:, None] * ao[:, None]
    metal = (col * 0.35 + refl * 0.9 + spec * 1.2) * GOLD[None] * ao[:, None] + 0.04
    if 'engraving' in solid:
        face = (np.abs(z) > 1.2) & (y > hy(75))
        g = solid['engraving'](x, y, z) * face
        dielectric = dielectric * (1 - 0.8 * g)[:, None]
        lines = solid['gilt_lines'](x, y, z) * face
        metal_line = metal * 0.9
        shade = np.where(gilt[:, None], metal, dielectric * m['exposure'])
        shade = shade * (1 - lines[:, None]) + metal_line * lines[:, None]
    else:
        shade = np.where(gilt[:, None], metal, dielectric * m['exposure'])

    # turned ivory darkens a little toward its silhouette, so it reads on pale squares
    if material == 'ivory':
        shade = shade * (0.70 + 0.30 * np.sqrt(ndv))[:, None]

    # filmic tone map
    shade = shade / (shade + 0.62) * 1.25
    out[idx[0], idx[1], :3] = shade
    out[idx[0], idx[1], 3] = 1
    img = out.reshape(size, ss, size, ss, 4).mean(axis=(1, 3))
    rgb = np.clip(img[..., :3], 0, 1) ** (1 / 1.0)
    a = img[..., 3:4]
    rgba = np.concatenate([np.where(a > 0, rgb / np.maximum(a, 1e-6), 0), a], axis=-1)
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), 'RGBA')


def write_catalog(catalog, size=384):
    import json
    for name in ['pawn', 'knight', 'bishop', 'rook', 'queen', 'king']:
        for color, mat in [('white', 'ivory'), ('black', 'ebony')]:
            set_name = f'piece-{color}-{name}'
            d = os.path.join(catalog, 'Pieces', f'{set_name}.imageset')
            os.makedirs(d, exist_ok=True)
            render(name, mat, size).save(os.path.join(d, f'{set_name}.png'), optimize=True)
            with open(os.path.join(d, 'Contents.json'), 'w') as fh:
                json.dump({"images": [{"filename": f"{set_name}.png", "idiom": "universal"}],
                           "info": {"author": "xcode", "version": 1}}, fh, indent=2)
            print(set_name, flush=True)
    with open(os.path.join(catalog, 'Pieces', 'Contents.json'), 'w') as fh:
        json.dump({"info": {"author": "xcode", "version": 1}}, fh, indent=2)


if __name__ == '__main__':
    if sys.argv[1] == '--catalog':
        write_catalog(sys.argv[2])
        sys.exit(0)
    out = sys.argv[1]
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 512
    which = sys.argv[3:] or ['pawn', 'knight', 'bishop', 'rook', 'queen', 'king']
    os.makedirs(out, exist_ok=True)
    for name in which:
        for color, mat in [('white', 'ivory'), ('black', 'ebony')]:
            im = render(name, mat, size)
            im.save(os.path.join(out, f'{color}_{name}.png'))
            print(color, name, flush=True)
