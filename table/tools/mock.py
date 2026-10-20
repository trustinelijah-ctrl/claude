#!/usr/bin/env python3
"""Art-direction mockups: renders a full portrait iPad screen for a visual direction.

  python3 tools/mock.py OUT_DIR
"""
import base64
import io
import os
import sys

import cairosvg
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import pieces as P  # noqa: E402

RNG = np.random.default_rng(3)
W, H = 1032, 1376          # iPad Pro 13" portrait, points
SCALE = 2
FONTS = os.environ.get("MOCK_FONTS", "")


def font(size, italic=False, weight=500):
    path = os.path.join(FONTS, "CormorantGaramond-Italic[wght].ttf" if italic else "CormorantGaramond[wght].ttf")
    f = ImageFont.truetype(path, int(size * SCALE))
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def sans(size, weight=500):
    names = {400: "Inter-Regular", 500: "Inter-Medium", 600: "Inter-SemiBold"}
    for d in ["/usr/share/fonts/truetype/inter", "/usr/share/fonts/opentype/inter", "/usr/share/fonts/truetype"]:
        for ext in (".ttf", ".otf"):
            p = os.path.join(d, names.get(weight, "Inter-Medium") + ext)
            if os.path.exists(p):
                return ImageFont.truetype(p, int(size * SCALE))
    return ImageFont.truetype("DejaVuSans.ttf", int(size * SCALE))


# ------------------------------------------------------------------ textures

def noise(h, w, gy, gx):
    g = RNG.standard_normal((gy + 3, gx + 3))
    z = ndimage.zoom(g, ((h * 1.6) / (gy + 3), (w * 1.6) / (gx + 3)), order=3)
    return z[:h, :w]


def norm(a):
    a = a - a.mean()
    return a / (np.abs(a).max() + 1e-9)


def colorize(f, dark, light, c=1.0):
    t = np.clip(0.5 + 0.5 * f * c, 0, 1)[..., None]
    return np.array(dark)[None, None] + (np.array(light) - np.array(dark))[None, None] * t


def shagreen(n, base, bead, rim):
    """Stingray leather: densely packed small raised beads."""
    img = np.zeros((n, n))
    yy, xx = np.mgrid[0:n, 0:n]
    step = n / 26
    for gy in range(-1, 28):
        for gx in range(-1, 28):
            cx = (gx + 0.5 * (gy % 2)) * step + RNG.normal(0, step * 0.12)
            cy = gy * step * 0.88 + RNG.normal(0, step * 0.12)
            r = step * RNG.uniform(0.34, 0.46)
            x0, x1 = int(max(0, cx - r - 2)), int(min(n, cx + r + 2))
            y0, y1 = int(max(0, cy - r - 2)), int(min(n, cy + r + 2))
            if x0 >= x1 or y0 >= y1:
                continue
            d = np.sqrt((xx[y0:y1, x0:x1] - cx) ** 2 + (yy[y0:y1, x0:x1] - cy) ** 2) / r
            dome = np.clip(1 - d ** 2, 0, None)
            img[y0:y1, x0:x1] = np.maximum(img[y0:y1, x0:x1], dome)
    light = ndimage.gaussian_filter(img, 0.8)
    # bead centres glow, gaps stay dark, a faint rim where beads meet
    out = np.array(base)[None, None] * (1 - light[..., None]) + np.array(bead)[None, None] * light[..., None]
    edge = np.clip(ndimage.sobel(light) ** 2 * 0.02, 0, 1)
    out = out * (1 - edge[..., None]) + np.array(rim)[None, None] * edge[..., None]
    shade = norm(noise(n, n, 3, 3))[..., None] * 10
    return out + shade


def bone(n):
    f = norm(noise(n, n, 60, 3)) * 0.35 + norm(noise(n, n, 4, 4)) * 0.5
    return colorize(f, (222, 212, 192), (241, 235, 222), 0.5)


