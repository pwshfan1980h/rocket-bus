#!/usr/bin/env python3
"""Synthesizes every Rocket Bus sound effect and music loop (no dependencies).

Run from the project root:  python3 tools/gen_audio.py [name ...]
Writes 22.05 kHz mono 16-bit WAVs into assets/audio. Files ending in _loop
(and all music_*) are made seamless and are looped at runtime by Audio.
"""
import math
import os
import random
import struct
import sys
import wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio")
SR = 22050
TAU = math.tau


# --- DSP helpers ------------------------------------------------------------

def silence(sec):
    return [0.0] * int(sec * SR)


def mix(dst, src, at=0.0, gain=1.0):
    i0 = int(at * SR)
    end = min(len(dst), i0 + len(src))
    for i in range(max(i0, 0), end):
        dst[i] += src[i - i0] * gain
    return dst


def osc(freq, dur, wave_="sine", duty=0.5, phase=0.0):
    """freq may be a number or a function of time (seconds)."""
    n = int(dur * SR)
    out = [0.0] * n
    fn = freq if callable(freq) else None
    f = 0.0 if fn else freq
    ph = phase
    for i in range(n):
        if fn:
            f = fn(i / SR)
        ph = (ph + f / SR) % 1.0
        if wave_ == "sine":
            v = math.sin(ph * TAU)
        elif wave_ == "square":
            v = 1.0 if ph < duty else -1.0
        elif wave_ == "saw":
            v = 2.0 * ph - 1.0
        else:  # triangle
            v = 4.0 * abs(ph - 0.5) - 1.0
        out[i] = v
    return out


def noise(dur, seed=1):
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) for _ in range(int(dur * SR))]


