"""The little pictures of the screens (docs/art.md 「畫面上的小圖」), in the same felt and pom-pom
look: the three big home buttons, the lock, the 「去過了」 stamp, the tick, the breathing flower
(open and closed), and the five cards of 「先看看四周」.

    python3 build.py ui           # writes app/assets/art/ui/*.svg and app/assets/art/safety/*.svg
"""
import math

import kit
import kids

U = 160


def party(c):
    c.pom(80, 70, 40, 40, "#B9A2EC", key="ball")
    for i in range(4):
        for j in range(4):
            x, y = 58 + i * 14, 48 + j * 14
            if math.hypot(x - 80, y - 70) < 34:
                c.felt(kit.rrect(x - 5, y - 5, 10, 10, 2), kit.mix("#B9A2EC", kit.WHITE, .45 if (i + j) % 2 else .15), edge=0)
    c.stroke(kit.path([(80, 30), (80, 6)]), kit.GREY, 3)
    for x, y, col in ((26, 122, kit.PINK), (124, 128, kit.YELLOW)):
        c.felt(kit.ellipse(x, y, 11, 8).rotate(-20, x, y), col, edge=1.6)
        c.stroke(kit.path([(x + 9, y - 3), (x + 9, y - 36), (x + 22, y - 30)]), kit.mix(col, kit.INK, .45), 4)
    c.sparkle(130, 40, 10, kit.YELLOW)
    c.sparkle(30, 50, 7, kit.PINK)


def build_(c):
    for i, (dx, rot, col) in enumerate(((-28, -12, "#9FD8A6"), (0, 0, "#FFD27A"), (28, 12, "#9CC8F0"))):
        x, y = 80 + dx, 86 + abs(dx) * .3
        c.felt(kit.rrect(x - 26, y - 36, 52, 70, 10).rotate(rot, x, y), kit.WHITE, edge=2.2)
        c.pom(x, y - 6, 15, 14, col, key=f"card{i}", rot=rot, edge=2.6, fibres=False)
        c.googly(x - 5, y - 9, 3.5)
        c.googly(x + 5, y - 9, 3.5)
    c.felt(kit.rrect(30, 132, 100, 10, 5), kit.mix(kit.TAN, kit.WHITE, .3), edge=1.4)


def flower(c, open_=True, face=True):
    cx, cy = 80, 78
    c.cleaner([(80, 110), (78, 135), (80, 158)], kit.GREEN, 8, twist=False)
    c.felt(kit.ellipse(64, 138, 16, 7).rotate(-30, 64, 138), kit.GREEN, edge=1.4)
    if open_:
        for i in range(8):
            a = 2 * math.pi * i / 8
            c.pom(cx + math.cos(a) * 36, cy + math.sin(a) * 36, 20, 14, "#F7A8C4", key=f"petal{i}", rot=math.degrees(a), edge=2.6, fibres=False)
        c.pom(cx, cy, 26, 26, kit.YELLOW, key="middle", edge=2.8)
        if face:
            c.googly(cx - 9, cy - 3, 5.5, (0, .2))
            c.googly(cx + 9, cy - 3, 5.5, (0, .2))
            c.mouth(cx, cy + 8, 10, .4)
    else:
        for i, (dx, rot) in enumerate(((-14, -14), (14, 14), (0, 0))):
            c.pom(cx + dx, cy + 10, 18, 36, "#F7A8C4" if i < 2 else "#F4B6CE", key=f"bud{i}", rot=rot, edge=2.6, fibres=False)
        if face:
            c.googly(cx - 7, cy + 14, 4, closed=True)
            c.googly(cx + 7, cy + 14, 4, closed=True)


def calm(c):
    flower(c, True)


def lock(c):
    c.stroke(kit.arc(80, 70, 26, 180, 360), "#8A8496", 12)
    c.felt(kit.rrect(42, 66, 76, 64, 16), kit.GOLD, edge=2.4)
    c.felt(kit.circle(80, 92, 8), kit.mix(kit.GOLD, kit.INK, .55), edge=0)
    c.felt(kit.rrect(77, 96, 6, 18, 3), kit.mix(kit.GOLD, kit.INK, .55), edge=0)


def stamp(c):
    red = kit.RED
    c.path_el(kit.circle(80, 80, 62).d(), "none", red, 8)
    c.path_el(kit.circle(80, 80, 50).d(), "none", red, 3)
    c.felt(kit.ellipse(80, 96, 20, 16), red, edge=0)
    for x, y in ((56, 70), (70, 56), (90, 56), (104, 70)):
        c.felt(kit.ellipse(x, y, 8, 10), red, edge=0)


def check(c):
    c.pom(80, 80, 62, 62, kit.GREEN, key="check", edge=4)
    c.stroke(kit.path([(48, 82), (72, 106), (114, 58)]), kit.WHITE, 16)


ICONS = {"party": party, "build": build_, "calm": calm, "lock": lock, "stamp": stamp, "check": check,
         "flower_open": lambda c: flower(c, True), "flower_closed": lambda c: flower(c, False)}


# ---------------------------------------------------------------- 先看看四周
SW, SH = 200, 150


def _floor(c):
    c.felt(kit.rrect(4, 4, SW - 8, SH - 8, 18), "#FFF8EC", edge=0)
    c.felt(kit.rect(4, 112, SW - 8, 34), "#F1E2C8", edge=0)


def no_sign(c, x, y, r):
    c.path_el(kit.circle(x, y, r).d(), "none", kit.RED, r * .2)
    c.stroke(kit.path([(x - r * .7, y - r * .7), (x + r * .7, y + r * .7)]), kit.RED, r * .2)