def lacquer(n, dark, light):
    f = norm(noise(n, n, 2, 2)) * 0.6 + norm(RNG.standard_normal((n, n))) * 0.04
    return colorize(f, dark, light, 0.6)


def travertine(n):
    f = norm(noise(n, n, 40, 4)) * 0.4 + norm(noise(n, n, 5, 5)) * 0.5
    pits = np.clip(norm(noise(n, n, 120, 30)) - 0.75, 0, None) * 2.2
    return colorize(f - pits, (205, 190, 166), (233, 222, 203), 0.6)


def board_surface(sq, light_fn, dark_fn):
    n = sq * 8
    img = np.zeros((n, n, 3))
    for r in range(8):
        for f in range(8):
            tile = light_fn(sq) if (r + f) % 2 == 1 else dark_fn(sq)
            img[(7 - r) * sq:(8 - r) * sq, f * sq:(f + 1) * sq] = tile
    return np.clip(img, 0, 255).astype(np.uint8)


# ------------------------------------------------------------------ pieces

def piece_svg(name, color, mat, size, gold, gloss):
    art = getattr(P, name)()
    m = mat[color]
    gid = f"g{RNG.integers(1e9)}"
    offs = [0, 0.16, 0.32, 0.42, 0.6, 0.82, 1]
    stops = ''.join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in zip(offs, m['stops']))
    s = size / 100
    body_d = ' '.join(P.svg_path(b) for b in art['body'])
    out = [f'<g transform="scale({s})"><defs>'
           f'<linearGradient id="{gid}" x1="21" x2="79" y1="0" y2="0" gradientUnits="userSpaceOnUse">{stops}</linearGradient>'
           f'<linearGradient id="{gid}v" x1="0" y1="8" x2="0" y2="92" gradientUnits="userSpaceOnUse">'
           f'<stop offset="0" stop-color="#fff" stop-opacity="0.08"/><stop offset="0.5" stop-color="#fff" stop-opacity="0"/>'
           f'<stop offset="0.8" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.22"/></linearGradient>'
           f'<linearGradient id="{gid}s" x1="0" x2="1" y1="0" y2="0">'
           f'<stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset="0.5" stop-color="#fff" stop-opacity="{gloss}"/>'
           f'<stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
           f'<clipPath id="{gid}c"><path d="{body_d}"/></clipPath></defs>']
    for b in art['body']:
        out.append(f'<path d="{P.svg_path(b)}" fill="none" stroke="{m["outline"]}" stroke-width="2.6" stroke-linejoin="round"/>')
    for b in art['body']:
        out.append(f'<path d="{P.svg_path(b)}" fill="url(#{gid})"/>')
    out.append(f'<path d="{body_d}" fill="url(#{gid}v)"/>')
    # a narrow specular streak, as on lacquer or glazed porcelain
    out.append(f'<g clip-path="url(#{gid}c)"><rect x="34" y="0" width="7" height="100" fill="url(#{gid}s)"/></g>')
    # gilded finials and turned rings
    if name == 'queen':
        for b in art['body'][:5]:
            out.append(f'<path d="{P.svg_path(b)}" fill="{gold}"/>')
    if name == 'bishop':
        out.append(f'<path d="{P.svg_path(art["body"][0])}" fill="{gold}"/>')
    for d in art['detail']:
        out.append(f'<path d="{P.svg_path(d)}" fill="none" stroke="{gold}" stroke-width="1.5" stroke-linecap="round"/>')
    for c in art['cut']:
        out.append(f'<path d="{P.svg_path(c)}" fill="{m["cut"]}"/>')
    out.append('</g>')
    return ''.join(out)


SPRITES = os.environ.get("MOCK_SPRITES")
SPRITE_K = 1.16
SPRITE_BASE = 0.81      # base centre within the sprite (from top)
SQUARE_BASE = 0.71      # base centre within the square (from top, for White)


