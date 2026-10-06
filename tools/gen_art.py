#!/usr/bin/env python3
"""Generates the Rocket Bus pixel art into assets/sprites.

Run from the project root:  python3 tools/gen_art.py

Every breakable bus piece is drawn on the same 80x53 canvas so the pieces
line up when stacked, and can be spawned as debris using the same transform.
Body coordinates: x 0..79 cabin (rear -> front), x 80..99 hood, y 0..45 (rack -> skirt).
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
GLASS = (150, 200, 230, 56)
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
# A single-deck, go-anywhere school bus: roof rack with luggage, snorkel, bull bar.
#   y  1..11  roof rack + luggage + sign     y 12..14  roof
#   y 16..28  window band (glass 17..27)     y 29..41  pinstripe, checker, panels
#   y 42..45  skirt / bash plate             x 80..98  hood, snorkel, bull bar

ROOF_Y = 12
WIN_Y = (17, 27)
WINDOWS = [(2, 12), (15, 25), (28, 38), (53, 63)]  # passenger windows
DRIVER_WIN = (66, 77)
DOOR = (41, 50)
PILLARS = (0, 13, 26, 39, 51, 64, 78)
RIDER_X = (4, 17, 30, 55)  # left edge of each 8px rider sprite (body px)
LEATHER = (130, 76, 40)
LEATHER_D = (90, 50, 28)
DUFFEL = (60, 90, 170)
DUFFEL_D = (36, 56, 120)
JERRY = (200, 40, 40)
JERRY_D = (130, 24, 30)


def frame():
    """The skeleton: interior, pillars, floor, chassis rail. Seen through the
    windows, and fully exposed once the shell is ripped off."""
    c = Body()
    c.rect(1, ROOF_Y + 1, 78, 43, INTERIOR)
    c.rect(1, ROOF_Y + 1, 78, ROOF_Y + 3, INTERIOR_D)  # ceiling
    for x in range(8, 76, 13):  # ceiling lamps
        c.set(x, 16, LAMP)
        c.set(x + 1, 16, LAMP)
    for rx in RIDER_X:  # high seat backs, right behind each (forward-facing) rider
        c.rect(rx - 2, 20, rx - 1, 30, SEAT)
        c.rect(rx - 2, 20, rx - 1, 20, SEAT_L)
        c.rect(rx - 2, 29, rx + 6, 30, SEAT)  # seat cushion
    c.rect(1, 31, 78, 32, INTERIOR_D)  # floor
    c.rect(2, ROOF_Y, 77, ROOF_Y, STEEL_D)  # roof rail
    for px in PILLARS:
        c.rect(px, ROOF_Y, px + 1, 43, STEEL)
        c.rect(px + 1, ROOF_Y, px + 1, 43, STEEL_D)
    bays = PILLARS + (80,)
    for a, b in zip(bays, bays[1:]):  # cross braces in the skirt
        span = b - a - 2
        for i in range(span):
            y = 41 - round(i * 4 / max(span - 1, 1))
            c.set(a + 2 + i, y, STEEL_D)
    c.rect(0, 40, 79, 43, STEEL_D)  # chassis rail
    c.rect(0, 40, 79, 40, STEEL)
    for x in range(3, 78, 6):
        c.set(x, 42, STEEL_L)
    c.rect(80, 40, 86, 43, STEEL_D)  # rail runs under the hood (stops where the nose angles up)
    c.rect(80, 40, 86, 40, STEEL)
    c.rect(82, 30, 93, 39, (70, 72, 84))  # engine block
    for x in range(83, 93, 3):
        c.rect(x, 28, x + 1, 30, STEEL)  # cylinder heads
    c.rect(82, 35, 93, 35, (50, 50, 60))
    c.rect(93, 30, 94, 35, (120, 60, 50))  # radiator
    for y in range(31, 35, 2):
        c.set(94, y, (170, 90, 70))
    cut_arches(c, STEEL_D)
    c.save("bus_frame.png")


def roof():
    c = Body()
    y = ROOF_Y
    c.rect(3, y, 76, y, YEL_L)
    c.rect(1, y + 1, 78, y + 1, YEL)
    c.rect(0, y + 2, 79, y + 2, YEL_D)
    c.set(1, y + 1, YEL_L)
    for x in range(4, 77, 5):  # roof rivets
        c.set(x, y + 1, YEL_D)
    add_rust(c, 11, 18)
    c.save("bus_roof.png")


def rack():
    """Roof rack loaded for a long trip: suitcases, duffel, spare tire, jerry can, lamps."""
    c = Body()
    c.rect(3, 9, 77, 9, STEEL_D)  # rail
    c.rect(3, 8, 77, 8, STEEL)
    for x in range(4, 78, 9):  # posts down to the roof
        c.rect(x, 10, x, 11, STEEL_D)
    # rear: two suitcases and a duffel
    c.rect(4, 3, 12, 7, LEATHER)
    c.rect(4, 3, 12, 3, (170, 104, 60))
    c.rect(7, 2, 9, 2, LEATHER_D)  # handle
    c.rect(4, 5, 12, 5, LEATHER_D)  # strap
    c.rect(13, 5, 21, 7, DUFFEL)
    c.rect(14, 4, 20, 4, DUFFEL)
    c.rect(13, 7, 21, 7, DUFFEL_D)
    c.set(17, 3, DUFFEL_D)
    # front: spare tire lying flat, jerry can, roof lamps
    c.rect(56, 5, 66, 7, TIRE)
    c.rect(57, 4, 65, 4, TIRE)
    c.rect(58, 5, 64, 5, TIRE_L)
    c.rect(68, 3, 72, 7, JERRY)
    c.rect(68, 3, 72, 3, (240, 90, 80))
    c.rect(68, 7, 72, 7, JERRY_D)
    c.set(71, 2, JERRY_D)
    c.set(70, 5, JERRY_D)
    for lx in (74, 77):
        c.rect(lx - 1, 5, lx, 7, STEEL_D)
        c.set(lx, 6, LAMP)
    add_rust(c, 15, 8)
    c.save("bus_rack.png")


GLYPHS = {
    "R": ["110", "101", "110", "101", "101"],
    "O": ["010", "101", "101", "101", "010"],
    "C": ["011", "100", "100", "100", "011"],
    "K": ["101", "101", "110", "101", "101"],
    "E": ["111", "100", "110", "100", "111"],
    "T": ["111", "010", "010", "010", "010"],
}


def roof_sign():
    """Taxi-style lit sign strapped to the rack. Flies off on a crash."""
    c = Body()
    c.rect(26, 1, 53, 7, PINK)
    c.rect(27, 2, 52, 6, BLACK)
    c.rect(26, 1, 53, 1, (255, 120, 190))
    for i, ch in enumerate("ROCKET"):
        for gy, row in enumerate(GLYPHS[ch]):
            for gx, bit in enumerate(row):
                if bit == "1":
                    c.set(28 + i * 4 + gx, 2 + gy, YEL)
    c.save("bus_sign.png")


def side_panel():
    """The whole side skin in one canvas; split_pieces() cuts it into breakable panels."""
    c = Body()
    c.rect(0, 15, 79, 41, YEL)
    c.rect(0, 15, 79, 15, YEL_L)
    c.rect(79, 15, 79, 41, YEL_D)  # cab front edge (the hood takes over from here)
    for x0, x1 in WINDOWS:
        window(c, x0, WIN_Y[0], x1, WIN_Y[1], YEL_D)
    window(c, DRIVER_WIN[0], WIN_Y[0], DRIVER_WIN[1], WIN_Y[1], YEL_D)
    c.rect(0, 29, 79, 29, PINK)  # pink pinstripe under the sills
    c.rect(0, 30, 79, 30, PINK_D)
    for x in range(80):  # taxi checker band
        top = (x // 2) % 2 == 0
        c.set(x, 31, CHK_B if top else CHK_W)
        c.set(x, 32, CHK_W if top else CHK_B)
    c.rect(0, 33, 79, 33, YEL_D)
    for px in PILLARS[1:-1]:  # panel seams
        c.rect(px, 34, px, 41, YEL_D)
    for x in range(2, 78, 4):  # rivet line
        c.set(x, 35, YEL_D)
    for x in range(2, 60):  # teal speed stripe with a slanted nose
        c.set(x, 38, TEAL)
        c.set(x, 39, TEAL_D)
    for i in range(3):
        c.set(60 + i, 38 - i, TEAL)
        c.set(60 + i, 39 - i, TEAL_D)
    c.rect(0, 42, 79, 45, SKIRT)  # skirt with a bolted bash plate
    c.rect(0, 45, 79, 45, SKIRT_D)
    c.rect(0, 43, 79, 43, STEEL_D)
    for x in range(3, 78, 7):
        c.set(x, 43, STEEL_L)
    # door: tall, glazed, split down the middle
    d0, d1 = DOOR
    c.rect(d0, 16, d1, 41, YEL_D)
    c.rect(d0 + 1, 17, d1 - 1, 41, GLASS)
    c.rect(d0 + 4, 17, d0 + 5, 41, STEEL_D)
    c.set(d0 + 2, 18, GLARE)
    c.set(d1 - 2, 18, GLARE)
    c.rect(d0 + 1, 34, d1 - 1, 34, STEEL_D)  # kick plate rail
    # tail light, reflector, rear bumper
    c.rect(0, 34, 1, 38, TAIL)
    c.set(0, 39, AMBER)
    c.rect(0, 42, 4, 45, STEEL)
    c.rect(0, 42, 4, 42, STEEL_L)
    cut_arches(c, ARCH)
    add_rust(c, 13, 70)
    c.save("bus_side.png")


def hood_bottom(x):
    """Underside of the snubbed nose: flat, then angled up toward the front
    so the bus doesn't dig into ramps (matches the chassis collision shape)."""
    return 41 if x < 86 else 41 - round((x - 86) * 0.55)


