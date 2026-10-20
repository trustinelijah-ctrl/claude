#!/usr/bin/env python3
"""TABLE piece set: original lathe-turned silhouettes authored as vector paths.

One source of truth for the artwork:
  python3 tools/pieces.py swift  > App/Pieces/PieceArtwork.swift
  python3 tools/pieces.py svg OUT_DIR   (preview sheets)

Coordinates live in a 100 x 100 box, y pointing down, pieces standing on y = 92.
Symmetric pieces are drawn as a right-hand profile (dx from the centre line) and
mirrored, like turning a piece on a lathe. The knight is drawn freehand.
"""
import math
import sys

CX = 50.0
FLOOR = 92.0
K = 0.5523  # cubic circle constant


# ---------------------------------------------------------------- path helpers

def circle(cx, cy, r):
    k = K * r
    return [('M', cx, cy - r),
            ('C', cx + k, cy - r, cx + r, cy - k, cx + r, cy),
            ('C', cx + r, cy + k, cx + k, cy + r, cx, cy + r),
            ('C', cx - k, cy + r, cx - r, cy + k, cx - r, cy),
            ('C', cx - r, cy - k, cx - k, cy - r, cx, cy - r),
            ('Z',)]


def ellipse(cx, cy, rx, ry):
    kx, ky = K * rx, K * ry
    return [('M', cx, cy - ry),
            ('C', cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy),
            ('C', cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry),
            ('C', cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy),
            ('C', cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry),
            ('Z',)]


def lathe(top, profile):
    """top: y of the crown on the centre line. profile: segments in (dx, y)
    from the top point down the right side, ending on the floor."""
    pts = [(0.0, top)]
    for seg in profile:
        pts.append(seg[-2:])
    cmds = [('M', CX, top)]
    for seg in profile:
        if seg[0] == 'L':
            cmds.append(('L', CX + seg[1], seg[2]))
        else:
            _, a, b, c, d, x, y = seg
            cmds.append(('C', CX + a, b, CX + c, d, CX + x, y))
    # mirror back up the left side
    for i in range(len(profile) - 1, -1, -1):
        seg = profile[i]
        px, py = pts[i]
        if seg[0] == 'L':
            cmds.append(('L', CX - px, py))
        else:
            _, a, b, c, d, x, y = seg
            cmds.append(('C', CX - c, d, CX - a, b, CX - px, py))
    cmds.append(('Z',))
    return cmds


def base(hw, ty, sw):
    """Shared turned base. sw: stem half-width where it meets the base at y = ty.
    Returns profile segments from (sw, ty) to the floor centre."""
    return [
        ('C', sw + 0.10 * hw, ty + 0.2, 0.80 * hw, ty + 0.8, 0.84 * hw, ty + 2.6),   # upper ring
        ('C', 0.86 * hw, ty + 3.8, 0.79 * hw, ty + 4.6, 0.80 * hw, ty + 5.6),        # tuck
        ('C', 0.82 * hw, ty + 7.6, 0.98 * hw, ty + 8.6, 1.00 * hw, ty + 11.0),       # flare
        ('L', 1.00 * hw, FLOOR - 1.8),
        ('C', 1.00 * hw, FLOOR - 0.5, 0.99 * hw, FLOOR, 0.96 * hw, FLOOR),
        ('L', 0.0, FLOOR),
    ]


def base_details(hw, ty):
    """Fine turned grooves on the base, drawn as open strokes."""
    y1 = ty + 5.4
    y2 = FLOOR - 4.6
    return [
        [('M', CX - 0.79 * hw, y1), ('C', CX - 0.4 * hw, y1 + 1.4, CX + 0.4 * hw, y1 + 1.4, CX + 0.79 * hw, y1)],
        [('M', CX - 0.985 * hw, y2), ('C', CX - 0.5 * hw, y2 + 1.6, CX + 0.5 * hw, y2 + 1.6, CX + 0.985 * hw, y2)],
    ]


def band(dx, y, sag=1.2):
    """A horizontal turned ring line across the body."""
    return [('M', CX - dx, y), ('C', CX - dx * 0.5, y + sag, CX + dx * 0.5, y + sag, CX + dx, y)]


# ---------------------------------------------------------------- the pieces

