"""Pom-pom and pipe-cleaner drawing kit for 動物動一動 (毛球毛根風, docs/design.md 「選 B 之後怎麼畫」).

Every animal is a kindergarten craft: yarn pom-poms for bodies and heads, pipe cleaners (扭扭棒) for
arms and legs, googly eyes, little felt cut-outs for beaks, ears and shells. Because the phone stands
two metres away, the fuzz is only a thin ring: each pom-pom has a bold, dark, slightly bumpy outline
outside a thin fuzzy ring in its own colour, and a soft round body inside; each pipe cleaner has a
dark outline, its colour and a twisted stripe. Backgrounds are calm felt, so the animal is always the
darkest, brightest thing on screen.

Only plain paths with fill / stroke / opacity and linear / radial gradients, so flutter_svg draws
what Chromium draws (no filter, mask, clipPath, style, text, image, pattern; docs/art.md).

    import kit
    c = kit.Ctx(300, 240)
    c.ground(150, 222, 90)                                  # the soft shadow on the floor
    c.cleaner([(120, 150), (110, 190), (118, 220)], kit.GREEN, 9)   # a pipe-cleaner leg
    c.pom(150, 140, 50, 42, kit.GREEN, key="frog body")     # a pom-pom
    c.googly(135, 100, 12, look=(.3, 0))                    # a googly eye
    c.felt(kit.ellipse(150, 150, 20, 10), kit.PINK)         # a felt piece
    kit.write_svg(path, c.svg())                            # checks the rules, then writes

Deterministic: gradient ids are hashes, randomness only via `rnd(key)`.
"""
import colorsys
import hashlib
import math
import pathlib
import random
import re
import xml.etree.ElementTree as ET

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ART = ROOT / "app" / "assets" / "art"

# ---------------------------------------------------------------- palette (yarn and felt colours)
INK = "#2F2436"        # outlines, pupils: a deep plum (never pure black)
CREAM = "#FFF8EC"
WHITE = "#FFFFFF"
RED = "#E94B4B"
PINK = "#F49AC1"
ROSE = "#E9668F"
ORANGE = "#FF9A3C"
YELLOW = "#FFD24A"
GOLD = "#F2B33D"
GREEN = "#55B85A"
LEAF = "#3E9E4F"
LIME = "#A5D65A"
TEAL = "#3CC1B5"
SKY = "#8FD0F2"
BLUE = "#3F8FE0"
NAVY = "#2F4C8F"
PURPLE = "#9C7BE0"
BROWN = "#9A6338"
TAN = "#D9A66E"
SAND = "#EFD3A0"
SKIN = "#FFD0AE"
GREY = "#9C9AA8"
DARK = "#3B3540"        # a black animal's yarn (the bear): very dark but not black
CHEEK = "#FF8FA3"
MOUTH = "#C93D5A"
SHADOW = "#2F2436"

def _rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def _hex(r, g, b):
    return "#%02X%02X%02X" % tuple(max(0, min(255, round(v))) for v in (r, g, b))


def mix(a, b, t):
    """Colour a moved t (0..1) of the way to colour b."""
    return _hex(*[x + (y - x) * t for x, y in zip(_rgb(a), _rgb(b))])


def lt(c, t):
    return mix(c, "#FFFFFF", t)


def dk(c, t):
    return mix(c, INK, t)


def tone(c, l=1.0, s=1.0, dh=0.0):
    h, L, S = colorsys.rgb_to_hls(*[x / 255 for x in _rgb(c)])
    r, g, b = colorsys.hls_to_rgb((h + dh) % 1, max(0, min(1, L * l)), max(0, min(1, S * s)))
    return _hex(r * 255, g * 255, b * 255)


def rnd(*key):
    h = hashlib.md5("|".join(map(str, key)).encode()).hexdigest()
    return random.Random(int(h[:12], 16))



