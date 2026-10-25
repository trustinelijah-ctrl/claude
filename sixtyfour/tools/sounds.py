#!/usr/bin/env python3
"""TABLE sound palette, built from real recordings.

Every sound is made from recorded material in tools/sources/kenney (Kenney's Impact,
Casino and UI audio packs, released CC0). A real chess move is two things at once: the
crisp click of the felted base meeting the board, and the short woody knock of the board
itself. No single recording has both, so each move sound is layered the way foley is:
the body of a light wood impact, pitched up to the size of a chess piece, with the
contact click taken from a chip set down on a table.

  python3 tools/sounds.py App/Resources/Sounds

Replace any output with a recording of the same name to change it; the app loads
whatever is in the folder.
"""
import os
import subprocess
import sys
import wave

import numpy as np
from scipy import signal

SR = 48000
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sources', 'kenney')
RNG = np.random.default_rng(64)


def load(name):
    raw = subprocess.run(['ffmpeg', '-v', 'quiet', '-i', os.path.join(SRC, name), '-ac', '1', '-ar', str(SR),
                          '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(np.float64)
    return x / (np.max(np.abs(x)) + 1e-12)


def onset(x, frac=0.08):
    return int(np.argmax(np.abs(x) > np.max(np.abs(x)) * frac))


def from_onset(x, pre_ms=1.5):
    o = max(0, onset(x) - int(pre_ms * SR / 1000))
    return x[o:]


def hp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, 'highpass', fs=SR, output='sos'), x)


def lp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, 'lowpass', fs=SR, output='sos'), x)


def pitch(x, ratio):
    """Resample so the sound plays `ratio` times higher (and shorter), like a smaller object."""
    n = int(len(x) / ratio)
    return np.interp(np.arange(n) * ratio, np.arange(len(x)), x)


def crop(x, ms, fade_ms=None):
    n = min(len(x), int(ms * SR / 1000))
    y = x[:n].copy()
    f = int((fade_ms if fade_ms is not None else ms * 0.45) * SR / 1000)
    f = min(f, n)
    y[n - f:] *= np.cos(np.linspace(0, np.pi / 2, f)) ** 2
    y[:24] *= np.linspace(0, 1, 24)
    return y


def db(v):
    return 10 ** (v / 20)


def mix(*layers):
    n = max(int(o * SR / 1000) + len(x) for x, o in layers)
    out = np.zeros(n)
    for x, o in layers:
        s = int(o * SR / 1000)
        out[s:s + len(x)] += x
    return out


def room(x, level=db(-24)):
    """A small table-top space: two faint, dark reflections. No audible reverb."""
    out = x.copy()
    for ms, g in [(6.1, 1.0), (11.7, 0.55)]:
        d = int(ms * SR / 1000)
        r = np.zeros_like(x)
        r[d:] = x[:-d]
        out += lp(r, 2800) * g * level
    return out


def finish(x, peak_db):
    x = hp(x, 70, 1)
    return x / (np.max(np.abs(x)) + 1e-12) * db(peak_db)


# ---------------------------------------------------------------- recorded layers

WOOD_LIGHT = [from_onset(load(f'impactWood_light_00{i}.ogg')) for i in range(5)]
WOOD_MEDIUM = [from_onset(load(f'impactWood_medium_00{i}.ogg')) for i in range(5)]
CHIP_LAY = [from_onset(load(f'chip-lay-{i}.ogg')) for i in (1, 2)]
CHIP_CLACK = [from_onset(load(f'chips-collide-{i}.ogg')) for i in range(1, 5)]


