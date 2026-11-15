"""The backgrounds (docs/design.md 「顏色」): calm, low-contrast felt so the pom-pom animal is always the
darkest, brightest thing on screen. 400 x 250, shown filling the stage from the bottom (the sides are
cut off when the phone stands upright, so nothing important sits at the edges).

    python3 build.py scenes       # writes app/assets/art/scenes/<name>.svg
"""
import math

import kit

W, H = 400, 250


def sky(c, top, bottom):
    c.fill(kit.rect(0, 0, W, H), c.linear(0, 0, 0, H, [(0, top, 1), (1, bottom, 1)]))


def hill(c, y, amp, col, key, waves=2.0, phase=0.0):
    pts = [(0, H + 5)]
    for i in range(0, 41):
        x = W * i / 40
        pts.append((x, y - amp * (0.5 + 0.5 * math.sin(phase + waves * math.pi * i / 40))))
    pts.append((W, H + 5))
    c.felt(kit.Shape([("M",) + pts[0]] + [("L",) + p for p in pts[1:]] + [("Z",)]), col, edge=1.2)


def floor(c, y, col):
    c.felt(kit.rect(-2, y, W + 4, H - y + 4), col, edge=1.2)


def cloud(c, x, y, s, col="#FFFFFF", op=.85):
    c.felt(kit.cloud(x, y, 60 * s, 26 * s, 4), col, edge=1, op=op)


def leaf(c, x, y, s, rot, col):
    shape = kit.Shape([("M", x, y), ("C", x + 30 * s, y - 25 * s, x + 70 * s, y - 20 * s, x + 90 * s, y),
                       ("C", x + 70 * s, y + 20 * s, x + 30 * s, y + 25 * s, x, y), ("Z",)]).rotate(rot, x, y)
    c.felt(shape, col, edge=1.4)
    c.stroke(kit.path([(x, y), (x + 80 * s, y)]).rotate(rot, x, y), kit.mix(col, kit.INK, .2), 1.6, op=.6)


def home(c):
    sky(c, "#CFEAF7", "#FFF8EC")
    c.felt(kit.circle(330, 52, 24), "#FFE59A", edge=1.4)
    cloud(c, 90, 50, .8)
    cloud(c, 250, 34, .6)
    hill(c, 175, 30, "#D7EEC9", "h1", 1.5)
    hill(c, 200, 20, "#C4E6B5", "h2", 2.4, 1)
    floor(c, 222, "#E9F3D9")


def jungle(c):
    sky(c, "#D4F0E6", "#F1FAEC")
    hill(c, 160, 30, "#BFE3B4", "j1", 1.4)
    for x, y, s, r in ((-10, 70, 1.3, 20), (410, 60, 1.3, 160), (-20, 140, 1.1, -10), (420, 150, 1.0, 190)):
        leaf(c, x, y, s, r, "#9FD39A")
    floor(c, 210, "#D6EEC4")
    c.felt(kit.ellipse(200, 232, 130, 14), "#BFE4EE", edge=1.2)
    for x, y in ((120, 232), (200, 236), (280, 230)):
        c.felt(kit.Shape([("M", x, y), ("L", x + 20, y - 4), ("C", x + 22, y + 10, x - 22, y + 10, x - 22, y), ("C", x - 22, y - 9, x + 16, y - 9, x + 20, y - 4), ("Z",)]), "#9ED49A", edge=1.2)


def zoo(c):
    sky(c, "#FFF1C9", "#FFF8EC")
    c.felt(kit.cloud(330, 70, 90, 50, 4), "#CDE8B6", edge=1.2)
    c.felt(kit.rect(326, 90, 10, 80), "#D9B38C", edge=1.2)
    hill(c, 185, 14, "#F2E3B8", "z1", 1.2)
    for i in range(12):
        x = 10 + i * 34
        c.felt(kit.rrect(x, 150, 10, 60, 4), "#E9C99B", edge=1.2)
    c.felt(kit.rect(0, 165, W, 7), "#E2BC8C", edge=1)
    c.felt(kit.rect(0, 188, W, 7), "#E2BC8C", edge=1)
    floor(c, 212, "#F5E7C8")


def sea(c):
    sky(c, "#BEE7F6", "#7FC6E8")
    for i, (x, y, r) in enumerate(((60, 60, 7), (80, 40, 4), (330, 90, 6), (350, 60, 4), (200, 30, 3))):
        c.path_el(kit.circle(x, y, r).d(), "none", "#FFFFFF", 2, op=.6)
    for x, h in ((40, 70), (70, 50), (340, 80), (370, 56)):
        pts = [(x + math.sin(k * .9) * 8, 215 - k * h / 6) for k in range(7)]
        c.cleaner(pts, "#7CC99A", 9, edge=1.2, twist=False)
    floor(c, 212, "#F2DDB0")
    c.dots([(120, 230), (260, 236), (330, 228)], 4, "#E6C58E")


