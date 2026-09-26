#!/usr/bin/env python3
"""Generates the Rocket Bus pixel art into assets/sprites.

Run from the project root:  python3 tools/gen_art.py

Every breakable bus piece is drawn on the same 80x53 canvas so the pieces
line up when stacked, and can be spawned as debris using the same transform.
Body coordinates: x 0..79 cabin (rear -> front), x 80..99 hood, y 0..45 (roof -> skirt).
The canvas has OY rows of headroom above the roof for the roof sign.
"""
import math
import os
import random
import struct
import zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "sprites")

W, H, OY = 100, 53, 7  # body is 80 wide + a 20px school-bus hood

CLEAR = (0, 0, 0, 0)
STORE = {}  # name -> Canvas, filled by Canvas.save
RUST = [(138, 74, 42), (168, 96, 46), (106, 58, 36), (190, 120, 60)]

# --- Palette (Crazy-Taxi-ish: loud yellow, checker, hot pink, teal) ---
YEL = (255, 204, 38)
YEL_D = (214, 138, 18)
YEL_L = (255, 240, 130)
CHK_B = (24, 22, 30)
CHK_W = (246, 244, 236)
PINK = (240, 48, 140)
PINK_D = (160, 24, 96)
TEAL = (40, 214, 200)
TEAL_D = (20, 140, 150)
GLASS = (40, 110, 130, 96)
GLARE = (200, 250, 255, 170)
SKIRT = (58, 52, 70)
SKIRT_D = (36, 32, 46)
STEEL = (110, 116, 134)
STEEL_D = (60, 62, 76)
STEEL_L = (170, 176, 192)
INTERIOR = (104, 80, 52)
INTERIOR_D = (70, 52, 34)
SEAT = (220, 60, 90)
SEAT_L = (250, 110, 130)
LAMP = (255, 246, 200)
HEADLIGHT = (255, 250, 200)
TAIL = (255, 50, 40)
AMBER = (255, 150, 30)
TIRE = (26, 24, 30)
TIRE_L = (62, 60, 70)
HUB = (220, 222, 230)
HUB_D = (130, 132, 146)
BOLT = (70, 70, 84)
BLACK = (14, 12, 18)
ARCH = (30, 20, 16)

LOWER_WINDOWS = [(4, 13), (16, 27), (30, 41), (54, 61)]
LOWER_WIN_Y = (27, 33)
UPPER_WINDOWS = [(4, 15), (18, 29), (32, 43), (46, 57), (60, 71)]
WHEEL_CX = (18, 74)
ARCH_R = 10.5
FENDER = (30, 28, 38)
FENDER_L = (84, 80, 96)
CHROME = (200, 206, 220)
GRILLE = (40, 40, 50)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[CLEAR] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c if len(c) == 4 else (*c, 255)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def save(self, name):
        STORE[name] = self
        raw = b"".join(
            b"\x00" + b"".join(struct.pack("BBBB", *p) for p in row) for row in self.px
        )

        def chunk(tag, data):
            return (
                struct.pack(">I", len(data))
                + tag
                + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
            )

        png = (
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b"")
        )
        with open(os.path.join(OUT, name), "wb") as f:
            f.write(png)


class Body(Canvas):
    """Canvas addressed in body coordinates (y shifted down by OY)."""

    def __init__(self):
        super().__init__(W, H)

    def set(self, x, y, c):
        super().set(x, y + OY, c)


def cut_arches(c, rim):
    for cx in WHEEL_CX:
        for y in range(30, 46):
            for x in range(cx - 14, cx + 15):
                d = math.hypot(x - cx + 0.5, y - 45.5)
                if d <= ARCH_R:
                    c.set(x, y, CLEAR)
                elif d <= ARCH_R + 1.2 and rim:
                    c.set(x, y, rim)