def clear(c):
    _floor(c)
    c.felt(kit.rrect(14, 74, 46, 8, 3), kit.TAN, edge=1.6)
    for x in (18, 52):
        c.felt(kit.rect(x, 82, 5, 34), kit.mix(kit.TAN, kit.INK, .2), edge=1)
    c.felt(kit.rrect(150, 70, 30, 6, 3), kit.SKY, edge=1.4)
    c.felt(kit.rect(150, 48, 6, 28), kit.SKY, edge=1.4)
    for x in (150, 174):
        c.felt(kit.rect(x, 76, 5, 38), kit.mix(kit.SKY, kit.INK, .2), edge=1)
    for x0, x1 in ((96, 70), (106, 136)):
        c.stroke(kit.path([(x0, 120), (x1, 120)]), kit.ORANGE, 5)
        s = 1 if x1 > x0 else -1
        c.stroke(kit.path([(x1 - s * 8, 113), (x1, 120), (x1 - s * 8, 127)]), kit.ORANGE, 5)
    c.felt(kit.ellipse(100, 128, 30, 8), "#DFF2D2", edge=0)


def nobed(c):
    _floor(c)
    c.felt(kit.rrect(30, 70, 140, 40, 10), "#9CC8F0", edge=2)
    c.felt(kit.rrect(30, 54, 34, 30, 8), kit.WHITE, edge=1.6)
    c.felt(kit.rect(34, 108, 8, 14), kit.TAN, edge=1)
    c.felt(kit.rect(158, 108, 8, 14), kit.TAN, edge=1)
    c.begin("translate(56 17) scale(.5)")
    kids.kid(c, dict(dy=-60, la=(-160, -175), ra=(160, 175), ll=(-10, 6), rl=(10, -6), float=True), "nobedkid")
    c.end()
    no_sign(c, 166, 38, 22)


def feet(c):
    _floor(c)
    for x, flip in ((50, 1), (90, -1)):
        c.pom(x, 92, 16, 28, kit.SKIN, key=f"foot{x}", edge=2.6, fibres=False)
        for k in range(5):
            c.pom(x - flip * (12 - k * 6), 62 + abs(k - 1.5) * 2.5, 4.5 - k * .4, 4.5 - k * .4, kit.SKIN, key=f"toe{x}{k}", edge=1.8, fibres=False)
    c.felt(kit.Shape([("M", 130, 40), ("L", 160, 40), ("L", 160, 96), ("C", 160, 120, 186, 112, 186, 126), ("C", 186, 138, 150, 140, 136, 132),
                      ("C", 124, 124, 130, 108, 130, 96), ("Z",)]), "#F7B6CF", edge=2)
    c.dots([(140, 120), (150, 126), (162, 128), (174, 126), (146, 112), (158, 116)], 2.6, kit.mix(kit.ROSE, kit.INK, .3))


def phone(c):
    _floor(c)
    c.felt(kit.rrect(20, 82, 90, 10, 4), kit.TAN, edge=1.6)
    for x in (26, 98):
        c.felt(kit.rect(x, 92, 6, 26), kit.mix(kit.TAN, kit.INK, .2), edge=1)
    c.felt(kit.rrect(30, 62, 26, 20, 3), kit.BLUE, edge=1.4)
    c.felt(kit.rrect(56, 30, 44, 52, 6).rotate(-8, 78, 56), kit.DARK, edge=1.4)
    c.felt(kit.rrect(60, 34, 36, 42, 3).rotate(-8, 78, 56), "#BFE6F7", edge=0)
    c.pom(78, 58, 9, 8, kit.GREEN, key="phonefrog", edge=1.8, fibres=False)
    c.stroke(kit.path([(118, 120), (176, 120)]), kit.GREEN, 4)
    c.stroke(kit.path([(126, 113), (118, 120), (126, 127)]), kit.GREEN, 4)
    c.stroke(kit.path([(168, 113), (176, 120), (168, 127)]), kit.GREEN, 4)
    c.begin("translate(124 18) scale(.5)")
    kids.kid(c, dict(la=(-60, -40), ra=(60, 40)), "phonekid")
    c.end()


def spin(c):
    c.felt(kit.ellipse(100, 128, 92, 18), "#F1E2C8", edge=0)
    for i in range(18):
        a0 = i * 20
        c.stroke(kit.arc(100, 128, 86, a0, a0 + 10).scale(1, 100, 128, sy=.2), kit.ORANGE, 4)
    c.begin("translate(20 -14) scale(1.0)")
    kids.kid(c, dict(la=(-92, -92), ra=(92, 92), mouth=.4), "spinkid")
    c.end()
    for s in (-1, 1):
        x = 100 + s * 84
        c.stroke(kit.arc(x, 60, 14, 200 if s < 0 else -20, 290 if s < 0 else 70), kit.BLUE, 3.5)


SAFETY = {"clear": clear, "nobed": nobed, "feet": feet, "phone": phone, "spin": spin}


def build():
    out = kit.ART / "ui"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.svg"):
        old.unlink()
    total = 0
    for name, f in ICONS.items():
        c = kit.Ctx(U, U)
        f(c)
        total += kit.write_svg(out / f"{name}.svg", c.svg(), (U, U))
    sout = kit.ART / "safety"
    sout.mkdir(parents=True, exist_ok=True)
    for old in sout.glob("*.svg"):
        old.unlink()
    for name, f in SAFETY.items():
        c = kit.Ctx(SW, SH) if name != "spin" else kit.Ctx(200, 160)
        f(c)
        total += kit.write_svg(sout / f"{name}.svg", c.svg())
    print(f"ui: {len(ICONS)} icons, {len(SAFETY)} safety cards, {total:.0f} KB")


if __name__ == "__main__":
    build()
