"""「像這樣」: a child showing how a person does each move (docs/design.md 「跟著做」), because an
animal's legs are not a child's. The child is a pom-pom and pipe-cleaner puppet like the animals: a
pom-pom head with felt hair and googly eyes, a pom-pom shirt, pipe-cleaner arms and legs, felt shoes.

Canvas 160 x 160, the floor at y = 150. A pose gives the hip (dx, dy from standing), the torso's
angle t (0 upright, 90 lying along the floor with the head to the right, negative leaning left), and
two angles for each arm and leg (kit.limb: 0 down, 90 right, 180 up). view "side" draws the child
side on, facing right (crawling, lying, kneeling).

    python3 build.py kids         # writes app/assets/art/kids/<move>_<a|b>.svg
"""
import math

import kit
from kit import limb

W = H = 160
FLOOR = 150
SHIRT = "#FFB648"
PANTS = "#4B6FC2"
SKIN = kit.SKIN
HAIR = "#6B4428"
SHOE = "#E9566A"
ARM, LEG = (21, 19), (23, 23)


def _dir(t):
    a = math.radians(t)
    return math.sin(a), -math.cos(a)            # the way the torso points (up when t = 0)


def kid(c, P, key):
    view = P.get("view", "front")
    hip = (80 + P.get("dx", 0), FLOOR - sum(LEG) - 4 + P.get("dy", 0))
    t = P.get("t", 0)
    ux, uy = _dir(t)
    px, py = -uy, ux                            # across the body
    body = (hip[0] + ux * 17, hip[1] + uy * 17)
    sh = (hip[0] + ux * 29, hip[1] + uy * 29)
    head = (hip[0] + ux * 47 + P.get("hx", 0), hip[1] + uy * 47 + P.get("hy", 0))
    if view == "front":
        shoulders = [(sh[0] - px * 12, sh[1] - py * 12), (sh[0] + px * 12, sh[1] + py * 12)]
        hips = [(hip[0] - px * 6, hip[1] - py * 6), (hip[0] + px * 6, hip[1] + py * 6)]
    else:
        shoulders = [sh, sh]
        hips = [hip, hip]
    la = limb(shoulders[0], P.get("la", (-20, -10)), ARM)
    ra = limb(shoulders[1], P.get("ra", (20, 10)), ARM)
    ll = limb(hips[0], P.get("ll", (-4, 0)), LEG)
    rl = limb(hips[1], P.get("rl", (4, 0)), LEG)
    if not P.get("float"):
        c.ground(hip[0] + (ux * 20 if view == "side" else 0), FLOOR + 3, 42, op=.1)
    far = view == "side"
    # the far arm and leg first, a little darker, when side on
    for pts, col, w, end in ((rl, PANTS, 7, "shoe"), (ra, SKIN, 6, "hand")):
        if far:
            _limb(c, pts, kit.mix(col, kit.INK, .25), w, end, key + "far", dark=True)
    if not far:
        _limb(c, ll, PANTS, 7, "shoe", key + "ll")
        _limb(c, rl, PANTS, 7, "shoe", key + "rl")
    else:
        _limb(c, ll, PANTS, 7, "shoe", key + "ll")
    c.pom(body[0], body[1], 15, 19, SHIRT, key=key + "body", rot=t, edge=2.8)
    c.pom(hip[0] + ux * 4, hip[1] + uy * 4, 12, 7, PANTS, key=key + "pants", rot=t, edge=2.4, fibres=False)
    _head(c, head, P, key, view, t)
    _limb(c, la, SKIN, 6, "hand", key + "la")
    if not far:
        _limb(c, ra, SKIN, 6, "hand", key + "ra")


def _limb(c, pts, col, w, end, key, dark=False):
    c.cleaner(pts, col, w, edge=2.0)
    x, y = pts[-1]
    if end == "shoe":
        c.felt(kit.ellipse(x + 2, y + 2, 7, 4.5), kit.mix(SHOE, kit.INK, .25 if dark else 0), edge=1.2)
    else:
        c.pom(x, y, 4.5, 4.5, kit.mix(SKIN, kit.INK, .2 if dark else 0), key=key + "hand", edge=1.8, fibres=False)


def _head(c, head, P, key, view, t):
    x, y = head
    r = 16
    tilt = P.get("ht", 0) + (t if view == "side" else 0) * .3
    c.felt(kit.ellipse(x, y - 3, r + 3, r + 1).rotate(tilt, x, y), HAIR, edge=2)
    c.pom(x, y + 1, r, r - 1, SKIN, key=key + "head", edge=2.6, fibres=False)
    c.felt(kit.Shape([("M", x - r - 1, y - 2), ("C", x - r, y - r - 6, x + r, y - r - 6, x + r + 1, y - 2),
                      ("C", x + r * .4, y - r * .55, x - r * .4, y - r * .2, x - r - 1, y - 2), ("Z",)]).rotate(tilt, x, y), HAIR, edge=1.2)
    look = P.get("look", (0, .2))
    closed = P.get("eyes") == "closed"
    if view == "side":
        c.googly(x + 6, y + 1, 4.2, (.6, .1), closed=closed)
        c.mouth(x + 10, y + 8, 6, P.get("mouth", 0))
        c.cheeks(x + 4, y + 7, 1, 2.5)
    else:
        for s in (-1, 1):
            c.googly(x + s * 6, y + 1, 4.2, look, closed=closed)
        c.mouth(x, y + 8, 7, P.get("mouth", 0))
        c.cheeks(x, y + 6, 18, 2.5)


