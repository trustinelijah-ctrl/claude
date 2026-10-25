#!/usr/bin/env python3
"""Ambience scenes for 64 Pro, made from real field recordings.

Every source is public domain or CC0, from Wikimedia Commons; tools/sources/ambience/
CREDITS.md lists each file, its author and licence. The recordings themselves are not
kept in the repository (they are large); this script downloads any that are missing.

For each scene it picks the calmest stretch of the recording (the steadiest loudness,
no sudden bangs unless the scene wants them), cleans the low rumble and harsh top,
evens out the level, and crossfades the end into the start so it loops without a seam.

  python3 tools/scenes.py App/Resources/Sounds

Writes ambience_<scene>.m4a (AAC, stereo, 48 kHz), each LOOP seconds long.
"""
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

import numpy as np
from scipy import signal

SR = 48000
LOOP = 60.0         # seconds in each finished loop
XFADE = 5.0         # seconds crossfaded at the loop point
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'sources', 'ambience')
UA = {'User-Agent': '64-chess-app-ambience/1.0'}

# scene: (Commons file, start search window in seconds or None, options)
SCENES = {
    'rain':  ('Rain (1).ogg', None, dict(hp=90, lp=12000, target=-26, steady=True, flatten=True)),
    'storm': ('Light Rain Distant Thunder July 5th 2016.wav', None, dict(hp=35, lp=13000, target=-25, steady=False)),
    'cafe':  ('Cafe ambiance.ogg', None, dict(hp=80, lp=11000, target=-27, steady=True)),
    'sea':   ('Ocean Waves on a Tropical Beach.ogg', None, dict(hp=40, lp=12000, target=-25, steady=False)),
}


def fetch(name):
    """Downloads a Commons file into tools/sources/ambience if it isn't there yet."""
    os.makedirs(SRC, exist_ok=True)
    dest = os.path.join(SRC, name.replace(' ', '_'))
    if os.path.exists(dest):
        return dest
    q = urllib.parse.urlencode(dict(action='query', titles='File:' + name, prop='imageinfo', iiprop='url', format='json'))
    for attempt in range(8):
        try:
            d = json.load(urllib.request.urlopen(urllib.request.Request(
                'https://commons.wikimedia.org/w/api.php?' + q, headers=UA), timeout=60))
            url = next(iter(d['query']['pages'].values()))['imageinfo'][0]['url']
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=600) as r, open(dest, 'wb') as f:
                f.write(r.read())
            return dest
        except Exception as e:
            print('  retrying', name, e)
            time.sleep(30)
    raise SystemExit(f'Could not download {name}')


