#!/usr/bin/env python3
"""Cube Desk sound effects (stdlib only). Run: python3 tools/make_audio.py"""
import math, random, struct, wave, os
RATE = 22050
random.seed(5)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")

def render(name, dur, fn, vol=0.5):
    frames = bytearray()
    for i in range(int(RATE * dur)):
        t = i / RATE
        frames += struct.pack("<h", int(max(-1, min(1, fn(t) * vol)) * 32767))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(bytes(frames))

def sq(f, t): return 1.0 if math.sin(2 * math.pi * f * t) >= 0 else -1.0
def tri(f, t): p = (f * t) % 1.0; return 4 * abs(p - 0.5) - 1

# Turn: a plastic click-clack.
render("turn", 0.07, lambda t: ((random.random() * 2 - 1) * 0.7 + tri(1800, t) * 0.3) * math.exp(-t * 70), 0.6)
# Tap: UI click.
render("tap", 0.04, lambda t: sq(988, t) * math.exp(-t * 90), 0.25)
# Star: bright ding.
render("star", 0.4, lambda t: (tri(1568, t) + 0.5 * tri(2349, t)) * math.exp(-t * 7), 0.4)
# Solved: rising arpeggio and a held chord.
def solved(t):
    seq = [523, 659, 784, 1047]
    k = min(int(t / 0.09), 3)
    if t < 0.36:
        return sq(seq[k], t) * math.exp(-(t - k * 0.09) * 14) * 0.6
    tt = t - 0.36
    return (tri(523, t) + tri(659, t) + tri(784, t) + tri(1047, t)) * 0.3 * math.exp(-tt * 2.5)
render("solved", 1.3, solved, 0.45)
# Start: the competition timer beep.
render("beep", 0.18, lambda t: sq(1760, t) * (1 if t < 0.15 else 0), 0.2)
print("sounds written")
