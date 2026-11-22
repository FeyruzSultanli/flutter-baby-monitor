#!/usr/bin/env python3
"""Generates the app's sounds into assets/audio/ (standard library only).

All sounds are synthesized here, so there are no third-party recordings and
no licence questions (see assets/audio/LICENSES.md). Re-run after changes:

    python3 tool/gen_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.89 / peak
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))
    print(f'{path}: {len(samples) / RATE:.1f} s')


def bell(freq, dur, decay=3.0, partials=((1, 1.0), (2.01, 0.35), (3.02, 0.12))):
    """Soft bell / music box tone."""
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-decay * t) * min(1.0, t / 0.004)
        out.append(env * sum(a * math.sin(2 * math.pi * freq * m * t) for m, a in partials))
    return out


def mix_into(buf, start_s, part, gain=1.0):
    start = int(start_s * RATE)
    need = start + len(part)
    if len(buf) < need:
        buf.extend([0.0] * (need - len(buf)))
    for i, v in enumerate(part):
        buf[start + i] += v * gain


def alarm_connection():
    """Connection lost: insistent but not harsh, two descending chimes."""
    buf = [0.0] * int(2.6 * RATE)
    for k, (f, t) in enumerate([(880.0, 0.0), (659.25, 0.32), (880.0, 1.0), (659.25, 1.32)]):
        mix_into(buf, t, bell(f, 1.1, decay=4.0), 0.8)
    return buf


def alarm_cry():
    """Cry alarm: three rising soft chimes, then a pause (loops)."""
    buf = [0.0] * int(3.0 * RATE)
    for f, t in [(659.25, 0.0), (783.99, 0.22), (987.77, 0.44)]:
        mix_into(buf, t, bell(f, 1.4, decay=3.2), 0.75)
    return buf


if __name__ == '__main__':
    random.seed(7)
    write_wav('alarm_connection.wav', alarm_connection())
    write_wav('alarm_cry.wav', alarm_cry())