# ---------------------------------------------------------------- numbers
def n(v):
    """A number, short: one decimal, no trailing .0, no -0."""
    s = f"{v:.1f}"
    if s.endswith(".0"):
        s = s[:-2]
    if s == "-0":
        s = "0"
    return s


# ---------------------------------------------------------------- shapes
KAPPA = 0.5522847498


class Shape:
    """Path commands: ('M', x, y) ('L', x, y) ('C', x1, y1, x2, y2, x, y) ('Z',). All shapes the kit
    makes wind clockwise on screen, so unions (`a + b`) fill with the default nonzero rule."""

    def __init__(self, cmds=None):
        self.cmds = list(cmds or [])

    def __add__(self, other):
        return Shape(self.cmds + other.cmds)

    def move(self, dx, dy):
        return self.map(lambda x, y: (x + dx, y + dy))

    def scale(self, s, cx=0.0, cy=0.0, sy=None):
        sy = s if sy is None else sy
        return self.map(lambda x, y: (cx + (x - cx) * s, cy + (y - cy) * sy))

    def flip(self, cx):
        """Mirror left-right about x = cx (winding is fixed afterwards)."""
        return self.map(lambda x, y: (2 * cx - x, y)).reverse()

    def rotate(self, deg, cx, cy):
        a = math.radians(deg)
        ca, sa = math.cos(a), math.sin(a)
        return self.map(lambda x, y: (cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca))

    def map(self, f):
        out = []
        for c in self.cmds:
            if c[0] == "Z":
                out.append(c)
            else:
                pts = [f(c[i], c[i + 1]) for i in range(1, len(c), 2)]
                out.append((c[0],) + tuple(v for p in pts for v in p))
        return Shape(out)

    def reverse(self):
        """The same outline the other way round (one subpath at a time)."""
        out = []
        for sub in self.subpaths():
            pts = []   # (point, incoming control pair or None)
            cur = None
            for c in sub:
                if c[0] == "M":
                    cur = (c[1], c[2])
                    pts.append((cur, None))
                elif c[0] == "L":
                    cur = (c[1], c[2])
                    pts.append((cur, None))
                elif c[0] == "C":
                    cur = (c[5], c[6])
                    pts.append((cur, (c[1], c[2], c[3], c[4])))
            rev = pts[::-1]
            out.append(("M",) + rev[0][0])
            for i in range(1, len(rev)):
                p, _ = rev[i]
                _, ctrl = rev[i - 1]      # the control pair that led INTO rev[i-1] from rev[i]
                if ctrl is None:
                    out.append(("L",) + p)
                else:
                    out.append(("C", ctrl[2], ctrl[3], ctrl[0], ctrl[1]) + p)
            out.append(("Z",))
        return Shape(out)

    def subpaths(self):
        subs, cur = [], []
        for c in self.cmds:
            if c[0] == "M" and cur:
                subs.append(cur)
                cur = []
            cur.append(c)
        if cur:
            subs.append(cur)
        return subs

    def bbox(self):
        xs = [c[i] for c in self.cmds if c[0] != "Z" for i in range(1, len(c), 2)]
        ys = [c[i] for c in self.cmds if c[0] != "Z" for i in range(2, len(c), 2)]
        return min(xs), min(ys), max(xs), max(ys)

    def d(self, dx=0.0, dy=0.0):
        out = []
        for c in self.cmds:
            if c[0] == "Z":
                out.append("Z")
            else:
                nums = [n(c[i] + (dx if i % 2 else dy)) for i in range(1, len(c))]
                out.append(c[0] + " ".join(nums))
        return "".join(out)


def poly(points, close=True):
    """A polygon through points (any winding; it is made clockwise)."""
    pts = [tuple(p) for p in points]
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    if area < 0:      # counter-clockwise on screen (y down) -> reverse
        pts = pts[::-1]
    cmds = [("M",) + pts[0]] + [("L",) + p for p in pts[1:]]
    if close:
        cmds.append(("Z",))
    return Shape(cmds)


