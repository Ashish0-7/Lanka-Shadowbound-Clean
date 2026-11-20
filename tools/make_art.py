"""Generates store art for Lanka: Shadowbound from the game's own sprites.

Outputs (in c:/Game/builds/art/):
  cover_630x500.png   itch.io cover image
  icon_512.png        square icon (also 256 / 128 / 64 sizes)
  icon.png (project)  used by Godot for the window / web favicon
Run: python tools/make_art.py
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.join(HERE, "..")
SPR = os.path.join(PROJ, "assets", "sprites")
OUT = os.path.join(PROJ, "..", "builds", "art")
os.makedirs(OUT, exist_ok=True)
FONT_BLACK = r"C:\Windows\Fonts\seguibl.ttf"
FONT_BOLD = r"C:\Windows\Fonts\segoeuib.ttf"

GOLD = (240, 200, 96)
GOLD_DEEP = (190, 130, 40)
PLUM = (58, 24, 80)
LAVENDER = (200, 144, 255)
NIGHT_TOP = (7, 8, 24)
NIGHT_BOT = (30, 22, 66)


def sprite(cat, name):
    return Image.open(os.path.join(SPR, cat, name + ".png")).convert("RGBA")


def hero_frame(col=0, row=0):
    sheet = sprite("characters", "hero_sheet")
    return sheet.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16))


def up(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def shadowify(img, tint=(110, 46, 160)):
    """Same idea as the in-game shader: shadow-tinted body with a glowing rim."""
    out = Image.new("RGBA", (img.width + 2, img.height + 2), (0, 0, 0, 0))
    src = img.load()
    o = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = src[x, y]
            if a < 20:
                continue
            lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
            k = 0.25 + lum * 1.1
            o[x + 1, y + 1] = (min(255, int(tint[0] * k)), min(255, int(tint[1] * k)), min(255, int(tint[2] * k)), 255)
    rim = (min(255, int(tint[0] * 1.9)), min(255, int(tint[1] * 1.9)), min(255, int(tint[2] * 1.9)), 170)
    for y in range(out.height):
        for x in range(out.width):
            if o[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < out.width and 0 <= ny < out.height and o[nx, ny][3] == 255:
                        o[x, y] = rim
                        break
    return out


def vgrad(w, h, top, bot):
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    return img


def glow(size, color, radius, strength=1.0):
    g = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    cx, cy = size[0] // 2, size[1] // 2
    for i in range(radius, 0, -2):
        a = int(255 * strength * (1 - i / radius) ** 2 * 0.35)
        d.ellipse([cx - i, cy - i, cx + i, cy + i], fill=color + (a,))
    return g.filter(ImageFilter.GaussianBlur(radius // 6 + 1))


def outlined_text(base, xy, text, font, fill, outline, width, anchor="mm", shadow=True):
    d = ImageDraw.Draw(base)
    if shadow:
        d.text((xy[0] + 3, xy[1] + 5), text, font=font, fill=(0, 0, 0, 150), anchor=anchor, stroke_width=width, stroke_fill=(0, 0, 0, 150))
    d.text(xy, text, font=font, fill=fill, anchor=anchor, stroke_width=width, stroke_fill=outline)


def sea_band(w, h, k):
    """Tiled pixel-art water, upscaled by k, tinted for night."""
    tile = sprite("water", "water_deep")
    small = Image.new("RGBA", (w // k + 16, h // k + 16))
    for y in range(0, small.height, 16):
        for x in range(0, small.width, 16):
            small.paste(tile, (x, y))
    big = up(small, k).crop((0, 0, w, h))
    tint = Image.new("RGBA", big.size, (40, 50, 120, 120))
    return Image.alpha_composite(big, tint)


# ============================================================ cover
def make_cover():
    W, H = 630, 500
    rnd = random.Random(7)
    img = vgrad(W, H, NIGHT_TOP, NIGHT_BOT)
    d = ImageDraw.Draw(img)
    # stars
    for _ in range(140):
        x, y = rnd.randrange(W), rnd.randrange(0, 300)
        b = rnd.randint(120, 255)
        s = rnd.choice([1, 1, 1, 2])
        d.rectangle([x, y, x + s - 1, y + s - 1], fill=(b, b, min(255, b + 20), 255))
    # moon
    d.ellipse([60, 40, 116, 96], fill=(236, 236, 255, 255))
    d.ellipse([76, 32, 128, 86], fill=NIGHT_TOP + (255,))
    horizon = 300
    # the island on the horizon with the lighthouse, its lamp blazing gold
    isl = [(330, horizon), (380, horizon - 22), (430, horizon - 34), (470, horizon - 46), (505, horizon - 30), (560, horizon - 14), (610, horizon)]
    d.polygon(isl, fill=(14, 10, 30, 255))
    lx = 478
    d.rectangle([lx - 7, horizon - 110, lx + 7, horizon - 44], fill=(14, 10, 30, 255))
    d.polygon([(lx - 11, horizon - 110), (lx + 11, horizon - 110), (lx, horizon - 124)], fill=(14, 10, 30, 255))
    # lamp beams
    beam = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(beam)
    bd.polygon([(lx, horizon - 104), (0, horizon - 190), (0, horizon - 120)], fill=(255, 220, 120, 60))
    bd.polygon([(lx, horizon - 104), (W, horizon - 170), (W, horizon - 130)], fill=(255, 220, 120, 45))
    beam = beam.filter(ImageFilter.GaussianBlur(6))
    img = Image.alpha_composite(img, beam)
    gl = glow((160, 160), (255, 210, 110), 80, 1.6)
    img.alpha_composite(gl, (lx - 80, horizon - 104 - 80))
    d = ImageDraw.Draw(img)
    d.ellipse([lx - 5, horizon - 109, lx + 5, horizon - 99], fill=(255, 240, 190, 255))
    # sea
    sea = sea_band(W, H - horizon, 4)
    img.alpha_composite(sea, (0, horizon))
    # moon + lamp shimmer on water
    for i in range(10):
        y = horizon + 10 + i * 16
        w = 70 - i * 5
        d.rectangle([88 - w // 2, y, 88 + w // 2, y + 3], fill=(220, 225, 255, 70 - i * 6))
        d.rectangle([lx - w // 3, y + 6, lx + w // 3, y + 9], fill=(255, 220, 140, 80 - i * 7))
    # foreground beach (pixel sand, upscaled)
    sand = sprite("ground", "sand_1")
    beach_h = 120
    band = Image.new("RGBA", (W // 5 + 16, beach_h // 5 + 16))
    for y in range(0, band.height, 16):
        for x in range(0, band.width, 16):
            band.paste(sand, (x, y))
    band = up(band, 5)
    mask = Image.new("L", band.size, 0)
    md = ImageDraw.Draw(mask)
    pts = [(0, 40)] + [(x, 26 + int(14 * math.sin(x / 70.0))) for x in range(0, band.width + 1, 10)] + [(band.width, band.height), (0, band.height)]
    md.polygon(pts, fill=255)
    beach = Image.new("RGBA", band.size, (0, 0, 0, 0))
    beach.paste(band, (0, 0), mask)
    dark = Image.new("RGBA", beach.size, (20, 18, 50, 120))
    beach = Image.alpha_composite(beach, Image.composite(dark, Image.new("RGBA", beach.size, (0, 0, 0, 0)), mask))
    img.alpha_composite(beach.crop((0, 0, W, beach.height)), (0, H - beach_h - 20))
    # lantern glow around the hero
    hx, hy = 190, 390
    img.alpha_composite(glow((340, 340), (255, 190, 100), 170, 1.5), (hx - 170, hy - 190))
    # the hero, sword raised (side frame), big and crisp
    hero = up(hero_frame(0, 0), 9)
    img.alpha_composite(hero, (hx - hero.width // 2, hy - hero.height + 40))
    sword = Image.new("RGBA", (16, 5), (0, 0, 0, 0))
    sp = sword.load()
    for x in range(0, 4):
        sp[x, 2] = (138, 90, 42, 255)
    for y in range(5):
        sp[4, y] = (224, 176, 64, 255)
    for x in range(5, 15):
        sp[x, 1] = (168, 184, 200, 255); sp[x, 2] = (232, 240, 248, 255); sp[x, 3] = (168, 184, 200, 255)
    sp[15, 2] = (232, 240, 248, 255)
    sword = up(sword, 9).rotate(55, expand=True, resample=Image.NEAREST)
    img.alpha_composite(sword, (hx + 18, hy - 190))
    # shadow creatures closing in from the right
    for name, cat, k, pos in [("monkey", "critters", 7, (430, 340)), ("crab_1", "critters", 6, (520, 400)),
                              ("pirate", "characters", 7, (350, 360)), ("seagull_1", "critters", 5, (520, 230))]:
        sh = up(shadowify(sprite(cat, name)), k)
        img.alpha_composite(glow((sh.width + 60, sh.height + 60), (140, 60, 220), (sh.width + 60) // 2, 0.9), (pos[0] - 30, pos[1] - 30))
        img.alpha_composite(sh, pos)
    # title
    title_font = ImageFont.truetype(FONT_BLACK, 104)
    sub_font = ImageFont.truetype(FONT_BOLD, 30)
    tag_font = ImageFont.truetype(FONT_BOLD, 17)
    outlined_text(img, (W // 2, 92), "LANKA", title_font, GOLD + (255,), PLUM + (255,), 8)
    outlined_text(img, (W // 2, 170), "S H A D O W B O U N D", sub_font, LAVENDER + (255,), (16, 8, 28, 255), 4)
    outlined_text(img, (W // 2, 206), "an island that appears on no map", tag_font, (200, 210, 240, 255), (10, 8, 20, 255), 3, shadow=False)
    # thin gold frame
    d = ImageDraw.Draw(img)
    d.rectangle([6, 6, W - 7, H - 7], outline=GOLD_DEEP + (200,), width=2)
    img.convert("RGB").save(os.path.join(OUT, "cover_630x500.png"))
    return img


# ============================================================ icon
def make_icon():
    S = 512
    img = vgrad(S, S, NIGHT_TOP, (40, 26, 80))
    d = ImageDraw.Draw(img)
    rnd = random.Random(3)
    for _ in range(50):
        x, y = rnd.randrange(S), rnd.randrange(S // 2)
        d.rectangle([x, y, x + 2, y + 2], fill=(230, 230, 255, rnd.randint(120, 255)))
    # golden lamp-halo behind the hero
    img.alpha_composite(glow((S, S), (255, 200, 100), 230, 2.0), (0, 10))
    d = ImageDraw.Draw(img)
    d.ellipse([86, 76, S - 86, S - 96], outline=GOLD + (230,), width=10)
    d.ellipse([104, 94, S - 104, S - 114], outline=GOLD_DEEP + (160,), width=3)
    # the hero
    hero = up(hero_frame(0, 0), 20)
    img.alpha_composite(hero, ((S - hero.width) // 2, 70))
    # three lamp shards along the bottom
    for i, col in enumerate([(128, 216, 255), (140, 255, 128), (255, 154, 76)]):
        cx, cy = S // 2 + (i - 1) * 70, S - 52
        d.polygon([(cx, cy - 26), (cx + 18, cy), (cx, cy + 26), (cx - 18, cy)], fill=col + (255,), outline=(255, 255, 255, 200))
    # rounded mask
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=96, fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle([3, 3, S - 4, S - 4], radius=94, outline=GOLD_DEEP + (255,), width=6)
    out.save(os.path.join(OUT, "icon_512.png"))
    for s in (256, 128, 64):
        out.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, "icon_%d.png" % s))
    out.resize((256, 256), Image.LANCZOS).save(os.path.join(PROJ, "icon.png"))
    out.save(os.path.join(OUT, "icon.ico"), sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
    return out


if __name__ == "__main__":
    make_cover()
    make_icon()
    print("art written to", os.path.abspath(OUT))