def sprite(name, color, size_px, rotate):
    im = Image.open(os.path.join(SPRITES, f"{color}_{name}.png")).convert("RGBA").resize((size_px, size_px), Image.LANCZOS)
    return im.rotate(180) if rotate else im


def render_piece(name, color, mat, size_px, gold, gloss, rotate):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size_px}" height="{size_px}">'
           + piece_svg(name, color, mat, size_px, gold, gloss) + '</svg>')
    im = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode()))).convert("RGBA")
    return im.rotate(180) if rotate else im


START = {}
for f, n in enumerate(['rook', 'knight', 'bishop', 'queen', 'king', 'bishop', 'knight', 'rook']):
    START[(f, 0)] = ('white', n)
    START[(f, 7)] = ('black', n)
    START[(f, 1)] = ('white', 'pawn')
    START[(f, 6)] = ('black', 'pawn')


def midgame():
    pos = dict(START)
    def mv(a, b):
        pos[b] = pos.pop(a)
    mv((4, 1), (4, 3)); mv((4, 6), (4, 4)); mv((6, 0), (5, 2)); mv((1, 7), (2, 5))
    mv((5, 0), (2, 3)); mv((6, 7), (5, 5)); mv((3, 1), (3, 2)); mv((5, 7), (2, 4))
    return pos


# ------------------------------------------------------------------ composition

