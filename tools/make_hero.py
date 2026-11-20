"""Generates the hero sprite sheet: an original 16x16 island warrior.

Sheet layout (16x16 frames): 7 columns x 3 rows
  rows:    0 = facing down (front), 1 = facing up (back), 2 = facing right (side; flip for left)
  columns: 0-1 idle (breathing), 2-5 walk cycle, 6 attack (arms lifted off the body; the
           swinging arms are a separate sprite, hero_arms.png, that rotates with the sword)
Run:  python tools/make_hero.py   (writes assets/sprites/characters/hero_sheet.png and hero.png)
"""
from PIL import Image
import os

PAL = {
    '.': (0, 0, 0, 0),
    'K': (26, 16, 24, 255),     # outline
    'H': (34, 22, 18, 255),     # hair
    'h': (78, 50, 34, 255),     # hair highlight
    'R': (196, 44, 36, 255),    # headband
    'r': (130, 26, 24, 255),    # headband shade
    'S': (204, 138, 92, 255),   # skin
    's': (156, 96, 60, 255),    # skin shadow / muscle definition
    'W': (236, 186, 140, 255),  # skin highlight
    'A': (232, 184, 64, 255),   # gold armour
    'a': (156, 112, 32, 255),   # gold shade
    'L': (110, 64, 34, 255),    # leather strap
    'M': (196, 206, 216, 255),  # steel bracer
    'm': (120, 128, 140, 255),  # steel shade
    'T': (40, 138, 150, 255),   # teal sash
    't': (24, 88, 98, 255),     # sash shade
    'P': (62, 50, 82, 255),     # trousers
    'p': (42, 34, 58, 255),     # trousers shade
    'O': (70, 40, 26, 255),     # boots
    'E': (250, 250, 250, 255),  # eye glint
    'C': (150, 30, 40, 255),    # cape
    'c': (100, 18, 28, 255),    # cape shade
}

FRONT_TOP = [
    "......KKKK......",
    ".....KHhHHK.....",
    "....KHhHHHHK....",
    "....KRRRRRrK....",
    "....KSSSSSsK....",
    "....KSKSSKsK....",
    ".....KsSSsK.....",
    "..KKKAKSSKAKKK..",
    ".KAAaWSLSSSaAAK.",
    "KSWKSSSsLSSsKWSK",
    "KSsKSsSSSLSsKsSK",
    "KMmKTTTTTTTTKmMK",
]
FRONT_LEGS = {
    "stand": [
        "KSSKKPPpKPPpKSSK",
        ".KK.KPPK.KPPK.KK",
        "....KPpK.KpPK...",
        "....KOOK.KOOK...",
    ],
    "stepL": [
        "KSSKKPPpKPPpKSSK",
        ".KK.KPPK.KPPK.KK",
        "....KOOK.KpPK...",
        "....KKKK.KOOK...",
    ],
    "stepR": [
        "KSSKKPPpKPPpKSSK",
        ".KK.KPPK.KPPK.KK",
        "....KpPK.KOOK...",
        "....KOOK.KKKK...",
    ],
}

BACK_TOP = [
    "......KKKK......",
    ".....KHHHHK.....",
    "....KHHhHHHK....",
    "....KRRRRRRK....",
    "....KHHHHHHK....",
    "....KHHrrHHK....",
    ".....KsSSsK.....",
    "..KKKAKCCKAKKK..",
    ".KAAaCCCCCCaAAK.",
    "KSWKCCcCCcCCKWSK",
    "KSsKCCcCCcCCKsSK",
    "KMmKTTTTTTTTKmMK",
]
BACK_LEGS = FRONT_LEGS

SIDE_TOP = [
    "......KKKK......",
    ".....KHHhHK.....",
    "....KHHHhHHK....",
    "....KrRRRRRK....",
    ".....KSSSSSK....",
    ".....KSSSKEK....",
    "......KSSSsK....",
    ".....KAAKSK.....",
    "....KAaASLSK....",
    "....KAKSWSSK....",
    "....KCKSsSMK....",
    "....KCKTTTmK....",
]
SIDE_LEGS = {
    "stand": [
        "....KcKPPpK.....",
        ".....KKPPpK.....",
        "......KPpPK.....",
        "......KOOOK.....",
    ],
    "stepL": [
        "....KcKPPpK.....",
        ".....KPPKPPK....",
        ".....KpK.KPK....",
        ".....KOK.KOOK...",
    ],
    "stepR": [
        "....KcKPPpK.....",
        "....KPPKPPK.....",
        "....KPK.KpK.....",
        "...KOOK.KOK.....",
    ],
}


def frame(top, legs, bob=0, breathe=False):
    rows = top + legs
    assert len(rows) == 16, len(rows)
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    # legs first, then the (possibly bobbing) upper body on top so the sash never vanishes
    order = list(range(12, 16)) + list(range(0, 12))
    for y in order:
        row = rows[y]
        assert len(row) == 16, (row, len(row))
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            yy = y
            # upper body bobs during the walk / breath; legs stay planted
            if y < 12:
                yy = y + bob
                if breathe and y >= 7:
                    yy = y + bob
            if 0 <= yy < 16:
                img.putpixel((x, yy), PAL[ch])
    return img


ARMS = [
    ".KKKKKK..",
    "KSWSSMmKK",
    "KSsSSMmSK",
    "KsSSsMmSK",
    ".KKKKKKK.",
]


def attack_frame(base, row):
    """Copy of the idle frame with the arms removed so the rotating arm sprite can replace them."""
    img = base.copy()
    if row in (0, 1):  # front / back: arms hang at the sides
        for y in range(9, 14):
            for x in list(range(0, 3)) + list(range(13, 16)):
                img.putpixel((x, y), (0, 0, 0, 0))
    return img


def build_arms():
    img = Image.new("RGBA", (9, 5), (0, 0, 0, 0))
    for y, row in enumerate(ARMS):
        for x, ch in enumerate(row):
            if ch != '.':
                img.putpixel((x, y), PAL[ch])
    return img


def build():
    sheet = Image.new("RGBA", (16 * 7, 16 * 3), (0, 0, 0, 0))
    sets = [(FRONT_TOP, FRONT_LEGS), (BACK_TOP, BACK_LEGS), (SIDE_TOP, SIDE_LEGS)]
    for row, (top, legs) in enumerate(sets):
        frames = [
            frame(top, legs["stand"], 0),               # idle 0
            frame(top, legs["stand"], 1, True),         # idle 1 (breath in)
            frame(top, legs["stepL"], 1),               # walk 0
            frame(top, legs["stand"], 0),               # walk 1
            frame(top, legs["stepR"], 1),               # walk 2
            frame(top, legs["stand"], 0),               # walk 3
        ]
        frames.append(attack_frame(frames[0], row))
        for col, f in enumerate(frames):
            sheet.paste(f, (col * 16, row * 16))
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "assets", "sprites", "characters")
    sheet.save(os.path.join(out, "hero_sheet.png"))
    sheet.crop((0, 0, 16, 16)).save(os.path.join(out, "hero.png"))
    build_arms().save(os.path.join(out, "hero_arms.png"))
    return sheet


if __name__ == "__main__":
    s = build()
    print("hero sheet", s.size)