def rrect(x, y, w, h, r=8.0, rtl=None, rtr=None, rbr=None, rbl=None):
    """A rounded rectangle; corner radii can differ."""
    r = min(r, w / 2, h / 2)
    a, b, c_, d = [min(v if v is not None else r, w / 2, h / 2) for v in (rtl, rtr, rbr, rbl)]
    k = KAPPA
    cmds = [("M", x + a, y), ("L", x + w - b, y)]
    if b:
        cmds.append(("C", x + w - b + b * k, y, x + w, y + b - b * k, x + w, y + b))
    cmds.append(("L", x + w, y + h - c_))
    if c_:
        cmds.append(("C", x + w, y + h - c_ + c_ * k, x + w - c_ + c_ * k, y + h, x + w - c_, y + h))
    cmds.append(("L", x + d, y + h))
    if d:
        cmds.append(("C", x + d - d * k, y + h, x, y + h - d + d * k, x, y + h - d))
    cmds.append(("L", x, y + a))
    if a:
        cmds.append(("C", x, y + a - a * k, x + a - a * k, y, x + a, y))
    cmds.append(("Z",))
    return Shape(cmds)


def rect(x, y, w, h):
    return rrect(x, y, w, h, 0)


def ellipse(cx, cy, rx, ry=None):
    ry = rx if ry is None else ry
    k = KAPPA
    return Shape([
        ("M", cx + rx, cy),
        ("C", cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry),
        ("C", cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy),
        ("C", cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry),
        ("C", cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy),
        ("Z",)])


def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)


def smooth(points, tension=0.5):
    """A closed, smooth (Catmull-Rom) curve through points, clockwise."""
    pts = [tuple(p) for p in points]
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    if area < 0:
        pts = pts[::-1]
    m = len(pts)
    cmds = [("M",) + pts[0]]
    for i in range(m):
        p0, p1, p2, p3 = pts[(i - 1) % m], pts[i], pts[(i + 1) % m], pts[(i + 2) % m]
        c1 = (p1[0] + (p2[0] - p0[0]) * tension / 3, p1[1] + (p2[1] - p0[1]) * tension / 3)
        c2 = (p2[0] - (p3[0] - p1[0]) * tension / 3, p2[1] - (p3[1] - p1[1]) * tension / 3)
        cmds.append(("C",) + c1 + c2 + p2)
    cmds.append(("Z",))
    return Shape(cmds)


def blob(cx, cy, rx, ry=None, lumps=7, wobble=0.12, key="blob"):
    """A soft potato shape (a bush, a cushion, a cloud body): an ellipse with seeded bumps."""
    ry = rx if ry is None else ry
    r = rnd("blob", key, lumps)
    pts = []
    for i in range(lumps):
        a = 2 * math.pi * i / lumps
        f = 1 + r.uniform(-wobble, wobble)
        pts.append((cx + rx * f * math.cos(a), cy + ry * f * math.sin(a)))
    return smooth(pts, 0.9)


def cloud(cx, cy, w, h, puffs=4):
    """A cloud / bush: a flat base with round puffs on top (a union of shapes)."""
    s = rrect(cx - w / 2, cy - h * .1, w, h * .6, h * .3)
    for i in range(puffs):
        t = (i + .5) / puffs
        px = cx - w / 2 + w * t
        pr = h * (.42 if i % 2 == 0 else .34)
        s = s + circle(px, cy - h * .15 + (0 if i % 2 == 0 else h * .1), pr)
    return s


def star(cx, cy, R, r=None, points=5, rot=-90.0):
    r = R * .48 if r is None else r
    pts = []
    for i in range(points * 2):
        a = math.radians(rot + 180.0 * i / points)
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return poly(pts)