def hood():
    """Snubbed school-bus nose: sloped hood, louvers, grille, headlight."""
    c = Body()
    for x in range(80, 96):
        top = 26 + round((x - 80) * 5 / 16)  # hood slopes down toward the grille
        c.rect(x, top, x, hood_bottom(x), YEL)
        c.set(x, top, YEL_L)
    for x in range(84, 91, 2):  # louvers
        c.rect(x, 31, x, 35, YEL_D)
    c.rect(80, 37, 92, 37, BLACK)  # rub rail
    c.rect(94, 30, 95, hood_bottom(95), CHROME)  # grille
    for y in range(31, hood_bottom(95), 2):
        c.set(94, y, GRILLE)
    c.rect(91, 31, 93, 33, HEADLIGHT)
    c.set(91, 31, CHROME)
    c.set(93, 35, AMBER)
    # snorkel: intake up the front corner of the cab, for river crossings
    c.rect(80, 13, 81, 27, STEEL_D)
    c.rect(80, 13, 80, 27, STEEL)
    c.rect(80, 11, 84, 13, STEEL_D)
    c.rect(81, 11, 84, 11, STEEL)
    c.set(84, 12, BLACK)
    cut_arches(c, ARCH)
    add_rust(c, 14, 35)
    c.save("bus_hood.png")