S = dict(view="side")
POSES = {
    "frog": (dict(dy=24, ll=(-72, -5), rl=(72, 5), la=(-12, -2), ra=(12, 2), look=(0, .5)),
             dict(dy=-16, ll=(-10, 6), rl=(10, -6), la=(-160, -175), ra=(160, 175), mouth=.7, look=(0, -.5), float=True)),
    "bunny": (dict(dy=10, ll=(-35, 12), rl=(35, -12), la=(30, 150), ra=(-30, -150)),
              dict(dy=-12, ll=(-3, 0), rl=(3, 0), la=(30, 150), ra=(-30, -150), mouth=.5, float=True)),
    "kangaroo": (dict(dy=14, ll=(-45, 18), rl=(45, -18), la=(-35, -20), ra=(35, 20)),
                 dict(dy=-18, la=(-170, -178), ra=(170, 178), mouth=.6, look=(0, -.5), float=True)),
    "bear": (dict(S, dy=-6, t=98, ll=(-8, 4), rl=(8, -2), la=(14, 4), ra=(-8, -2)),
             dict(S, dy=-6, t=98, ll=(8, -2), rl=(-8, 4), la=(-8, -2), ra=(14, 4))),
    "crab": (dict(dy=20, ll=(-62, 0), rl=(62, 0), la=(-150, -120), ra=(150, 120)),
             dict(dy=20, dx=8, ll=(-50, 0), rl=(70, 0), la=(-135, -105), ra=(135, 105))),
    "penguin": (dict(t=-8, ll=(-3, 0), rl=(3, 0), la=(-22, -22), ra=(22, 22)),
                dict(t=8, ll=(-3, 0), rl=(3, 0), la=(-22, -22), ra=(22, 22))),
    "duck": (dict(dy=22, ll=(-60, 0), rl=(45, 5), la=(-75, 50), ra=(75, -50)),
             dict(dy=22, ll=(-45, -5), rl=(60, 0), la=(-75, 50), ra=(75, -50), mouth=.4)),
    "tiptoe": (dict(dy=-4, ll=(-6, 0), rl=(14, -6), la=(-60, -85), ra=(60, 85), look=(.5, .2)),
               dict(dy=-4, ll=(-14, 6), rl=(6, 0), la=(-60, -85), ra=(60, 85), look=(-.5, .2))),
    "deer": (dict(ll=(-24, -4), rl=(24, 8), la=(-30, -20), ra=(30, 20)),
             dict(dy=-12, ll=(-42, -18), rl=(46, 28), la=(-80, -70), ra=(80, 70), mouth=.5, float=True)),
    "elephant": (dict(ll=(-22, 18), rl=(4, 0), la=(8, -30), ra=(-22, -48), dy=-4, look=(-.5, .3)),
                 dict(ll=(-4, 0), rl=(22, -18), la=(22, 48), ra=(-8, 30), dy=-4, look=(.5, .3))),
    "snake": (dict(S, dy=42, t=88, ll=(-86, -92), rl=(-88, -94), la=(88, 92), ra=(86, 90), look=(.5, 0)),
              dict(S, dy=42, t=94, ll=(-94, -86), rl=(-96, -88), la=(94, 86), ra=(92, 84))),
    "fish": (dict(t=-8, la=(35, 125), ra=(-35, -125)),
             dict(t=8, la=(35, 125), ra=(-35, -125))),
    "bird": (dict(la=(-120, -110), ra=(120, 110), look=(0, -.3)),
             dict(la=(-55, -45), ra=(55, 45))),
    "salmon": (dict(ll=(-35, 30), rl=(4, 0), dy=-2, la=(-30, -20), ra=(-30, -75)),
               dict(ll=(-4, 0), rl=(35, -30), dy=-2, la=(30, 75), ra=(30, 20))),
    "flamingo": (dict(rl=(40, -65), la=(-20, -10), ra=(20, 10)),
                 dict(rl=(40, -65), la=(-92, -96), ra=(92, 96), look=(0, 0))),
    "giraffe": (dict(la=(-168, -176), ra=(168, 176), look=(0, -.5)),
                dict(dy=-6, la=(-174, -180), ra=(174, 180), look=(0, -.7), mouth=.4)),
    "sloth": (dict(la=(-150, -170), ra=(20, 10), ll=(-4, 0), rl=(25, -10), eyes="closed"),
              dict(la=(-20, -10), ra=(150, 170), ll=(-25, 10), rl=(4, 0), eyes="closed")),
    "starfish": (dict(ll=(-3, 0), rl=(3, 0), la=(-12, -6), ra=(12, 6)),
                 dict(ll=(-28, -28), rl=(28, 28), la=(-125, -125), ra=(125, 125), mouth=.5)),
    "jellyfish": (dict(dy=6, ll=(-12, 8), rl=(12, -8), la=(-150, -95), ra=(150, 95), look=(0, -.3)),
                  dict(la=(-70, -20), ra=(70, 20))),
    "octopus": (dict(dy=44, ll=(-62, -10), rl=(62, 10), la=(-100, -60), ra=(100, 140)),
                dict(dy=44, ll=(-58, 10), rl=(66, -10), la=(-140, -80), ra=(60, 100), mouth=.4)),
    "seaturtle": (dict(S, dy=42, t=90, ll=(-84, -84), rl=(-80, -80), la=(84, 84), ra=(80, 80)),
                  dict(S, dy=38, t=86, ll=(-106, -110), rl=(-102, -106), la=(106, 110), ra=(102, 106), mouth=.4)),
    "monkey": (dict(la=(-150, 100), ra=(150, -100), look=(0, -.5)),
               dict(dy=8, ll=(-20, 12), rl=(20, -12), la=(-6, 8), ra=(6, -8), look=(0, .6))),
    "squirrel": (dict(dy=18, t=-16, ll=(-52, 0), rl=(40, 0), la=(-25, -20), ra=(30, 20), look=(-.5, .6)),
                 dict(la=(40, 100), ra=(20, 10), look=(.5, .3), mouth=.3)),
    "lion": (dict(dy=26, ll=(-25, 80), rl=(25, -80), la=(-8, 12), ra=(8, -12)),
             dict(dy=26, ll=(-25, 80), rl=(25, -80), la=(-108, -122), ra=(108, 122), mouth=1.0)),
    "tortoise": (dict(S, dy=22, t=104, ll=(30, -90), rl=(30, -90), la=(20, 60), ra=(20, 60), eyes="closed"),
                 dict(S, dy=20, t=40, ll=(30, -90), rl=(30, -90), la=(110, 104), ra=(104, 100), mouth=.3)),
    "catarch": (dict(S, dy=22, t=94, ll=(0, -90), rl=(0, -90), la=(2, 0), ra=(-2, 0)),
                dict(S, dy=16, t=82, ll=(4, -92), rl=(4, -92), la=(14, 6), ra=(10, 4), hy=6, eyes="closed")),
    "butterfly": (dict(dy=44, ll=(-78, 62), rl=(78, -62), la=(20, 10), ra=(-20, -10)),
                  dict(dy=44, ll=(-62, 70), rl=(62, -70), la=(25, 15), ra=(-25, -15), mouth=.4)),
    "pangolin": (dict(dy=40, ll=(-22, 165), rl=(22, -165), la=(30, 85), ra=(-30, -85), ht=10, eyes="closed"),
                 dict(dy=44, ll=(-60, -5), rl=(60, 5), la=(-100, -112), ra=(100, 112), mouth=.4)),
    "rainbow": (dict(t=-16, la=(-150, -140), ra=(200, 212), look=(-.5, -.3)),
                dict(t=16, la=(150, 140), ra=(-200, -212), look=(.5, -.3))),
}