def heart(cx, cy, s):
    """A heart about s wide, centred on cx, cy."""
    w, h = s, s * .95
    x0, y0 = cx, cy - h * .3          # the notch
    return Shape([
        ("M", x0, y0),
        ("C", x0 + w * .1, y0 - h * .3, x0 + w * .5, y0 - h * .3, x0 + w * .5, y0 + h * .05),
        ("C", x0 + w * .5, y0 + h * .4, x0 + w * .15, y0 + h * .55, x0, y0 + h * .75),
        ("C", x0 - w * .15, y0 + h * .55, x0 - w * .5, y0 + h * .4, x0 - w * .5, y0 + h * .05),
        ("C", x0 - w * .5, y0 - h * .3, x0 - w * .1, y0 - h * .3, x0, y0),
        ("Z",)])


def path(points, closed=False):
    """An open polyline (for strokes) or closed polygon."""
    pts = [tuple(p) for p in points]
    cmds = [("M",) + pts[0]] + [("L",) + p for p in pts[1:]]
    if closed:
        cmds.append(("Z",))
    return Shape(cmds)


def arc(cx, cy, r, a0, a1, steps=None):
    """An open arc (degrees, clockwise on screen) made of cubic pieces, for smiles and the like."""
    span = a1 - a0
    steps = steps or max(1, int(abs(span) / 90) + 1)
    cmds = []
    for i in range(steps):
        t0 = math.radians(a0 + span * i / steps)
        t1 = math.radians(a0 + span * (i + 1) / steps)
        k = 4 / 3 * math.tan((t1 - t0) / 4)
        p0 = (cx + r * math.cos(t0), cy + r * math.sin(t0))
        p3 = (cx + r * math.cos(t1), cy + r * math.sin(t1))
        p1 = (p0[0] - k * r * math.sin(t0), p0[1] + k * r * math.cos(t0))
        p2 = (p3[0] + k * r * math.sin(t1), p3[1] - k * r * math.cos(t1))
        if i == 0:
            cmds.append(("M",) + p0)
        cmds.append(("C",) + p1 + p2 + p3)
    return Shape(cmds)


def ring(cx, cy, r_out, r_in):
    """A ring (needs even-odd: pass rule='evenodd' to flat())."""
    return circle(cx, cy, r_out) + circle(cx, cy, r_in)


def soft_rect(x, y, w, h):
    """A pill / very round rectangle (the usual marshmallow block)."""
    return rrect(x, y, w, h, min(w, h) * .45)


def puffs(cx, cy, w, h, n=5, key="puffs"):
    """A cloud: a soft base with round puffs on top, n puffs, seeded sizes."""
    r = rnd("puffs", key, n)
    s = rrect(cx - w / 2, cy - h * .05, w, h * .55, h * .27)
    for i in range(n):
        t = (i + .5) / n
        px = cx - w / 2 + w * (.08 + .84 * t)
        pr = h * (.30 + .14 * math.sin(math.pi * t)) * r.uniform(.9, 1.1)
        s = s + circle(px, cy - h * .02 - pr * .35, pr)
    return s





def curve(points, tension=0.5):
    """An open, smooth (Catmull-Rom) curve through points: for pipe cleaners and tails."""
    pts = [tuple(p) for p in points]
    if len(pts) == 2:
        return Shape([("M",) + pts[0], ("L",) + pts[1]])
    cmds = [("M",) + pts[0]]
    m = len(pts)
    for i in range(m - 1):
        p0, p1, p2 = pts[max(0, i - 1)], pts[i], pts[i + 1]
        p3 = pts[min(m - 1, i + 2)]
        c1 = (p1[0] + (p2[0] - p0[0]) * tension / 3, p1[1] + (p2[1] - p0[1]) * tension / 3)
        c2 = (p2[0] - (p3[0] - p1[0]) * tension / 3, p2[1] - (p3[1] - p1[1]) * tension / 3)
        cmds.append(("C",) + c1 + c2 + p2)
    return Shape(cmds)