def brown(dur, seed=1):
    rng = random.Random(seed)
    out, v = [], 0.0
    for _ in range(int(dur * SR)):
        v = (v + rng.uniform(-1, 1) * 0.08) * 0.995
        out.append(v * 4)
    return out


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be a function of time."""
    out = [0.0] * len(x)
    y = 0.0
    fn = cutoff if callable(cutoff) else None
    a = 1 - math.exp(-TAU * (cutoff if not fn else 1000) / SR)
    for i, v in enumerate(x):
        if fn and i % 32 == 0:
            a = 1 - math.exp(-TAU * max(20.0, fn(i / SR)) / SR)
        y += a * (v - y)
        out[i] = y
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def bandpass(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def env(x, fn):
    return [v * fn(i / SR) for i, v in enumerate(x)]


def decay(tau, attack=0.002):
    return lambda t: min(1.0, t / attack) * math.exp(-t / tau)


def adsr(a, d, s, r, dur):
    def f(t):
        if t < a:
            return t / a
        if t < a + d:
            return 1 - (1 - s) * (t - a) / d
        if t < dur - r:
            return s
        return max(0.0, s * (dur - t) / r)
    return f


def gain(x, g):
    return [v * g for v in x]


def drive(x, amount):
    return [math.tanh(v * amount) / math.tanh(amount) for v in x]


def normalize(x, peak=0.9):
    m = max(1e-9, max(abs(v) for v in x))
    return [v * peak / m for v in x]


def loopify(x, fade=0.08):
    """Crossfade the tail into the head so the sample loops without a click."""
    n = int(fade * SR)
    body = x[:len(x) - n]
    for i in range(n):
        t = i / n
        body[i] = body[i] * t + x[len(x) - n + i] * (1 - t)
    return body


def fade_out(x, sec=0.02):
    n = min(len(x), int(sec * SR))
    for i in range(n):
        x[len(x) - 1 - i] *= i / n
    return x


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def write(name, x, peak=0.9):
    x = normalize(x, peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))


# --- Vehicle ----------------------------------------------------------------

def engine_loop():
    dur = 1.0
    base = 42.0  # integer cycles per second -> loops cleanly
    saw = osc(base, dur, "saw")
    sub = osc(base / 2, dur, "sine")
    chug = [0.55 + 0.45 * max(0.0, math.sin(TAU * 21 * i / SR)) ** 3 for i in range(len(saw))]
    x = [(s * 0.7 + b * 0.6) * c for s, b, c in zip(saw, sub, chug)]
    x = lowpass(x, 420)
    rumble = lowpass(brown(dur, 3), 200)
    x = [a + b * 0.25 for a, b in zip(x, rumble)]
    return drive(x, 1.6)


def rocket_loop():
    roar = lowpass(brown(2.2, 7), 900)
    hiss = bandpass(noise(2.2, 8), 1500, 5000)
    rng = random.Random(9)
    crackle = silence(2.2)
    for _ in range(90):
        at = rng.uniform(0, 2.1)
        mix(crackle, env(noise(0.012, rng.randint(0, 999)), decay(0.003)), at, rng.uniform(0.3, 0.8))
    wobble = [0.8 + 0.2 * math.sin(TAU * 6 * i / SR) for i in range(len(roar))]
    x = [(r * 1.0 + h * 0.25 + c * 0.35) * w for r, h, c, w in zip(roar, hiss, crackle, wobble)]
    return loopify(drive(x, 1.4), 0.2)


def vroom():
    """Engine revving up hard, then settling: the bus arriving at the start line."""
    dur = 1.6
    def f(t):
        return 40 + 110 * min(1, t / 0.45) - 60 * max(0, (t - 0.6) / 1.0)
    saw = osc(f, dur, "saw")
    sub = osc(lambda t: f(t) / 2, dur, "square", 0.5)
    x = drive(lowpass([a * 0.7 + b * 0.4 for a, b in zip(saw, sub)], lambda t: 500 + 1400 * min(1, t / 0.5)), 2.2)
    x = env(x, adsr(0.05, 0.3, 0.7, 0.5, dur))
    rng = random.Random(3)
    for k in range(5):  # exhaust pops
        mix(x, env(lowpass(noise(0.04, rng.randint(0, 99)), 1500), decay(0.01)), 0.55 + k * 0.09, 0.5)
    return x


def rocket_ignite():
    dur = 0.6
    n = env(noise(dur, 11), adsr(0.01, 0.2, 0.5, 0.25, dur))
    n = lowpass(n, lambda t: 300 + 6000 * min(1, t / 0.15))
    thump = env(osc(lambda t: 90 - 50 * t, 0.3), decay(0.08))
    return mix(n, thump, 0, 0.9)


def rocket_sputter():
    x = silence(0.7)
    rng = random.Random(4)
    t = 0.0
    while t < 0.6:
        pop = lowpass(env(noise(0.05, rng.randint(0, 99)), decay(0.015)), 1200)
        mix(x, pop, t, rng.uniform(0.4, 1.0))
        t += rng.uniform(0.05, 0.14)
    return x


def land_soft():
    thump = env(osc(lambda t: 80 - 60 * t, 0.35), decay(0.07))
    body = env(lowpass(noise(0.2, 21), 400), decay(0.04))
    creak = env(osc(lambda t: 700 + 90 * math.sin(t * 60), 0.2, "saw"), decay(0.05))
    return mix(mix(thump, body, 0, 0.6), bandpass(creak, 500, 1400), 0.03, 0.12)


def land_hard():
    thump = env(osc(lambda t: 70 - 40 * t, 0.6), decay(0.14))
    crunch = env(lowpass(noise(0.35, 22), 1800), decay(0.06))
    clang = silence(0.9)
    for f, a in ((310, 1.0), (523, 0.7), (847, 0.5), (1290, 0.3)):
        mix(clang, env(osc(f, 0.9), decay(0.22)), 0.01, a * 0.25)
    boing = env(osc(lambda t: 180 + 60 * math.sin(t * 50) * math.exp(-t * 5), 0.5, "triangle"), decay(0.15))
    return mix(mix(mix(thump, crunch, 0, 0.7), clang, 0, 1), boing, 0.02, 0.25)


def spring_creak():
    s = osc(lambda t: 820 - 300 * t + 40 * math.sin(t * 90), 0.28, "saw")
    return env(bandpass(s, 600, 2200), adsr(0.02, 0.1, 0.5, 0.1, 0.28))


def _creak(seed, base, dur):
    rng = random.Random(seed)
    wob = rng.uniform(5, 11)
    s = osc(lambda t: base * (1 + 0.18 * math.sin(t * wob) + 0.06 * math.sin(t * 57)), dur, "saw")
    s = bandpass(s, base * 1.5, base * 7)
    grit = bandpass(noise(dur, seed), 800, 3000)
    x = [a + g * 0.15 for a, g in zip(s, grit)]
    return env(x, adsr(0.08, 0.1, 0.7, dur * 0.4, dur))


def creak_a():
    return _creak(301, 140, 0.7)


def creak_b():
    return _creak(302, 95, 0.9)


def creak_c():
    return _creak(303, 210, 0.5)


def rattle():
    x = silence(0.4)
    rng = random.Random(311)
    t = 0.0
    while t < 0.32:
        mix(x, env(osc(rng.uniform(700, 1600), 0.05), decay(0.012)), t, rng.uniform(0.3, 0.8))
        t += rng.uniform(0.025, 0.06)
    return x


def clank():
    x = silence(0.3)
    for f, a in ((620, 1.0), (1017, 0.6), (1583, 0.4)):
        mix(x, env(osc(f, 0.3), decay(0.06)), 0, a)
    return mix(x, env(highpass(noise(0.05, 5), 2000), decay(0.01)), 0, 0.5)


def glass():
    x = silence(0.9)
    rng = random.Random(33)
    for _ in range(26):
        at = rng.uniform(0, 0.5)
        f = rng.uniform(2800, 6500)
        mix(x, env(osc(f, 0.25), decay(rng.uniform(0.02, 0.08))), at, rng.uniform(0.2, 0.6))
    return mix(x, env(highpass(noise(0.3, 34), 3000), decay(0.06)), 0, 0.6)


def crash():
    dur = 1.8
    boom = env(osc(lambda t: 60 - 30 * t, 1.2), decay(0.3))
    impact = env(lowpass(noise(dur, 41), lambda t: 4000 * math.exp(-t * 3) + 200), decay(0.35))
    x = mix(silence(dur), boom, 0, 1.0)
    mix(x, impact, 0, 0.9)
    rng = random.Random(42)
    for _ in range(7):
        c = clank()
        mix(x, c, rng.uniform(0.05, 1.1), rng.uniform(0.2, 0.5))
    mix(x, glass(), 0.05, 0.6)
    return drive(x, 1.5)


def splash():
    dur = 1.3
    body = env(noise(dur, 51), decay(0.25, 0.01))
    body = lowpass(body, lambda t: 3500 * math.exp(-t * 2.5) + 300)
    x = mix(silence(dur), body)
    mix(x, env(osc(lambda t: 90 - 40 * t, 0.4), decay(0.1)), 0, 0.6)
    return mix(x, bubbles(0.9, 52), 0.3, 0.6)


def bubbles(dur=1.4, seed=61):
    x = silence(dur)
    rng = random.Random(seed)
    for _ in range(int(dur * 14)):
        f0 = rng.uniform(300, 900)
        b = env(osc(lambda t, f0=f0: f0 + 2500 * t, 0.06), decay(0.02))
        mix(x, b, rng.uniform(0, dur - 0.07), rng.uniform(0.2, 0.7))
    return x


def lava_sizzle():
    dur = 1.6
    hiss = env(highpass(noise(dur, 71), 2500), adsr(0.02, 0.3, 0.6, 0.8, dur))
    x = mix(silence(dur), hiss, 0, 0.7)
    rng = random.Random(72)
    for _ in range(40):
        mix(x, env(noise(0.01, rng.randint(0, 999)), decay(0.003)), rng.uniform(0, 1.5), rng.uniform(0.3, 1))
    burble = env(lowpass(brown(dur, 73), 180), adsr(0.05, 0.2, 0.8, 0.6, dur))
    return mix(x, burble, 0, 0.8)


def fall_whistle():
    dur = 1.6
    return env(osc(lambda t: 1500 - 1100 * (t / dur), dur), adsr(0.05, 0.1, 0.8, 0.2, dur))


def horn():
    dur = 0.7
    a = osc(311.1, dur, "square", 0.4)
    b = osc(370.0, dur, "square", 0.4)
    x = [(p + q) * 0.5 for p, q in zip(a, b)]
    return env(lowpass(x, 1400), adsr(0.02, 0.05, 0.9, 0.08, dur))


def skid():
    dur = 0.5
    s = bandpass(noise(dur, 81), 1800, 3500)
    tone_ = osc(lambda t: 2200 + 150 * math.sin(t * 40), dur, "triangle")
    return env([a + b * 0.15 for a, b in zip(s, tone_)], adsr(0.02, 0.1, 0.7, 0.2, dur))


def wind_loop():
    dur = 3.0
    n = noise(dur + 0.3, 91)
    x = bandpass(n, 300, lambda t: 900 + 500 * math.sin(TAU * t / (dur + 0.3)))
    return loopify(env(x, lambda t: 0.7 + 0.3 * math.sin(TAU * 2 * t / dur)), 0.3)


def fuel_pickup():
    glug = mix(silence(0.5), bubbles(0.25, 101), 0, 0.5)
    for i, n in enumerate((72, 76, 79, 84)):
        mix(glug, env(osc(midi(n), 0.2, "square", 0.25), decay(0.06)), 0.1 + i * 0.05, 0.5)
    return glug


def fuel_low():
    x = silence(0.35)
    for i in range(2):
        mix(x, env(osc(988, 0.1, "square", 0.5), adsr(0.005, 0.02, 0.8, 0.02, 0.1)), i * 0.16, 0.5)
    return x


# --- Voices (passengers) ----------------------------------------------------

def voice(contour, dur, vowel=(700, 1200), seed=1):
    """Tiny formant-ish cartoon voice: square source through two bandpasses."""
    rng = random.Random(seed)
    src = osc(lambda t: contour(t) * (1 + 0.03 * math.sin(t * 40 + rng.random())), dur, "square", 0.3)
    f1 = bandpass(src, vowel[0] * 0.7, vowel[0] * 1.3)
    f2 = bandpass(src, vowel[1] * 0.8, vowel[1] * 1.2)
    x = [a + b * 0.6 for a, b in zip(f1, f2)]
    return env(x, adsr(0.02, 0.05, 0.8, 0.08, dur))


def voice_blip():
    return voice(lambda t: 260, 0.08, (800, 1400), 1)


def voice_happy():
    return voice(lambda t: 240 + 260 * min(1, t / 0.25), 0.4, (750, 1300), 2)


def voice_hurt():
    return voice(lambda t: 420 - 250 * min(1, t / 0.3), 0.35, (500, 900), 3)


def voice_scream():
    return voice(lambda t: 560 + 60 * math.sin(t * 38), 0.9, (850, 1250), 4)


def voice_glub():
    x = voice(lambda t: 200 - 60 * t, 0.3, (400, 800), 5)
    return mix(x, bubbles(0.3, 6), 0, 0.5)


def voice_driver():
    """Gruff, low driver grumble."""
    x = voice(lambda t: 150 - 30 * t + 8 * math.sin(t * 25), 0.35, (480, 900), 21)
    return drive(x, 1.8)


def voice_driver_shout():
    """Driver bellowing HOLD ON!"""
    x = voice(lambda t: 180 + 60 * min(1, t / 0.15) - 40 * max(0, t - 0.3), 0.6, (600, 1100), 22)
    return drive(x, 2.2)


def squelch():
    """Wet tearing: filtered noise with a falling pitch."""
    dur = 0.45
    n = lowpass(noise(dur, 401), lambda t: 2500 * math.exp(-t * 6) + 300)
    tone_ = osc(lambda t: 320 * math.exp(-t * 5) + 60, dur, "triangle")
    x = [a * 0.9 + b * 0.35 for a, b in zip(n, tone_)]
    x = env(x, lambda t: min(1, t / 0.01) * math.exp(-t * 7) * (0.6 + 0.4 * math.sin(t * 90)))
    return mix(x, bubbles(0.3, 402), 0.05, 0.25)


def splat():
    """Short wet thud."""
    dur = 0.25
    n = lowpass(noise(dur, 411), lambda t: 1600 * math.exp(-t * 14) + 200)
    body = env(osc(lambda t: 110 - 60 * t, dur), decay(0.05))
    return env([a + b * 0.8 for a, b in zip(n, body)], decay(0.07))


def cannon():
    boom = env(osc(lambda t: 110 * math.exp(-t * 9) + 45, 0.5), decay(0.12))
    crack = env(highpass(noise(0.12, 501), 1500), decay(0.02))
    body = env(lowpass(noise(0.4, 502), lambda t: 3000 * math.exp(-t * 10) + 200), decay(0.08))
    x = mix(mix(silence(0.6), boom), crack, 0, 0.8)
    mix(x, body, 0, 0.7)
    mix(x, clank(), 0.12, 0.25)  # breech clack
    return drive(x, 1.8)


def explosion():
    dur = 1.6
    boom = env(osc(lambda t: 70 * math.exp(-t * 3) + 30, dur), decay(0.4))
    roar = env(lowpass(noise(dur, 511), lambda t: 5000 * math.exp(-t * 3) + 120), decay(0.45))
    x = mix(silence(dur), boom, 0, 1.0)
    mix(x, roar, 0, 0.9)
    rng = random.Random(512)
    for _ in range(30):
        mix(x, env(noise(0.02, rng.randint(0, 999)), decay(0.006)), rng.uniform(0.05, 1.0), rng.uniform(0.1, 0.4))
    return drive(x, 1.6)


def wood_break():
    x = silence(0.6)
    rng = random.Random(521)
    for _ in range(9):
        crack = env(bandpass(noise(0.08, rng.randint(0, 999)), 600, 3500), decay(rng.uniform(0.01, 0.03)))
        mix(x, crack, rng.uniform(0, 0.25), rng.uniform(0.4, 1.0))
    mix(x, env(osc(lambda t: 180 - 80 * t, 0.3, "triangle"), decay(0.06)), 0, 0.5)
    return x


def rock_break():
    x = silence(0.8)
    x = mix(x, env(lowpass(noise(0.6, 531), lambda t: 2000 * math.exp(-t * 5) + 150), decay(0.15)), 0, 1.0)
    rng = random.Random(532)
    for _ in range(12):
        mix(x, env(lowpass(noise(0.03, rng.randint(0, 999)), 1500), decay(0.01)), rng.uniform(0.05, 0.6), rng.uniform(0.2, 0.6))
    return mix(x, env(osc(lambda t: 60 - 20 * t, 0.5), decay(0.12)), 0, 0.8)


def plastic_bonk():
    return env(osc(lambda t: 520 * math.exp(-t * 8) + 220, 0.2, "triangle"), decay(0.05))


def ammo_pickup():
    x = silence(0.4)
    for i, n in enumerate((60, 67, 72)):
        mix(x, env(osc(midi(n), 0.1, "square", 0.5), decay(0.03)), i * 0.07, 0.5)
    return mix(x, clank(), 0.0, 0.3)


def rain_loop():
    dur = 3.3
    hiss = bandpass(noise(dur + 0.3, 601), 1200, 7000)
    x = mix(silence(dur + 0.3), hiss, 0, 0.5)
    rng = random.Random(602)
    for _ in range(260):  # individual drops
        mix(x, env(highpass(noise(0.01, rng.randint(0, 9999)), 2500), decay(0.003)), rng.uniform(0, dur), rng.uniform(0.1, 0.5))
    return loopify(x, 0.3)


def thunder():
    dur = 2.8
    crack = env(highpass(noise(0.3, 611), 800), decay(0.06))
    rumble = env(lowpass(brown(dur, 612), lambda t: 400 * math.exp(-t * 0.8) + 60), lambda t: min(1, t / 0.15) * math.exp(-t * 1.1))
    x = mix(silence(dur), crack, 0, 0.6)
    return mix(x, rumble, 0.05, 1.0)


def sandstorm_loop():
    dur = 3.3
    w = bandpass(noise(dur + 0.3, 621), 500, lambda t: 2500 + 1200 * math.sin(TAU * t / dur))
    grit = highpass(noise(dur + 0.3, 622), 4000)
    return loopify([a + b * 0.25 for a, b in zip(w, grit)], 0.3)


def blizzard_loop():
    dur = 3.3
    w = bandpass(noise(dur + 0.3, 631), 300, lambda t: 1600 + 900 * math.sin(TAU * t / dur))
    howl = osc(lambda t: 520 + 90 * math.sin(TAU * t / dur), dur + 0.3)
    return loopify([a + b * 0.05 for a, b in zip(w, howl)], 0.3)


def mud_splash():
    x = env(lowpass(noise(0.4, 641), lambda t: 1800 * math.exp(-t * 7) + 200), decay(0.1))
    return mix(x, bubbles(0.3, 642), 0.05, 0.3)


def monkey_screech():
    x = silence(0.7)
    for i in range(3):
        mix(x, env(osc(lambda t: 900 + 700 * math.sin(t * 30), 0.16, "saw"), adsr(0.01, 0.03, 0.7, 0.05, 0.16)), i * 0.2, 0.4)
    return bandpass(x, 500, 4000)


def goat_bleat():
    return voice(lambda t: 330 * (1 + 0.08 * math.sin(t * 60)), 0.55, (700, 1500), 651)


def penguin_squawk():
    return voice(lambda t: 420 - 150 * t, 0.3, (600, 1100), 661)


def snake_hiss():
    return env(highpass(noise(0.7, 671), 3500), adsr(0.05, 0.1, 0.7, 0.3, 0.7))


def bat_squeak():
    x = silence(0.3)
    for i in range(3):
        mix(x, env(osc(lambda t: 5200 - 2000 * t * 10, 0.04), decay(0.012)), i * 0.07, 0.5)
    return x


def vulture_caw():
    return drive(voice(lambda t: 260 - 60 * t, 0.5, (450, 850), 681), 2.0)


def amb_moon_loop():
    dur = 4.3
    hum = osc(55, dur + 0.3, "sine")
    hum2 = osc(82.5, dur + 0.3, "sine")
    air = lowpass(noise(dur + 0.3, 691), 300)
    return loopify([a * 0.5 + b * 0.3 + c * 0.2 for a, b, c in zip(hum, hum2, air)], 0.3)


def cheer():
    x = silence(1.3)
    rng = random.Random(7)
    base = voice_happy()
    for _ in range(8):
        v = voice(lambda t, p=rng.uniform(0.8, 1.5): (240 + 260 * min(1, t / 0.25)) * p, 0.5,
                  (rng.uniform(600, 900), rng.uniform(1100, 1500)), rng.randint(0, 99))
        mix(x, v, rng.uniform(0, 0.6), rng.uniform(0.4, 0.8))
    return mix(x, base, 0, 0.3)


def groan():
    x = silence(1.0)
    rng = random.Random(8)
    for _ in range(6):
        v = voice(lambda t, p=rng.uniform(0.7, 1.3): (330 - 150 * min(1, t / 0.5)) * p, 0.6,
                  (rng.uniform(450, 650), rng.uniform(800, 1000)), rng.randint(0, 99))
        mix(x, v, rng.uniform(0, 0.3), rng.uniform(0.5, 0.8))
    return x


# --- Wildlife ---------------------------------------------------------------

def bird_flap():
    dur = 0.45
    n = bandpass(noise(dur, 111), 400, 2400)
    return env(n, lambda t: max(0.0, math.sin(TAU * 16 * t)) ** 2 * math.exp(-t * 4))


def bird_chirp():
    x = silence(0.35)
    for i in range(3):
        mix(x, env(osc(lambda t: 3200 + 2400 * math.sin(t * 60), 0.06), decay(0.02)), i * 0.09, 0.6)
    return x


def lizard_scurry():
    x = silence(0.35)
    rng = random.Random(121)
    t = 0.0
    while t < 0.3:
        mix(x, env(highpass(noise(0.01, rng.randint(0, 99)), 3000), decay(0.003)), t, 0.6)
        t += rng.uniform(0.02, 0.04)
    return x


def bug_buzz_loop():
    dur = 1.0
    s = osc(lambda t: 220 + 12 * math.sin(TAU * 3 * t), dur, "saw")
    am = [0.5 + 0.5 * math.sin(TAU * 40 * i / SR) for i in range(len(s))]
    return loopify(bandpass([a * b for a, b in zip(s, am)], 300, 2000), 0.1)


def rustle():
    return env(bandpass(noise(0.5, 131), 1500, 6000), adsr(0.05, 0.1, 0.5, 0.3, 0.5))


# --- Ambience (4s loops) ----------------------------------------------------

def amb_desert_loop():
    x = gain(wind_loop(), 0.8)
    return x


def amb_jungle_loop():
    dur = 4.3
    x = silence(dur)
    cic = osc(4200, dur, "square", 0.5)
    am = [0.5 + 0.5 * math.sin(TAU * 0.5 * i / SR) ** 8 for i in range(len(cic))]
    mix(x, bandpass([a * b for a, b in zip(cic, am)], 3000, 6000), 0, 0.15)
    rng = random.Random(141)
    for _ in range(6):
        mix(x, bird_chirp(), rng.uniform(0, dur - 0.4), rng.uniform(0.15, 0.35))
    for _ in range(3):
        call = env(osc(lambda t, f=rng.uniform(600, 900): f * (1 + 0.4 * math.sin(t * 20)), 0.3), decay(0.1))
        mix(x, call, rng.uniform(0, dur - 0.4), 0.2)
    mix(x, lowpass(noise(dur, 142), 500), 0, 0.1)
    return loopify(x, 0.3)


def amb_mountain_loop():
    dur = 4.3
    w = bandpass(noise(dur, 151), 200, lambda t: 700 + 400 * math.sin(TAU * t / dur))
    return loopify(env(w, lambda t: 0.6 + 0.4 * math.sin(TAU * t / dur) ** 2), 0.3)


def amb_snow_loop():
    dur = 4.3
    w = bandpass(noise(dur, 161), 600, lambda t: 1800 + 900 * math.sin(TAU * t / dur))
    whistle = osc(lambda t: 900 + 120 * math.sin(TAU * t / dur), dur)
    return loopify([a + b * 0.03 for a, b in zip(w, whistle)], 0.3)


def amb_volcano_loop():
    dur = 4.3
    rumble = lowpass(brown(dur, 171), 120)
    x = mix(silence(dur), rumble, 0, 1.0)
    rng = random.Random(172)
    for _ in range(50):
        mix(x, env(noise(0.01, rng.randint(0, 999)), decay(0.004)), rng.uniform(0, dur - 0.1), rng.uniform(0.05, 0.25))
    return loopify(x, 0.3)


def amb_city_loop():
    dur = 4.3
    hum = lowpass(brown(dur, 181), 300)
    x = mix(silence(dur), hum, 0, 0.8)
    mix(x, env(osc(lambda t: 500 + 80 * t, 1.2, "square", 0.4), adsr(0.2, 0.2, 0.4, 0.6, 1.2)), 1.5, 0.03)
    return loopify(x, 0.3)


# --- UI / feedback jingles --------------------------------------------------

def notes(seq, step, wave_="square", duty=0.25, tail=0.3, decay_=0.12):
    x = silence(len(seq) * step + tail)
    for i, n in enumerate(seq):
        if n is None:
            continue
        mix(x, env(osc(midi(n), step + tail, wave_, duty), decay(decay_)), i * step, 0.5)
    return x


def jingle_perfect():
    x = notes([72, 76, 79, 84, 88], 0.07, tail=0.5, decay_=0.2)
    return mix(x, notes([96, 100, 103], 0.04, "sine", tail=0.4), 0.35, 0.4)


def jingle_good():
    return notes([72, 79], 0.09, tail=0.3)


def sting_hard():
    return notes([67, 61], 0.12, "saw", tail=0.25)


def sting_crash():
    x = silence(1.6)
    for i, n in enumerate((55, 54, 53)):
        mix(x, env(osc(lambda t, f=midi(n): f * (1 + 0.02 * math.sin(t * 30)), 0.35, "saw"), adsr(0.02, 0.1, 0.7, 0.1, 0.35)), i * 0.35, 0.5)
    last = env(osc(lambda t: midi(52) * (1 + 0.04 * math.sin(t * 25)), 0.8, "saw"), adsr(0.02, 0.1, 0.7, 0.4, 0.8))
    return lowpass(mix(x, last, 1.05, 0.5), 2200)


def ui_move():
    return env(osc(1320, 0.05, "square", 0.5), decay(0.015))


def ui_select():
    return notes([79, 86], 0.05, tail=0.12, decay_=0.06)


def ui_back():
    return notes([74, 67], 0.05, tail=0.1, decay_=0.05)


def ui_start():
    x = notes([60, 64, 67, 72, 76, 79, 84], 0.045, tail=0.5, decay_=0.25)
    return mix(x, rocket_ignite(), 0.1, 0.5)


def count_beep():
    return env(osc(660, 0.18, "square", 0.5), adsr(0.005, 0.03, 0.7, 0.05, 0.18))


def count_go():
    x = silence(0.6)
    for n in (72, 76, 79, 84):
        mix(x, env(osc(midi(n), 0.6, "square", 0.3), adsr(0.005, 0.1, 0.6, 0.3, 0.6)), 0, 0.3)
    return x


def gap_cleared():
    whoosh = env(bandpass(noise(0.4, 191), lambda t: 400 + 3000 * t, 6000), adsr(0.05, 0.1, 0.5, 0.2, 0.4))
    return mix(whoosh, notes([84, 91], 0.06, "sine", tail=0.3), 0.1, 0.8)


def star():
    x = notes([88, 95], 0.05, "sine", tail=0.5, decay_=0.25)
    return mix(x, notes([100], 0.05, "square", 0.125, tail=0.2), 0.08, 0.3)


def score_tick():
    return env(osc(1760, 0.03, "square", 0.5), decay(0.01))


def level_clear():
    seq = [72, 72, 72, 76, None, 79, None, 84, 84, 84]
    x = notes(seq, 0.1, tail=0.8, decay_=0.3)
    bass = notes([48, None, None, 52, None, 55, None, 60], 0.12, "triangle", 0.5, 0.8, 0.4)
    return mix(x, bass, 0, 0.8)


def fail_jingle():
    return notes([67, 66, 65, 64, None, 55], 0.14, "triangle", tail=0.6, decay_=0.3)


def title_slam():
    boom = env(osc(lambda t: 70 - 40 * t, 1.0), decay(0.35))
    hit = env(lowpass(noise(1.2, 201), lambda t: 5000 * math.exp(-t * 4) + 150), decay(0.3))
    x = mix(silence(1.4), boom, 0, 1.0)
    mix(x, hit, 0, 0.7)
    return mix(x, notes([40, 47, 52], 0.0, "saw", tail=1.2, decay_=0.5), 0, 0.3)


def typewriter():
    return env(highpass(noise(0.03, 211), 1500), decay(0.006))


# --- Music ------------------------------------------------------------------

class Song:
    def __init__(self, bpm, bars):
        self.beat = 60.0 / bpm
        self.buf = silence(bars * 4 * self.beat + 0.01)
        self.len_beats = bars * 4

    def t(self, beat):
        return beat * self.beat

    def note(self, beat, dur_beats, n, inst, vol=0.3):
        dur = dur_beats * self.beat
        f = midi(n)
        if inst == "lead":
            x = osc(lambda t: f * (1 + 0.012 * math.sin(t * 34) * min(1, t * 6)), dur, "square", 0.25)
            x = env(x, adsr(0.005, 0.08, 0.6, 0.04, dur))
        elif inst == "twang":
            x = osc(lambda t: f * (1 + 0.02 * math.sin(t * 30) * min(1, t * 4)), dur, "saw")
            x = env(lowpass(x, 2500), decay(max(0.08, dur * 0.6)))
        elif inst == "bass":
            a = osc(f, dur, "triangle")
            b = osc(f, dur, "square", 0.5)
            x = env([p + q * 0.3 for p, q in zip(a, b)], adsr(0.005, 0.05, 0.8, 0.03, dur))
        elif inst == "pluck":
            a = osc(f, dur + 0.3, "sine")
            b = osc(f * 4, dur + 0.3, "sine")
            x = env([p + q * 0.2 for p, q in zip(a, b)], decay(0.18))
        elif inst == "bell":
            a = osc(f, dur + 0.6, "sine")
            b = osc(f * 2.76, dur + 0.6, "sine")
            x = env([p + q * 0.35 for p, q in zip(a, b)], decay(0.45))
        elif inst == "pad":
            x = env(lowpass(osc(f, dur, "saw"), 1200), adsr(0.2, 0.2, 0.7, 0.2, dur))
        elif inst == "power":
            a = osc(f, dur, "square", 0.5)
            b = osc(f * 1.5, dur, "square", 0.5)
            x = drive(lowpass([p + q for p, q in zip(a, b)], 1800), 2.5)
            x = env(x, adsr(0.005, 0.05, 0.7, 0.03, dur))
        else:
            raise ValueError(inst)
        mix(self.buf, fade_out(x), self.t(beat), vol)

    def drum(self, beat, kind, vol=0.35):
        if kind == "k":
            x = env(osc(lambda t: 140 * math.exp(-t * 25) + 45, 0.25), decay(0.09))
        elif kind == "s":
            x = mix(env(bandpass(noise(0.2, int(beat * 7)), 800, 6000), decay(0.05)),
                    env(osc(190, 0.1, "triangle"), decay(0.03)), 0, 0.6)
        elif kind == "h":
            x = env(highpass(noise(0.05, int(beat * 13)), 6000), decay(0.012))
        elif kind == "o":
            x = env(highpass(noise(0.2, int(beat * 17)), 5000), decay(0.06))
        elif kind == "t":
            x = env(osc(lambda t: 160 * math.exp(-t * 8) + 80, 0.3), decay(0.1))
        elif kind == "b":  # bongo
            x = env(osc(lambda t: 420 * math.exp(-t * 12) + 260, 0.15), decay(0.04))
        elif kind == "c":  # conga low
            x = env(osc(lambda t: 260 * math.exp(-t * 10) + 170, 0.2), decay(0.06))
        elif kind == "m":  # shaker
            x = env(highpass(noise(0.08, int(beat * 19)), 5000), adsr(0.02, 0.02, 0.5, 0.03, 0.08))
        else:
            raise ValueError(kind)
        mix(self.buf, x, self.t(beat), vol)

    def pattern(self, bar, pat, vol=0.35):
        """pat: dict kind -> 16-char string of x/. per 16th note."""
        for kind, steps in pat.items():
            for i, c in enumerate(steps):
                if c in "xX":
                    self.drum(bar * 4 + i / 4, kind, vol * (1.2 if c == "X" else 1.0))


SCALES = {
    "minor": [0, 2, 3, 5, 7, 8, 10], "major": [0, 2, 4, 5, 7, 9, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "penta": [0, 3, 5, 7, 10],
}


def degree_note(root, scale, deg):
    s = SCALES[scale]
    return root + s[deg % len(s)] + 12 * (deg // len(s))


def melody(rng, root, scale, prog, bars, rhythm_choices, lo=0, hi=9):
    """A-A'-B-A phrase structure over 2-bar cells, chord tones on strong beats."""
    def cell(seed, chords):
        r = random.Random(seed)
        out, deg = [], r.randint(2, 5)
        for bar in range(2):
            ch = chords[bar]
            rhythm = r.choice(rhythm_choices)
            pos = 0.0
            for d in rhythm:
                if pos % 1 == 0:
                    deg = ch + r.choice([0, 2, 4])  # chord tone
                else:
                    deg += r.choice([-1, 1, 1, -2, 2])
                deg = max(lo, min(hi, deg))
                if r.random() > 0.12:
                    out.append((bar * 4 + pos, d * 0.9, deg))
                pos += d
        return out

    phrases = []
    a_seed, b_seed = rng.randint(0, 9999), rng.randint(0, 9999)
    order = [a_seed, a_seed + 1, b_seed, a_seed]
    for p in range(bars // 2):
        chords = [prog[(p * 2) % len(prog)], prog[(p * 2 + 1) % len(prog)]]
        for beat, dur, deg in cell(order[p % 4], chords):
            phrases.append((p * 8 + beat, dur, degree_note(root, scale, deg)))
    return phrases


ROCK = {"k": "x.......x.x.....", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.x."}
ROCK_FILL = {"k": "x.......x.......", "s": "....x...x.xxXxXX", "h": "x.x.x.x........."}


def song(name, bpm, root, scale, prog, style, seed, bars=16):
    rng = random.Random(seed)
    s = Song(bpm, bars)
    r8 = [[1, 0.5, 0.5, 1, 1], [0.5, 0.5, 1, 0.5, 0.5, 1], [1.5, 0.5, 1, 1], [0.5] * 8, [2, 1, 1]]
    lead_inst = {"punk": "lead", "surf": "twang", "jungle": "pluck", "anthem": "lead",
                 "snow": "bell", "metal": "lead", "chill": "pluck"}[style]
    for beat, dur, n in melody(rng, root + 12, scale, prog, bars, r8):
        if style == "metal" and beat < 16:
            continue  # let the riff breathe first
        s.note(beat, dur, n, lead_inst, 0.22 if lead_inst in ("lead", "twang") else 0.3)
    for bar in range(bars):
        deg = prog[bar % len(prog)]
        chord_root = degree_note(root - 12, scale, deg)
        fill = bar % 4 == 3
        if style in ("punk", "metal"):
            for e in range(8):
                s.note(bar * 4 + e * 0.5, 0.45, chord_root, "power", 0.16)
                s.note(bar * 4 + e * 0.5, 0.45, chord_root - 12, "bass", 0.3)
            pat = dict(ROCK_FILL if fill else ROCK)
            if style == "metal":
                pat["k"] = "x.x.x.x.x.x.x.x."
            s.pattern(bar, pat)
        elif style == "surf":
            for e, off in enumerate([0, 7, 12, 7, 0, 7, 10, 7]):
                s.note(bar * 4 + e * 0.5, 0.45, chord_root + off, "bass", 0.3)
            s.pattern(bar, {"k": "x...x...x...x...", "s": "....x.......x..x",
                            "t": "............xx.x" if fill else "................", "h": "x.xxx.xxx.xxx.xx"})
        elif style == "jungle":
            for e, off in enumerate([0, 0, 7, 0, 10, 0, 7, 12]):
                if e % 2 == 0 or rng.random() < 0.5:
                    s.note(bar * 4 + e * 0.5, 0.4, chord_root + off, "bass", 0.28)
            s.pattern(bar, {"c": "x..x..x...x.....", "b": "..x...x.x..x.xx.", "m": "xxxxxxxxxxxxxxxx",
                            "k": "x.......x......."}, 0.3)
            for e in range(4):
                s.note(bar * 4 + e + 0.5, 0.4, degree_note(root, scale, deg + 2 * (e % 3)), "pluck", 0.12)
        elif style == "anthem":
            for e in range(8):
                s.note(bar * 4 + e * 0.5, 0.45, chord_root, "bass", 0.3)
            for e in range(8):
                s.note(bar * 4 + e * 0.5, 0.45, degree_note(root, scale, deg + [0, 2, 4, 7][e % 4]), "pluck", 0.1)
            s.pattern(bar, ROCK_FILL if fill else {"k": "x.....x.x.......", "s": "....x.......x...",
                                                     "h": "x.x.x.x.x.x.x.x."})
        elif style == "snow":
            s.note(bar * 4, 4, chord_root + 12, "pad", 0.1)
            s.note(bar * 4, 4, degree_note(root, scale, deg + 2), "pad", 0.07)
            s.note(bar * 4, 2, chord_root, "bass", 0.25)
            s.note(bar * 4 + 2.5, 1.5, chord_root + 7, "bass", 0.2)
            s.pattern(bar, {"k": "x.........x.....", "h": "..x...x...x...x.", "m": "....x.......x..."}, 0.25)
        elif style == "chill":
            s.note(bar * 4, 4, chord_root + 12, "pad", 0.1)
            for e in range(4):
                s.note(bar * 4 + e, 0.9, chord_root if e % 2 == 0 else chord_root + 7, "bass", 0.25)
            s.pattern(bar, {"k": "x.......x.......", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.x."}, 0.22)
    return s.buf


MUSIC = {
    "music_menu": (150, 52, "minor", [0, 5, 2, 6], "punk", 1),
    "music_desert": (138, 57, "minor", [0, 3, 4, 0], "surf", 2),
    "music_jungle": (116, 50, "dorian", [0, 3, 0, 3], "jungle", 3),
    "music_mountain": (128, 55, "major", [0, 4, 5, 3], "anthem", 4),
    "music_snow": (100, 53, "major", [5, 3, 0, 4], "snow", 5),
    "music_volcano": (160, 48, "phrygian", [0, 1, 0, 6], "metal", 6),
    "music_results": (118, 60, "major", [0, 5, 3, 4], "chill", 7),
    "music_moon": (96, 50, "dorian", [0, 5, 3, 6], "snow", 8),
}


SFX = [
    engine_loop, vroom, rocket_loop, rocket_ignite, rocket_sputter, land_soft, land_hard, spring_creak,
    clank, creak_a, creak_b, creak_c, rattle, glass, crash, splash, bubbles, lava_sizzle, fall_whistle, horn, skid, wind_loop,
    fuel_pickup, fuel_low, voice_blip, voice_driver, voice_driver_shout, voice_happy, voice_hurt, voice_scream, voice_glub, squelch, splat, cheer,
    groan, bird_flap, bird_chirp, lizard_scurry, bug_buzz_loop, rustle, amb_desert_loop,
    amb_jungle_loop, amb_mountain_loop, amb_snow_loop, amb_volcano_loop, amb_city_loop,
    jingle_perfect, jingle_good, sting_hard, sting_crash, ui_move, ui_select, ui_back, ui_start,
    count_beep, count_go, gap_cleared, star, score_tick, level_clear, fail_jingle, title_slam,
    typewriter, rain_loop, thunder, sandstorm_loop, blizzard_loop, mud_splash, monkey_screech,
    goat_bleat, penguin_squawk, snake_hiss, bat_squeak, vulture_caw, amb_moon_loop, cannon, explosion, wood_break, rock_break, plastic_bonk, ammo_pickup,
]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[1:])
    for fn in SFX:
        if not only or fn.__name__ in only:
            write(fn.__name__, fn())
    for name, args in MUSIC.items():
        if not only or name in only:
            print("composing", name)
            write(name, loopify(song(name, *args), 0.05), 0.85)
    print("audio written to", os.path.normpath(OUT))