def front_bumper():
    """Tubular bull bar bolted over the nose, following its angled underside."""
    c = Body()
    for x in range(78, 97):
        b = hood_bottom(min(x, 95))
        c.rect(x, b + 1, x, b + 3, BLACK)
        c.set(x, b + 1, FENDER_L)
    c.rect(96, 27, 97, hood_bottom(95) + 2, FENDER)  # upright
    c.rect(96, 27, 96, hood_bottom(95) + 2, FENDER_L)
    for y in (28, 33):  # cross tubes
        c.rect(92, y, 97, y + 1, FENDER)
        c.rect(92, y, 97, y, FENDER_L)
    c.rect(94, hood_bottom(95) - 1, 97, hood_bottom(95) + 1, CHROME)
    c.save("bus_bumper_f.png")


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
    """Fat 21px knobby tire (lots of rubber) with a chrome 5-lug hub."""
    n, r = 21, 10.3
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
            if 5.4 < d <= 6.2:
                c.set(x, y, (40, 38, 46))  # sidewall ring
            if d <= 4.8:
                c.set(x, y, HUB_D)
            if d <= 4.0:
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
    """Sheet: columns = mood (idle, cheer, shock), rows = rider variant. 8x10.
    Riders sit facing forward (right, the way the bus goes), seen in profile."""
    riders = [
        # skin, hair, shirt, style
        ((240, 200, 160), (110, 60, 30), (40, 200, 180), "short"),
        ((200, 140, 100), (30, 26, 30), (150, 70, 200), "long"),
        ((130, 84, 56), (24, 20, 24), (255, 130, 40), "afro"),
        ((250, 214, 180), (250, 210, 90), (240, 70, 150), "bun"),
        ((170, 110, 80), (200, 200, 210), (90, 190, 70), "short"),
        ((220, 170, 130), (20, 30, 60), (30, 60, 150), "cap"),  # driver (ragdoll head)
    ]
    eye, mouth, white = (24, 18, 30), (140, 40, 50), (255, 255, 255)
    c = Canvas(24, 60)
    for row, (skin, hair, shirt, style) in enumerate(riders):
        for mood in range(3):
            ox, oy = mood * 8, row * 10

            def p(x, y, col):
                c.set(ox + x, oy + y, col)

            for y in range(2, 7):  # head: back of the head left, face right
                for x in range(1, 6):
                    p(x, y, skin)
            p(6, 4, skin)  # nose
            for x in range(1, 6):
                p(x, 1, hair)
            for y in range(2, 5):  # hair over the back of the head
                p(1, y, hair)
            p(2, 2, hair)
            if style == "long":
                for y in range(2, 8):
                    p(0, y, hair)
                    p(1, y, hair)
            elif style == "afro":
                for x in range(0, 7):
                    p(x, 0, hair)
                    p(x, 1, hair)
                for y in range(2, 5):
                    p(0, y, hair)
                p(2, 3, hair)
            elif style == "bun":
                p(0, 1, hair)
                p(0, 2, hair)
                p(1, 0, hair)
            elif style == "cap":
                for x in range(1, 6):
                    p(x, 0, hair)
                p(6, 1, hair)  # brim
                p(7, 1, hair)
                p(3, 0, (250, 200, 40))
            if mood == 2 and style not in ("cap", "afro"):  # hair stands up
                p(2, 0, hair)
                p(4, 0, hair)
            for x in range(0, 7):  # shoulders / torso
                for y in range(7, 10):
                    p(x, y, shirt)
            p(3, 7, skin)  # neck
            p(4, 7, skin)
            if mood == 0:
                p(4, 3, eye)
                p(5, 5, mouth)
            elif mood == 1:  # big grin, fist pumped
                p(4, 3, eye)
                p(4, 5, mouth)
                p(5, 5, mouth)
                p(5, 6, white)
                for y in range(1, 7):
                    p(7, y, skin)
                p(7, 7, shirt)
                p(6, 8, shirt)
            else:  # wide eye, gaping mouth, hands up
                p(4, 3, white)
                p(5, 3, eye)
                p(5, 5, eye)
                p(5, 6, eye)
                p(6, 6, mouth)
                p(7, 2, skin)
                p(7, 3, skin)
                p(6, 8, shirt)
                p(7, 4, shirt)
    c.save("passengers.png")