def sample(points, step=4.0, tension=0.5):
    """Points along the open smooth curve through points, about step apart (for the twist stripes)."""
    pts = [tuple(p) for p in points]
    out = []
    m = len(pts)
    for i in range(m - 1):
        p0, p1, p2 = pts[max(0, i - 1)], pts[i], pts[i + 1]
        p3 = pts[min(m - 1, i + 2)]
        c1 = (p1[0] + (p2[0] - p0[0]) * tension / 3, p1[1] + (p2[1] - p0[1]) * tension / 3)
        c2 = (p2[0] - (p3[0] - p1[0]) * tension / 3, p2[1] - (p3[1] - p1[1]) * tension / 3)
        length = math.dist(p1, p2)
        k = max(2, int(length / step))
        for j in range(k):
            t = j / k
            u = 1 - t
            x = u ** 3 * p1[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t ** 3 * p2[0]
            y = u ** 3 * p1[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t ** 3 * p2[1]
            out.append((x, y))
    out.append(pts[-1])
    return out


def bumpy(cx, cy, rx, ry, key, amp=1.6, rot=0.0, every=7.0):
    """An ellipse with a soft scalloped edge (the yarn of a pom-pom), rotated rot degrees."""
    r = rnd("bumpy", key, round(rx), round(ry))
    per = 2 * math.pi * math.sqrt((rx * rx + ry * ry) / 2)
    k = max(14, int(per / every)) * 2
    pts = []
    for i in range(k):
        a = 2 * math.pi * i / k
        out = amp * (1 if i % 2 == 0 else -.35) * r.uniform(.6, 1.15)
        pts.append((cx + (rx + out) * math.cos(a), cy + (ry + out) * math.sin(a)))
    s = smooth(pts, .55)
    return s.rotate(rot, cx, cy) if rot else s


def limb(start, angles, lengths):
    """The joints of a limb from start: each segment points angles[i] degrees (0 straight down,
    90 to the right, -90 to the left, 180 up), lengths[i] long. Returns the points, start included."""
    pts = [tuple(start)]
    x, y = start
    for a, l in zip(angles, lengths):
        r = math.radians(a)
        x, y = x + math.sin(r) * l, y + math.cos(r) * l
        pts.append((x, y))
    return pts

# ---------------------------------------------------------------- the SVG writer
class Ctx:
    """One SVG file being drawn: viewBox 0 0 w h. Gradients go into <defs> (ids are hashes of their
    content, so files are deterministic)."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.body = []
        self.defs = {}
        self._open = 0

    # ---- gradients
    def _grad(self, kind, attrs, stops):
        st = "".join(f'<stop offset="{o:g}" stop-color="{c}"' + (f' stop-opacity="{a:.2f}"' if a < 1 else "") + "/>"
                     for o, c, a in stops)
        key = hashlib.md5((kind + attrs + st).encode()).hexdigest()[:8]
        gid = f"g{key}"
        self.defs.setdefault(gid, f'<{kind} id="{gid}" gradientUnits="userSpaceOnUse" {attrs}>{st}</{kind}>')
        return f"url(#{gid})"

    def linear(self, x1, y1, x2, y2, stops):
        """stops: [(offset, colour, opacity)]."""
        return self._grad("linearGradient", f'x1="{n(x1)}" y1="{n(y1)}" x2="{n(x2)}" y2="{n(y2)}"', stops)

    def radial(self, cx, cy, r, stops):
        return self._grad("radialGradient", f'cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}"', stops)

    # ---- raw
    def path_el(self, d, fill="none", stroke=None, sw=0.0, op=1.0, cap="round"):
        a = [f'd="{d}"', f'fill="{fill}"']
        if stroke:
            a += [f'stroke="{stroke}"', f'stroke-width="{n(sw)}"', f'stroke-linecap="{cap}"', 'stroke-linejoin="round"']
        if op < 1:
            a.append(f'fill-opacity="{op:.2f}"' if fill != "none" else f'stroke-opacity="{op:.2f}"')
        self.body.append("<path " + " ".join(a) + "/>")

    def flat(self, shape, col, op=1.0):
        self.path_el(shape.d(), col, op=op)

    def fill(self, shape, paint, op=1.0):
        """Fill with any paint (a gradient url)."""
        self.path_el(shape.d(), paint, op=op)

    def stroke(self, shape, col=INK, w=3.0, op=1.0, cap="round"):
        self.path_el(shape.d(), "none", col, w, op=op, cap=cap)

    def dots(self, points, r, col, op=1.0):
        s = Shape()
        for x, y in points:
            s = s + circle(x, y, r)
        self.flat(s, col, op)

    def sparkle(self, cx, cy, r, col="#FFD24A", op=1.0):
        k = .16
        self.flat(Shape([("M", cx, cy - r), ("C", cx + r * k, cy - r * k, cx + r * k, cy - r * k, cx + r, cy),
                         ("C", cx + r * k, cy + r * k, cx + r * k, cy + r * k, cx, cy + r),
                         ("C", cx - r * k, cy + r * k, cx - r * k, cy + r * k, cx - r, cy),
                         ("C", cx - r * k, cy - r * k, cx - r * k, cy - r * k, cx, cy - r), ("Z",)]), col, op)


    # ---- the craft pieces
    def ground(self, cx, y, w, op=.13):
        """A soft shadow on the floor under a puppet."""
        self.path_el(ellipse(cx, y, w, w * .12).d(), SHADOW, op=op)

    def pom(self, cx, cy, rx, ry=None, col=GREEN, key="pom", rot=0.0, edge=3.4, fibres=True, shade=True):
        """A yarn pom-pom: a bold dark bumpy outline, a thin fuzzy ring in its colour, a soft round
        body lit from the top left, and a few lighter fibres."""
        ry = rx if ry is None else ry
        dark = mix(col, INK, .6)
        self.path_el(bumpy(cx, cy, rx + edge, ry + edge, key + "o", amp=1.5, rot=rot).d(), dark)
        self.path_el(bumpy(cx, cy, rx + 1.3, ry + 1.3, key + "f", amp=1.3, rot=rot, every=5.0).d(), mix(col, INK, .12))
        body = ellipse(cx, cy, rx, ry)
        if rot:
            body = body.rotate(rot, cx, cy)
        if shade:
            r = max(rx, ry)
            self.path_el(body.d(), self.radial(cx - rx * .3, cy - ry * .35, r * 1.35,
                                               [(0, lt(col, .3), 1), (.55, col, 1), (1, mix(col, INK, .22), 1)]))
        else:
            self.path_el(body.d(), col)
        if fibres and min(rx, ry) > 9:
            g = rnd("fibres", key)
            s = Shape()
            for _ in range(int(6 + (rx + ry) / 9)):
                a = g.uniform(0, 2 * math.pi)
                d = g.uniform(.25, .82)
                x, y = cx + rx * d * math.cos(a), cy + ry * d * math.sin(a)
                t = a + math.pi / 2 + g.uniform(-.5, .5)
                l = min(rx, ry) * g.uniform(.12, .22)
                s = s + Shape([("M", x - math.cos(t) * l, y - math.sin(t) * l), ("L", x + math.cos(t) * l, y + math.sin(t) * l)])
            if rot:
                s = s.rotate(rot, cx, cy)
            self.path_el(s.d(), "none", lt(col, .45), 1.4, op=.55)

    def cleaner(self, points, col, w=8.0, edge=2.4, twist=True, cap="round"):
        """A pipe cleaner along the smooth curve through points: a dark outline, its colour, a
        lighter middle and the slanted stripes of its twisted wire."""
        d = curve(points).d()
        self.path_el(d, "none", mix(col, INK, .6), w + edge * 2, cap=cap)
        self.path_el(d, "none", mix(col, INK, .1), w + 1.2, cap=cap)
        self.path_el(d, "none", col, w, cap=cap)
        self.path_el(d, "none", lt(col, .4), w * .32, op=.7, cap=cap)
        if twist:
            pts = sample(points, max(3.5, w * .75))
            s = Shape()
            for i in range(1, len(pts) - 1):
                (x0, y0), (x1, y1) = pts[i - 1], pts[i + 1]
                dx, dy = x1 - x0, y1 - y0
                L = math.hypot(dx, dy) or 1
                nx, ny = -dy / L, dx / L
                tx, ty = dx / L, dy / L
                x, y = pts[i]
                h = w * .42
                s = s + Shape([("M", x - nx * h - tx * h * .5, y - ny * h - ty * h * .5), ("L", x + nx * h + tx * h * .5, y + ny * h + ty * h * .5)])
            if s.cmds:
                self.path_el(s.d(), "none", mix(col, INK, .25), max(1.0, w * .16), op=.5)

    def googly(self, cx, cy, r, look=(0.0, .2), closed=False):
        """A googly eye: a dark rim, white, a big black pupil that has rolled to look, a glint.
        closed: a sleepy shut eye (a curve on a white-less lid)."""
        if closed:
            self.stroke(arc(cx, cy - r * .35, r * .95, 25, 155), INK, max(2.0, r * .28))
            return
        self.path_el(circle(cx, cy, r + max(1.4, r * .14)).d(), INK)
        self.path_el(circle(cx, cy, r).d(), WHITE)
        px, py = cx + look[0] * r * .38, cy + look[1] * r * .38
        self.path_el(circle(px, py, r * .56).d(), INK)
        self.path_el(circle(px - r * .2, py - r * .22, r * .17).d(), WHITE)

    def felt(self, shape, col, edge=1.6, op=1.0):
        """A felt cut-out: flat colour with a slightly darker cut edge."""
        if edge:
            self.path_el(shape.d(), "none", mix(col, INK, .35), edge * 2, op=op)
        self.path_el(shape.d(), col, op=op)

    def mouth(self, cx, cy, w, open_=0.0, col=INK):
        """A stitched smile (open_ 0) or an open felt mouth (open_ up to 1)."""
        if open_ <= 0:
            self.stroke(arc(cx, cy - w * .45, w * .55, 30, 150), col, max(1.6, w * .17))
            return
        h = w * .9 * open_
        m = Shape([("M", cx - w / 2, cy), ("C", cx - w * .45, cy + h * 1.3, cx + w * .45, cy + h * 1.3, cx + w / 2, cy),
                   ("C", cx + w * .2, cy - h * .15, cx - w * .2, cy - h * .15, cx - w / 2, cy), ("Z",)])
        self.felt(m, MOUTH, edge=1.2)
        self.felt(ellipse(cx, cy + h * .55, w * .22, h * .25), "#FF8FA0", edge=0)

    def cheeks(self, cx, cy, gap, r, op=.5):
        for x in (cx - gap / 2, cx + gap / 2):
            self.path_el(ellipse(x, cy, r, r * .62).d(), CHEEK, op=op)

    # ---- groups
    def begin(self, transform=None, op=None):
        a = ""
        if transform:
            a += f' transform="{transform}"'
        if op is not None:
            a += f' opacity="{op:.2f}"'
        self.body.append(f"<g{a}>")
        self._open += 1

    def end(self):
        self.body.append("</g>")
        self._open -= 1

    def svg(self):
        if self._open:
            raise SystemExit("Ctx: a <g> was not closed")
        defs = f"<defs>{''.join(self.defs[k] for k in sorted(self.defs))}</defs>" if self.defs else ""
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {n(self.w)} {n(self.h)}">'
                f'{defs}{"".join(self.body)}</svg>\n')


# ---------------------------------------------------------------- checks (docs/art.md: flutter_svg)
FORBIDDEN = ("<filter", "<mask", "<style", "style=", "class=", "<text", "<image", "<foreignObject", "<pattern",
             "mix-blend-mode", "mask=", "filter=", "vector-effect", "<symbol", "<marker", "@import", "<clipPath",
             "clip-path=")
_TOK = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
_NARGS = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7, "Z": 0}
DRAWN = {"path", "ellipse", "circle", "rect", "polygon", "polyline", "line", "use"}
MAX_KB = 70


def check_path(d):
    """ValueError unless d is path data flutter_svg reads (it drops the WHOLE picture over one bad
    path, where Chromium only skips that path)."""
    toks = _TOK.findall(d)
    if not toks or toks[0] not in "Mm":
        raise ValueError(f"path does not start with M: {d[:40]!r}")
    if len("".join(toks)) != len(re.sub(r"[\s,]", "", d)):
        raise ValueError(f"stray characters in path: {d[:60]!r}")
    i = 0
    while i < len(toks):
        cmd = toks[i]
        if not cmd.isalpha():
            raise ValueError(f"numbers without a command: {d[:60]!r}")
        i += 1
        k = _NARGS[cmd.upper()]
        j = i
        while j < len(toks) and not toks[j].isalpha():
            j += 1
        cnt = j - i
        if (k == 0 and cnt) or (k and (cnt == 0 or cnt % k)):
            raise ValueError(f"command {cmd} has {cnt} numbers: {d[:60]!r}")
        i = j


def check_svg(name, text, size=None):
    """docs/art.md's rules: no filter/mask/style/text/image/pattern/blend, every drawn element has
    fill or stroke, under 70 KB, well-formed XML ending in </svg>, viewBox 0 0 w h (= size if given),
    parseable path data. Returns the size in KB; SystemExit on a problem."""
    bad = [f for f in FORBIDDEN if f in text]
    if bad:
        raise SystemExit(f"{name}: uses {bad} (flutter_svg cannot draw these)")
    kb = len(text.encode()) / 1024
    if kb > MAX_KB:
        raise SystemExit(f"{name}: {kb:.0f} KB (keep under {MAX_KB} KB)")
    if not text.rstrip().endswith("</svg>"):
        raise SystemExit(f"{name}: does not end with </svg>")
    try:
        root = ET.fromstring(text)
    except ET.ParseError as e:
        raise SystemExit(f"{name}: not well-formed XML: {e}")
    ns = "{http://www.w3.org/2000/svg}"
    if root.tag != f"{ns}svg":
        raise SystemExit(f"{name}: root is not <svg xmlns=...>")
    vb = root.get("viewBox")
    if not vb:
        raise SystemExit(f"{name}: no viewBox")
    vb = [float(v) for v in vb.split()]
    if vb[0] or vb[1]:
        raise SystemExit(f"{name}: viewBox must start at 0 0")
    if size and (abs(vb[2] - size[0]) > .01 or abs(vb[3] - size[1]) > .01):
        raise SystemExit(f"{name}: viewBox {vb[2]:g} x {vb[3]:g}, expected {size[0]:g} x {size[1]:g}")
    defs = root.find(f"{ns}defs")
    in_defs = {id(el) for el in defs.iter()} if defs is not None else set()
    for el in root.iter():
        tag = el.tag.replace(ns, "")
        d = el.get("d")
        if d is not None:
            try:
                check_path(d)
            except ValueError as e:
                raise SystemExit(f"{name}: {e}")
        if tag in DRAWN and id(el) not in in_defs and el.get("fill") is None and el.get("stroke") is None:
            raise SystemExit(f"{name}: a <{tag}> without fill/stroke")
        for a in ("fill", "stroke"):
            v = el.get(a)
            if v and v.startswith("url(#") and root.find(f".//*[@id='{v[5:-1]}']") is None:
                raise SystemExit(f"{name}: {a} points to a missing {v}")
    return kb


def viewbox_of(path):
    """(w, h) of an SVG file's viewBox."""
    vb = [float(v) for v in ET.parse(path).getroot().get("viewBox").split()]
    return vb[2], vb[3]


def write_svg(path, text, size=None):
    """Check, then write. Returns the size in KB."""
    path = pathlib.Path(path)
    name = str(path.relative_to(ROOT)) if ROOT in path.parents else str(path)
    kb = check_svg(name, text, size)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return kb