def pawn():
    hw, ty = 24.5, 75.0
    head_r = 9.6
    hc = 39.5
    top = hc - head_r
    k = K * head_r
    profile = [
        ('C', k, top, head_r, hc - k, head_r, hc),
        ('C', head_r, hc + 4.6, 7.8, hc + 7.9, 5.4, hc + 9.3),
        # collar disc
        ('C', 8.0, hc + 9.6, 12.2, hc + 9.9, 12.6, hc + 11.4),
        ('C', 13.0, hc + 12.9, 11.0, hc + 13.7, 7.4, hc + 14.1),
        # flared stem
        ('C', 7.6, hc + 22.0, 11.0, ty - 4.0, 0.62 * hw, ty),
    ] + base(hw, ty, 0.62 * hw)
    body = lathe(top, profile)
    details = [band(11.6, hc + 12.0, 0.9)] + base_details(hw, ty)
    return {'body': [body], 'detail': details, 'cut': []}


def rook():
    hw, ty = 26.5, 75.0
    top = 25.5
    profile = [
        ('L', 3.0, top),
        ('L', 3.0, top + 5.0),
        ('C', 3.0, top + 5.6, 3.4, top + 6.0, 4.0, top + 6.0),
        ('L', 7.4, top + 6.0),
        ('C', 8.0, top + 6.0, 8.4, top + 5.6, 8.4, top + 5.0),
        ('L', 8.4, top),
        ('L', 15.2, top),
        ('C', 16.0, top, 16.4, top + 0.4, 16.4, top + 1.2),
        ('L', 16.4, top + 11.0),
        # molding under the battlement
        ('C', 16.4, top + 12.6, 12.4, top + 12.6, 12.0, top + 14.0),
        ('C', 11.7, top + 15.0, 13.0, top + 15.6, 13.0, top + 16.6),
        ('C', 13.0, top + 17.6, 11.4, top + 17.8, 11.4, top + 19.0),
        # tower body, gently waisted
        ('C', 11.0, top + 30.0, 13.5, ty - 6.0, 0.70 * hw, ty),
    ] + base(hw, ty, 0.70 * hw)
    body = lathe(top, profile)
    details = [
        band(16.2, top + 11.0, 0.9),
        band(12.6, top + 16.3, 0.7),
    ] + base_details(hw, ty)
    return {'body': [body], 'detail': details, 'cut': []}


def bishop():
    hw, ty = 25.5, 75.0
    bead_r = 3.4
    bead_c = 18.5
    mitre_top = bead_c + bead_r - 0.6
    profile = [
        # mitre: an elongated drop
        ('C', 3.4, mitre_top, 11.4, 29.0, 12.4, 38.0),
        ('C', 13.0, 43.5, 10.6, 47.2, 7.0, 48.6),
        # double collar
        ('C', 9.8, 48.8, 13.4, 49.4, 13.6, 50.9),
        ('C', 13.8, 52.3, 10.6, 52.7, 9.8, 53.2),
        ('C', 11.2, 53.6, 11.6, 54.6, 11.0, 55.6),
        ('C', 10.4, 56.4, 8.4, 56.6, 7.6, 56.8),
        # stem
        ('C', 7.8, 64.0, 11.0, ty - 4.0, 0.62 * hw, ty),
    ] + base(hw, ty, 0.62 * hw)
    body = lathe(mitre_top, profile)
    bead = circle(CX, bead_c, bead_r)
    # the mitre's slanted cut
    cut = [('M', CX + 6.6, 30.2),
           ('C', CX + 7.6, 31.0, CX + 7.8, 31.9, CX + 7.0, 32.7),
           ('L', CX - 1.8, 41.6),
           ('C', CX - 2.6, 42.4, CX - 3.6, 42.2, CX - 3.9, 41.2),
           ('C', CX - 4.1, 40.4, CX - 3.7, 39.8, CX - 3.1, 39.4),
           ('Z',)]
    details = [band(13.4, 51.0, 0.8), band(10.9, 55.4, 0.6)] + base_details(hw, ty)
    return {'body': [bead, body], 'detail': details, 'cut': [cut]}


