#!/usr/bin/env python3
"""64's piece sounds from real recordings of a chess set.

Takes a Voice Memo (any format ffmpeg reads), finds every hit in it, cuts each one
cleanly, and grades it: level, brightness, how long it rings, whether there is handling
noise just before it, and whether it carries a table thump (low rumble) that would sound
like a knock on the device. Good takes are cleaned and written as app sounds.

  python3 tools/foley.py RECORDING.m4a OUT_DIR            # cut, grade, write takes + report
  python3 tools/foley.py RECORDING.m4a OUT_DIR --app SOUNDS_DIR --map "place:3,7,8 ..."

Cleaning, per take:
  - starts 12 ms before the hit (keeps the attack), ends when it has fallen 55 dB or at
    0.7 s, with a short cosine fade;
  - high-pass at 90 Hz removes table thumps and handling rumble;
  - a gentle lift around 250-400 Hz gives the wood its body (phone microphones are thin there);
  - a soft shelf above 7 kHz takes the edge off the click;
  - a very short, quiet room (a few early reflections) so it sits in a space, not in a vacuum;
  - peak-normalised to the level the app's sounds are mixed at.
"""
import json
import os
import subprocess
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 48000


def load(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR),
                          '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def env_db(x, ms=3):
    w = max(1, int(ms / 1000 * SR))
    return 20 * np.log10(np.sqrt(np.convolve(x ** 2, np.ones(w) / w, 'same')) + 1e-9)


def find_hits(x):
    db = env_db(x)
    peaks, _ = signal.find_peaks(db, height=-50, distance=int(0.35 * SR), prominence=20)
    return peaks, db


def grade(x, db, i):
    seg = x[max(0, i - int(0.02 * SR)):i + int(0.4 * SR)]
    f, P = signal.welch(seg, SR, nperseg=1024)
    centroid = float((f * P).sum() / P.sum())
    low = float(P[f < 120].sum() / P.sum())
    tail = db[i:i + int(0.7 * SR)]
    k = np.argmax(tail < db[i] - 30)
    ring = (k / SR) if k else 0.7
    pre = float(db[max(0, i - int(0.5 * SR)):max(1, i - int(0.04 * SR))].max())
    bounces, _ = signal.find_peaks(db[i + int(0.015 * SR):i + int(0.3 * SR)], prominence=8, height=db[i] - 25)
    return dict(t=round(i / SR, 2), peak=round(float(db[i]), 1), centroid=round(centroid), low=round(low, 3),
                ring_ms=round(ring * 1000), pre=round(pre, 1), bounces=int(len(bounces)))


def cut(x, db, i, longest=0.7):
    a = max(0, i - int(0.012 * SR))
    tail = db[i:i + int(longest * SR)]
    k = np.argmax(tail < db[i] - 55)
    b = i + (k if k else len(tail))
    y = x[a:b].copy()
    fade = min(len(y) // 3, int(0.04 * SR))
    y[-fade:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, fade)))
    y[:24] *= np.linspace(0, 1, 24)
    return y


def clean(y, peak_db=-8.0, body_db=3.0):
    sos = signal.butter(4, 90, 'hp', fs=SR, output='sos')
    y = signal.sosfiltfilt(sos, y)
    # Body: a broad, gentle peak around 320 Hz.
    b, a = peaking(320, body_db, 0.8)
    y = signal.lfilter(b, a, y)
    # Soften the very top.
    b, a = shelf(7000, -3.0)
    y = signal.lfilter(b, a, y)
    # A small room: a few quiet early reflections.
    room = np.zeros(int(0.04 * SR))
    room[0] = 1
    for ms, g in [(7, 0.12), (13, 0.08), (19, 0.06), (29, 0.04), (37, 0.025)]:
        room[int(ms / 1000 * SR)] += g
    room = signal.sosfilt(signal.butter(2, 5000, 'lp', fs=SR, output='sos'), room) * 0.6 + np.eye(1, len(room))[0] * 0.4
    y = np.convolve(y, room)[:len(y) + int(0.03 * SR)]
    fade = int(0.02 * SR)
    y[-fade:] *= np.linspace(1, 0, fade)
    return y / (np.abs(y).max() + 1e-12) * 10 ** (peak_db / 20)


def peaking(f0, gain_db, q):
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f0 / SR
    al = np.sin(w) / (2 * q)
    b = [1 + al * A, -2 * np.cos(w), 1 - al * A]
    a = [1 + al / A, -2 * np.cos(w), 1 - al / A]
    return np.array(b) / a[0], np.array(a) / a[0]


def shelf(f0, gain_db):
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f0 / SR
    al = np.sin(w) / 2 * np.sqrt(2)
    c = np.cos(w)
    b = [A * ((A + 1) + (A - 1) * c + 2 * np.sqrt(A) * al), -2 * A * ((A - 1) + (A + 1) * c),
         A * ((A + 1) + (A - 1) * c - 2 * np.sqrt(A) * al)]
    a = [(A + 1) - (A - 1) * c + 2 * np.sqrt(A) * al, 2 * ((A - 1) - (A + 1) * c),
         (A + 1) - (A - 1) * c - 2 * np.sqrt(A) * al]
    return np.array(b) / a[0], np.array(a) / a[0]


def write(path, y):
    wavfile.write(path, SR, (np.clip(y, -1, 1) * 32767).astype(np.int16))


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    x = load(src)
    peaks, db = find_hits(x)
    report = []
    for n, i in enumerate(peaks, 1):
        g = grade(x, db, i)
        g['n'] = n
        raw = cut(x, db, i)
        write(os.path.join(out, f'take{n:02d}_raw.wav'), raw / (np.abs(raw).max() + 1e-12) * 10 ** (-8 / 20))
        write(os.path.join(out, f'take{n:02d}.wav'), clean(raw))
        report.append(g)
    with open(os.path.join(out, 'takes.json'), 'w') as f:
        json.dump(report, f, indent=1)
    for g in report:
        print(g)


if __name__ == '__main__':
    main()