def load(path):
    raw = subprocess.run(['ffmpeg', '-v', 'quiet', '-i', path, '-ac', '2', '-ar', str(SR), '-f', 'f32le', '-'],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(np.float64).reshape(-1, 2)
    return x.T.copy()


def filt(x, kind, f, order=2):
    """Zero-phase filter that treats the signal as a loop, so the loop point stays seamless."""
    pad = min(x.shape[-1] // 2, SR)
    xp = np.concatenate([x[..., -pad:], x, x[..., :pad]], axis=-1)
    y = signal.sosfiltfilt(signal.butter(order, f, kind, fs=SR, output='sos'), xp, axis=-1)
    return y[..., pad:-pad]


def shelf_down(x, f, db):
    """A gentle high shelf: blends in a low-passed copy above `f`."""
    g = 10 ** (db / 20)
    low = filt(x, 'lowpass', f, 1)
    return low + (x - low) * g


def window_rms(x, win):
    m = (x ** 2).mean(axis=0)
    n = len(m) // win
    return np.sqrt(m[:n * win].reshape(n, win).mean(axis=1) + 1e-12)


def flatten(x, seconds=4.0, amount=0.8):
    """Rides out slow swells in loudness, so the bed stays even for an hour of play."""
    win = int(seconds * SR)
    e = np.sqrt(signal.fftconvolve((x ** 2).mean(axis=0), np.ones(win) / win, mode='same') + 1e-10)
    return x / (e / np.median(e)) ** amount


def best_stretch(x, seconds, steady):
    """The start (in samples) of the stretch whose loudness is most even and free of spikes."""
    need = int(seconds * SR)
    if x.shape[1] <= need:
        return 0
    win = SR // 4
    r = 20 * np.log10(window_rms(x, win))
    per = need // win
    best, best_score = 0, 1e9
    # Skip the first and last few seconds: recordings often start and stop with handling noise.
    lo, hi = int(4 * SR / win), len(r) - per - int(4 * SR / win)
    for s in range(max(0, lo), max(lo + 1, hi), 2):
        seg = r[s:s + per]
        if len(seg) < per:
            break
        spread = np.percentile(seg, 95) - np.percentile(seg, 10)
        spikes = np.max(seg) - np.median(seg)
        score = spread + (2.0 if steady else 0.6) * spikes
        if score < best_score:
            best, best_score = s, score
    return best * win


def peak_tame(x, ceiling_db=-4.0):
    """Soft-clips the rare peak above the ceiling, so loudness can sit higher without bangs."""
    c = 10 ** (ceiling_db / 20)
    return np.where(np.abs(x) <= c * 0.7, x, np.sign(x) * (c * 0.7 + (c * 0.3) * np.tanh((np.abs(x) - c * 0.7) / (c * 0.3))))


def seamless(x, loop, xfade):
    n = int(loop * SR)
    f = int(xfade * SR)
    ramp = np.sin(np.linspace(0, np.pi / 2, f)) ** 2
    y = x[:, :n].copy()
    y[:, :f] = x[:, n:n + f] * (1 - ramp) + x[:, :f] * ramp
    return y


def build(scene, out_dir):
    name, _, o = SCENES[scene]
    x = load(fetch(name))
    mono = np.allclose(x[0], x[1], atol=1e-4)
    if o.get('flatten'):
        x = flatten(x)
    dur = x.shape[1] / SR
    # A mono recording becomes stereo from two stretches a few seconds apart, one per ear;
    # each is looped on its own, so neither side has a seam.
    offset = 6.0 if mono else 0.0
    loop = min(LOOP, dur - 4.0 - XFADE - offset)
    total = loop + XFADE
    start = best_stretch(x, total + offset, o['steady'])
    take = lambda s0: x[:, s0:s0 + int(total * SR)]
    if mono:
        y = np.stack([seamless(take(start), loop, XFADE)[0],
                      seamless(take(start + int(offset * SR)), loop, XFADE)[0]])
    else:
        y = seamless(take(start), loop, XFADE)
    y = filt(y, 'highpass', o['hp'], 2)
    y = filt(y, 'lowpass', o['lp'], 2)
    y = shelf_down(y, 6000, -3.0)
    if not mono:
        # A touch narrower than the raw recording: easier to sit under the game.
        mid, side = (y[0] + y[1]) / 2, (y[0] - y[1]) / 2
        y = np.stack([mid + side * 0.8, mid - side * 0.8])
    y *= 10 ** (o['target'] / 20) / np.sqrt((y ** 2).mean())
    y = peak_tame(y)
    path = os.path.join(out_dir, f'ambience_{scene}.m4a')
    pcm = (np.clip(y.T, -1, 1) * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-v', 'quiet', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2', '-i', '-',
                    '-c:a', 'aac', '-b:a', '160k', path], input=pcm, check=True)
    print(f'{scene:6s} {loop:4.0f} s loop from {start / SR:6.1f}s of {name[:40]:40s} '
          f'rms {20 * np.log10(np.sqrt((y ** 2).mean())):.1f} dBFS  {os.path.getsize(path) // 1024} KB')


if __name__ == '__main__':
    out = sys.argv[1]
    only = sys.argv[2:] or list(SCENES)
    for s in only:
        build(s, out)