def add_rust(c, seed, spots=40):
    """Rust blotches low on the panels and streaks running down from corners."""
    rng = random.Random(seed)
    paint = {(*YEL, 255), (*YEL_D, 255), (*YEL_L, 255)}

    def rust_px(x, y, col):
        if 0 <= x < c.w and 0 <= y + OY < c.h and c.px[y + OY][x] in paint:
            c.set(x, y, col)

    for _ in range(spots):
        x = rng.randrange(0, c.w)
        y = rng.choice([rng.randrange(36, 44), rng.randrange(0, 46)])
        for _ in range(rng.randint(2, 7)):
            rust_px(x + rng.randint(-2, 2), y + rng.randint(-1, 1), rng.choice(RUST))
    for _ in range(spots // 3):  # drip streaks
        x, y = rng.randrange(0, c.w), rng.randrange(5, 38)
        for k in range(rng.randint(2, 6)):
            rust_px(x, y + k, RUST[0] if k < 2 else RUST[2])


def window(c, x0, y0, x1, y1, sill):
    c.rect(x0 - 1, y0 - 1, x1 + 1, y0 - 1, sill)
    c.rect(x0 - 1, y1 + 1, x1 + 1, y1 + 1, sill)
    c.rect(x0, y0, x1, y1, GLASS)
    for gx, gy in ((1, 1), (2, 1), (1, 2), (4, 1)):
        if x0 + gx <= x1:
            c.set(x0 + gx, y0 + gy, GLARE)


# --- Pieces -----------------------------------------------------------------

def frame():
    """The skeleton: interior, pillars, floors, chassis rail. Seen through the
    windows, and fully exposed once the shell is ripped off."""
    c = Body()
    c.rect(1, 2, 78, 43, INTERIOR)
    c.rect(1, 2, 78, 3, INTERIOR_D)
    c.rect(1, 25, 78, 26, INTERIOR_D)
    for x in range(8, 76, 14):  # ceiling lamps
        c.set(x, 4, LAMP)
        c.set(x + 1, 4, LAMP)
        c.set(x, 27, LAMP)
        c.set(x + 1, 27, LAMP)
    for sx in (6, 20, 34, 48, 62):  # upper deck seat backs
        c.rect(sx, 11, sx + 1, 17, SEAT)
        c.set(sx, 11, SEAT_L)
    for sx in (6, 19, 33, 56):  # lower deck seat backs
        c.rect(sx, 30, sx + 1, 37, SEAT)
        c.set(sx, 30, SEAT_L)
    c.rect(2, 0, 77, 0, STEEL_D)  # roof rail
    c.rect(0, 1, 79, 1, STEEL_D)
    c.rect(0, 20, 79, 24, STEEL_D)  # upper floor beam
    c.rect(0, 20, 79, 20, STEEL)
    for px in (0, 16, 30, 44, 58, 72):  # pillars
        c.rect(px, 1, px + 1, 43, STEEL)
        c.rect(px + 1, 1, px + 1, 43, STEEL_D)
    c.rect(78, 1, 79, 43, STEEL)
    bays = (0, 16, 30, 44, 58, 72, 78)
    for a, b in zip(bays, bays[1:]):  # cross braces in the skirt
        span = b - a - 2
        for i in range(span):
            y = 41 - round(i * 4 / max(span - 1, 1))
            c.set(a + 2 + i, y, STEEL_D)
    c.rect(0, 40, 79, 43, STEEL_D)  # chassis rail
    c.rect(0, 40, 79, 40, STEEL)
    for x in range(3, 78, 6):
        c.set(x, 42, STEEL_L)
    c.rect(80, 40, 97, 43, STEEL_D)  # rail runs under the hood
    c.rect(80, 40, 97, 40, STEEL)
    c.rect(82, 30, 93, 39, (70, 72, 84))  # engine block
    for x in range(83, 93, 3):
        c.rect(x, 28, x + 1, 30, STEEL)  # cylinder heads
    c.rect(82, 35, 93, 35, (50, 50, 60))
    c.rect(94, 30, 96, 41, (120, 60, 50))  # radiator
    for y in range(31, 41, 2):
        c.set(95, y, (170, 90, 70))
    cut_arches(c, STEEL_D)
    c.save("bus_frame.png")


def roof():
    c = Body()
    c.rect(3, 0, 76, 0, YEL_L)
    c.rect(1, 1, 78, 1, YEL)
    c.rect(0, 2, 79, 2, YEL)
    c.rect(0, 3, 79, 3, YEL_D)
    c.set(1, 1, YEL_L)
    add_rust(c, 11, 18)
    c.save("bus_roof.png")


GLYPHS = {
    "R": ["110", "101", "110", "101", "101"],
    "O": ["010", "101", "101", "101", "010"],
    "C": ["011", "100", "100", "100", "011"],
    "K": ["101", "101", "110", "101", "101"],
    "E": ["111", "100", "110", "100", "111"],
    "T": ["111", "010", "010", "010", "010"],
}


def roof_sign():
    """Taxi-style lit sign on the roof. Flies off on a crash."""
    c = Body()
    c.rect(26, -7, 53, -1, PINK)
    c.rect(27, -6, 52, -2, BLACK)
    c.rect(26, -7, 53, -7, (255, 120, 190))
    for i, ch in enumerate("ROCKET"):
        for gy, row in enumerate(GLYPHS[ch]):
            for gx, bit in enumerate(row):
                if bit == "1":
                    c.set(28 + i * 4 + gx, -6 + gy, YEL)
    c.save("bus_sign.png")


def upper_panel():
    c = Body()
    c.rect(0, 4, 79, 21, YEL)
    c.rect(0, 4, 79, 4, YEL_L)
    c.rect(0, 21, 79, 21, YEL_D)
    c.rect(79, 5, 79, 20, YEL_D)
    for x0, x1 in UPPER_WINDOWS:
        window(c, x0, 7, x1, 16, YEL_D)
    window(c, 74, 7, 77, 16, YEL_D)
    c.rect(0, 18, 79, 19, PINK)  # pink pinstripe
    c.rect(0, 19, 79, 19, PINK_D)
    add_rust(c, 12, 80)
    c.save("bus_upper.png")


def lower_panel():
    c = Body()
    for x in range(80):  # taxi checker band
        top = (x // 2) % 2 == 0
        c.set(x, 22, CHK_B if top else CHK_W)
        c.set(x, 23, CHK_W if top else CHK_B)
    c.rect(0, 24, 79, 24, YEL_D)
    c.rect(0, 25, 79, 41, YEL)
    c.rect(0, 25, 79, 25, YEL_L)
    c.rect(0, 42, 79, 45, SKIRT)
    c.rect(0, 45, 79, 45, SKIRT_D)
    for x0, x1 in LOWER_WINDOWS:
        window(c, x0, LOWER_WIN_Y[0], x1, LOWER_WIN_Y[1], YEL_D)
    window(c, 66, 27, 77, 33, YEL_D)  # driver's side window
    # door
    c.rect(43, 26, 52, 41, YEL_D)
    c.rect(44, 27, 51, 41, GLASS)
    c.rect(47, 27, 48, 41, STEEL_D)
    c.set(45, 28, GLARE)
    c.set(50, 28, GLARE)
    c.rect(79, 25, 79, 41, YEL_D)  # cab front edge (the hood takes over from here)
    # teal speed stripe with a slanted nose
    for x in range(2, 60):
        c.set(x, 37, TEAL)
        c.set(x, 38, TEAL_D)
    for i in range(3):
        c.set(60 + i, 37 - i, TEAL)
        c.set(60 + i, 38 - i, TEAL_D)
    # lights + bumpers
    c.rect(0, 36, 1, 40, TAIL)
    c.set(0, 41, AMBER)
    c.rect(0, 42, 4, 45, STEEL)
    c.rect(0, 42, 4, 42, STEEL_L)
    cut_arches(c, ARCH)
    add_rust(c, 13, 110)
    c.save("bus_lower.png")


def hood():
    """School-bus nose: sloped hood, louvers, grille, headlight, black bumper."""
    c = Body()
    for x in range(80, 97):
        top = 26 + round((x - 80) * 5 / 16)  # hood slopes down toward the grille
        c.rect(x, top, x, 41, YEL)
        c.set(x, top, YEL_L)
    for x in range(84, 91, 2):  # louvers
        c.rect(x, 31, x, 35, YEL_D)
    c.rect(80, 38, 96, 38, BLACK)  # rub rail
    c.rect(97, 30, 98, 41, CHROME)  # grille
    for y in range(31, 41, 2):
        c.set(97, y, GRILLE)
    c.rect(94, 32, 96, 34, HEADLIGHT)
    c.set(94, 32, CHROME)
    c.set(96, 36, AMBER)
    c.rect(78, 42, 99, 45, BLACK)  # front bumper
    c.rect(78, 42, 99, 42, FENDER_L)
    c.rect(96, 43, 99, 44, CHROME)
    cut_arches(c, ARCH)
    add_rust(c, 14, 35)
    c.save("bus_hood.png")


def fenders():
    """Chunky black fender flares over each wheel, saved as two pieces."""
    for name, cx in (("rear", WHEEL_CX[0]), ("front", WHEEL_CX[1])):
        c = Body()
        for y in range(28, 46):
            for x in range(cx - 15, cx + 16):
                d = math.hypot(x - cx + 0.5, y - 45.5)
                if ARCH_R - 0.5 < d <= ARCH_R + 2.6 and y <= 44:
                    c.set(x, y, FENDER)
                    if d > ARCH_R + 1.8 and y < 40:
                        c.set(x, y, FENDER_L)
        c.rect(cx - 14, 44, cx - 11, 45, FENDER)  # flared feet
        c.rect(cx + 11, 44, cx + 14, 45, FENDER)
        c.save(f"bus_fender_{name}.png")


def wheel():
    """Chunky 19px knobby tire with a chrome 5-lug hub."""
    n, r = 19, 9.3
    c = Canvas(n, n)
    m = (n - 1) / 2
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - m, y - m)
            a = math.atan2(y - m, x - m)
            knob = (int((a + math.pi) / (2 * math.pi) * 14) % 2) == 0
            if d <= r - 1 or (d <= r and knob):
                c.set(x, y, TIRE)
            if r - 2.6 <= d <= r - 1.6 and knob:
                c.set(x, y, TIRE_L)  # tread blocks make the spin readable
            if d <= 5.2:
                c.set(x, y, HUB_D)
            if d <= 4.3:
                c.set(x, y, HUB)
    for i in range(5):
        a = i * 2 * math.pi / 5
        c.set(round(m + 2.6 * math.cos(a)), round(m + 2.6 * math.sin(a)), BOLT)
    c.set(round(m), round(m), PINK)
    c.set(round(m), round(m - 1), PINK)
    c.save("wheel.png")


def rocket():
    """Two big boosters bolted to the rear bumper, nozzles pointing back (left). 24x20."""
    c = Canvas(24, 20)
    c.rect(19, 1, 23, 18, STEEL_D)  # mounting plate
    for y in range(1, 19):
        c.set(21, y, YEL if y % 2 else BLACK)
    for y in (3, 9, 16):
        c.set(22, y, STEEL_L)
    for cy in (5, 14):
        c.rect(6, cy - 3, 18, cy + 3, STEEL)  # tank
        c.rect(6, cy - 3, 18, cy - 3, STEEL_L)
        c.rect(6, cy + 3, 18, cy + 3, STEEL_D)
        c.rect(10, cy - 3, 11, cy + 3, PINK)  # band
        c.rect(15, cy - 3, 15, cy + 3, RUST[1])
        c.rect(1, cy - 4, 5, cy + 4, STEEL_D)  # bell
        c.rect(1, cy - 4, 5, cy - 4, STEEL)
        c.rect(0, cy - 3, 1, cy + 3, (110, 50, 30))
        c.rect(0, cy - 2, 0, cy + 2, (255, 150, 60))  # hot throat
        c.set(12, cy - 5, STEEL_D)  # fins
        c.set(13, cy - 5, STEEL_D)
        c.set(12, cy + 5, STEEL_D)
        c.set(13, cy + 5, STEEL_D)
    c.save("rocket.png")


def cannon():
    """Bumper cannon: stubby barrel on a bracket, muzzle pointing right. 16x8."""
    c = Canvas(16, 8)
    c.rect(0, 3, 4, 7, STEEL_D)  # bracket
    c.rect(1, 4, 3, 4, STEEL)
    c.rect(3, 2, 13, 5, STEEL)  # barrel
    c.rect(3, 2, 13, 2, STEEL_L)
    c.rect(3, 5, 13, 5, STEEL_D)
    c.rect(13, 1, 15, 6, STEEL_D)  # muzzle
    c.rect(15, 3, 15, 4, BLACK)
    c.rect(6, 2, 7, 5, PINK)  # stripe
    c.rect(9, 2, 9, 5, RUST[1])
    c.save("cannon.png")


def flame():
    """3 frames, 16x7 each, base at the right edge, tip pointing left."""
    c = Canvas(48, 7)
    lengths = (13, 16, 11)
    for f, length in enumerate(lengths):
        for x in range(16):
            t = (15 - x) / length
            if t > 1:
                continue
            half = 3.2 * (1 - t) ** 0.6 + 0.3
            for y in range(7):
                dy = abs(y - 3)
                if dy > half:
                    continue
                r = dy / max(half, 0.01)
                if t < 0.45 and r < 0.4:
                    col = (255, 252, 230)
                elif r < 0.75 and t < 0.7:
                    col = (255, 214, 80)
                elif t < 0.85:
                    col = (255, 120, 40)
                else:
                    col = (220, 50, 60)
                c.set(f * 16 + x, y, col)
    c.save("flame.png")


def passengers():
    """Sheet: columns = mood (idle, cheer, shock), rows = rider variant. 8x10."""
    riders = [
        # skin, hair, shirt, style
        ((240, 200, 160), (110, 60, 30), (40, 200, 180), "short"),
        ((200, 140, 100), (30, 26, 30), (150, 70, 200), "long"),
        ((130, 84, 56), (24, 20, 24), (255, 130, 40), "afro"),
        ((250, 214, 180), (250, 210, 90), (240, 70, 150), "bun"),
        ((170, 110, 80), (200, 200, 210), (90, 190, 70), "short"),
        ((220, 170, 130), (20, 30, 60), (30, 60, 150), "cap"),  # driver
    ]
    eye, mouth = (24, 18, 30), (140, 40, 50)
    c = Canvas(24, 60)
    for row, (skin, hair, shirt, style) in enumerate(riders):
        for mood in range(3):
            ox, oy = mood * 8, row * 10

            def p(x, y, col):
                c.set(ox + x, oy + y, col)

            for y in range(2, 7):
                for x in range(1, 7):
                    p(x, y, skin)
            for x in range(1, 7):
                p(x, 1, hair)
            p(1, 2, hair)
            if style == "long":
                for y in range(2, 7):
                    p(1, y, hair)
                    p(6, y, hair)
            elif style == "afro":
                for x in range(0, 8):
                    p(x, 0, hair)
                    p(x, 1, hair)
                p(0, 2, hair)
                p(7, 2, hair)
            elif style == "bun":
                p(3, 0, hair)
                p(4, 0, hair)
            elif style == "cap":
                for x in range(1, 7):
                    p(x, 0, hair)
                p(6, 1, hair)
                p(7, 1, hair)
                p(4, 0, (250, 200, 40))
            if mood == 2 and style != "cap":  # hair stands up
                p(2, 0, hair)
                p(5, 0, hair)
            for x in range(0, 8):  # shoulders
                for y in range(7, 10):
                    p(x, y, shirt)
            p(3, 7, skin)
            p(4, 7, skin)
            if mood == 0:
                p(2, 3, eye)
                p(5, 3, eye)
                p(3, 5, mouth)
                p(4, 5, mouth)
            elif mood == 1:
                p(2, 3, eye)
                p(5, 3, eye)
                for x in (2, 3, 4, 5):
                    p(x, 5, mouth)
                p(3, 6, (255, 255, 255))
                p(4, 6, mouth)
                for y in range(2, 7):  # arms up
                    p(0, y, skin)
                    p(7, y, skin)
                p(0, 7, shirt)
                p(7, 7, shirt)
            else:
                for x in (2, 5):
                    p(x, 3, (255, 255, 255))
                    p(x, 4, eye)
                for x in (3, 4):
                    p(x, 5, eye)
                    p(x, 6, eye)
    c.save("passengers.png")


def axle():
    c = Canvas(12, 3)
    c.rect(0, 0, 11, 2, STEEL_D)
    c.rect(0, 0, 11, 0, STEEL_L)
    c.rect(0, 0, 1, 2, STEEL)
    c.rect(10, 0, 11, 2, STEEL)
    c.save("axle.png")


def light_radial():
    n = 64
    c = Canvas(n, n)
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - n / 2 + 0.5, y - n / 2 + 0.5) / (n / 2)
            v = max(0.0, 1 - d) ** 2
            c.set(x, y, (round(255 * v),) * 3 + (255,))
    c.save("light_radial.png")


