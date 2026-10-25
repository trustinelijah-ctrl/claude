#!/usr/bin/env python3
"""Ambience for 64 Pro that is synthesised rather than recorded: a fire in the grate and
a summer night of crickets. The recorded scenes come from tools/scenes.py.

Both are seamless stereo loops: the tail of a longer render is crossfaded into its head,
so the loop point can't be heard.

  python3 tools/ambience.py App/Resources/Sounds [fire] [night]

Replace either output with a recording of the same name to change it; the app trims
encoder padding and loops whatever is there.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 48000
LOOP = 60.0          # seconds in the finished loop
XFADE = 3.0          # seconds crossfaded at the loop point
RNG = np.random.default_rng(6464)


def sos(kind, f, order=2):
    return signal.butter(order, f, kind, fs=SR, output='sos')


def filt(x, kind, f, order=2):
    return signal.sosfilt(sos(kind, f, order), x)


def pink(n):
    """Pink noise by spectral shaping."""
    w = RNG.standard_normal(n)
    X = np.fft.rfft(w)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = f[1]
    X /= np.sqrt(f)
    x = np.fft.irfft(X, n)
    return x / np.std(x)


def brown(n):
    x = np.cumsum(RNG.standard_normal(n))
    x = filt(x, 'highpass', 20, 1)
    return x / np.std(x)


def lfo(n, rate_lo, rate_hi, depth, layers=3):
    """Slow, irregular swell: a few sines at unrelated rates."""
    t = np.arange(n) / SR
    m = np.zeros(n)
    for _ in range(layers):
        m += np.sin(2 * np.pi * RNG.uniform(rate_lo, rate_hi) * t + RNG.uniform(0, 2 * np.pi))
    return 1 + depth * m / layers


def place_events(n, times, make, pan_spread=0.8):
    """Adds short stereo events (mono `make()` buffers) at `times` seconds."""
    L = np.zeros(n)
    R = np.zeros(n)
    for t in times:
        e = make()
        s = int(t * SR)
        if s + len(e) >= n:
            continue
        p = RNG.uniform(-pan_spread, pan_spread)
        gl, gr = np.cos((p + 1) * np.pi / 4), np.sin((p + 1) * np.pi / 4)
        L[s:s + len(e)] += e * gl
        R[s:s + len(e)] += e * gr
    return L, R


def poisson(rate, seconds):
    t, out = 0.0, []
    while True:
        t += RNG.exponential(1 / rate)
        if t >= seconds:
            return out
        out.append(t)


def env(n, tau_ms):
    """An exponential decay over `n` samples."""
    return np.exp(-np.arange(n) / (tau_ms * SR / 1000))


# ---------------------------------------------------------------- rain

def droplet():
    """A single small drop on glass or a sill: a bright, very short tick."""
    n = int(RNG.uniform(1.5, 4) * SR / 1000)
    x = RNG.standard_normal(n) * env(n, RNG.uniform(0.3, 0.9))
    x = filt(x, 'bandpass', [RNG.uniform(2500, 4500), RNG.uniform(7000, 11000)])
    return x * RNG.lognormal(-2.2, 0.7)


def drip():
    """A heavier drop from the gutter: a short rising 'plink', like a bubble."""
    ms = RNG.uniform(18, 40)
    n = int(ms * SR / 1000)
    t = np.arange(n) / SR
    f0 = RNG.uniform(900, 1900)
    freq = f0 * (1 + 2.5 * t / t[-1])
    phase = 2 * np.pi * np.cumsum(freq) / SR
    x = np.sin(phase) * np.exp(-t / (ms / 1000 / 4))
    x[:24] *= np.linspace(0, 1, 24)
    return x * RNG.lognormal(-2.0, 0.5)


def rain(seconds):
    n = int(seconds * SR)
    # The steady wash of rain, heard through a window: soft, never hissy.
    wash_l = filt(filt(pink(n), 'highpass', 300), 'lowpass', 6500) * lfo(n, 0.03, 0.12, 0.18)
    wash_r = filt(filt(pink(n), 'highpass', 300), 'lowpass', 6500) * lfo(n, 0.03, 0.12, 0.18)
    # A low body to it: the rest of the street in the rain.
    body = filt(brown(n), 'lowpass', 180) * 0.1
    dl, dr = place_events(n, poisson(260, seconds), droplet)
    pl, pr = place_events(n, poisson(2.2, seconds), drip, pan_spread=0.6)
    L = wash_l * 0.22 + body + dl + pl
    R = wash_r * 0.22 + body + dr + pr
    # Indoors: the window takes the very top off.
    return filt(L, 'lowpass', 9000), filt(R, 'lowpass', 9000)


# ---------------------------------------------------------------- fire

def click():
    """One crackle of burning wood: a tiny, sharp burst."""
    ms = RNG.uniform(0.4, 1.6)
    n = max(8, int(ms * SR / 1000) + 40)
    x = RNG.standard_normal(n) * env(n, RNG.uniform(0.15, 0.6))
    lo = RNG.uniform(900, 2500)
    x = filt(x, 'bandpass', [lo, min(lo * RNG.uniform(2.5, 5), 15000)])
    return x


def crackle():
    """A crackle is a quick cluster of clicks, loud then trailing off."""
    count = RNG.integers(1, 7)
    span = int(RNG.uniform(8, 45) * SR / 1000)
    out = np.zeros(span + 200)
    amp = RNG.lognormal(-0.8, 0.8)
    for i in range(count):
        c = click() * amp * (0.6 ** i) * RNG.uniform(0.5, 1)
        s = int(RNG.uniform(0, span))
        out[s:s + len(c)] += c
    return out


def pop():
    """Now and then a pocket of sap pops: lower and fuller."""
    ms = RNG.uniform(12, 30)
    n = int(ms * SR / 1000)
    x = RNG.standard_normal(n) * env(n, RNG.uniform(2, 5))
    x = filt(x, 'bandpass', [RNG.uniform(300, 600), RNG.uniform(1800, 3500)])
    return x * RNG.lognormal(-0.9, 0.4)


def fire(seconds):
    n = int(seconds * SR)
    # The roar of the flames: deep and breathing.
    roar_l = filt(brown(n), 'lowpass', 260) * lfo(n, 0.08, 0.5, 0.35)
    roar_r = filt(brown(n), 'lowpass', 260) * lfo(n, 0.08, 0.5, 0.35)
    # A faint hiss of gas from the logs.
    hiss = filt(RNG.standard_normal(n), 'bandpass', [2500, 7000]) * lfo(n, 0.2, 0.9, 0.6) * 0.012
    # Crackles come in bursts: their rate swells and falls.
    times = []
    t = 0.0
    while t < seconds:
        rate = 4 + 14 * (0.5 + 0.5 * np.sin(2 * np.pi * t / RNG.uniform(5, 11))) ** 2
        t += RNG.exponential(1 / rate)
        times.append(t)
    cl, cr = place_events(n, times, crackle, pan_spread=0.7)
    pl, pr = place_events(n, poisson(0.35, seconds), pop, pan_spread=0.5)
    L = roar_l * 0.3 + hiss + cl + pl
    R = roar_r * 0.3 + hiss + cr + pr
    return L, R


def room(x, seconds=0.35, wet=0.22):
    """A small room around dry sounds: a short, dark, decaying noise tail."""
    n = int(seconds * SR)
    ir = RNG.standard_normal(n) * np.exp(-np.arange(n) / (seconds * SR / 5))
    ir = filt(ir, 'lowpass', 3500)
    ir /= np.sqrt((ir ** 2).sum())
    return x + signal.fftconvolve(x, ir)[:len(x)] * wet


def fire_room(seconds):
    L, R = fire(seconds)
    return room(L), room(R)


# ---------------------------------------------------------------- night

def chirp(f0):
    """One cricket call: three or four quick pulses of a pure, high tone."""
    pulses = RNG.integers(3, 5)
    pulse = int(0.012 * SR)
    gap = int(0.022 * SR)
    out = np.zeros(pulses * (pulse + gap))
    t = np.arange(pulse) / SR
    env = np.sin(np.pi * np.arange(pulse) / pulse) ** 2
    for i in range(pulses):
        f = f0 * RNG.uniform(0.995, 1.005)
        out[i * (pulse + gap):i * (pulse + gap) + pulse] += np.sin(2 * np.pi * f * t) * env
    return out


def night(seconds):
    n = int(seconds * SR)
    L = np.zeros(n)
    R = np.zeros(n)
    # A handful of crickets, near and far, each keeping its own steady rhythm.
    for _ in range(7):
        f0 = RNG.uniform(3900, 5200)
        period = RNG.uniform(0.32, 0.75)
        dist = RNG.uniform(0.15, 1.0)
        p = RNG.uniform(-0.8, 0.8)
        gl, gr = np.cos((p + 1) * np.pi / 4), np.sin((p + 1) * np.pi / 4)
        t = RNG.uniform(0, period)
        while t < seconds - 0.2:
            c = chirp(f0) * dist * 0.08
            s0 = int(t * SR)
            L[s0:s0 + len(c)] += c * gl
            R[s0:s0 + len(c)] += c * gr
            # Crickets pause now and then.
            t += period * (RNG.uniform(0.97, 1.03) if RNG.random() > 0.04 else RNG.uniform(3, 8))
    # Far-off ones blur into a shimmer; the night air is a soft, dark hush.
    L, R = filt(L, 'lowpass', 7500), filt(R, 'lowpass', 7500)
    air_l = filt(pink(n), 'lowpass', 900) * lfo(n, 0.02, 0.08, 0.3) * 0.02
    air_r = filt(pink(n), 'lowpass', 900) * lfo(n, 0.02, 0.08, 0.3) * 0.02
    return room(L + air_l, 0.5, 0.3), room(R + air_r, 0.5, 0.3)


# ---------------------------------------------------------------- loop and write

def seamless(make):
    total = LOOP + XFADE
    L, R = make(total)
    n = int(LOOP * SR)
    x = int(XFADE * SR)
    ramp = np.sin(np.linspace(0, np.pi / 2, x)) ** 2
    out = []
    for ch in (L, R):
        y = ch[:n].copy()
        # The extra tail fades into the head: the end of the loop flows into its start.
        y[:x] = ch[n:n + x] * (1 - ramp) + ch[:x] * ramp
        out.append(y)
    return out


def write(path, L, R, peak_db):
    m = max(np.max(np.abs(L)), np.max(np.abs(R)))
    g = 10 ** (peak_db / 20) / m
    pcm = (np.stack([L, R], axis=1) * g * 32767).clip(-32767, 32767).astype('<i2')
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        name = tmp.name
    with wave.open(name, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-v', 'quiet', '-y', '-i', name, '-c:a', 'aac', '-b:a', '128k', path], check=True)
    os.remove(name)
    rms = np.sqrt(np.mean((np.stack([L, R]) * g) ** 2))
    print(f"{os.path.basename(path):22s} {LOOP:.0f} s  rms {20 * np.log10(rms):.1f} dBFS  {os.path.getsize(path) // 1024} KB")


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    only = sys.argv[2:] or ['fire', 'night']
    if 'fire' in only:
        write(os.path.join(out, 'ambience_fire.m4a'), *seamless(fire_room), peak_db=-6.0)
    if 'night' in only:
        write(os.path.join(out, 'ambience_night.m4a'), *seamless(night), peak_db=-9.0)