def compose(d, out_path):
    S = SCALE
    canvas = Image.new("RGB", (W * S, H * S))
    # table surface: base gradient + warm pool of light from a lamp over the board
    yy, xx = np.mgrid[0:H * S, 0:W * S].astype(np.float32)
    cx, cy = W * S / 2, H * S / 2
    r = np.sqrt((xx - cx) ** 2 + ((yy - cy) * 0.82) ** 2) / (H * S * 0.62)
    t = np.clip(r, 0, 1)[..., None] ** 1.3
    bg = np.array(d['table_center'])[None, None] * (1 - t) + np.array(d['table_edge'])[None, None] * t
    grain = RNG.standard_normal((H * S, W * S, 1)) * d.get('table_grain', 2.0)
    canvas = Image.fromarray(np.clip(bg + grain, 0, 255).astype(np.uint8))

    board = d['board_px'] * S
    rim = int(board * d['rim'])
    inner = board - 2 * rim
    sq = inner // 8
    inner = sq * 8
    board = inner + 2 * rim
    bx = (W * S - board) // 2
    by = (H * S - board) // 2

    # soft shadow under the slab
    sh = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(sh).rounded_rectangle([bx + 10, by + 30, bx + board - 10, by + board + 44], radius=30, fill=d['shadow'])
    sh = sh.filter(ImageFilter.GaussianBlur(46))
    canvas.paste(Image.new("RGB", canvas.size, (0, 0, 0)), (0, 0), sh)

    # slab edge (thickness) then frame
    edge = d['edge_px'] * S
    dr = ImageDraw.Draw(canvas)
    dr.rounded_rectangle([bx, by + edge, bx + board, by + board + edge], radius=d['corner'] * S, fill=d['slab_edge'])
    dr.rounded_rectangle([bx, by - edge, bx + board, by + board - edge], radius=d['corner'] * S, fill=d['slab_edge'])
    frame = Image.fromarray(np.clip(d['frame_fn'](board), 0, 255).astype(np.uint8))
    mask = Image.new("L", (board, board), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, board - 1, board - 1], radius=d['corner'] * S, fill=255)
    canvas.paste(frame, (bx, by), mask)
    # bevel highlight
    dr.rounded_rectangle([bx + 1, by + 1, bx + board - 2, by + board - 2], radius=d['corner'] * S,
                         outline=d['bevel'], width=2)

    # playing surface
    surf = Image.fromarray(board_surface(sq, d['light_fn'], d['dark_fn']))
    canvas.paste(surf, (bx + rim, by + rim))
    # tooled lines
    g = d['gold_rgb']
    for inset, wdt in d['tooling']:
        o = int(inset * rim)
        dr.rectangle([bx + rim - o, by + rim - o, bx + rim + inner + o, by + rim + inner + o], outline=g, width=wdt)

    # light pool across the surface
    sy, sx = np.mgrid[0:inner, 0:inner].astype(np.float32)
    rr = np.sqrt((sx - inner / 2) ** 2 + (sy - inner / 2) ** 2) / (inner * 0.72)
    vign = np.clip(1 - d['vignette'] * rr ** 2, 0, 1)
    region = np.asarray(canvas.crop((bx + rim, by + rim, bx + rim + inner, by + rim + inner))).astype(np.float32)
    region = region * vign[..., None]
    canvas.paste(Image.fromarray(np.clip(region, 0, 255).astype(np.uint8)), (bx + rim, by + rim))

    # coordinates on the frame
    cf = font(rim / S * 0.42, weight=500)
    for i, ch in enumerate("abcdefgh"):
        x = bx + rim + i * sq + sq // 2
        dr.text((x, by + board - rim // 2), ch, fill=d['coord'], font=cf, anchor="mm")
        txt = Image.new("RGBA", (rim, rim), (0, 0, 0, 0))
        ImageDraw.Draw(txt).text((rim // 2, rim // 2), ch, fill=d['coord'], font=cf, anchor="mm")
        canvas.paste(txt.rotate(180), (x - rim // 2, by), txt.rotate(180))
    for i in range(8):
        y = by + rim + (7 - i) * sq + sq // 2
        dr.text((bx + rim // 2, y), str(i + 1), fill=d['coord'], font=cf, anchor="mm")
        txt = Image.new("RGBA", (rim, rim), (0, 0, 0, 0))
        ImageDraw.Draw(txt).text((rim // 2, rim // 2), str(i + 1), fill=d['coord'], font=cf, anchor="mm")
        canvas.paste(txt.rotate(180), (bx + board - rim, y - rim // 2), txt.rotate(180))

    # marks: last move, selection, hints
    pos = midgame()
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    def sqrect(f, r):
        x = bx + rim + f * sq
        y = by + rim + (7 - r) * sq
        return [x, y, x + sq, y + sq]
    for s in [(5, 7), (2, 4)]:
        od.rectangle(sqrect(*s), fill=d['last'])
    od.rectangle(sqrect(5, 2), fill=d['select'])
    for (f, r) in [(6, 4), (7, 3), (3, 3), (6, 0)]:
        x0, y0, _, _ = sqrect(f, r)
        c = (x0 + sq / 2, y0 + sq / 2)
        rad = sq * 0.11
        od.ellipse([c[0] - rad, c[1] - rad, c[0] + rad, c[1] + rad], fill=d['hint'])
    x0, y0, _, _ = sqrect(4, 4)
    od.ellipse([x0 + sq * 0.06, y0 + sq * 0.06, x0 + sq * 0.94, y0 + sq * 0.94], outline=d['hint'], width=int(sq * 0.05))
    canvas.paste(overlay, (0, 0), overlay)

    # pieces with shadows cast away from the lamp over the centre of the table
    shadow_layer = Image.new("L", canvas.size, 0)
    sd = ImageDraw.Draw(shadow_layer)
    bcx, bcy = bx + board / 2, by + board / 2
    sprites = []
    for (f, r), (color, name) in pos.items():
        x0, y0, _, _ = sqrect(f, r)
        cxp, cyp = x0 + sq / 2, y0 + sq / 2
        vx, vy = (cxp - bcx) / board, (cyp - bcy) / board
        base_y = y0 + sq * (SQUARE_BASE if color == 'white' else 1 - SQUARE_BASE)
        ox, oy = vx * sq * 0.9, vy * sq * 0.9
        rw, rh = sq * 0.36, sq * 0.21
        sd.ellipse([cxp - rw + ox, base_y - rh + oy, cxp + rw + ox, base_y + rh + oy], fill=d['piece_shadow'])
        lifted = (f, r) == (5, 2)
        sprites.append((x0, y0, color, name, lifted))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(sq * 0.07))
    canvas.paste(Image.new("RGB", canvas.size, (0, 0, 0)), (0, 0), shadow_layer)
    sprites.sort(key=lambda t: t[1])
    for x0, y0, color, name, lifted in sprites:
        size = int(sq * SPRITE_K)
        im = sprite(name, color, size, rotate=(color == 'black'))
        ox = int(x0 + (sq - size) / 2)
        if color == 'white':
            oy = int(y0 + sq * SQUARE_BASE - size * SPRITE_BASE)
        else:
            oy = int(y0 + sq * (1 - SQUARE_BASE) - size * (1 - SPRITE_BASE))
        canvas.paste(im, (ox, oy), im)

    # the players' sides of the table
    draw = ImageDraw.Draw(canvas)
    def side(img_draw, top):
        pass
    for who in ('white', 'black'):
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        y_band = by + board + edge + 34 * S
        active = who == 'white'
        if active and d.get('turn_glow'):
            glow = Image.new("L", canvas.size, 0)
            ImageDraw.Draw(glow).ellipse([W * S * 0.15, H * S - 120 * S, W * S * 0.85, H * S + 160 * S], fill=d['turn_glow'][3])
            glow = glow.filter(ImageFilter.GaussianBlur(80 * S))
            layer.paste(Image.new("RGBA", canvas.size, d['turn_glow'][:3] + (255,)), (0, 0), glow)
        ld.text((bx + 6 * S, y_band), "White" if who == 'white' else "Black", font=font(34, weight=500), fill=d['ink'], anchor="ls")
        status = "Your move" if active else "Waiting"
        ld.text((bx + 6 * S, y_band + 30 * S), status, font=font(21, italic=True, weight=500),
                fill=d['accent'] if active else d['ink2'], anchor="ls")
        # captured tray
        caps = ['knight', 'pawn', 'pawn'] if who == 'white' else ['bishop', 'pawn']
        csz = int(sq * 0.78)
        shadow = Image.new("L", canvas.size, 0)
        sdr = ImageDraw.Draw(shadow)
        for i, name in enumerate(caps):
            px0 = int(bx + 210 * S + i * csz * 0.62)
            base = int(y_band + 6 * S)
            sdr.ellipse([px0 + csz * 0.2, base - csz * 0.07 + csz * 0.06, px0 + csz * 0.8, base + csz * 0.09 + csz * 0.06], fill=120)
        shadow = shadow.filter(ImageFilter.GaussianBlur(6 * S))
        layer.paste(Image.new("RGBA", canvas.size, (0, 0, 0, 255)), (0, 0), shadow)
        for i, name in enumerate(caps):
            im = sprite(name, 'black' if who == 'white' else 'white', csz, False)
            px0 = int(bx + 210 * S + i * csz * 0.62)
            layer.paste(im, (px0, int(y_band + 6 * S - csz * SPRITE_BASE)), im)
        # two quiet controls
        for i, sym in enumerate(["↶", "···"]):
            c = (bx + board - 26 * S - i * 58 * S, y_band - 10 * S)
            ld.ellipse([c[0] - 22 * S, c[1] - 22 * S, c[0] + 22 * S, c[1] + 22 * S], outline=d['control'], width=2)
            ld.text(c, sym, font=sans(16), fill=d['ink'], anchor="mm")
        if who == 'black':
            layer = layer.rotate(180)
        canvas.paste(layer, (0, 0), layer)

    canvas = canvas.resize((W, H), Image.LANCZOS)
    canvas.save(out_path)


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


IVORY = dict(stops=['#C9BBA0', '#EAE0CB', '#FBF6EA', '#FFFDF6', '#EEE5D2', '#CDBD9E', '#AE9A78'],
             outline='#4A3B2A', cut='#5A4630')
OBSIDIAN = dict(stops=['#050505', '#1C1A19', '#3A3634', '#4A4542', '#272422', '#121110', '#040404'],
                outline='#000000', cut='#000000')

DIRECTIONS = {
    'salon': dict(
        table_center=(28, 38, 33), table_edge=(6, 10, 9), table_grain=2.2,
        board_px=960, rim=0.05, corner=10, edge_px=0, shadow=200,
        slab_edge=(10, 12, 11), bevel=(214, 182, 120),
        frame_fn=lambda n: lacquer(n, (12, 20, 17), (26, 38, 33)),
        light_fn=lambda n: bone(n), dark_fn=lambda n: shagreen(n, (18, 52, 44), (52, 112, 96), (10, 30, 26)),
        tooling=[(0.22, 3), (0.42, 1)], gold='#C9A35A', gold_rgb=(201, 163, 90),
        vignette=0.26, coord=(201, 163, 90, 200),
        last=(212, 175, 95, 60), select=(230, 196, 120, 90), hint=(14, 30, 26, 110),
        piece_shadow=140, materials={'white': IVORY, 'black': OBSIDIAN}, gloss={'white': 0.35, 'black': 0.30},
        ink=(236, 226, 205, 255), ink2=(236, 226, 205, 120), accent=(214, 182, 120, 255), control=(214, 182, 120, 90),
        turn_glow=(214, 170, 90, 70)),
    'oxblood': dict(
        table_center=(40, 30, 28), table_edge=(10, 7, 7), table_grain=2.0,
        board_px=960, rim=0.045, corner=6, edge_px=0, shadow=210,
        slab_edge=(6, 5, 5), bevel=(220, 190, 130),
        frame_fn=lambda n: lacquer(n, (8, 8, 8), (24, 22, 22)),
        light_fn=lambda n: lacquer(n, (228, 214, 190), (242, 233, 214)),
        dark_fn=lambda n: lacquer(n, (88, 22, 24), (120, 34, 34)),
        tooling=[(0.25, 2)], gold='#D2AE68', gold_rgb=(210, 174, 104),
        vignette=0.3, coord=(210, 174, 104, 210),
        last=(230, 190, 110, 60), select=(240, 205, 130, 95), hint=(30, 8, 8, 110),
        piece_shadow=150, materials={'white': IVORY, 'black': OBSIDIAN}, gloss={'white': 0.35, 'black': 0.35},
        ink=(240, 228, 206, 255), ink2=(240, 228, 206, 120), accent=(222, 186, 120, 255), control=(222, 186, 120, 90),
        turn_glow=(200, 120, 80, 60)),
    'travertine': dict(
        table_center=(214, 200, 178), table_edge=(176, 160, 136), table_grain=2.5,
        board_px=960, rim=0.045, corner=8, edge_px=0, shadow=120,
        slab_edge=(150, 134, 110), bevel=(255, 250, 240),
        frame_fn=lambda n: travertine(n) * 0.82,
        light_fn=lambda n: travertine(n), dark_fn=lambda n: lacquer(n, (96, 104, 92), (122, 130, 116)),
        tooling=[(0.25, 2)], gold='#A88B57', gold_rgb=(168, 139, 87),
        vignette=0.12, coord=(250, 244, 230, 220),
        last=(180, 140, 70, 60), select=(190, 150, 80, 90), hint=(40, 44, 38, 90),
        piece_shadow=110, materials={'white': IVORY, 'black': OBSIDIAN}, gloss={'white': 0.35, 'black': 0.3},
        ink=(48, 44, 38, 255), ink2=(48, 44, 38, 120), accent=(150, 112, 60, 255), control=(48, 44, 38, 60),
        turn_glow=None),
}

if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    which = sys.argv[2:] or list(DIRECTIONS)
    for name in which:
        compose(DIRECTIONS[name], os.path.join(out, f"mock-{name}.png"))
        print(name)