def body(src, ratio, ms):
    """The board's knock: low thump removed, pitched to the size of a chess piece.
    Kept short and high-passed well above the boom, so placements stay crisp."""
    return crop(hp(pitch(src, ratio), 260), ms, fade_ms=min(ms // 2, 60))


def contact(src, ms=20, gain=-9.0, bright=11000):
    """The click of the base meeting the surface."""
    return crop(lp(src, bright), ms, fade_ms=12) * db(gain)


TOCK = from_onset(load('chip-lay-3.ogg'))


def tock(_src=None, ratio=1.0, ms=90, gain=-3.0):
    """The piece's own short ring: the mid-range 'tock' that carries on small speakers.
    Taken from a chip laid hard on a table, which rings at the right pitch for a piece."""
    return crop(hp(pitch(TOCK, ratio), 420), ms, fade_ms=40) * db(gain)


def place(i):
    b = body(WOOD_LIGHT[i % 5], 1.22 + RNG.uniform(-0.04, 0.04), 110) * db(-2)
    t = tock(ratio=1.04 + RNG.uniform(-0.06, 0.08), ms=70)
    c = contact(CHIP_LAY[i % 2], gain=-4.0 + RNG.uniform(-1, 1))
    return finish(room(mix((c, 0.0), (t, 0.4), (b, 0.8)), level=db(-30)), -9.0)


def place_light(i):
    """A pawn: smaller and lighter than the other pieces, so a little higher and quicker."""
    b = body(WOOD_LIGHT[(i + 2) % 5], 1.42 + RNG.uniform(-0.04, 0.04), 85) * db(-4)
    t = tock(ratio=1.2 + RNG.uniform(-0.05, 0.06), ms=55, gain=-4)
    c = contact(CHIP_LAY[i % 2], ms=16, gain=-3.0 + RNG.uniform(-1, 1), bright=12500)
    return finish(room(mix((c, 0.0), (t, 0.3), (b, 0.6)), level=db(-32)), -10.5)


def place_heavy(i):
    """Rook, queen and king: more wood under them, a deeper knock and a longer ring."""
    b = body(WOOD_MEDIUM[i % 5], 1.06 + RNG.uniform(-0.03, 0.03), 150)
    t = tock(ratio=0.9 + RNG.uniform(-0.04, 0.04), ms=95, gain=-2.5)
    c = contact(CHIP_LAY[(i + 1) % 2], gain=-5.0 + RNG.uniform(-1, 1), bright=10000)
    return finish(room(mix((c, 0.0), (t, 0.5), (b, 1.0)), level=db(-28)), -8.0)


def notch():
    """A carried piece passing over a square: the faintest detent, felt as much as heard."""
    tick = crop(lp(hp(from_onset(load('switch2.ogg')), 1200), 6000), 14, fade_ms=9)
    return finish(tick, -30.0)


def clock_press():
    """A mechanical chess clock: the plunger snapping down, then the case answering."""
    snap = crop(hp(from_onset(load('switch3.ogg')), 400), 35, fade_ms=18) * db(-2)
    click = crop(lp(from_onset(load('click3.ogg')), 9000), 25, fade_ms=12) * db(-8)
    case = body(WOOD_LIGHT[3], 1.6, 70) * db(-9)
    return finish(room(mix((snap, 0.0), (click, 2.0), (case, 1.5)), level=db(-30)), -14.0)


def clock_tick():
    """The last seconds: a small, dry tick, the escapement of the clock."""
    tick = crop(hp(lp(from_onset(load('click3.ogg')), 7000), 900), 18, fade_ms=10)
    return finish(tick, -24.0)


def topple():
    """A king tipping over: the hard knock of the crown on wood, two small bounces and a
    short roll on its side. The animation is timed to this: knock 0 ms, bounces 105 and 175 ms."""
    knock = mix((contact(CHIP_LAY[0], gain=-4, bright=12000), 0.0), (tock(ratio=0.86, ms=110, gain=-1.5), 0.4),
                (body(WOOD_MEDIUM[2], 0.98, 200), 0.8))
    b1 = mix((contact(CHIP_LAY[1], ms=14, gain=-6), 0.0), (tock(ratio=1.05, ms=60, gain=-6), 0.3),
             (body(WOOD_LIGHT[1], 1.3, 80) * db(-8), 0.5))
    b2 = mix((contact(CHIP_LAY[0], ms=12, gain=-12), 0.0), (tock(ratio=1.15, ms=45, gain=-12), 0.3))
    roll_src = from_onset(load('chips-handle-4.ogg'))
    roll = crop(lp(hp(roll_src, 300), 3500), 220, fade_ms=160) * db(-20)
    return finish(room(mix((knock, 0.0), (b1, 105.0), (b2, 175.0), (roll, 190.0)), level=db(-26)), -8.0)


def capture(i):
    clack = crop(lp(CHIP_CLACK[i % 4], 12000), 36, fade_ms=20) * db(-3.0)
    b = body(WOOD_MEDIUM[(i + 1) % 5], 1.12 + RNG.uniform(-0.03, 0.03), 150)
    t = tock(ratio=0.94, ms=85, gain=-2.0)
    nudge = contact(CHIP_LAY[(i + 1) % 2], ms=16, gain=-14)
    return finish(room(mix((nudge, 0.0), (clack, 9.0), (t, 9.5), (b, 10.0)), level=db(-30)), -7.0)


def pickup(i):
    src = from_onset(load(['chips-handle-2.ogg', 'chips-handle-3.ogg', 'chips-handle-5.ogg'][i % 3]))
    return finish(crop(lp(src, 7000), 45, fade_ms=25), -22.0)


def invalid():
    src = from_onset(load('impactGeneric_light_001.ogg'))
    return finish(crop(lp(hp(src, 160), 1300), 110), -19.0)


def ui_click():
    src = from_onset(load('switch2.ogg'))
    return finish(crop(src, 40, fade_ms=20), -25.0)


def check():
    # a light, slightly higher tock-tock: noticeable, never an alarm
    a = mix((contact(CHIP_LAY[0], gain=-8), 0.0), (tock(ratio=1.18, gain=-2), 0.3), (body(WOOD_LIGHT[2], 1.45, 120), 0.6))
    b = mix((contact(CHIP_LAY[1], gain=-11), 0.0), (tock(ratio=1.3, gain=-5), 0.3), (body(WOOD_LIGHT[4], 1.6, 100) * db(-4), 0.6))
    return finish(room(mix((a, 0.0), (b, 92.0))), -13.0)


def promotion():
    stack = crop(lp(from_onset(load('chips-stack-1.ogg')), 9000), 120, fade_ms=60)
    return finish(room(mix((stack, 0.0))), -15.0)


def bell(ratio, ms):
    src = from_onset(load('impactBell_heavy_000.ogg'))
    return crop(lp(pitch(src, ratio), 6000), ms, fade_ms=ms * 0.7)


def checkmate():
    knock = body(WOOD_MEDIUM[0], 1.0, 260)
    return finish(room(mix((knock, 0.0), (bell(1.0, 1100) * db(-9), 120.0))), -11.0)


def draw_end():
    return finish(room(bell(0.84, 1000)), -15.0)


def reset():
    gather = crop(lp(from_onset(load('chips-handle-1.ogg')), 8000), 520, fade_ms=200)
    settle = mix((contact(CHIP_LAY[0], gain=-6), 0.0), (body(WOOD_LIGHT[1], 1.2, 160), 0.8))
    return finish(room(mix((gather * db(-3), 0.0), (settle, 470.0))), -13.0)


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith('.wav'):
            os.remove(os.path.join(out, f))
    files = {}
    for i in range(5):
        files[f'place_{i + 1}'] = place(i)
    for i in range(4):
        files[f'capture_{i + 1}'] = capture(i)
    for i in range(4):
        files[f'placeLight_{i + 1}'] = place_light(i)
        files[f'placeHeavy_{i + 1}'] = place_heavy(i)
    files['clockPress_1'] = clock_press()
    files['clockTick_1'] = clock_tick()
    files['notch_1'] = notch()
    files['topple_1'] = topple()
    for i in range(3):
        files[f'pickup_{i + 1}'] = pickup(i)
    files['invalid_1'] = invalid()
    files['ui_1'] = ui_click()
    files['check_1'] = check()
    files['promotion_1'] = promotion()
    files['checkmate_1'] = checkmate()
    files['draw_1'] = draw_end()
    files['reset_1'] = reset()
    for name, x in files.items():
        write_wav(os.path.join(out, name + '.wav'), x)
        X = np.abs(np.fft.rfft(x))
        f = np.fft.rfftfreq(len(x), 1 / SR)
        e = np.array([(X[(f >= a) & (f < b)] ** 2).sum() for a, b in [(0, 300), (300, 1000), (1000, 3000), (3000, 24000)]])
        e /= e.sum()
        print(f"{name:14s} {len(x) / SR * 1000:6.0f} ms  bands {np.round(e, 2)}")
