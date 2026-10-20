#!/usr/bin/env python3
"""TABLE sound palette, synthesized offline.

Every sound is built from the same physical model so the palette feels like one
material: a felted boxwood piece meeting a walnut board. Impacts are modal
syntheses (a short excitation ringing a bank of damped resonances); tonal accents
are struck wooden bars with marimba-like partials. A very short early-reflection
pattern gives body without audible reverb.

  python3 tools/sounds.py App/Resources/Sounds

Replace any file in that folder with a recording of the same name to upgrade the
palette; the app loads whatever is there.
"""
import os
import sys
import wave
import numpy as np
from scipy import signal

SR = 48000
RNG = np.random.default_rng(1964)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def db(x):
    return 10 ** (x / 20)


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype='bandpass', fs=SR, output='sos')
    return signal.sosfilt(sos, x)


def lowpass(x, f, order=2):
    sos = signal.butter(order, f, btype='lowpass', fs=SR, output='sos')
    return signal.sosfilt(sos, x)


def highpass(x, f, order=2):
    sos = signal.butter(order, f, btype='highpass', fs=SR, output='sos')
    return signal.sosfilt(sos, x)


def modes(dur, bank, jitter=0.0):
    """bank: list of (freq Hz, decay seconds, amplitude). Returns summed damped sinusoids."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f, tau, a in bank:
        f *= 1 + RNG.normal(0, jitter)
        tau *= 1 + RNG.normal(0, jitter * 2)
        phase = RNG.uniform(0, 2 * np.pi)
        out += a * np.exp(-t / tau) * np.sin(2 * np.pi * f * t + phase)
    attack = 1 - np.exp(-t / 0.00035)
    return out * attack


def click(dur, lo, hi, tau, amp):
    t = t_axis(dur)
    n = RNG.standard_normal(len(t)) * np.exp(-t / tau)
    return bandpass(n, lo, hi) * amp


def early_reflections(x, level=db(-20)):
    """A small table-top space: three faint reflections within 20 ms, high frequencies absorbed."""
    out = x.copy()
    for ms, g in [(7.3, 1.0), (12.9, 0.6), (19.4, 0.35)]:
        d = int(ms * SR / 1000)
        refl = np.zeros_like(x)
        refl[d:] = x[:-d]
        out += lowpass(refl, 3200) * g * level
    return out


def finish(x, peak_db, fade_ms=6.0):
    """Remove DC, fade the tail, normalise to a peak level."""
    x = highpass(x, 60, order=1)
    n = int(fade_ms * SR / 1000)
    if n and len(x) > n:
        x[-n:] *= np.linspace(1, 0, n) ** 2
    x[:16] *= np.linspace(0, 1, 16)
    peak = np.max(np.abs(x)) + 1e-12
    return x / peak * db(peak_db)


def pad(x, dur):
    n = int(dur * SR)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def mix(*layers):
    n = max(len(l) for l, _ in layers)
    out = np.zeros(n)
    for l, offset in layers:
        o = int(offset * SR)
        seg = l[:max(0, n - o)]
        out[o:o + len(seg)] += seg
    return out


# ---------------------------------------------------------------- impacts

def knock(weight=1.0, brightness=1.0, dur=0.22, jitter=0.03):
    """A felted wooden piece set onto a wooden board.
    weight scales the low body; brightness scales the piece's own high modes."""
    board = modes(dur, [
        (232, 0.050, 0.55 * weight),
        (371, 0.042, 0.80 * weight),
        (548, 0.034, 0.70),
        (812, 0.026, 0.55),
    ], jitter)
    piece = modes(dur, [
        (1180, 0.018, 0.42 * brightness),
        (1730, 0.013, 0.34 * brightness),
        (2460, 0.009, 0.24 * brightness),
        (3390, 0.006, 0.16 * brightness),
    ], jitter)
    contact = click(dur, 900, 6500, 0.0011, 0.9 * brightness)
    felt = click(dur, 200, 1400, 0.0030, 0.55)        # the felt pad compressing
    return taper(early_reflections(board + piece + contact + felt))


def taper(x, portion=0.4):
    """Fade the last part of a layer so truncated tails never click."""
    n = int(len(x) * portion)
    x = x.copy()
    x[-n:] *= np.cos(np.linspace(0, np.pi / 2, n)) ** 2
    return x


def place(i):
    w = 1.0 + RNG.normal(0, 0.06)
    b = 1.0 + RNG.normal(0, 0.10)
    return finish(knock(w, b, jitter=0.035), -5.0)


def capture(i):
    main = knock(1.35, 1.15, dur=0.30, jitter=0.03)
    # weight comes from a longer, lower-mid body that small speakers can still reproduce
    low = taper(modes(0.30, [(262, 0.075, 0.55), (318, 0.060, 0.45), (455, 0.040, 0.3)], 0.03))
    # the taken piece is nudged a moment before the attacker lands
    nudge = knock(0.35, 1.6, dur=0.12, jitter=0.05) * db(-11)
    return finish(mix((nudge, 0.0), (main + low * 1.1, 0.016)), -3.0)


def pickup(i):
    t = t_axis(0.06)
    lift = click(0.06, 1800, 7000, 0.0016, 1.0)
    tick = modes(0.06, [(2300 * (1 + RNG.normal(0, 0.05)), 0.006, 0.35), (3600, 0.004, 0.2)])
    slide = bandpass(RNG.standard_normal(len(t)), 2500, 9000) * np.exp(-t / 0.012) * 0.12
    return finish(lift + tick + slide, -21.0, fade_ms=4)