def queen():
    hw, ty = 27.5, 75.0
    top = 22.6
    profile = [
        # coronet: alternating valleys and points (balls sit on the points)
        ('C', 1.6, top + 2.4, 3.2, top + 4.4, 4.6, top + 5.0),
        ('C', 6.2, top + 3.4, 7.8, top + 1.4, 9.6, top + 0.6),
        ('C', 10.6, top + 3.0, 11.8, top + 5.0, 13.0, top + 5.6),
        ('C', 14.4, top + 4.6, 15.6, top + 3.6, 16.8, top + 3.2),
        # crown bowl narrowing to the waist
        ('C', 16.2, top + 9.0, 12.0, top + 14.0, 8.6, top + 17.4),
        # collar
        ('C', 11.0, top + 17.8, 14.2, top + 18.4, 14.4, top + 20.0),
        ('C', 14.6, top + 21.6, 11.6, top + 22.0, 10.6, top + 22.4),
        ('C', 12.0, top + 22.9, 12.2, top + 24.0, 11.6, top + 24.8),
        ('C', 10.8, top + 25.6, 8.8, top + 25.8, 8.0, top + 26.0),
        # stem
        ('C', 8.4, top + 37.0, 12.4, ty - 4.5, 0.66 * hw, ty),
    ] + base(hw, ty, 0.66 * hw)
    body = lathe(top + 2.0, [('C', 0.6, top + 2.0, 1.0, top + 2.2, 1.6, top + 2.4)] + profile[1:])
    balls = [circle(CX, top - 1.0, 3.3),
             circle(CX + 9.8, top - 1.6, 2.7), circle(CX - 9.8, top - 1.6, 2.7),
             circle(CX + 17.2, top + 1.2, 2.4), circle(CX - 17.2, top + 1.2, 2.4)]
    details = [
        [('M', CX - 15.2, top + 8.4), ('C', CX - 7.0, top + 10.2, CX + 7.0, top + 10.2, CX + 15.2, top + 8.4)],
        band(14.2, top + 20.1, 0.8),
        band(11.5, top + 24.6, 0.6),
    ] + base_details(hw, ty)
    return {'body': balls + [body], 'detail': details, 'cut': []}


def king():
    hw, ty = 28.5, 75.0
    top = 8.0
    bar = 2.3     # half width of the cross's upright
    arm = 6.8     # half span of the arms
    profile = [
        ('L', bar, top),
        ('L', bar, top + 4.2),
        ('L', arm, top + 4.2),
        ('L', arm, top + 8.6),
        ('L', bar, top + 8.6),
        ('L', bar, top + 13.4),
        # small disc under the cross
        ('C', 4.2, top + 13.4, 5.8, top + 14.0, 5.8, top + 15.0),
        ('C', 5.8, top + 16.0, 4.4, top + 16.4, 4.0, top + 16.8),
        # crown cup
        ('C', 9.0, top + 17.0, 15.0, top + 18.4, 15.2, top + 20.4),
        ('C', 15.4, top + 22.4, 14.4, top + 23.2, 13.6, top + 24.0),
        ('C', 12.6, top + 28.0, 10.6, top + 31.4, 8.8, top + 34.4),
        # collar
        ('C', 11.4, top + 34.8, 14.8, top + 35.4, 15.0, top + 37.0),
        ('C', 15.2, top + 38.6, 12.2, top + 39.0, 11.2, top + 39.4),
        ('C', 12.6, top + 39.9, 12.8, top + 41.0, 12.2, top + 41.8),
        ('C', 11.4, top + 42.6, 9.4, top + 42.8, 8.6, top + 43.0),
        # stem
        ('C', 9.0, top + 53.0, 13.0, ty - 4.5, 0.66 * hw, ty),
    ] + base(hw, ty, 0.66 * hw)
    body = lathe(top, profile)
    details = [
        band(14.9, top + 21.6, 1.0),
        band(14.8, top + 37.1, 0.8),
        band(12.1, top + 41.6, 0.6),
    ] + base_details(hw, ty)
    return {'body': [body], 'detail': details, 'cut': []}


