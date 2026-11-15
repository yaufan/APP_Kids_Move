"""The animals of 動物動一動, each move in two poses (docs/art.md 「動物」).

Every animal is a pom-pom puppet (kit.py) on a 300 x 240 canvas, standing on the floor at y = 222,
facing the child (or, for crawling and swimming, side on, facing right). Two rigs do most of them:

- `biped`: a front-facing puppet: body and head pom-poms, pipe-cleaner arms and legs from shoulders
  and hips, each limb two segments at angles (kit.limb: 0 is straight down, 90 to the right, 180 up).
- `quad`: a side-on puppet on four legs (the bear crawling, the leopard cat, the deer leaping).

The rest are drawn on their own (the snake, fish, turtles, starfish, jellyfish, octopus, crab,
butterfly). A look (`L`) says what an animal is like; a pose (`P`) says what it is doing.
MOVES lists, for every move, the animal and its two poses a and b; the app switches between them on
the beat (lib/app/figures.dart) and moves the whole puppet too.

    python3 build.py animals      # writes app/assets/art/moves/<move>_<a|b>.svg
"""
import math

import kit
from kit import limb

G = 222          # the floor
W, H = 300, 240


def _rot(cx, cy, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return lambda x, y: (cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca)


def _rotp(p, cx, cy, deg):
    return _rot(cx, cy, deg)(*p)


# ================================================================ the front-facing rig
def biped(c, P, L, key):
    """A front-facing pom-pom puppet. L: body (rx, ry), col, head r, hcol, arm/leg lengths and
    widths, limb colours, paw/foot, and optional callables back, legs_back, ears, body_deco, face,
    front (each called with c, g, P). P: dx, dy, tilt, hx, hy, la, ra, ll, rl, look, mouth, eyes."""
    rx, ry = L["body"]
    hr = L["head"]
    arm, aw, leg, lw = L["arm"], L["aw"], L["leg"], L["lw"]
    bx = 150 + P.get("dx", 0)
    by = G - leg - ry * .7 - L.get("foot_h", 6) + P.get("dy", 0)
    tilt = P.get("tilt", 0)
    R = _rot(bx, by, tilt)
    sh = [R(bx - rx * L.get("sh", .78), by - ry * .36), R(bx + rx * L.get("sh", .78), by - ry * .36)]
    hp = [R(bx - rx * .42, by + ry * .72), R(bx + rx * .42, by + ry * .72)]
    hc = R(bx + P.get("hx", 0), by - ry - hr * L.get("neck", .5) + P.get("hy", 0))
    la = limb(sh[0], P.get("la", (-28, -12)), (arm * .52, arm * .5))
    ra = limb(sh[1], P.get("ra", (28, 12)), (arm * .52, arm * .5))
    ll = limb(hp[0], P.get("ll", (-5, 0)), (leg * .5, leg * .52))
    rl = limb(hp[1], P.get("rl", (5, 0)), (leg * .5, leg * .52))
    g = dict(bx=bx, by=by, rx=rx, ry=ry, tilt=tilt, hx=hc[0], hy=hc[1], hr=hr, la=la, ra=ra, ll=ll, rl=rl, sh=sh, hp=hp, key=key, R=R)
    if not P.get("float"):
        c.ground(bx, G + 4, rx * 1.2 + 10)
    if "back" in L:
        L["back"](c, g, P)
    lcol = L.get("lcol", L["col"])
    for side, pts in (("l", ll), ("r", rl)):
        if P.get("hide_" + side + "l"):
            continue
        c.cleaner(pts, lcol, lw)
        L.get("foot", _foot)(c, g, pts[-1], side, P)
    c.pom(bx, by, rx, ry, L["col"], key=key + "body", rot=tilt)
    if "body_deco" in L:
        L["body_deco"](c, g, P)
    if "ears" in L:
        L["ears"](c, g, P)
    c.pom(hc[0], hc[1], hr * L.get("hw", 1.0), hr, L.get("hcol", L["col"]), key=key + "head", rot=P.get("htilt", 0) + tilt)
    L.get("face", _face)(c, g, P)
    acol = L.get("acol", lcol)
    for side, pts in (("l", la), ("r", ra)):
        if P.get("hide_" + side + "a"):
            continue
        if "arm_draw" in L:
            L["arm_draw"](c, g, pts, side, P)
        else:
            c.cleaner(pts, acol, aw)
            L.get("paw", _paw)(c, g, pts[-1], side, P)
    if "front" in L:
        L["front"](c, g, P)
    return g


def _foot(c, g, p, side, P):
    x, y = p
    s = -1 if side == "l" else 1
    c.felt(kit.ellipse(x + s * 4, y + 3, 11, 6), g.get("footcol", kit.mix(kit.TAN, kit.INK, .15)))


def _paw(c, g, p, side, P):
    c.pom(p[0], p[1], 6, 6, kit.mix(kit.TAN, kit.WHITE, .2), key=g["key"] + "paw" + side, edge=2.2, fibres=False)


def _face(c, g, P, gap=.42, eye=.3, mouth_y=.42):
    hx, hy, hr = g["hx"], g["hy"], g["hr"]
    look = P.get("look", (0, .2))
    for s in (-1, 1):
        c.googly(hx + s * hr * gap, hy - hr * .1, hr * eye, look, closed=P.get("eyes") == "closed")
    c.mouth(hx, hy + hr * mouth_y, hr * .42, P.get("mouth", 0))


def nose(c, x, y, r, col=kit.INK):
    c.felt(kit.ellipse(x, y, r, r * .72), col, edge=0)
    c.path_el(kit.ellipse(x - r * .3, y - r * .3, r * .3, r * .2).d(), kit.WHITE, op=.7)


def muzzle_face(c, g, P, col, nose_col=kit.INK, gap=.4, eye=.27, my=.42, mw=.42, mh=.3):
    """A face with a lighter muzzle and a nose (bear, cat, deer, monkey, lion, kangaroo)."""
    hx, hy, hr = g["hx"], g["hy"], g["hr"]
    c.felt(kit.ellipse(hx, hy + hr * my, hr * mw, hr * mh), col, edge=1.2)
    look = P.get("look", (0, .2))
    for s in (-1, 1):
        c.googly(hx + s * hr * gap, hy - hr * .14, hr * eye, look, closed=P.get("eyes") == "closed")
    nose(c, hx, hy + hr * (my - .1), hr * .12, nose_col)
    c.mouth(hx, hy + hr * (my + .12), hr * .3, P.get("mouth", 0))


def round_ears(col, inner, r=.36, at=.78, spread=.72):
    def ears(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        for s in (-1, 1):
            x, y = hx + s * hr * spread, hy - hr * at
            c.pom(x, y, hr * r, hr * r, col, key=g["key"] + "ear" + str(s), edge=2.6, fibres=False)
            c.felt(kit.circle(x, y + hr * .03, hr * r * .55), inner, edge=0)
    return ears


def tall_ears(col, inner, h=1.0, w=.28, spread=.42, lean=10):
    def ears(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        for s in (-1, 1):
            x, y = hx + s * hr * spread, hy - hr * (.75 + .5 * h)
            rot = s * (lean + P.get("ear_flop", 0))
            c.pom(x, y, hr * w, hr * .62 * h, col, key=g["key"] + "ear" + str(s), rot=rot, edge=2.6, fibres=False)
            c.felt(kit.ellipse(x, y + hr * .05, hr * w * .45, hr * .45 * h).rotate(rot, x, y), inner, edge=0)
    return ears


def pointy_ears(col, inner, size=.42, spread=.62):
    def ears(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        for s in (-1, 1):
            bx, by = hx + s * hr * spread, hy - hr * .55
            tip = (hx + s * hr * (spread + .12), hy - hr * (.62 + size * 1.3))
            pts = [(bx - hr * size * .55, by + hr * .1), tip, (bx + hr * size * .55, by + hr * .1)]
            c.felt(kit.smooth(pts, .2), col, edge=2.4)
            c.felt(kit.smooth([(bx - hr * size * .28, by), ((tip[0] * 2 + bx) / 3, (tip[1] * 2 + by) / 3 + 3), (bx + hr * size * .28, by)], .2), inner, edge=0)
    return ears


def tail(points, col, w=9):
    def back(c, g, P):
        pts = [(g["bx"] + x, g["by"] + y) for x, y in points]
        c.cleaner(pts, col, w)
    return back


def spots(points, col, r=5.0):
    def deco(c, g, P):
        for i, (x, y) in enumerate(points):
            px, py = g["R"](g["bx"] + x * g["rx"], g["by"] + y * g["ry"])
            c.felt(kit.blob(px, py, r, r * .85, lumps=6, wobble=.2, key=f"spot{i}"), col, edge=0)
    return deco


def belly(col, w=.62, h=.66, y=.18):
    def deco(c, g, P):
        cx, cy = g["R"](g["bx"], g["by"] + g["ry"] * y)
        c.felt(kit.ellipse(cx, cy, g["rx"] * w, g["ry"] * h).rotate(g["tilt"], cx, cy), col, edge=1.2)
    return deco


def chain(*fns):
    def run(c, g, P):
        for f in fns:
            f(c, g, P)
    return run


# ================================================================ the side-on rig
def quad(c, P, L, key):
    """A side-on puppet on four legs, facing right. L: body (rx, ry), col, head r, leg length and
    width, snout, ears, tail, deco. P: dx, dy, tilt (clockwise lifts the back end), hx, hy, legs
    fn, ff, bn, bf (near/far front/back, two angles each)."""
    rx, ry = L["body"]
    hr = L["head"]
    leg, lw = L["leg"], L["lw"]
    bx = 145 + P.get("dx", 0)
    by = G - leg - ry * .55 + P.get("dy", 0)
    tilt = P.get("tilt", 0)
    R = _rot(bx, by, tilt)
    fh, bh = R(bx + rx * .55, by + ry * .5), R(bx - rx * .55, by + ry * .5)
    hc = R(bx + rx * .92 + P.get("hx", 0), by - ry * .55 + P.get("hy", 0))
    legs = {}
    for k in ("fn", "ff", "bn", "bf"):
        hip = fh if k[0] == "f" else bh
        legs[k] = limb((hip[0] + (-5 if k[1] == "f" else 2), hip[1]), P.get(k, (0, 0)), (leg * .52, leg * .52))
    g = dict(bx=bx, by=by, rx=rx, ry=ry, tilt=tilt, hx=hc[0], hy=hc[1], hr=hr, legs=legs, key=key, R=R)
    c.ground(bx + 10, G + 4, rx * 1.35)
    far = kit.mix(L.get("lcol", L["col"]), kit.INK, .3)
    for k in ("ff", "bf"):
        c.cleaner(legs[k], far, lw)
        c.felt(kit.ellipse(legs[k][-1][0] + 3, legs[k][-1][1] + 2, lw * .8, lw * .45), kit.mix(far, kit.INK, .2), edge=1)
    if "tail" in L:
        L["tail"](c, g, P)
    if "neck" in L:
        L["neck"](c, g, P)
    if P.get("arch"):
        c.pom(bx, by - ry * .7, rx * .62, ry * 1.1, L["col"], key=key + "hump")
    c.pom(bx, by, rx, ry, L["col"], key=key + "body", rot=tilt)
    if "deco" in L:
        L["deco"](c, g, P)
    near = L.get("lcol", L["col"])
    for k in ("fn", "bn"):
        c.cleaner(legs[k], near, lw)
        c.felt(kit.ellipse(legs[k][-1][0] + 3, legs[k][-1][1] + 2, lw * .85, lw * .5), kit.mix(near, kit.INK, .25), edge=1)
    if "ears" in L:
        L["ears"](c, g, P)
    c.pom(hc[0], hc[1], hr * L.get("hw", 1.08), hr, L.get("hcol", L["col"]), key=key + "head", rot=P.get("htilt", 0))
    L["face"](c, g, P)
    return g


def side_face(c, g, P, snout_col, nose_col=kit.INK, eye=.28, snout=.42):
    hx, hy, hr = g["hx"], g["hy"], g["hr"]
    sx, sy = hx + hr * .78, hy + hr * .22
    c.pom(sx, sy, hr * snout, hr * snout * .8, snout_col, key=g["key"] + "snout", edge=2.4, fibres=False)
    nose(c, sx + hr * snout * .75, sy - hr * .08, hr * .13, nose_col)
    c.googly(hx + hr * .25, hy - hr * .2, hr * eye, P.get("look", (.5, .1)), closed=P.get("eyes") == "closed")
    c.mouth(sx + hr * .05, sy + hr * .22, hr * .25, P.get("mouth", 0))


# ================================================================ the animals (looks)
def frog_look(rainbow=False):
    def face(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        for s in (-1, 1):
            c.pom(hx + s * hr * .52, hy - hr * .62, hr * .36, hr * .33, kit.GREEN, key=g["key"] + "bump" + str(s), edge=2.6, fibres=False)
            c.googly(hx + s * hr * .52, hy - hr * .66, hr * .27, P.get("look", (0, .1)), closed=P.get("eyes") == "closed")
        c.mouth(hx, hy + hr * .22, hr * .8, P.get("mouth", 0))
        c.cheeks(hx, hy + hr * .12, hr * 1.25, hr * .14)

    def back(c, g, P):
        if not rainbow:
            return
        cx = 150
        for i, col in enumerate(["#F48C8C", "#FFC46B", "#FFE38A", "#9FDB9A", "#8FC7F0", "#B9A2EC"]):
            r = 128 - i * 11
            c.stroke(kit.arc(cx, 205, r, 180, 360), col, 11, op=.8, cap="butt")
    return dict(body=(58, 40), col=kit.GREEN, head=38, hw=1.25, neck=.1, hcol=kit.GREEN, arm=46, aw=10, leg=46, lw=12, lcol=kit.mix(kit.GREEN, kit.LIME, .3),
                face=face, body_deco=belly(kit.mix(kit.LIME, kit.WHITE, .45), .6, .62, .25), back=back,
                foot=lambda c, g, p, side, P: c.felt(kit.smooth([(p[0] - 12, p[1] + 5), (p[0] - 6, p[1] - 3), (p[0], p[1] - 1), (p[0] + 6, p[1] - 3), (p[0] + 12, p[1] + 5), (p[0], p[1] + 7)], .4), kit.LIME),
                paw=lambda c, g, p, side, P: c.felt(kit.circle(p[0], p[1], 6), kit.LIME))


def rabbit_look():
    col = "#F3E7EF"
    return dict(body=(40, 42), col=col, head=33, arm=34, aw=9, leg=36, lw=11, lcol=col, ears=tall_ears(col, kit.PINK, 1.1),
                face=lambda c, g, P: (muzzle_face(c, g, P, kit.WHITE, kit.ROSE, my=.38, mw=.36, mh=.26), _teeth(c, g)),
                body_deco=belly(kit.WHITE, .55, .6), foot=lambda c, g, p, s, P: c.felt(kit.ellipse(p[0] + (-5 if s == "l" else 5), p[1] + 3, 14, 7), "#F7D9E5"),
                paw=lambda c, g, p, s, P: c.pom(p[0], p[1], 6, 6, kit.WHITE, key=g["key"] + s, edge=2, fibres=False))


def _teeth(c, g):
    hx, hy, hr = g["hx"], g["hy"], g["hr"]
    c.felt(kit.rrect(hx - hr * .1, hy + hr * .5, hr * .2, hr * .16, 1.5), kit.WHITE, edge=1)


def kangaroo_look():
    col = "#C98A55"

    def back(c, g, P):
        c.cleaner([(g["bx"] - 10, g["by"] + g["ry"] * .6), (g["bx"] + 30, G - 6), (g["bx"] + 70, G - 2)], kit.mix(col, kit.INK, .1), 15)
    return dict(body=(40, 52), col=col, head=26, neck=.4, arm=32, aw=8, leg=34, lw=12, back=back, ears=tall_ears(col, kit.PINK, .8, .24, .5),
                face=lambda c, g, P: muzzle_face(c, g, P, kit.SAND, my=.34, mw=.42, mh=.32),
                body_deco=chain(belly(kit.SAND, .6, .66, .2), lambda c, g, P: c.felt(kit.ellipse(*g["R"](g["bx"], g["by"] + g["ry"] * .42), g["rx"] * .4, g["ry"] * .18), kit.mix(kit.SAND, kit.INK, .12), edge=1.2)),
                foot=lambda c, g, p, s, P: c.felt(kit.ellipse(p[0] + (-8 if s == "l" else 8), p[1] + 3, 20, 7), kit.mix(col, kit.INK, .2)))


def monkey_look():
    col = "#A88566"
    face_col = "#F2B8A2"

    def face(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        c.felt(kit.heart(hx, hy + hr * .12, hr * 1.25), face_col, edge=1.2)
        look = P.get("look", (0, .2))
        for s in (-1, 1):
            c.googly(hx + s * hr * .3, hy - hr * .02, hr * .25, look, closed=P.get("eyes") == "closed")
        nose(c, hx, hy + hr * .28, hr * .07, kit.mix(face_col, kit.INK, .5))
        c.mouth(hx, hy + hr * .5, hr * .32, P.get("mouth", 0))

    def ears(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        for s in (-1, 1):
            c.pom(hx + s * hr * .98, hy + hr * .05, hr * .3, hr * .34, col, key=g["key"] + "ear" + str(s), edge=2.4, fibres=False)
            c.felt(kit.circle(hx + s * hr * 1.0, hy + hr * .05, hr * .16), face_col, edge=0)
    return dict(body=(38, 44), col=col, head=32, arm=48, aw=8, leg=40, lw=9, ears=ears, face=face,
                back=tail([(-20, 30), (-60, 40), (-75, 10), (-62, -15)], kit.mix(col, kit.INK, .1), 8),
                body_deco=belly(kit.mix(face_col, kit.WHITE, .3), .5, .55, .25),
                paw=lambda c, g, p, s, P: c.pom(p[0], p[1], 6, 6, face_col, key=g["key"] + "paw" + s, edge=2, fibres=False))


def squirrel_look():
    col = "#D98A45"

    def back(c, g, P):
        x, y = g["bx"] - g["rx"] * .9, g["by"] - 4
        c.pom(x - 6, y + 10, 22, 34, kit.mix(col, kit.WHITE, .1), key=g["key"] + "tail1", rot=-20)
        c.pom(x - 2, y - 40, 22, 26, kit.mix(col, kit.WHITE, .1), key=g["key"] + "tail2", rot=20)

    def front(c, g, P):
        if P.get("nut"):
            x, y = g[P["nut"]][-1]
            c.felt(kit.ellipse(x, y + 4, 7, 8), kit.BROWN)
            c.felt(kit.ellipse(x, y - 3, 8, 4), kit.mix(kit.BROWN, kit.INK, .3))
    return dict(body=(34, 40), col=col, head=28, arm=34, aw=7, leg=32, lw=9, back=back, front=front,
                ears=pointy_ears(col, kit.SAND, .4, .55),
                face=lambda c, g, P: muzzle_face(c, g, P, kit.SAND, my=.36, mw=.4, mh=.3),
                body_deco=belly(kit.SAND, .55, .62, .22))


def lion_look():
    col = kit.GOLD
    mane = "#C9692E"

    def back(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        for i in range(12):
            a = 2 * math.pi * i / 12
            c.pom(hx + math.cos(a) * hr * 1.08, hy + math.sin(a) * hr * 1.08, hr * .38, hr * .38, mane, key=g["key"] + f"m{i}", edge=2.6, fibres=False)

    def legs_folded(c, g, P):
        pass
    return dict(body=(46, 40), col=col, head=34, neck=.35, arm=40, aw=11, leg=12, lw=12, back=back,
                ears=round_ears(col, kit.SAND, .28, .85, .68),
                face=lambda c, g, P: (muzzle_face(c, g, P, kit.SAND, kit.mix(kit.ROSE, kit.INK, .3), my=.4, mw=.48, mh=.3), _tongue(c, g, P)),
                body_deco=belly(kit.SAND, .55, .6, .2),
                foot=lambda c, g, p, s, P: c.pom(p[0] + (-8 if s == "l" else 8), p[1] - 2, 12, 9, col, key=g["key"] + "f" + s, edge=2.4, fibres=False))


def _tongue(c, g, P):
    if P.get("mouth", 0) > .5:
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        c.felt(kit.ellipse(hx, hy + hr * .82, hr * .14, hr * .16), "#FF7A90", edge=1)


def sloth_look():
    col = "#A99175"
    mask = "#EADBC4"

    def face(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        c.felt(kit.ellipse(hx, hy + hr * .08, hr * .82, hr * .62), mask, edge=1.2)
        for s in (-1, 1):
            c.felt(kit.ellipse(hx + s * hr * .38, hy - hr * .02, hr * .3, hr * .2).rotate(s * -20, hx + s * hr * .38, hy), kit.mix(col, kit.INK, .45), edge=0)
            c.googly(hx + s * hr * .38, hy - hr * .02, hr * .17, P.get("look", (0, .4)), closed=P.get("eyes") == "closed")
        nose(c, hx, hy + hr * .22, hr * .1)
        c.mouth(hx, hy + hr * .42, hr * .3, P.get("mouth", 0))

    def paw(c, g, p, s, P):
        for k in (-1, 0, 1):
            c.stroke(kit.path([(p[0] + k * 4, p[1]), (p[0] + k * 5 + (2 if s == "r" else -2), p[1] + 10)]), "#4B3B32", 3)
    return dict(body=(40, 46), col=col, head=30, arm=62, aw=9, leg=36, lw=9, face=face, paw=paw,
                body_deco=belly(kit.mix(col, kit.WHITE, .25), .5, .6, .2))


def penguin_look():
    col = "#34406A"

    def face(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        c.felt(kit.ellipse(hx, hy + hr * .15, hr * .78, hr * .6), kit.WHITE, edge=0)
        look = P.get("look", (0, .2))
        for s in (-1, 1):
            c.googly(hx + s * hr * .36, hy, hr * .24, look)
        c.felt(kit.poly([(hx - hr * .2, hy + hr * .3), (hx + hr * .2, hy + hr * .3), (hx, hy + hr * .55)]), kit.ORANGE, edge=1.2)
        c.cheeks(hx, hy + hr * .35, hr * 1.1, hr * .12)

    def arm_draw(c, g, pts, s, P):
        (x0, y0), (x1, y1) = pts[0], pts[-1]
        a = math.atan2(y1 - y0, x1 - x0)
        L = math.hypot(x1 - x0, y1 - y0)
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        c.felt(kit.ellipse(mx, my, L * .55, 10).rotate(math.degrees(a), mx, my), kit.mix(col, kit.INK, .15), edge=1.6)
    return dict(body=(44, 50), col=col, head=30, neck=.35, arm=40, aw=8, leg=12, lw=8, lcol=kit.ORANGE, face=face, arm_draw=arm_draw,
                body_deco=belly(kit.WHITE, .7, .78, .12),
                foot=lambda c, g, p, s, P: c.felt(kit.ellipse(p[0] + (-6 if s == "l" else 6), p[1] + 2, 13, 6), kit.ORANGE))


def duck_look():
    col = kit.YELLOW

    def face(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        look = P.get("look", (0, .2))
        for s in (-1, 1):
            c.googly(hx + s * hr * .38, hy - hr * .12, hr * .26, look)
        c.felt(kit.ellipse(hx, hy + hr * .38, hr * .5, hr * .2), kit.ORANGE, edge=1.4)
        c.stroke(kit.path([(hx - hr * .35, hy + hr * .38), (hx + hr * .35, hy + hr * .38)]), kit.mix(kit.ORANGE, kit.INK, .4), 1.5)
        c.cheeks(hx, hy + hr * .2, hr * 1.2, hr * .12)

    def arm_draw(c, g, pts, s, P):
        (x0, y0), (x1, y1) = pts[0], pts[-1]
        a = math.atan2(y1 - y0, x1 - x0)
        L = math.hypot(x1 - x0, y1 - y0)
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        c.felt(kit.ellipse(mx, my, L * .55, 11).rotate(math.degrees(a), mx, my), kit.mix(col, kit.ORANGE, .25), edge=1.6)
    return dict(body=(44, 38), col=col, head=30, neck=.3, arm=36, aw=8, leg=24, lw=7, lcol=kit.ORANGE, face=face, arm_draw=arm_draw,
                foot=lambda c, g, p, s, P: c.felt(kit.smooth([(p[0] - 11, p[1] + 5), (p[0], p[1] - 3), (p[0] + 11, p[1] + 5), (p[0], p[1] + 7)], .3), kit.ORANGE))


def bird_look(magpie=False):
    col = kit.BLUE if magpie else kit.ORANGE
    hcol = kit.DARK if magpie else kit.ORANGE
    beak = kit.RED if magpie else kit.YELLOW

    def back(c, g, P):
        if magpie:
            x, y = g["bx"] + 12, g["by"] + g["ry"] * .4
            for i, (dx, dy) in enumerate([(-6, 0), (6, 0)]):
                tip = (x + dx + 70, G - 30 + dy * 2)
                c.felt(kit.smooth([(x + dx - 6, y), (tip[0] - 4, tip[1] - 8), (tip[0], tip[1]), (tip[0] - 8, tip[1] + 6), (x + dx + 6, y + 6)], .4), col, edge=1.8)
                c.felt(kit.ellipse(tip[0] - 4, tip[1] - 1, 7, 5), kit.WHITE, edge=1)

    def face(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        look = P.get("look", (0, .2))
        for s in (-1, 1):
            c.googly(hx + s * hr * .38, hy - hr * .1, hr * .27, look, closed=P.get("eyes") == "closed")
        c.felt(kit.poly([(hx - hr * .2, hy + hr * .2), (hx + hr * .2, hy + hr * .2), (hx, hy + hr * .55)]), beak, edge=1.2)

    def arm_draw(c, g, pts, s, P):
        (x0, y0), (x1, y1) = pts[0], pts[-1]
        a = math.degrees(math.atan2(y1 - y0, x1 - x0))
        L = math.hypot(x1 - x0, y1 - y0)
        for k, f in enumerate((1.0, .82, .64)):
            mx, my = x0 + (x1 - x0) * (.55 + k * .05), y0 + (y1 - y0) * (.55 + k * .05)
            c.felt(kit.ellipse(mx, my + k * 6, L * .6 * f, 12).rotate(a, mx, my + k * 6), kit.mix(col, kit.INK if k else kit.WHITE, .12 * k), edge=1.6)
    return dict(body=(40, 40), col=col, head=28, hcol=hcol, neck=.25, arm=44, aw=8, leg=26, lw=6, lcol=kit.RED if magpie else kit.mix(kit.ORANGE, kit.INK, .3),
                face=face, arm_draw=arm_draw, back=back, body_deco=belly(kit.mix(col, kit.WHITE, .55), .55, .6, .25),
                foot=lambda c, g, p, s, P: c.stroke(kit.path([(p[0] - 8, p[1] + 3), (p[0], p[1]), (p[0] + 8, p[1] + 3)]), kit.RED if magpie else kit.mix(kit.ORANGE, kit.INK, .3), 4))


def flamingo_look():
    col = "#F58BB0"

    def back(c, g, P):
        hx, hy = g["hx"], g["hy"]
        bx, by = g["bx"], g["by"]
        c.cleaner([(bx + 8, by - g["ry"] * .6), (bx + 30, by - 40), (bx + 2, by - 70), (hx, hy + 10)], col, 13)

    def face(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        c.googly(hx - hr * .25, hy - hr * .15, hr * .34, P.get("look", (0, .2)))
        c.felt(kit.smooth([(hx + hr * .3, hy - hr * .2), (hx + hr * 1.4, hy + hr * .1), (hx + hr * 1.2, hy + hr * .8), (hx + hr * .35, hy + hr * .35)], .4), "#FFE4EE", edge=1.4)
        c.felt(kit.smooth([(hx + hr * 1.0, hy + hr * .25), (hx + hr * 1.38, hy + hr * .2), (hx + hr * 1.2, hy + hr * .8)], .4), kit.DARK, edge=0)

    def arm_draw(c, g, pts, s, P):
        (x0, y0), (x1, y1) = pts[0], pts[-1]
        a = math.degrees(math.atan2(y1 - y0, x1 - x0))
        L = math.hypot(x1 - x0, y1 - y0)
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        c.felt(kit.ellipse(mx, my, L * .55, 13).rotate(a, mx, my), kit.mix(col, kit.ROSE, .4), edge=1.6)
    return dict(body=(42, 30), col=col, head=17, neck=2.6, arm=34, aw=8, leg=80, lw=6, lcol=kit.ROSE, back=back, face=face, arm_draw=arm_draw,
                foot=lambda c, g, p, s, P: c.felt(kit.ellipse(p[0] + 4, p[1] + 2, 9, 4), kit.ROSE))


def giraffe_look():
    col = "#F2BE4E"
    spot = "#B96B2E"

    def back(c, g, P):
        bx, by = g["bx"], g["by"]
        top = g["hy"] + g["hr"] * .5
        c.pom(bx, (by - g["ry"] * .5 + top) / 2, 15, ((by - g["ry"] * .5) - top) / 2 + 6, col, key=g["key"] + "neck", edge=3)
        for i, t in enumerate((.25, .55, .8)):
            y = top + ((by - g["ry"] * .5) - top) * t
            c.felt(kit.blob(bx + (5 if i % 2 else -5), y, 6, 5, key=f"ns{i}"), spot, edge=0)

    def ears(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        for s in (-1, 1):
            c.cleaner([(hx + s * hr * .3, hy - hr * .6), (hx + s * hr * .4, hy - hr * 1.25)], spot, 5, twist=False)
            c.pom(hx + s * hr * .4, hy - hr * 1.3, 5, 5, kit.BROWN, key=g["key"] + "oss" + str(s), edge=2, fibres=False)
            c.felt(kit.ellipse(hx + s * hr * 1.0, hy - hr * .35, hr * .32, hr * .14).rotate(s * -25, hx + s * hr * 1.0, hy - hr * .35), col, edge=1.6)
    return dict(body=(46, 40), col=col, head=24, neck=P_NECK, arm=40, aw=9, leg=44, lw=10, back=back, ears=ears,
                face=lambda c, g, P: muzzle_face(c, g, P, "#F7DDA6", kit.BROWN, my=.42, mw=.5, mh=.32),
                body_deco=spots([(-.4, -.3), (.35, -.4), (0, .1), (-.5, .35), (.45, .3), (.1, -.65)], spot, 7))


P_NECK = 2.85


def elephant_look():
    col = "#9DA3B8"

    def ears(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        for s in (-1, 1):
            x = hx + s * hr * 1.05
            c.pom(x, hy + hr * .1, hr * .62, hr * .75, col, key=g["key"] + "ear" + str(s), rot=s * 10, edge=3, fibres=False)
            c.felt(kit.ellipse(x + s * 2, hy + hr * .12, hr * .36, hr * .48), "#F2B8C6", edge=0)

    def face(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        sw = P.get("trunk", 0)
        c.cleaner([(hx, hy + hr * .2), (hx + sw * .3, hy + hr * .85), (hx + sw * .8, hy + hr * 1.35), (hx + sw * 1.2, hy + hr * 1.55)], col, 15, twist=False)
        look = P.get("look", (0, .2))
        for s in (-1, 1):
            c.googly(hx + s * hr * .4, hy - hr * .12, hr * .24, look)
        c.cheeks(hx, hy + hr * .25, hr * 1.2, hr * .14)
    return dict(body=(56, 46), col=col, head=38, neck=.45, arm=34, aw=15, leg=30, lw=16, ears=ears, face=face,
                paw=lambda c, g, p, s, P: c.felt(kit.ellipse(p[0], p[1] + 3, 9, 5), kit.WHITE),
                foot=lambda c, g, p, s, P: c.felt(kit.ellipse(p[0], p[1] + 3, 12, 6), kit.mix(col, kit.WHITE, .4)))


def bear_front_look():
    col = kit.DARK
    return dict(body=(46, 50), col=col, head=34, arm=40, aw=12, leg=34, lw=13, ears=round_ears(col, "#6E6274", .34, .8, .78),
                face=lambda c, g, P: muzzle_face(c, g, P, kit.TAN, my=.38, mw=.46, mh=.32),
                body_deco=lambda c, g, P: _moon(c, *g["R"](g["bx"], g["by"] - g["ry"] * .45), g["rx"] * .55),
                paw=lambda c, g, p, s, P: c.pom(p[0], p[1], 7, 7, "#5A505F", key=g["key"] + s, edge=2, fibres=False))


def _moon(c, x, y, w):
    """The Formosan black bear's white crescent on its chest."""
    c.felt(kit.Shape([("M", x - w, y - w * .15), ("C", x - w * .5, y + w * .55, x + w * .5, y + w * .55, x + w, y - w * .15),
                      ("C", x + w * .5, y + w * .25, x - w * .5, y + w * .25, x - w, y - w * .15), ("Z",)]), "#F4F0E6", edge=1.2)


def leopardcat_front_look():
    col = "#CFA36A"

    def face(c, g, P):
        muzzle_face(c, g, P, "#F4E6CF", kit.ROSE, my=.42, mw=.42, mh=.28)
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        for s in (-1, 1):
            c.stroke(kit.path([(hx + s * hr * .1, hy - hr * .9), (hx + s * hr * .14, hy - hr * .42)]), kit.WHITE, 3.5)
            c.stroke(kit.path([(hx + s * hr * .22, hy - hr * .88), (hx + s * hr * .3, hy - hr * .5)]), kit.DARK, 2.5)
    return dict(body=(40, 44), col=col, head=31, arm=36, aw=9, leg=34, lw=9, ears=round_ears(col, kit.WHITE, .3, .8, .66), face=face,
                back=tail([(18, 30), (55, 32), (70, 5), (64, -20)], col, 9),
                body_deco=spots([(-.45, -.3), (.4, -.35), (-.2, .25), (.3, .3), (0, -.6), (-.55, .45), (.55, .5)], "#5B4632", 4.5))


def deer_front_look():
    col = "#C27F48"
    return dict(body=(38, 44), col=col, head=30, arm=36, aw=8, leg=40, lw=8, ears=tall_ears(col, kit.PINK, .5, .3, .9, 60),
                face=lambda c, g, P: muzzle_face(c, g, P, "#F1D7B8", my=.42, mw=.4, mh=.3),
                body_deco=spots([(-.45, -.3), (.4, -.35), (-.2, .2), (.3, .25), (0, -.55), (.55, .5)], kit.WHITE, 4.5),
                paw=lambda c, g, p, s, P: c.felt(kit.ellipse(p[0], p[1] + 3, 6, 5), kit.DARK),
                foot=lambda c, g, p, s, P: c.felt(kit.ellipse(p[0], p[1] + 3, 8, 5), kit.DARK))


def pangolin_front_look():
    col = "#B88552"

    def deco(c, g, P):
        _scales(c, g["bx"], g["by"], g["rx"], g["ry"], col, g["key"])
    return dict(body=(42, 46), col=col, head=24, neck=.4, arm=30, aw=8, leg=26, lw=9, body_deco=deco,
                back=tail([(-10, 30), (-50, 44), (-80, 30), (-88, 5)], kit.mix(col, kit.INK, .1), 14),
                face=lambda c, g, P: muzzle_face(c, g, P, "#F0D2B4", kit.ROSE, my=.42, mw=.36, mh=.3),
                ears=round_ears(col, "#F0D2B4", .2, .7, .7))


def _scales(c, cx, cy, rx, ry, col, key, rows=4):
    sc = kit.mix(col, kit.INK, .2)
    for r in range(rows):
        y = cy - ry * .6 + r * ry * .38
        half = math.sqrt(max(0, 1 - ((y - cy) / ry) ** 2)) * rx * .85
        k = max(2, int(half * 2 / 16))
        for i in range(k):
            x = cx - half + (i + .5 + (.5 if r % 2 else 0)) * (half * 2 / (k + .5))
            s = kit.Shape([("M", x - 8, y), ("C", x - 8, y + 9, x + 8, y + 9, x + 8, y), ("Z",)])
            c.felt(s, kit.mix(col, kit.WHITE, .12), edge=1.3)
            c.path_el(s.d(), "none", sc, 1.2)


def bear_side_look():
    col = kit.DARK

    def deco(c, g, P):
        x, y = g["R"](g["bx"] + g["rx"] * .62, g["by"] + g["ry"] * .05)
        c.felt(kit.ellipse(x, y, 10, 14).rotate(20, x, y), "#F4F0E6", edge=1)

    def ears(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        c.pom(hx - hr * .2, hy - hr * .82, hr * .3, hr * .3, col, key=g["key"] + "ear", edge=2.4, fibres=False)
    return dict(body=(64, 36), col=col, head=27, leg=46, lw=14, deco=deco, ears=ears,
                face=lambda c, g, P: side_face(c, g, P, kit.TAN),
                tail=lambda c, g, P: c.pom(*g["R"](g["bx"] - g["rx"] * .98, g["by"] - g["ry"] * .3), 7, 7, col, key=g["key"] + "tail", edge=2, fibres=False))


def leopardcat_side_look():
    col = "#CFA36A"

    def deco(c, g, P):
        for i, (x, y) in enumerate([(-.5, -.3), (-.1, -.45), (.3, -.3), (-.3, .1), (.15, .05), (.55, .1), (-.65, .2)]):
            px, py = g["R"](g["bx"] + x * g["rx"], g["by"] + y * g["ry"])
            c.felt(kit.blob(px, py, 5, 4, lumps=6, key=f"ls{i}"), "#5B4632", edge=0)

    def tl(c, g, P):
        x, y = g["R"](g["bx"] - g["rx"] * .9, g["by"] - g["ry"] * .2)
        pts = [(x, y), (x - 25, y - 6 + P.get("tail", 0)), (x - 44, y - 26 + P.get("tail", 0) * 1.5)]
        c.cleaner(pts, col, 9)
        for p in kit.sample(pts, 12)[1:-1]:
            c.flat(kit.circle(p[0], p[1], 3), "#5B4632")

    def ears(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        for k, dx in enumerate((-.35, .1)):
            c.pom(hx + hr * dx, hy - hr * .85, hr * .28, hr * .3, kit.mix(col, kit.INK, .15 * (1 - k)), key=g["key"] + f"e{k}", edge=2.2, fibres=False)
            c.flat(kit.circle(hx + hr * dx, hy - hr * .85, hr * .1), kit.WHITE)

    def face(c, g, P):
        side_face(c, g, P, "#F4E6CF", kit.ROSE, snout=.36)
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        c.stroke(kit.path([(hx + hr * .1, hy - hr * .85), (hx + hr * .4, hy - hr * .45)]), kit.WHITE, 3)
    return dict(body=(56, 28), col=col, head=24, leg=46, lw=8, deco=deco, tail=tl, ears=ears, face=face)


def deer_side_look():
    col = "#C27F48"

    def deco(c, g, P):
        for i, (x, y) in enumerate([(-.5, -.35), (-.15, -.5), (.2, -.4), (.5, -.3), (-.35, -.05), (.05, -.1), (.35, .0)]):
            px, py = g["R"](g["bx"] + x * g["rx"], g["by"] + y * g["ry"])
            c.flat(kit.circle(px, py, 3.6), kit.WHITE)
        tx, ty = g["R"](g["bx"] - g["rx"] * .95, g["by"] - g["ry"] * .4)
        c.pom(tx, ty, 7, 9, kit.WHITE, key=g["key"] + "tail", edge=2, fibres=False)

    def neck(c, g, P):
        nx, ny = g["R"](g["bx"] + g["rx"] * .6, g["by"] - g["ry"] * .2)
        c.cleaner([(nx, ny), (g["hx"] - 4, g["hy"] + 10)], col, 18, twist=False)

    def ears(c, g, P):
        hx, hy, hr = g["hx"], g["hy"], g["hr"]
        x, y = hx - hr * .45, hy - hr * .75
        c.felt(kit.ellipse(x, y, hr * .22, hr * .45).rotate(-30, x, y), col, edge=1.6)
        c.felt(kit.ellipse(x, y, hr * .1, hr * .28).rotate(-30, x, y), kit.PINK, edge=0)
    return dict(body=(54, 30), col=col, head=24, leg=58, lw=8, deco=deco, neck=neck, ears=ears,
                face=lambda c, g, P: side_face(c, g, P, "#F1D7B8", snout=.38))


# ================================================================ the animals drawn on their own
def snake(c, phase, col, belly_col, key, worm=False):
    n = 9
    pts = []
    for i in range(n):
        x = 30 + i * 23
        y = 196 - math.sin(i * .85 + phase) * 14
        pts.append((x, y))
    c.ground(150, G + 2, 120)
    for i, (x, y) in enumerate(pts):
        r = 15 + 9 * (i / (n - 1)) if not worm else 16 + 4 * math.sin(math.pi * i / (n - 1))
        col_i = col if i % 2 == 0 else belly_col
        c.pom(x, y, r, r * .9, col_i, key=f"{key}{i}", edge=3.2, fibres=r > 12)
    hx, hy = pts[-1][0] + 18, pts[-1][1] - 8
    c.pom(hx, hy, 28, 23, col, key=key + "head", edge=3.4)
    if not worm:
        c.felt(kit.path([(hx + 24, hy + 6), (hx + 40, hy + 4), (hx + 46, hy - 2), (hx + 41, hy + 5), (hx + 47, hy + 10), (hx + 40, hy + 7), (hx + 24, hy + 9)], closed=True), kit.RED, edge=1)
    for s, dx in ((0, -6), (1, 10)):
        c.googly(hx + dx, hy - 10, 8.5, (.4, .1))
    c.mouth(hx + 12, hy + 8, 14)
    c.cheeks(hx + 4, hy + 4, 30, 4)


def fish(c, flip, col, key, salmon=False):
    rot = -18 if salmon else 0
    cx, cy = 150, 130
    c.ground(150, G + 2, 80, op=.07)
    c.begin(f"rotate({rot} {cx} {cy})")
    t = 22 * flip
    tail = kit.smooth([(cx - 52, cy), (cx - 92, cy - 38 + t * .4), (cx - 82, cy + t * .5), (cx - 92, cy + 38 + t * .4)], .3)
    c.felt(tail.rotate(t * .6, cx - 52, cy), kit.mix(col, kit.INK, .12), edge=2.4)
    c.felt(kit.smooth([(cx - 20, cy - 40), (cx + 8, cy - 64), (cx + 26, cy - 40)], .5), kit.mix(col, kit.INK, .12), edge=2.4)
    c.pom(cx, cy, 64, 44, col, key=key + "body", edge=3.6)
    if salmon:
        c.felt(kit.ellipse(cx - 4, cy + 6, 52, 7), "#F08FA8", edge=0, op=.9)
        for i in range(5):
            c.felt(kit.ellipse(cx - 40 + i * 19, cy - 6, 6, 11), kit.mix(col, kit.INK, .45), edge=0, op=.75)
        for x, y in ((cx - 30, cy - 26), (cx - 5, cy - 30), (cx + 20, cy - 24), (cx + 8, cy + 24)):
            c.flat(kit.circle(x, y, 2.6), kit.DARK)
    else:
        for x in (cx - 24, cx + 14):
            c.felt(kit.ellipse(x, cy, 8, 40), kit.WHITE, edge=1.4)
    c.felt(kit.ellipse(cx + 6, cy + 18, 16, 8).rotate(25 - t, cx + 6, cy + 18), kit.mix(col, kit.WHITE, .25), edge=1.6)
    c.googly(cx + 34, cy - 12, 13, (.5, .1))
    c.felt(kit.circle(cx + 58, cy + 8, 5), kit.MOUTH, edge=1)
    c.cheeks(cx + 34, cy + 6, 4, 6)
    c.end()


def seaturtle(c, flip, key):
    col = "#6FB06A"
    shell = "#8A6A3E"
    cx, cy = 140, 140
    c.ground(150, G + 2, 100)
    fa = -30 + 50 * flip
    for k, (x, y, a0, L, w) in enumerate([(cx - 46, cy + 18, 40 - 30 * flip, 30, 11), (cx + 30, cy + 10, fa, 56, 17)]):
        far = k == 1
        c.felt(kit.ellipse(x + L * .45, y, L * .55, w).rotate(a0, x, y), kit.mix(col, kit.INK, .3), edge=2.2)
    c.pom(cx + 78, cy - 6, 24, 20, col, key=key + "head", edge=3)
    c.googly(cx + 84, cy - 12, 8, (.5, .2))
    c.mouth(cx + 90, cy + 2, 10)
    c.pom(cx, cy, 68, 40, shell, key=key + "shell", edge=3.6)
    for x, y, r in ((cx - 30, cy - 10, 14), (cx, cy - 18, 15), (cx + 30, cy - 10, 14), (cx - 15, cy + 14, 12), (cx + 15, cy + 14, 12)):
        c.felt(kit.poly([(x + r * math.cos(math.radians(a)), y + r * .8 * math.sin(math.radians(a))) for a in range(0, 360, 60)]), kit.mix(shell, kit.SAND, .35), edge=1.4)
    for x, y, a0, L, w in [(cx + 26, cy + 24, 120 - fa, 50, 15), (cx - 50, cy + 26, 150 + 30 * flip, 28, 10)]:
        c.felt(kit.ellipse(x + L * .45 * math.cos(math.radians(a0 - 90)), y + L * .45 * math.sin(math.radians(a0 - 90)), L * .55, w).rotate(a0 - 90, x, y), col, edge=2.2)


def tortoise(c, out, key):
    col = "#8FBF6A"
    shell = "#5E8C4A"
    cx = 145
    c.ground(150, G + 2, 95)
    sy = G - 44 + (0 if out else 6)
    if out:
        c.cleaner([(cx + 40, sy + 18), (cx + 70, sy - 10), (cx + 82, sy - 22)], col, 16, twist=False)
        c.pom(cx + 92, sy - 30, 22, 19, col, key=key + "head", edge=3)
        c.googly(cx + 98, sy - 36, 7.5, (.5, .1))
        c.mouth(cx + 106, sy - 22, 10)
        for x in (cx - 46, cx + 32):
            c.cleaner([(x, sy + 20), (x + 4, G - 2)], col, 15, twist=False)
            c.felt(kit.ellipse(x + 6, G, 10, 5), kit.mix(col, kit.INK, .2), edge=1)
    else:
        c.pom(cx + 50, sy + 22, 11, 9, col, key=key + "peek", edge=2.6, fibres=False)
        c.googly(cx + 54, sy + 19, 4.5, (.3, .2), closed=True)
    c.pom(cx, sy, 64, 46, shell, key=key + "shell", edge=3.8)
    c.felt(kit.rrect(cx - 68, sy + 22, 136, 14, 7), kit.mix(shell, kit.SAND, .4), edge=1.6)
    for x, y, r in ((cx - 30, sy - 8, 15), (cx, sy - 22, 16), (cx + 30, sy - 8, 15), (cx, sy + 6, 13)):
        c.felt(kit.poly([(x + r * math.cos(math.radians(a)), y + r * .8 * math.sin(math.radians(a))) for a in range(0, 360, 60)]), kit.mix(shell, kit.LIME, .35), edge=1.4)


def starfish(c, open_, key):
    col = kit.ORANGE
    cx, cy = 150, 118
    c.ground(150, G + 2, 80)
    arms = [(180, 70)] + ([(-125, 74), (125, 74), (-28, 92), (28, 92)] if open_ else [(-160, 64), (160, 64), (-6, 96), (6, 96)])
    if not open_:
        arms = [(180, 70), (-20, 70), (20, 70), (-6, 96), (6, 96)]
    for i, (a, L) in enumerate(arms):
        end = limb((cx, cy), (a,), (L,))[-1]
        mid = ((cx + end[0]) / 2, (cy + end[1]) / 2)
        c.cleaner([(cx, cy), mid, end], col, 24, twist=False)
        c.dots([((cx + end[0] * 2) / 3, (cy + end[1] * 2) / 3), (end[0] * .85 + cx * .15, end[1] * .85 + cy * .15)], 3, kit.mix(col, kit.WHITE, .5))
    c.pom(cx, cy, 40, 40, col, key=key + "body", edge=3.4)
    for s in (-1, 1):
        c.googly(cx + s * 14, cy - 8, 10, (0, .2))
    c.mouth(cx, cy + 14, 18, .5 if open_ else 0)
    c.cheeks(cx, cy + 6, 40, 5)


def jellyfish(c, wide, key):
    col = "#C7A6F0"
    cx, cy = 150, 100
    c.ground(150, G + 2, 60, op=.07)
    rx, ry = (62, 40) if wide else (48, 50)
    for i in range(5):
        x0 = cx - rx * .7 + i * rx * .35
        ph = i * 1.3 + (1.6 if wide else 0)
        pts = [(x0, cy + 18)] + [(x0 + math.sin(ph + k * 1.2) * (12 if wide else 6), cy + 18 + k * 24) for k in range(1, 5)]
        c.cleaner(pts, kit.mix(col, kit.PINK, .4), 7, twist=False)
    c.pom(cx, cy, rx, ry, col, key=key + "dome", edge=3.4)
    c.felt(kit.smooth([(cx - rx, cy + 4)] + [(cx - rx + (k + .5) * rx / 3, cy + 18) for k in range(6)] + [(cx + rx, cy + 4), (cx, cy + 10)], .4), kit.mix(col, kit.WHITE, .35), edge=1.4)
    for s in (-1, 1):
        c.googly(cx + s * 16, cy - 8, 10, (0, .3))
    c.mouth(cx, cy + 6, 14)
    c.cheeks(cx, cy + 2, 46, 5)


def octopus(c, phase, key):
    col = "#F07A5A"
    cx, cy = 150, 112
    c.ground(150, G + 2, 100)
    for i in range(8):
        a = -150 + i * (300 / 7)
        sx = cx + math.sin(math.radians(a)) * 34
        pts = [(sx, cy + 30)]
        x, y = sx, cy + 30
        for k in range(1, 5):
            spread = math.sin(math.radians(a)) * 20
            x += spread + math.sin(phase + i + k) * 9
            y += 20 - k * 2
            pts.append((x, min(y, G - 4)))
        c.cleaner(pts, kit.mix(col, kit.INK, .08 if i % 2 else 0), 12, twist=False)
        c.dots([pts[2], pts[3]], 2.6, "#FFD1C4")
    c.pom(cx, cy, 56, 52, col, key=key + "head", edge=3.6)
    for s in (-1, 1):
        c.googly(cx + s * 18, cy + 4, 12, (math.sin(phase) * .6, .2))
    c.mouth(cx, cy + 26, 16, .3)
    c.cheeks(cx, cy + 18, 56, 6)
    c.dots([(cx - 22, cy - 26), (cx + 18, cy - 32), (cx + 2, cy - 40)], 4, kit.mix(col, kit.WHITE, .35))


def crab(c, up, key):
    col = kit.RED
    cx = 150 + (0 if up else 14)
    cy = 160
    c.ground(cx, G + 2, 90)
    for s in (-1, 1):
        for k in range(3):
            hip = (cx + s * (26 + k * 10), cy + 16)
            c.cleaner(limb(hip, (s * (70 - k * 12 + (10 if up else -6) * (k % 2)), s * (20 + k * 6)), (24, 26)), kit.mix(col, kit.INK, .1), 7)
    for s in (-1, 1):
        c.cleaner([(cx + s * 16, cy - 24), (cx + s * 20, cy - 52)], col, 6, twist=False)
        c.googly(cx + s * 20, cy - 58, 10, (0, .2))
    c.pom(cx, cy, 58, 34, col, key=key + "body", edge=3.6)
    c.mouth(cx, cy + 6, 22)
    c.cheeks(cx, cy - 2, 60, 6)
    for s in (-1, 1):
        sh = (cx + s * 50, cy - 8)
        arm = limb(sh, (s * (150 if up else 95), s * (175 if up else 120)), (28, 26))
        c.cleaner(arm, col, 9)
        x, y = arm[-1]
        a = -math.pi / 2 if up else (0 if s > 0 else math.pi)
        c.pom(x, y, 17, 15, col, key=key + f"claw{s}", edge=3)
        c.felt(kit.poly([(x + math.cos(a) * 6, y + math.sin(a) * 6), (x + math.cos(a + .35) * 22, y + math.sin(a + .35) * 22), (x + math.cos(a - .35) * 22, y + math.sin(a - .35) * 22)]), kit.CREAM, edge=1)


def butterfly(c, open_, key):
    cx, cy = 150, 112
    c.ground(150, G + 2, 60, op=.08)
    k = 1.0 if open_ else .45
    for s in (-1, 1):
        for up, (rx, ry, dy, col) in enumerate([(46, 38, -26, kit.ORANGE), (34, 28, 26, kit.YELLOW)]):
            x = cx + s * (rx * k * .9 + 6)
            c.pom(x, cy + dy, rx * k, ry, col, key=key + f"w{s}{up}", edge=3.2, rot=s * (-20 if up == 0 else 15))
            c.felt(kit.circle(x + s * 4 * k, cy + dy, ry * .32 * max(k, .6)), kit.PURPLE, edge=1.2)
    for s in (-1, 1):
        c.cleaner([(cx + s * 4, cy - 40), (cx + s * 14, cy - 66), (cx + s * 24, cy - 76)], kit.DARK, 3.5, twist=False)
        c.pom(cx + s * 24, cy - 78, 5, 5, kit.PURPLE, key=key + f"a{s}", edge=2, fibres=False)
    for i, (y, r) in enumerate([(cy + 34, 10), (cy + 14, 12), (cy - 8, 13)]):
        c.pom(cx, y, r, r, kit.mix(kit.PURPLE, kit.INK, .2), key=key + f"b{i}", edge=2.6, fibres=False)
    c.pom(cx, cy - 30, 18, 17, kit.PURPLE, key=key + "head", edge=3)
    for s in (-1, 1):
        c.googly(cx + s * 7, cy - 32, 6.5, (0, .2))
    c.mouth(cx, cy - 22, 8)


def pangolin_ball(c, key):
    col = "#B88552"
    cx, cy = 150, G - 52
    c.ground(150, G + 2, 70)
    c.pom(cx, cy, 56, 52, col, key=key + "ball", edge=3.6)
    _scales(c, cx, cy - 4, 56, 52, col, key, rows=5)
    c.felt(kit.Shape([("M", cx - 40, cy + 36), ("C", cx - 10, cy + 60, cx + 30, cy + 58, cx + 50, cy + 30), ("L", cx + 40, cy + 26),
                      ("C", cx + 22, cy + 46, cx - 10, cy + 46, cx - 34, cy + 28), ("Z",)]), kit.mix(col, kit.INK, .15), edge=1.6)
    c.pom(cx + 24, cy + 18, 15, 13, "#F0D2B4", key=key + "face", edge=2.6, fibres=False)
    c.googly(cx + 22, cy + 15, 5, (.2, .3), closed=True)


# ================================================================ the moves
def _std(make, **pose):
    return (lambda c, key: biped(c, pose, make(), key))


def _quad(make, **pose):
    return (lambda c, key: quad(c, pose, make(), key))


def _frog_rainbow(lean):
    s = -1 if lean < 0 else 1
    return _std(lambda: frog_look(True), tilt=lean, la=(180 + s * 28, 180 + s * 42), ra=(180 + s * 28, 180 + s * 42), dx=s * 6, look=(s * .6, -.2), mouth=.4)


MOVES = {
    "frog": (_std(frog_look, dy=30, ll=(-80, 20), rl=(80, -20), la=(-10, 0), ra=(10, 0), look=(0, .5)),
             _std(frog_look, dy=-6, ll=(-14, -4), rl=(14, 4), la=(-155, -170), ra=(155, 170), mouth=.7, look=(0, -.5))),
    "bunny": (_std(rabbit_look, dy=16, ll=(-60, 30), rl=(60, -30), la=(-15, 10), ra=(15, -10), look=(0, .4)),
              _std(rabbit_look, dy=-4, ll=(-6, 0), rl=(6, 0), la=(-120, -150), ra=(120, 150), mouth=.5, look=(0, -.4))),
    "kangaroo": (_std(kangaroo_look, dy=18, ll=(-50, 30), rl=(50, -30), la=(30, 60), ra=(-30, -60), look=(0, .3)),
                 _std(kangaroo_look, dy=-6, ll=(-4, 4), rl=(4, -4), la=(-170, -178), ra=(170, 178), mouth=.6, look=(0, -.5))),
    "bear": (_quad(bear_side_look, tilt=8, fn=(30, 10), ff=(-15, -5), bn=(-20, 0), bf=(15, 5)),
             _quad(bear_side_look, tilt=8, fn=(-15, -5), ff=(30, 10), bn=(15, 5), bf=(-20, 0), look=(.6, .3))),
    "crab": (lambda c, k: crab(c, True, k), lambda c, k: crab(c, False, k)),
    "penguin": (_std(penguin_look, tilt=-10, la=(-40, -30), ra=(30, 20), ll=(-4, 0), rl=(10, 0), look=(-.5, .2)),
                _std(penguin_look, tilt=10, la=(-30, -20), ra=(40, 30), ll=(-10, 0), rl=(4, 0), look=(.5, .2))),
    "duck": (_std(duck_look, dy=10, ll=(-40, 20), rl=(15, 10), la=(-60, -70), ra=(60, 70), dx=-6),
             _std(duck_look, dy=10, ll=(-15, -10), rl=(40, -20), la=(-75, -85), ra=(75, 85), dx=6, mouth=.4)),
    "tiptoe": (_quad(leopardcat_side_look, dy=-6, fn=(-25, 10), ff=(10, 0), bn=(25, -5), bf=(-5, 5), look=(.7, 0), tail=-4),
               _quad(leopardcat_side_look, dy=-6, fn=(10, 0), ff=(-25, 10), bn=(-5, 5), bf=(25, -5), look=(.7, 0), tail=6)),
    "deer": (_quad(deer_side_look, dy=8, fn=(-40, 40), ff=(-20, 30), bn=(40, -30), bf=(20, -20)),
             _quad(deer_side_look, dy=-22, tilt=-6, fn=(-80, -40), ff=(-65, -30), bn=(75, 60), bf=(60, 50), mouth=.5)),
    "elephant": (_std(elephant_look, trunk=-34, ll=(-30, 20), rl=(4, 0), dy=-4, la=(-25, -10), ra=(25, 10), look=(-.5, .2)),
                 _std(elephant_look, trunk=34, ll=(-4, 0), rl=(30, -20), dy=-4, la=(-25, -10), ra=(25, 10), look=(.5, .2), mouth=.4)),
    "snake": (lambda c, k: snake(c, 0, kit.GREEN, kit.LIME, k), lambda c, k: snake(c, math.pi, kit.GREEN, kit.LIME, k)),
    "snake-worm": (lambda c, k: snake(c, 0, "#F09AA6", "#F7BFC6", k, worm=True), lambda c, k: snake(c, math.pi, "#F09AA6", "#F7BFC6", k, worm=True)),
    "fish": (lambda c, k: fish(c, -1, kit.ORANGE, k), lambda c, k: fish(c, 1, kit.ORANGE, k)),
    "bird": (_std(bird_look, la=(-130, -150), ra=(130, 150), dy=-8, mouth=.3, look=(0, -.3)),
             _std(bird_look, la=(-60, -40), ra=(60, 40), dy=0)),
    "bird-magpie": (_std(lambda: bird_look(True), la=(-130, -150), ra=(130, 150), dy=-8, look=(0, -.3)),
                    _std(lambda: bird_look(True), la=(-60, -40), ra=(60, 40), dy=0)),
    "salmon": (lambda c, k: fish(c, -1, "#A9BFA9", k, salmon=True), lambda c, k: fish(c, 1, "#A9BFA9", k, salmon=True)),
    "flamingo": (_std(flamingo_look, rl=(40, -70), la=(-10, -5), ra=(10, 5), look=(.3, .2)),
                 _std(flamingo_look, rl=(40, -70), la=(-100, -110), ra=(100, 110), look=(.3, 0), mouth=0)),
    "giraffe": (_std(giraffe_look, la=(-25, -10), ra=(25, 10)),
                _std(giraffe_look, dy=-14, la=(-165, -175), ra=(165, 175), ll=(-3, 0), rl=(3, 0), look=(0, -.6), mouth=.4)),
    "sloth": (_std(sloth_look, la=(-150, -170), ra=(30, 15), ll=(-4, 0), rl=(30, -10), dy=-4, htilt=-8),
              _std(sloth_look, la=(-30, -15), ra=(150, 170), ll=(-30, 10), rl=(4, 0), dy=-4, htilt=8)),
    "starfish": (lambda c, k: starfish(c, False, k), lambda c, k: starfish(c, True, k)),
    "jellyfish": (lambda c, k: jellyfish(c, False, k), lambda c, k: jellyfish(c, True, k)),
    "octopus": (lambda c, k: octopus(c, 0, k), lambda c, k: octopus(c, 2.2, k)),
    "seaturtle": (lambda c, k: seaturtle(c, 0, k), lambda c, k: seaturtle(c, 1, k)),
    "monkey": (_std(monkey_look, la=(-160, 115), ra=(160, -115), look=(0, -.5)),
               _std(monkey_look, dy=14, ll=(-25, 15), rl=(25, -15), la=(-5, 0), ra=(5, 0), look=(0, .6), mouth=.4)),
    "squirrel": (_std(squirrel_look, dy=20, tilt=-14, ll=(-50, 20), rl=(40, -10), la=(-25, -30), ra=(30, 20), nut="la", look=(-.5, .6)),
                 _std(squirrel_look, la=(45, 110), ra=(25, 10), nut="la", look=(.5, .3), mouth=.3)),
    "lion": (_std(lion_look, dy=4, la=(10, -40), ra=(-10, 40), ll=(-60, 0), rl=(60, 0)),
             _std(lion_look, dy=4, la=(-110, -130), ra=(110, 130), ll=(-60, 0), rl=(60, 0), mouth=1.0, look=(0, -.4))),
    "tortoise": (lambda c, k: tortoise(c, False, k), lambda c, k: tortoise(c, True, k)),
    "catarch": (_quad(leopardcat_side_look, dy=6, fn=(0, 0), ff=(5, 0), bn=(0, 0), bf=(5, 0), look=(.6, .2)),
                _quad(leopardcat_side_look, dy=-6, fn=(-18, -6), ff=(-14, -4), bn=(18, 6), bf=(14, 4), hy=22, hx=-4, htilt=12, eyes="closed", tail=10, arch=True)),
    "butterfly": (lambda c, k: butterfly(c, False, k), lambda c, k: butterfly(c, True, k)),
    "pangolin": (lambda c, k: pangolin_ball(c, k), _std(pangolin_front_look, la=(-60, -90), ra=(60, 90), mouth=.4)),
    "rainbow": (_frog_rainbow(-14), _frog_rainbow(14)),
}


# How much bigger each puppet is drawn (about its feet), so it fills the stage.
SCALE = {"bunny": 1.12, "bird": 1.3, "bird-magpie": 1.2, "duck": 1.35, "squirrel": 1.35, "penguin": 1.3, "monkey": 1.2, "lion": 1.3,
         "frog": 1.25, "kangaroo": 1.15, "elephant": 1.15, "sloth": 1.15, "butterfly": 1.12, "jellyfish": 1.2, "starfish": 1.15,
         "crab": 1.15, "octopus": 1.05, "fish": 1.15, "salmon": 1.15, "seaturtle": 1.15, "tortoise": 1.18, "bear": 1.25, "tiptoe": 1.3,
         "catarch": 1.3, "deer": 1.3, "snake": 1.05, "snake-worm": 1.05, "pangolin": 1.25, "giraffe": 1.0, "flamingo": 1.05, "rainbow": 1.0}


def draw(name, frame):
    """One pose of a move: a Ctx with it drawn, scaled about the floor."""
    c = kit.Ctx(W, H)
    s = SCALE.get(name, 1.2)
    c.begin(f"translate(150 {G}) scale({s}) translate(-150 -{G})")
    MOVES[name]["ab".index(frame)](c, f"{name}{frame}")
    c.end()
    return c


def build():
    out = kit.ART / "moves"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.svg"):
        old.unlink()
    total = 0
    for name, frames in MOVES.items():
        for f in "ab":
            total += kit.write_svg(out / f"{name}_{f}.svg", draw(name, f).svg(), (W, H))
    print(f"animals: {len(MOVES) * 2} poses, {total:.0f} KB")


if __name__ == "__main__":
    build()