def light_cone():
    w, h = 128, 64
    c = Canvas(w, h)
    half = math.radians(20)
    for y in range(h):
        for x in range(w):
            dx, dy = x + 0.5, y - h / 2 + 0.5
            dist = math.hypot(dx, dy) / w
            ang = abs(math.atan2(dy, dx))
            edge = max(0.0, min(1.0, (half - ang) / math.radians(8)))
            v = max(0.0, 1 - dist) ** 1.4 * edge
            v += max(0.0, 1 - math.hypot(dx, dy) / 10) * 0.8  # hot spot at lamp
            c.set(x, y, (round(255 * min(v, 1)),) * 3 + (255,))
    c.save("light_cone.png")


def extract(src, x0, y0, x1, y1, pred=None, clear=True, fill=CLEAR):
    """Move pixels in the body-space rect (inclusive) from src into a new piece."""
    out = Body()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if not (0 <= x < W and 0 <= y + OY < H):
                continue
            px = src.px[y + OY][x]
            if px[3] and (pred is None or pred(px)):
                out.px[y + OY][x] = px
                if clear:
                    src.px[y + OY][x] = fill if len(fill) == 4 else (*fill, 255)
    return out


def split_pieces():
    frame, upper, lower = STORE["bus_frame.png"], STORE["bus_upper.png"], STORE["bus_lower.png"]
    hood_c, roof_c = STORE["bus_hood.png"], STORE["bus_roof.png"]
    seat_cols = {(*SEAT, 255), (*SEAT_L, 255)}
    extract(frame, 0, 8, 79, 38, lambda p: p in seat_cols, fill=INTERIOR_D).save("bus_seats.png")
    extract(frame, 80, 26, 99, 39).save("bus_engine.png")
    extract(frame, 0, -7, 79, 23).save("bus_cage.png")  # upper-deck skeleton
    frame.save("bus_core.png")  # the rigid inside piece that stays on the chassis
    glass = Body()
    for src in (upper, lower):
        g = extract(src, 0, 0, 99, 45, lambda p: p[3] < 255)
        for y in range(H):
            for x in range(W):
                if g.px[y][x][3]:
                    glass.px[y][x] = g.px[y][x]
    glass.save("bus_glass.png")
    extract(upper, 0, 0, 39, 45).save("bus_upper_r.png")
    extract(upper, 40, 0, 79, 45).save("bus_upper_f.png")
    extract(lower, 43, 26, 52, 41).save("bus_door.png")
    extract(lower, 0, 42, 4, 45).save("bus_bumper_r.png")
    extract(lower, 0, 22, 42, 45).save("bus_lower_r.png")
    lower.save("bus_lower_f.png")
    extract(hood_c, 78, 42, 99, 45).save("bus_bumper_f.png")
    hood_c.save("bus_hood.png")
    extract(roof_c, 0, -7, 39, 3).save("bus_roof_r.png")
    roof_c.save("bus_roof_f.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in (frame, roof, roof_sign, upper_panel, lower_panel, hood, fenders, wheel, rocket, cannon,
               flame, passengers, axle, light_radial, light_cone):
        fn()
    split_pieces()
    for old in ("bus_frame.png", "bus_upper.png", "bus_lower.png", "bus_roof.png"):
        path = os.path.join(OUT, old)
        if os.path.exists(path):
            os.remove(path)
    print("art written to", os.path.normpath(OUT))