def knight():
    hw, ty = 26.0, 75.0
    # shared base, drawn on its own and overlapped by the horse
    base_profile = [('L', 0.76 * hw, ty - 0.6), ('L', 0.76 * hw, ty)] + base(hw, ty, 0.76 * hw)
    base_body = lathe(ty - 0.6, base_profile)
    horse = [
        ('M', 33.0, 75.6),                                   # chest, at the base
        ('C', 31.6, 70.0, 30.6, 64.6, 32.4, 59.6),           # breast
        ('C', 34.0, 55.6, 37.6, 53.6, 39.6, 50.4),           # throat
        ('C', 40.6, 48.8, 39.4, 47.4, 37.2, 47.6),           # under the jaw
        ('C', 33.0, 48.0, 28.4, 48.6, 24.6, 48.0),           # jaw line to mouth
        ('C', 21.6, 47.6, 19.0, 46.0, 18.4, 43.4),           # lower lip
        ('C', 17.8, 41.0, 18.2, 38.8, 19.2, 37.2),           # muzzle front
        ('C', 21.6, 33.2, 26.4, 28.0, 30.4, 24.2),           # bridge of the nose
        ('C', 32.0, 22.6, 33.6, 21.2, 35.2, 19.8),           # forehead
        ('C', 36.0, 16.6, 37.4, 13.2, 39.6, 10.6),           # front of the ear
        ('C', 40.6, 9.6, 41.6, 10.0, 42.0, 11.4),            # ear tip
        ('C', 42.6, 13.6, 43.0, 16.0, 43.4, 18.0),           # back of the ear
        ('C', 50.0, 18.4, 57.4, 21.6, 62.4, 27.8),           # poll and crest
        ('C', 67.6, 34.4, 70.4, 43.0, 70.8, 52.4),           # mane
        ('C', 71.2, 61.0, 70.2, 68.6, 68.6, 75.6),           # back of the neck
        ('Z',),
    ]
    eye = [('M', 31.2, 30.6),
           ('C', 32.6, 28.8, 35.4, 28.4, 37.0, 29.6),
           ('C', 35.6, 31.6, 33.0, 32.0, 31.2, 30.6),
           ('Z',)]
    nostril = [('M', 21.2, 40.2),
               ('C', 22.4, 39.0, 24.2, 39.2, 24.6, 40.6),
               ('C', 23.4, 41.2, 22.0, 41.2, 21.2, 40.2),
               ('Z',)]
    details = [
        # mane edge, following the crest
        [('M', 45.0, 21.0), ('C', 53.0, 23.4, 60.6, 30.4, 63.6, 40.6),
         ('C', 65.4, 47.0, 65.8, 54.0, 65.4, 60.0)],
        # mane strands
        [('M', 52.2, 24.6), ('C', 53.4, 27.0, 54.6, 28.4, 56.6, 29.4)],
        [('M', 58.0, 31.0), ('C', 58.8, 33.6, 59.8, 35.0, 61.6, 36.2)],
        [('M', 61.6, 39.6), ('C', 62.2, 42.2, 63.0, 43.6, 64.6, 44.8)],
        [('M', 63.4, 48.6), ('C', 63.8, 51.0, 64.4, 52.4, 65.6, 53.6)],
        # cheek
        [('M', 37.6, 37.4), ('C', 41.0, 39.2, 42.6, 42.6, 41.4, 46.6)],
        # mouth
        [('M', 18.8, 44.6), ('C', 20.8, 44.4, 22.6, 44.8, 24.0, 45.8)],
        # collar where the horse meets the base
        band(0.74 * hw, ty + 0.4, 1.0),
    ] + base_details(hw, ty)
    return {'body': [base_body, horse], 'detail': details, 'cut': [eye, nostril]}


PIECES = {
    'pawn': pawn, 'knight': knight, 'bishop': bishop,
    'rook': rook, 'queen': queen, 'king': king,
}


# ---------------------------------------------------------------- output

def fmt(v):
    s = f"{v:.2f}".rstrip('0').rstrip('.')
    return s if s not in ('-0', '') else '0'


def svg_path(cmds):
    out = []
    for c in cmds:
        if c[0] == 'Z':
            out.append('Z')
        else:
            out.append(c[0] + ' ' + ' '.join(fmt(v) for v in c[1:]))
    return ' '.join(out)


MATERIALS = {
    'white': dict(stops=['#BFA885', '#E8DBC1', '#FBF4E6', '#FFFCF4', '#EADFC8', '#C7B28E', '#A88F6A'],
                  outline='#4B3826', detail='#6E5638', cut='#5A4430'),
    'black': dict(stops=['#0B0807', '#2A211C', '#4E4038', '#5D4E44', '#3A2F28', '#1A1411', '#0A0706'],
                  outline='#050403', detail='#7A6656', cut='#050403'),
}