def invalid():
    """The piece set back softly on its own square: muted and brief."""
    soft = knock(0.7, 0.25, dur=0.14, jitter=0.02)
    soft = lowpass(soft, 1400, order=2)
    return finish(soft, -17.0)


def ui_click():
    t = t_axis(0.04)
    tick = modes(0.04, [(3100, 0.0035, 0.6), (4700, 0.0022, 0.35)])
    body = modes(0.04, [(1250, 0.006, 0.25)])
    return finish(tick + body + click(0.04, 2500, 9000, 0.0006, 0.4), -24.0, fade_ms=3)


# ---------------------------------------------------------------- tonal accents

def bar(freq, dur, amp=1.0, decay=0.9, hardness=0.5):
    """A struck wooden bar. Marimba bars are tuned so the first overtone sits two octaves up."""
    partials = [(1.0, decay, 1.0), (3.93, decay * 0.32, 0.30 * hardness), (9.2, decay * 0.12, 0.10 * hardness)]
    tone = modes(dur, [(freq * r, tau, a) for r, tau, a in partials])
    mallet = click(dur, freq * 1.5, min(freq * 8, 12000), 0.0012, 0.25 * hardness)
    return (tone + mallet) * amp


def promotion():
    # a rising fifth on soft rosewood bars, under the placement
    g5, d6 = 783.99, 1174.66
    tone = mix((bar(g5, 0.9, 0.8, decay=0.36), 0.0), (bar(d6, 0.9, 0.7, decay=0.40), 0.075))
    tone = early_reflections(tone, db(-16))
    return finish(tone, -9.0, fade_ms=60)


def check():
    # two quick, low taps on a wooden bar: noticeable, never alarming
    a4 = 440.0
    taps = mix((bar(a4, 0.45, 0.9, decay=0.16, hardness=0.7), 0.0),
               (bar(a4 * 1.5, 0.45, 0.55, decay=0.14, hardness=0.6), 0.09))
    return finish(early_reflections(taps, db(-16)), -12.0, fade_ms=40)


def checkmate():
    # a deep final knock, then an unhurried D major spread on wooden bars
    d3, a3, d4, fs4, a4 = 146.83, 220.0, 293.66, 369.99, 440.0
    thunk = knock(1.8, 0.8, dur=0.5, jitter=0.0)
    low = taper(modes(0.5, [(220, 0.14, 0.4), (293.7, 0.11, 0.35)]))
    chord = mix(
        (bar(d4, 2.2, 0.75, decay=0.9), 0.10),
        (bar(a4, 2.2, 0.55, decay=0.85), 0.17),
        (bar(fs4 * 2, 2.2, 0.32, decay=0.7), 0.25),
        (bar(d4 * 2, 2.2, 0.36, decay=0.8), 0.33),
    )
    body = mix((bar(d3, 2.4, 0.22, decay=1.1, hardness=0.2), 0.10), (bar(a3, 2.4, 0.3, decay=1.0, hardness=0.2), 0.12))
    out = mix((thunk + low, 0.0), (chord, 0.0), (body, 0.0))
    return finish(early_reflections(out, db(-14)), -5.0, fade_ms=300)


def draw_end():
    # the same bars, without a winner: a quiet open fifth
    d4, a4 = 293.66, 440.0
    out = mix((bar(d4, 1.8, 0.7, decay=0.8, hardness=0.3), 0.0), (bar(a4, 1.8, 0.5, decay=0.75, hardness=0.3), 0.12))
    return finish(early_reflections(out, db(-16)), -10.0, fade_ms=250)


def reset():
    """Pieces gathered and set back home: a soft felt slide, a cascade of light taps, one settle."""
    dur = 0.75
    t = t_axis(dur)
    slide = bandpass(RNG.standard_normal(len(t)), 600, 5000)
    env = np.clip(np.sin(np.pi * np.clip(t / 0.5, 0, 1)), 0, None) ** 2
    out = slide * env * 0.06
    times = np.cumsum(RNG.uniform(0.028, 0.055, 9)) + 0.05
    for i, at in enumerate(times):
        tap = knock(0.4, 0.9, dur=0.12, jitter=0.06) * (0.18 + 0.05 * RNG.random())
        out = mix((out, 0.0), (pad(tap, 0.12), float(at)))
    settle = knock(0.9, 0.7, dur=0.25) * 0.55
    out = mix((out, 0.0), (settle, float(times[-1] + 0.07)))
    return finish(pad(out, dur + 0.25), -11.0, fade_ms=40)


# ---------------------------------------------------------------- output

def write_wav(path, x):
    pcm = np.clip(x, -1, 1)
    pcm = (pcm * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    files = {}
    for i in range(4):
        files[f'place_{i + 1}'] = place(i)
    for i in range(3):
        files[f'capture_{i + 1}'] = capture(i)
        files[f'pickup_{i + 1}'] = pickup(i)
    files['invalid_1'] = invalid()
    files['ui_1'] = ui_click()
    files['promotion_1'] = promotion()
    files['check_1'] = check()
    files['checkmate_1'] = checkmate()
    files['draw_1'] = draw_end()
    files['reset_1'] = reset()
    for name, x in files.items():
        write_wav(os.path.join(out, name + '.wav'), x)
        print(f"{name:14s} {len(x) / SR * 1000:6.0f} ms  peak {20 * np.log10(np.max(np.abs(x))):6.1f} dBFS")