def rain(c):
    sky(c, "#D5DFEC", "#EEF2F6")
    for x, y, s in ((80, 40, 1.0), (250, 30, 1.2), (360, 60, .8)):
        cloud(c, x, y, s, "#C2CCDA", 1)
    s = kit.Shape()
    r = kit.rnd("rain")
    for _ in range(40):
        x, y = r.uniform(0, W), r.uniform(70, 200)
        s = s + kit.Shape([("M", x, y), ("L", x - 3, y + 10)])
    c.path_el(s.d(), "none", "#9FB4CC", 2, op=.6)
    hill(c, 195, 12, "#CFE0C8", "r1", 1.5)
    floor(c, 214, "#DCE6D4")
    for x, w in ((90, 50), (300, 60)):
        c.felt(kit.ellipse(x, 232, w, 7), "#B9CDE2", edge=1)


def mountain(c):
    sky(c, "#DDF0F5", "#F4FAEE")
    for k, (y, amp, col, waves) in enumerate(((120, 70, "#C9E3CF", 1.2), (150, 55, "#B6DBB9", 1.7), (180, 35, "#A5D3A4", 2.3))):
        hill(c, y, amp, col, f"m{k}", waves, k)
    for x, y, s in ((40, 190, 1.0), (360, 185, 1.1), (80, 200, .8)):
        c.felt(kit.poly([(x, y - 50 * s), (x + 20 * s, y), (x - 20 * s, y)]), "#8CC191", edge=1.2)
    floor(c, 214, "#D9EDCB")


def party(c):
    sky(c, "#E3D7F6", "#F3ECFB")
    for x, col in ((100, "#FFF2B8"), (300, "#FFD9EA")):
        c.felt(kit.poly([(x - 14, 0), (x + 14, 0), (x + 80, 230), (x - 80, 230)]), col, edge=0, op=.45)
    flags = ["#F7A8B8", "#FFD27A", "#9FD8A6", "#9CC8F0", "#C7A6F0"]
    c.stroke(kit.curve([(0, 14), (100, 34), (200, 40), (300, 34), (400, 14)]), "#B49ACB", 2)
    for i in range(14):
        t = (i + .5) / 14
        x = t * W
        y = 14 + 26 * math.sin(math.pi * t)
        c.felt(kit.poly([(x - 9, y), (x + 9, y), (x, y + 18)]), flags[i % 5], edge=1)
    floor(c, 206, "#E8C9A2")
    for i in range(9):
        c.stroke(kit.path([(i * 50, 206), (i * 50 - 20, 250)]), "#D9B48A", 1.6, op=.7)


def calm(c):
    sky(c, "#E6E0F5", "#DDF1E4")
    c.felt(kit.circle(320, 58, 20), "#FFF1C9", edge=1)
    hill(c, 190, 26, "#D3EAD8", "c1", 1.2)
    hill(c, 210, 14, "#C8E5CF", "c2", 2, 1.5)
    floor(c, 226, "#E4F1E2")


def rest(c):
    sky(c, "#2F3470", "#6D5FA8")
    c.felt(kit.Shape([("M", 330, 30), ("C", 300, 40, 296, 86, 330, 96), ("C", 306, 80, 306, 46, 330, 30), ("Z",)]), "#FFE9A8", edge=1.2)
    for i, (x, y) in enumerate(((60, 40), (120, 70), (200, 30), (250, 80), (40, 110), (380, 120), (160, 110))):
        c.sparkle(x, y, 5 + i % 3, "#FFF2C2", .9)
    hill(c, 200, 22, "#4B4A8C", "n1", 1.4)
    floor(c, 222, "#5A5596")


SCENES = {"home": home, "jungle": jungle, "zoo": zoo, "sea": sea, "rain": rain, "mountain": mountain, "party": party, "calm": calm, "rest": rest}


def build():
    out = kit.ART / "scenes"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.svg"):
        old.unlink()
    total = 0
    for name, f in SCENES.items():
        c = kit.Ctx(W, H)
        f(c)
        total += kit.write_svg(out / f"{name}.svg", c.svg(), (W, H))
    print(f"scenes: {len(SCENES)}, {total:.0f} KB")


if __name__ == "__main__":
    build()
