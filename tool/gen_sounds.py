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


def crossfade_loop(samples, fade_s=0.6):
    """Makes a seamless loop: the tail fades into the head."""
    n = int(fade_s * RATE)
    body = samples[:-n]
    tail = samples[-n:]
    for i in range(n):
        a = i / n
        body[i] = body[i] * a + tail[i] * (1 - a)
    return body


def pink_noise(seconds):
    """Soft 'white noise' for babies: pink noise (Paul Kellet's filter)."""
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    out = []
    for _ in range(int(seconds * RATE)):
        w = random.uniform(-1, 1)
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        out.append(b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362)
        b6 = w * 0.115926
    return out


def lowpass(samples, alpha):
    y = 0.0
    out = []
    for x in samples:
        y += alpha * (x - y)
        out.append(y)
    return out


def white_noise_track():
    return crossfade_loop(pink_noise(16.6))


def rain_track():
    base = lowpass(pink_noise(16.6), 0.35)
    # slow swell of the shower
    for i in range(len(base)):
        t = i / RATE
        base[i] *= 0.75 + 0.25 * math.sin(2 * math.pi * t / 8.3)
    # droplets: tiny filtered clicks
    for _ in range(900):
        start = random.randint(0, len(base) - 400)
        amp = random.uniform(0.05, 0.25)
        f = random.uniform(1800, 4200)
        for k in range(300):
            env = math.exp(-k / 40)
            base[start + k] += amp * env * math.sin(2 * math.pi * f * k / RATE)
    return crossfade_loop(base)


def heartbeat_track():
    """Womb-like heartbeat at 70 bpm: lub-dub thumps over a soft whoosh."""
    beat = 60 / 70
    beats = 14
    n = int(beat * beats * RATE)
    buf = [x * 0.04 for x in lowpass(pink_noise(n / RATE), 0.05)]

    def thump(freq, dur, amp):
        out = []
        for i in range(int(dur * RATE)):
            t = i / RATE
            env = math.exp(-t * 18) * min(1, t / 0.006)
            out.append(amp * env * math.sin(2 * math.pi * freq * t * (1 - 0.4 * t)))
        return out
    for b in range(beats):
        mix_into(buf, b * beat, thump(58, 0.25, 1.0))
        mix_into(buf, b * beat + 0.28, thump(52, 0.22, 0.7))
    return buf[:n]


# "Dandini dandini dastana": a traditional (public domain) Turkish lullaby.
# Our own simple transcription (D minor, eighth notes); listen and correct by
# ear if needed (see assets/audio/LICENSES.md).
_NOTES = {'D4': 293.66, 'E4': 329.63, 'F4': 349.23, 'G4': 392.0, 'A4': 440.0, 'Bb4': 466.16, 'C5': 523.25, 'D5': 587.33}
DANDINI = [
    ('A4', 1), ('A4', 1), ('G4', 1), ('A4', 1), ('A4', 1), ('G4', 1), ('F4', 1), ('G4', 1), ('A4', 3),
    ('G4', 1), ('G4', 1), ('F4', 1), ('G4', 1), ('G4', 1), ('F4', 1), ('E4', 1), ('F4', 1), ('G4', 3),
    ('A4', 1), ('Bb4', 1), ('A4', 1), ('G4', 1), ('F4', 1), ('G4', 1), ('A4', 3),
    ('G4', 1), ('F4', 1), ('E4', 1), ('F4', 1), ('E4', 1), ('D4', 1), ('D4', 4),
]


def dandini_track():
    eighth = 0.36
    total = sum(d for _, d in DANDINI) * eighth + 2.0
    buf = [0.0] * int(total * RATE)
    t = 0.0
    for note, d in DANDINI:
        f = _NOTES[note]
        # music box: bright partials, longer ring on long notes
        mix_into(buf, t, bell(f * 2, 0.4 + d * eighth * 1.4, decay=2.6,
                              partials=((1, 1.0), (2.0, 0.18), (3.0, 0.06), (4.2, 0.04))), 0.6)
        t += d * eighth
    return buf


if __name__ == '__main__':
    random.seed(7)
    write_wav('alarm_connection.wav', alarm_connection())
    write_wav('alarm_cry.wav', alarm_cry())
    write_wav('soothe_white_noise.wav', white_noise_track())
    write_wav('soothe_rain.wav', rain_track())
    write_wav('soothe_heartbeat.wav', heartbeat_track())
    write_wav('soothe_dandini.wav', dandini_track())