def driver():
    """The driver in profile, facing right (the way the bus goes), hands on the wheel.
    3 frames of 12x11: idle, cheer (fist up), shock."""
    skin, cap, shirt = (220, 170, 130), (20, 30, 60), (30, 60, 150)
    eye, mouth, wheel = (24, 18, 30), (140, 40, 50), (40, 40, 48)
    c = Canvas(36, 11)
    for f in range(3):
        ox = f * 12

        def p(x, y, col):
            c.set(ox + x, y, col)

        for y in range(2, 7):  # head (profile): back of head left, nose right
            for x in range(2, 7):
                p(x, y, skin)
        p(7, 4, skin)  # nose
        for x in range(2, 7):  # cap + forward brim
            p(x, 1, cap)
            p(x, 2, cap)
        p(7, 2, cap)
        p(8, 2, cap)
        p(3, 0, cap)
        p(4, 0, cap)
        p(2, 3, (60, 40, 30))  # hair under the cap
        p(5, 3, eye if f != 2 else (255, 255, 255))
        if f == 2:
            p(5, 4, eye)
            p(6, 5, mouth)
            p(6, 6, mouth)
        elif f == 1:
            p(6, 5, mouth)
            p(5, 5, mouth)
        else:
            p(6, 5, mouth)
        for y in range(7, 11):  # shoulders/torso
            for x in range(1, 7):
                p(x, y, shirt)
        if f == 1:  # fist pumped up
            p(7, 1, skin)
            p(7, 0, skin)
            p(7, 2, shirt)
            p(7, 3, shirt)
        else:  # arm out to the wheel
            for x in range(6, 9):
                p(x, 8, shirt)
            p(9, 8, skin)
        for y in range(6, 11):  # steering wheel, seen edge-on
            p(10, y, wheel)
        p(9, 6, wheel)
        p(11, 10, wheel)
    c.save("driver.png")


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
    frame, side = STORE["bus_frame.png"], STORE["bus_side.png"]
    hood_c, roof_c = STORE["bus_hood.png"], STORE["bus_roof.png"]
    seat_cols = {(*SEAT, 255), (*SEAT_L, 255)}
    extract(frame, 0, 18, 79, 31, lambda p: p in seat_cols, fill=INTERIOR_D).save("bus_seats.png")
    extract(frame, 80, 26, 99, 39).save("bus_engine.png")
    frame.save("bus_core.png")  # the rigid inside piece that stays on the chassis
    extract(side, 0, 0, 99, 45, lambda p: p[3] < 255).save("bus_glass.png")
    extract(side, DOOR[0], 16, DOOR[1], 41).save("bus_door.png")
    extract(side, 0, 42, 4, 45).save("bus_bumper_r.png")
    extract(side, 0, 15, DOOR[0] - 1, 30).save("bus_upper_r.png")
    extract(side, DOOR[1] + 1, 15, 79, 30).save("bus_upper_f.png")
    extract(side, 0, 31, DOOR[0] - 1, 45).save("bus_lower_r.png")
    side.save("bus_lower_f.png")
    hood_c.save("bus_hood.png")
    extract(roof_c, 0, ROOF_Y, 39, ROOF_Y + 2).save("bus_roof_r.png")
    roof_c.save("bus_roof_f.png")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in (frame, roof, rack, roof_sign, side_panel, hood, front_bumper, fenders, wheel, rocket,
               flame, passengers, driver, axle, light_radial, light_cone):
        fn()
    split_pieces()
    for old in ("bus_frame.png", "bus_side.png", "bus_roof.png"):  # intermediates
        path = os.path.join(OUT, old)
        if os.path.exists(path):
            os.remove(path)
    print("art written to", os.path.normpath(OUT))