def svg_piece(name, color, x=0, y=0, size=100):
    art = PIECES[name]()
    m = MATERIALS[color]
    gid = f"g_{name}_{color}_{x}_{y}"
    offsets = [0, 0.16, 0.32, 0.42, 0.6, 0.82, 1]
    stops = ''.join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in zip(offsets, m['stops']))
    s = size / 100.0
    parts = [f'<g transform="translate({x},{y}) scale({s})">',
             f'<defs><linearGradient id="{gid}" x1="20" y1="0" x2="80" y2="0" gradientUnits="userSpaceOnUse">{stops}</linearGradient>',
             f'<linearGradient id="{gid}v" x1="0" y1="10" x2="0" y2="92" gradientUnits="userSpaceOnUse">'
             f'<stop offset="0" stop-color="#fff" stop-opacity="0.10"/><stop offset="0.55" stop-color="#fff" stop-opacity="0"/>'
             f'<stop offset="0.8" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.16"/></linearGradient></defs>',
             f'<ellipse cx="50" cy="91.5" rx="27" ry="4.2" fill="#000" opacity="0.28"/>']
    for b in art['body']:
        parts.append(f'<path d="{svg_path(b)}" fill="none" stroke="{m["outline"]}" stroke-width="2.6" stroke-linejoin="round"/>')
    for b in art['body']:
        parts.append(f'<path d="{svg_path(b)}" fill="url(#{gid})"/>')
        parts.append(f'<path d="{svg_path(b)}" fill="url(#{gid}v)"/>')
    for d in art['detail']:
        parts.append(f'<path d="{svg_path(d)}" fill="none" stroke="{m["detail"]}" stroke-width="1.0" stroke-linecap="round" opacity="0.7"/>')
    for c in art['cut']:
        parts.append(f'<path d="{svg_path(c)}" fill="{m["cut"]}"/>')
    parts.append('</g>')
    return '\n'.join(parts)


def svg_sheet(size=120, light='#E6D2B0', dark='#6B4429'):
    names = ['king', 'queen', 'rook', 'bishop', 'knight', 'pawn']
    w = size * len(names)
    h = size * 2
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">']
    for row, color in enumerate(['white', 'black']):
        for col, name in enumerate(names):
            sq = light if (row + col) % 2 == 0 else dark
            out.append(f'<rect x="{col * size}" y="{row * size}" width="{size}" height="{size}" fill="{sq}"/>')
            out.append(svg_piece(name, color, col * size, row * size, size))
    out.append('</svg>')
    return '\n'.join(out)


def swift_cmd(c):
    if c[0] == 'M':
        return f".m({fmt(c[1])}, {fmt(c[2])})"
    if c[0] == 'L':
        return f".l({fmt(c[1])}, {fmt(c[2])})"
    if c[0] == 'C':
        return ".c(" + ", ".join(fmt(v) for v in c[1:]) + ")"
    return ".z"


def swift_paths(paths, indent):
    lines = []
    for p in paths:
        cmds = [swift_cmd(c) for c in p]
        chunks = [', '.join(cmds[i:i + 3]) for i in range(0, len(cmds), 3)]
        body = (',\n' + indent + '    ').join(chunks)
        lines.append(f"{indent}[{body}]")
    return '[\n' + ',\n'.join(lines) + '\n' + indent[:-4] + ']' if lines else '[]'


def emit_swift():
    out = ['// Generated by tools/pieces.py. Do not edit by hand: change the script and regenerate.',
           '// Original TABLE piece artwork in a 100 x 100 unit box, standing on y = 92.',
           '',
           'import ChessCore',
           '',
           'enum PieceArtwork {',
           '    static func art(for kind: PieceKind) -> PieceArt {',
           '        switch kind {']
    for name in PIECES:
        out.append(f'        case .{name}: return {name}')
    out += ['        }', '    }', '']
    for name, fn in PIECES.items():
        art = fn()
        ind = '            '
        out.append(f'    static let {name} = PieceArt(')
        out.append(f'        body: {swift_paths(art["body"], ind)},')
        out.append(f'        detail: {swift_paths(art["detail"], ind)},')
        out.append(f'        cut: {swift_paths(art["cut"], ind)}')
        out.append('    )')
        out.append('')
    out.append('}')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'swift'
    if mode == 'swift':
        sys.stdout.write(emit_swift())
    elif mode == 'svg':
        import os
        out_dir = sys.argv[2]
        os.makedirs(out_dir, exist_ok=True)
        with open(os.path.join(out_dir, 'walnut.svg'), 'w') as f:
            f.write(svg_sheet())
        with open(os.path.join(out_dir, 'slate.svg'), 'w') as f:
            f.write(svg_sheet(light='#EEE8DD', dark='#4A4E54'))
        with open(os.path.join(out_dir, 'small.svg'), 'w') as f:
            f.write(svg_sheet(size=56))