# Quiet mode (docs/design.md 「安全」 3): the second pose of these moves leaves the floor, so quiet
# mode shows the child with the feet down instead (moves.dart `quietKids`, `kids/<move>-quiet_b.svg`).
QUIET = {
    "frog": dict(ll=(-4, 0), rl=(4, 0), la=(-160, -175), ra=(160, 175), mouth=.7, look=(0, -.5)),      # stand up, 呱
    "bunny": dict(dy=-4, ll=(-3, 0), rl=(3, 0), la=(30, 150), ra=(-30, -150), mouth=.5),             # up on tiptoe
    "kangaroo": dict(dy=-4, la=(-170, -178), ra=(170, 178), mouth=.6, look=(0, -.5)),                 # tiptoe, arms up
    "deer": dict(ll=(-34, -10), rl=(16, 2), la=(-14, -8), ra=(34, 24), mouth=.3),                      # a big step
}


def draw(move, frame):
    c = kit.Ctx(W, H)
    if frame == "quiet":
        kid(c, QUIET[move], f"kid{move}q")
        return c
    kid(c, POSES[move]["ab".index(frame)], f"kid{move}{frame}")
    return c


def build():
    out = kit.ART / "kids"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.svg"):
        old.unlink()
    total = 0
    for move in POSES:
        for f in "ab":
            total += kit.write_svg(out / f"{move}_{f}.svg", draw(move, f).svg(), (W, H))
    for move in QUIET:
        total += kit.write_svg(out / f"{move}-quiet_b.svg", draw(move, "quiet").svg(), (W, H))
    print(f"kids: {len(POSES) * 2 + len(QUIET)} poses, {total:.0f} KB")


if __name__ == "__main__":
    build()
