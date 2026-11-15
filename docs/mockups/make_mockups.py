"""Design-stage sketches for 「動物動一動」 (working name): a movement app for ages 2-5.

    python3 make_mockups.py          # writes docs/mockups/*.png (needs Node.js + Playwright's Chromium)
    python3 make_mockups.py 3        # only one page: 0 = style page, 1..8 = a screen, c = contact sheet

The app is LANDSCAPE: the phone or tablet stands on its side on a table like a small TV, 1.5-3 m away,
and the child copies the big animal with the whole body. So every screen here is 844x390 CSS px
(a phone on its side), rendered at device scale 2.

Every picture is drawn here by code as SVG: no outside pictures, no emoji. The text uses the font
jf open 粉圓 2.1 from a sibling app's checkout (in the real app Flutter draws the text, not the SVG).

    0_畫風選擇.png     the same "follow me" screen (frog jump in the jungle) in three styles:
                       A 摺紙風 (origami, recommended), B 毛球毛根風 (pom-pom and pipe-cleaner craft),
                       C 黑板粉筆風 (chalk on a blackboard). Screens 1-8 are drawn in A.
    1_首頁.png         home: five adventures, the dance party, make-your-own, slow stretch
    2_先看看四周.png   the "clear the space" check before moving
    3_跟著做.png       one move: the big frog jumps, the child copies; a kid shows the human version
    4_動物舞會.png     dance and freeze: the music stopped, freeze like a flamingo
    5_自己排.png       make your own routine from animal cards
    6_慢慢伸展.png     the calm-down stretch at the end, with slow breathing
    7_休息.png         time is up: 「換你去做了！」
    8_家長模式.png     settings, minutes moved this week, what each move trains
    contact_sheet.png  screens 1-8 small, with titles

How each style is drawn with only what flutter_svg can draw (no filter, mask, pattern, style, text or
image elements). Every animal is a list of simple parts (ellipses, limbs, polygons, eyes) shared by all
three styles; each style only changes how a part is painted:
- A 摺紙風: each part becomes a 6-8 sided polygon and is split into triangles from its centre; each
  triangle is painted light, middle or dark by which way it faces (light comes from the top left), so
  it looks folded from paper. A shifted copy at 10% black is the shadow. Parts are rigid, so in the app
  an animal moves by turning its parts around the joints (a paper puppet).
- B 毛球毛根風: ellipses are pom-poms: the fill plus a wide dashed stroke on the edge, which reads as
  fuzz; limbs are pipe cleaners: a round-capped line over a wider dashed line; googly eyes.
- C 黑板粉筆風: a dark green board; each part is a faint fill, chalk hatching clipped to the shape
  (clipPath) and two slightly wobbly outlines in pale chalk.
"""
import hashlib
import math
import pathlib
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
FONT = None
for _c in ("app_kids_maze", "app_kids_falsecharge", "app_kids_live_circ", "app_kids_brainstorming",
           "app_kids_card_game", "app_kids_cook", "app_kids_bopomofo"):
    _p = pathlib.Path("/home/user") / _c / "app" / "assets" / "fonts" / "jf-openhuninn-2.1.ttf"
    if _p.exists():
        FONT = _p
        break
if FONT is None:
    sys.exit("font jf-openhuninn-2.1.ttf not found in a sibling app's checkout")
SCRATCH = pathlib.Path("/dev/shm") if pathlib.Path("/dev/shm").is_dir() else pathlib.Path(tempfile.gettempdir())
W, H = 844, 390
STYLE = "origami"     # "origami" (A, recommended), "pompom" (B), "chalk" (C)

# ---------------------------------------------------------------- colours (paper)
INK = "#3D3346"
SOFT = "#8C8395"
PAPER = "#FBF6EC"
SKY = "#D6EEF3"
LEAF = "#6DBE5A"
LEAF2 = "#4FA35A"
LEAF3 = "#2F7D5B"
GRASS = "#A9D86E"
WATER = "#7CC6E4"
WATER2 = "#5AAFD6"
SUN = "#FFC94A"
ORANGE = "#F59B3A"
RED = "#EE5D4E"
PINK = "#F48FB1"
PURPLE = "#9A7FD1"
BLUE = "#4FA3E0"
YELLOW = "#FFD64A"
BROWN = "#B9784A"
TAN = "#F3D2A6"
NAVY = "#3E4A6B"
WHITE = "#FFFDF7"
GO = "#5DBB63"
CHEEK = "#FF9DB0"
SKIN = "#F6D2B4"
HAIR = "#4A3A3A"
EYE = "#2E2836"
BOARD = "#2E4A40"


# ---------------------------------------------------------------- defs registry and small maths
class Defs:
    def __init__(self):
        self.d = {}

    def add(self, key, svg):
        self.d.setdefault(key, svg)
        return key

    def svg(self):
        return "<defs>" + "".join(self.d.values()) + "</defs>"


D = Defs()


def _h(*parts):
    return hashlib.md5("|".join(map(str, (STYLE,) + parts)).encode()).hexdigest()[:10]


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mixc(a, b, t):
    ra, rb = _rgb(a), _rgb(b)
    return "#%02X%02X%02X" % tuple(round(ra[i] + (rb[i] - ra[i]) * t) for i in range(3))


def darker(c, t=.25):
    return mixc(c, "#1E1428", t)


def lighter(c, t=.35):
    return mixc(c, "#FFFFFF", t)


def _rand(seed, i):
    return int(hashlib.md5(f"{seed}:{i}".encode()).hexdigest()[:8], 16) / 0xFFFFFFFF


def lg(stops, x1=0, y1=0, x2=0, y2=1):
    k = "lg" + _h(stops, x1, y1, x2, y2)
    D.add(k, f'<linearGradient id="{k}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">' +
          "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops) + "</linearGradient>")
    return f"url(#{k})"


def fmt(pts):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)


# ---------------------------------------------------------------- parts
# An animal (or a tree, a sign...) is a list of parts in its own coordinates:
#   ("ell", cx, cy, rx, ry, rot, col)     ("cap", x1, y1, x2, y2, w, col)     ("poly", pts, col)
#   ("line", pts, w, col)                 ("eye", cx, cy, r)                   ("dot", cx, cy, r, col)
#   ("shut", cx, cy, r)  a sleeping eye
def E(cx, cy, rx, ry, col, rot=0):
    return ("ell", cx, cy, rx, ry, rot, col)


def C(x1, y1, x2, y2, w, col):
    return ("cap", x1, y1, x2, y2, w, col)


def P(pts, col):
    return ("poly", list(pts), col)


def L(pts, w=2.4, col=EYE):
    return ("line", list(pts), w, col)


def EYEp(cx, cy, r):
    return ("eye", cx, cy, r)


def DOT(cx, cy, r, col):
    return ("dot", cx, cy, r, col)


def SHUT(cx, cy, r):
    return ("shut", cx, cy, r)


def arc_pts(cx, cy, r, a0, a1, n=8):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def smile(cx, cy, w, deep=.5):
    return L([(cx - w, cy), (cx - w * .5, cy + w * deep * .8), (cx, cy + w * deep), (cx + w * .5, cy + w * deep * .8), (cx + w, cy)], 2.2)


def mirror(parts):
    out = []
    for p in parts:
        k = p[0]
        if k == "ell":
            out.append(("ell", -p[1], p[2], p[3], p[4], -p[5], p[6]))
        elif k == "cap":
            out.append(("cap", -p[1], p[2], -p[3], p[4], p[5], p[6]))
        elif k == "poly":
            out.append(("poly", [(-x, y) for x, y in p[1]], p[2]))
        elif k == "line":
            out.append(("line", [(-x, y) for x, y in p[1]], p[2], p[3]))
        else:
            out.append((k, -p[1]) + tuple(p[2:]))
    return out


def xform(parts, X, Y, s=1.0, rot=0.0, flip=False):
    """Moves parts from their own coordinates to the page (scale, turn, mirror) in Python, so the
    paper shading below always has its light from the top left."""
    if flip:
        parts = mirror(parts)
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))

    def T(x, y):
        return (X + s * (x * ca - y * sa), Y + s * (x * sa + y * ca))

    out = []
    for p in parts:
        k = p[0]
        if k == "ell":
            cx, cy = T(p[1], p[2])
            out.append(("ell", cx, cy, p[3] * s, p[4] * s, p[5] + rot, p[6]))
        elif k == "cap":
            a, b = T(p[1], p[2]), T(p[3], p[4])
            out.append(("cap", a[0], a[1], b[0], b[1], p[5] * s, p[6]))
        elif k == "poly":
            out.append(("poly", [T(x, y) for x, y in p[1]], p[2]))
        elif k == "line":
            out.append(("line", [T(x, y) for x, y in p[1]], p[2] * s, p[3]))
        else:
            cx, cy = T(p[1], p[2])
            out.append((k, cx, cy, p[3] * s) + tuple(p[4:]))
    return out


def ell_pts(cx, cy, rx, ry, rot=0, n=None, seed=0, jit=.07):
    if n is None:
        n = 6 if max(rx, ry) < 9 else (7 if max(rx, ry) < 22 else 8)
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    ph = -math.pi / 2 + .35
    pts = []
    for i in range(n):
        a = ph + 2 * math.pi * i / n
        j = 1 + jit * (_rand(seed, i) - .5)
        x, y = rx * math.cos(a) * j, ry * math.sin(a) * j
        pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    return pts


def cap_pts(x1, y1, x2, y2, w, round_=False):
    dx, dy = x2 - x1, y2 - y1
    ln = math.hypot(dx, dy) or 1
    ux, uy = dx / ln, dy / ln
    nx, ny = -uy, ux
    r = w / 2
    if round_:
        pts = []
        a0 = math.atan2(ny, nx)
        for i in range(9):
            a = a0 - math.pi * i / 8
            pts.append((x2 + r * math.cos(a), y2 + r * math.sin(a)))
        for i in range(9):
            a = a0 + math.pi - math.pi * i / 8
            pts.append((x1 + r * math.cos(a), y1 + r * math.sin(a)))
        return pts
    return [(x1 + nx * r, y1 + ny * r), (x2 + nx * r, y2 + ny * r), (x2 + ux * r * .8, y2 + uy * r * .8),
            (x2 - nx * r, y2 - ny * r), (x1 - nx * r, y1 - ny * r), (x1 - ux * r * .8, y1 - uy * r * .8)]


def part_pts(p, smooth=False):
    if p[0] == "ell":
        return ell_pts(p[1], p[2], p[3], p[4], p[5], n=28 if smooth else None, seed=_h(p[1], p[2]), jit=0 if smooth else .07)
    if p[0] == "cap":
        return cap_pts(p[1], p[2], p[3], p[4], p[5], round_=smooth)
    return p[1]


# ---------------------------------------------------------------- style A: folded paper
LIGHT = (-.5, -.866)


def ori_poly(pts, col, crease=True):
    n = len(pts)
    cx = sum(x for x, _ in pts) / n
    cy = sum(y for _, y in pts) / n
    out = []
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        ex, ey = b[0] - a[0], b[1] - a[1]
        nx, ny = ey, -ex
        mx, my = (a[0] + b[0]) / 2 - cx, (a[1] + b[1]) / 2 - cy
        if nx * mx + ny * my < 0:
            nx, ny = -nx, -ny
        ln = math.hypot(nx, ny) or 1
        sh = (nx * LIGHT[0] + ny * LIGHT[1]) / ln
        f = lighter(col, .26) if sh > .42 else (col if sh > -.25 else darker(col, .14))
        out.append(f'<polygon points="{fmt([(cx, cy), a, b])}" fill="{f}" stroke="{f}" stroke-width=".7" stroke-linejoin="round"/>')
    return "".join(out)


def ori_part(p):
    k = p[0]
    if k in ("ell", "cap", "poly"):
        return ori_poly(part_pts(p), p[-1])
    if k == "line":
        return f'<polyline points="{fmt(p[1])}" fill="none" stroke="{p[3]}" stroke-width="{p[2]:.1f}" stroke-linecap="round" stroke-linejoin="round"/>'
    if k == "eye":
        _, cx, cy, r = p[:4]
        return (f'<polygon points="{fmt(ell_pts(cx, cy, r, r * 1.1, n=6, jit=0))}" fill="{EYE}"/>'
                f'<circle cx="{cx - r * .32:.1f}" cy="{cy - r * .38:.1f}" r="{r * .3:.1f}" fill="#FFFFFF"/>')
    if k == "shut":
        _, cx, cy, r = p[:4]
        return f'<polyline points="{fmt([(cx - r, cy), (cx, cy + r * .6), (cx + r, cy)])}" fill="none" stroke="{EYE}" stroke-width="{max(1.6, r * .45):.1f}" stroke-linecap="round" stroke-linejoin="round"/>'
    if k == "dot":
        _, cx, cy, r, col = p[:5]
        return f'<polygon points="{fmt(ell_pts(cx, cy, r, r, n=6, jit=0))}" fill="{col}"/>'
    return ""


# ---------------------------------------------------------------- style B: pom-poms and pipe cleaners
def pom_part(p):
    k = p[0]
    if k == "ell":
        _, cx, cy, rx, ry, rot, col = p
        fz = max(2.5, min(rx, ry) * .32)
        tr = f'transform="rotate({rot:.1f} {cx:.1f} {cy:.1f})"'
        return (f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" {tr} fill="{col}" stroke="{darker(col, .2)}" stroke-width="{fz:.1f}" stroke-dasharray="1.1 1.5"/>'
                f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx * .97:.1f}" ry="{ry * .97:.1f}" {tr} fill="none" stroke="{lighter(col, .35)}" stroke-width="{fz * .6:.1f}" stroke-dasharray="0.9 2.2" stroke-dashoffset="1"/>'
                f'<ellipse cx="{cx - rx * .25:.1f}" cy="{cy - ry * .3:.1f}" rx="{rx * .45:.1f}" ry="{ry * .35:.1f}" {tr} fill="{lighter(col, .4)}" opacity=".45"/>')
    if k == "cap":
        _, x1, y1, x2, y2, w, col = p
        w = max(4.0, w * .62)
        ln = f'x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke-linecap="round"'
        return (f'<line {ln} stroke="{darker(col, .22)}" stroke-width="{w + 5:.1f}" stroke-dasharray="1 1.4"/>'
                f'<line {ln} stroke="{col}" stroke-width="{w:.1f}"/>'
                f'<line {ln} stroke="{lighter(col, .45)}" stroke-width="{w * .6:.1f}" stroke-dasharray="1 1.8" opacity=".8"/>')
    if k == "poly":
        pts, col = p[1], p[2]
        return (f'<polygon points="{fmt(pts)}" fill="{col}" stroke="{darker(col, .2)}" stroke-width="4" stroke-dasharray="1.1 1.5" stroke-linejoin="round"/>')
    if k == "line":
        return f'<polyline points="{fmt(p[1])}" fill="none" stroke="#3B2F2F" stroke-width="{p[2] * 1.1:.1f}" stroke-linecap="round" stroke-linejoin="round"/>'
    if k == "eye":
        _, cx, cy, r = p[:4]
        R = r * 1.7
        return (f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{R:.1f}" fill="#FFFFFF" stroke="#C9C2C9" stroke-width="1.2"/>'
                f'<circle cx="{cx + R * .2:.1f}" cy="{cy + R * .3:.1f}" r="{R * .55:.1f}" fill="#1E1A22"/>'
                f'<ellipse cx="{cx - R * .35:.1f}" cy="{cy - R * .4:.1f}" rx="{R * .3:.1f}" ry="{R * .18:.1f}" fill="#FFFFFF" opacity=".9"/>')
    if k == "shut":
        _, cx, cy, r = p[:4]
        return f'<polyline points="{fmt([(cx - r, cy), (cx, cy + r * .6), (cx + r, cy)])}" fill="none" stroke="#3B2F2F" stroke-width="2.4" stroke-linecap="round"/>'
    if k == "dot":
        _, cx, cy, r, col = p[:5]
        return f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{col}" stroke="{darker(col, .15)}" stroke-width="1.6" stroke-dasharray="0.8 1.2"/>'
    return ""


# ---------------------------------------------------------------- style C: chalk on a blackboard
def chalk_col(c):
    return mixc(c, "#FFFFFF", .45)


def wobble(pts, seed, amp=1.1, closed=True):
    out = []
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        out.append((x + amp * (_rand(seed, 2 * i) - .5) * 2, y + amp * (_rand(seed, 2 * i + 1) - .5) * 2))
    if closed:
        out.append(out[0])
    return out


def chalk_part(p):
    k = p[0]
    if k in ("ell", "cap", "poly"):
        col = p[-1]
        pts = part_pts(p, smooth=True)
        xs, ys = [x for x, _ in pts], [y for _, y in pts]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        cid = "cp" + _h("clip", fmt(pts))
        D.add(cid, f'<clipPath id="{cid}"><polygon points="{fmt(pts)}"/></clipPath>')
        hs = []
        gap = 4.2
        span = (x1 - x0) + (y1 - y0)
        i = 0
        t = -span
        while t < span:
            a = (x0 + t, y1 + 2)
            b = (x0 + t + (y1 - y0) * .75 + 4, y0 - 2)
            hs.append(f'M{a[0]:.1f} {a[1]:.1f}L{b[0]:.1f} {b[1]:.1f}')
            t += gap + 1.2 * _rand(fmt(pts[:2]), i)
            i += 1
        sd = _h(fmt(pts[:3]))
        return (f'<polygon points="{fmt(pts)}" fill="{col}" opacity=".30"/>'
                f'<path d="{"".join(hs)}" stroke="{lighter(col, .3)}" stroke-width="1.7" opacity=".6" clip-path="url(#{cid})"/>'
                f'<polyline points="{fmt(wobble(pts, sd))}" fill="none" stroke="{chalk_col(col)}" stroke-width="2.6" stroke-linejoin="round" opacity=".92"/>'
                f'<polyline points="{fmt(wobble(pts, sd + "b", 1.6))}" fill="none" stroke="{chalk_col(col)}" stroke-width="1.3" stroke-linejoin="round" opacity=".5"/>')
    if k == "line":
        return f'<polyline points="{fmt(p[1])}" fill="none" stroke="#F3F0E6" stroke-width="{p[2]:.1f}" stroke-linecap="round" stroke-linejoin="round" opacity=".9"/>'
    if k == "eye":
        _, cx, cy, r = p[:4]
        return (f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r * 1.15:.1f}" fill="#F6F3EA"/>'
                f'<circle cx="{cx + r * .15:.1f}" cy="{cy + r * .15:.1f}" r="{r * .55:.1f}" fill="{BOARD}"/>')
    if k == "shut":
        _, cx, cy, r = p[:4]
        return f'<polyline points="{fmt([(cx - r, cy), (cx, cy + r * .6), (cx + r, cy)])}" fill="none" stroke="#F3F0E6" stroke-width="2.2" stroke-linecap="round"/>'
    if k == "dot":
        _, cx, cy, r, col = p[:5]
        return f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{chalk_col(col)}" opacity=".85"/>'
    return ""


def shadow_of(parts, dx=3.0, dy=4.5, op=.11):
    out = []
    for p in parts:
        if p[0] in ("ell", "cap", "poly"):
            pts = [(x + dx, y + dy) for x, y in part_pts(p, smooth=STYLE != "origami")]
            out.append(f'<polygon points="{fmt(pts)}"/>')
    return f'<g fill="#1E1428" opacity="{op}">' + "".join(out) + "</g>" if out else ""


def draw(parts, X=0, Y=0, s=1.0, rot=0.0, flip=False, shadow=True, op=1.0):
    ps = xform(parts, X, Y, s, rot, flip)
    fn = {"origami": ori_part, "pompom": pom_part, "chalk": chalk_part}[STYLE]
    sh = shadow_of(ps, 3 * max(.6, s), 4.5 * max(.6, s)) if shadow and STYLE != "chalk" else ""
    body = "".join(fn(p) for p in ps)
    return f'<g opacity="{op}">{sh}{body}</g>' if op < 1 else sh + body


# ---------------------------------------------------------------- text and simple shapes
def tcol():
    return "#F3F0E6" if STYLE == "chalk" else INK


def tx(x, y, s, size=16, color=None, anchor="middle", extra=""):
    return f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" fill="{color or tcol()}" text-anchor="{anchor}" font-family="Huninn, sans-serif" {extra}>{s}</text>'


def txo(x, y, s, size, color, ol="#FFFFFF", ow=6, anchor="middle"):
    return tx(x, y, s, size, color, anchor, f'stroke="{ol}" stroke-width="{ow}" stroke-linejoin="round" paint-order="stroke"')


def rr_path(x, y, w, h, r):
    return (f"M{x + r:.1f} {y:.1f}H{x + w - r:.1f}Q{x + w:.1f} {y:.1f} {x + w:.1f} {y + r:.1f}V{y + h - r:.1f}"
            f"Q{x + w:.1f} {y + h:.1f} {x + w - r:.1f} {y + h:.1f}H{x + r:.1f}Q{x:.1f} {y + h:.1f} {x:.1f} {y + h - r:.1f}"
            f"V{y + r:.1f}Q{x:.1f} {y:.1f} {x + r:.1f} {y:.1f}Z")


def card(x, y, w, h, col=PAPER, r=14, fold=True):
    """A panel: a sheet of paper with a folded corner (A), a felt board with a fuzzy rim (B), a chalk frame (C)."""
    if STYLE == "origami":
        out = f'<path d="{rr_path(x + 3, y + 5, w, h, r)}" fill="#1E1428" opacity=".10"/>'
        out += f'<path d="{rr_path(x, y, w, h, r)}" fill="{col}"/>'
        cid = "cp" + _h("card", x, y, w, h)
        D.add(cid, f'<clipPath id="{cid}"><path d="{rr_path(x, y, w, h, r)}"/></clipPath>')
        out += f'<polygon points="{fmt([(x, y), (x + w * .62, y), (x, y + h * .9)])}" fill="#FFFFFF" opacity=".35" clip-path="url(#{cid})"/>'
        if fold:
            f = 22
            out += (f'<polygon points="{fmt([(x + w - f, y), (x + w, y + f), (x + w, y)])}" fill="{SKY if col == PAPER else lighter(col, .5)}"/>'
                    f'<polygon points="{fmt([(x + w - f, y), (x + w - f, y + f), (x + w, y + f)])}" fill="{darker(col, .12)}"/>')
        return out
    if STYLE == "pompom":
        return (f'<path d="{rr_path(x + 2, y + 4, w, h, r)}" fill="#3B2F2F" opacity=".12"/>'
                f'<path d="{rr_path(x, y, w, h, r)}" fill="{col}" stroke="{darker(col, .25)}" stroke-width="6" stroke-dasharray="1 1.4"/>'
                f'<path d="{rr_path(x + 6, y + 6, w - 12, h - 12, r - 4)}" fill="none" stroke="{darker(col, .3)}" stroke-width="1.4" stroke-dasharray="5 4"/>')
    pts = [(x + r, y), (x + w - r, y), (x + w, y + r), (x + w, y + h - r), (x + w - r, y + h), (x + r, y + h), (x, y + h - r), (x, y + r)]
    dense = []
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        for j in range(6):
            dense.append((a[0] + (b[0] - a[0]) * j / 6, a[1] + (b[1] - a[1]) * j / 6))
    sd = _h("cardc", x, y)
    return (f'<polygon points="{fmt(dense)}" fill="{BOARD}"/><polygon points="{fmt(dense)}" fill="#FFFFFF" opacity=".05"/>'
            f'<polyline points="{fmt(wobble(dense, sd, .9))}" fill="none" stroke="#F3F0E6" stroke-width="2.4" opacity=".85"/>'
            f'<polyline points="{fmt(wobble(dense, sd + "x", 1.4))}" fill="none" stroke="#F3F0E6" stroke-width="1.1" opacity=".45"/>')


def button(x, y, w, h, col, label="", size=24, icon="", tcolor="#FFFFFF", r=None):
    r = h / 2 if r is None else r
    if STYLE == "origami":
        cid = "cp" + _h("btn", x, y, w, h)
        D.add(cid, f'<clipPath id="{cid}"><path d="{rr_path(x, y, w, h, r)}"/></clipPath>')
        out = (f'<path d="{rr_path(x + 2, y + 5, w, h, r)}" fill="{darker(col, .35)}" opacity=".45"/>'
               f'<path d="{rr_path(x, y, w, h, r)}" fill="{col}"/>'
               f'<polygon points="{fmt([(x, y), (x + w * .7, y), (x + w * .3, y + h), (x, y + h)])}" fill="{lighter(col, .2)}" clip-path="url(#{cid})"/>'
               f'<line x1="{x + w * .7:.1f}" y1="{y:.1f}" x2="{x + w * .3:.1f}" y2="{y + h:.1f}" stroke="#FFFFFF" stroke-width="1.2" opacity=".45" clip-path="url(#{cid})"/>')
    elif STYLE == "pompom":
        out = (f'<path d="{rr_path(x + 2, y + 4, w, h, r)}" fill="#3B2F2F" opacity=".15"/>'
               f'<path d="{rr_path(x, y, w, h, r)}" fill="{col}" stroke="{darker(col, .22)}" stroke-width="7" stroke-dasharray="1 1.4"/>'
               f'<path d="{rr_path(x + 8, y + 5, w - 16, h * .4, h * .2)}" fill="#FFFFFF" opacity=".22"/>')
        tcolor = "#FFFFFF"
    else:
        out = chalk_part(("poly", cap_pts(x + r, y + h / 2, x + w - r, y + h / 2, h, round_=True), col))
        tcolor = "#FFFFFF"
    if label:
        dx = 16 if icon else 0
        out += tx(x + w / 2 + dx, y + h / 2 + size * .36, label, size, tcolor)
    if icon:
        out += icon_svg(icon, x + w / 2 - len(label) * size / 2 - 4 + (0 if label else len(label)), y + h / 2, size * .9, tcolor)
    return out


def round_btn(cx, cy, r, col, icon, icol="#FFFFFF"):
    out = button(cx - r, cy - r, 2 * r, 2 * r, col, r=r)
    return out + icon_svg(icon, cx, cy, r * 1.05, chalk_col(col) if STYLE == "chalk" else icol)


def icon_svg(name, cx, cy, s, col):
    """Small UI icons as paths (the real app uses the same shapes in SVG)."""
    k = s / 24
    if name == "home":
        return (f'<path d="M{cx - 9 * k:.1f} {cy:.1f}L{cx:.1f} {cy - 9 * k:.1f}L{cx + 9 * k:.1f} {cy:.1f}V{cy + 9 * k:.1f}H{cx - 9 * k:.1f}Z" fill="{col}"/>')
    if name == "pause":
        return (f'<rect x="{cx - 7 * k:.1f}" y="{cy - 8 * k:.1f}" width="{5 * k:.1f}" height="{16 * k:.1f}" rx="{1.5 * k:.1f}" fill="{col}"/>'
                f'<rect x="{cx + 2 * k:.1f}" y="{cy - 8 * k:.1f}" width="{5 * k:.1f}" height="{16 * k:.1f}" rx="{1.5 * k:.1f}" fill="{col}"/>')
    if name == "again":
        a = arc_pts(cx, cy, 8 * k, -60, 230, 12)
        tip = a[0]
        return (f'<polyline points="{fmt(a)}" fill="none" stroke="{col}" stroke-width="{3.2 * k:.1f}" stroke-linecap="round"/>'
                f'<polygon points="{fmt([(tip[0] + 5 * k, tip[1] - 5 * k), (tip[0] + 4 * k, tip[1] + 5 * k), (tip[0] - 5 * k, tip[1] + 1 * k)])}" fill="{col}"/>')
    if name == "lock":
        return (f'<path d="M{cx - 5 * k:.1f} {cy - 1 * k:.1f}V{cy - 5 * k:.1f}A{5 * k:.1f} {5 * k:.1f} 0 0 1 {cx + 5 * k:.1f} {cy - 5 * k:.1f}V{cy - 1 * k:.1f}" fill="none" stroke="{col}" stroke-width="{2.6 * k:.1f}"/>'
                f'<rect x="{cx - 8 * k:.1f}" y="{cy - 1.5 * k:.1f}" width="{16 * k:.1f}" height="{11 * k:.1f}" rx="{2.5 * k:.1f}" fill="{col}"/>')
    if name == "check":
        return f'<polyline points="{fmt([(cx - 7 * k, cy), (cx - 2 * k, cy + 5 * k), (cx + 8 * k, cy - 6 * k)])}" fill="none" stroke="{col}" stroke-width="{3.6 * k:.1f}" stroke-linecap="round" stroke-linejoin="round"/>'
    if name == "play":
        return f'<polygon points="{fmt([(cx - 6 * k, cy - 9 * k), (cx + 9 * k, cy), (cx - 6 * k, cy + 9 * k)])}" fill="{col}" stroke="{col}" stroke-width="{2 * k:.1f}" stroke-linejoin="round"/>'
    if name == "back":
        return f'<polyline points="{fmt([(cx + 4 * k, cy - 8 * k), (cx - 4 * k, cy), (cx + 4 * k, cy + 8 * k)])}" fill="none" stroke="{col}" stroke-width="{3.4 * k:.1f}" stroke-linecap="round" stroke-linejoin="round"/>'
    if name == "note":
        return (f'<ellipse cx="{cx - 3 * k:.1f}" cy="{cy + 6 * k:.1f}" rx="{5 * k:.1f}" ry="{4 * k:.1f}" fill="{col}"/>'
                f'<path d="M{cx + 1.5 * k:.1f} {cy + 6 * k:.1f}V{cy - 9 * k:.1f}L{cx + 9 * k:.1f} {cy - 6 * k:.1f}V{cy - 2 * k:.1f}L{cx + 1.5 * k:.1f} {cy - 5 * k:.1f}" fill="{col}" stroke="{col}" stroke-width="{1.6 * k:.1f}" stroke-linejoin="round"/>')
    if name == "dice":
        out = f'<rect x="{cx - 9 * k:.1f}" y="{cy - 9 * k:.1f}" width="{18 * k:.1f}" height="{18 * k:.1f}" rx="{4 * k:.1f}" fill="{col}"/>'
        for dx, dy in ((-4, -4), (4, 4), (0, 0), (4, -4), (-4, 4)):
            out += f'<circle cx="{cx + dx * k:.1f}" cy="{cy + dy * k:.1f}" r="{1.7 * k:.1f}" fill="{INK}"/>'
        return out
    return ""


# ================================================================ animals (one list of parts each)
FROG = "#6CC24A"
BELLY = "#E6F2A8"


def frog(pose="sit"):
    if pose == "jump":
        return [
            C(-14, 14, -44, 26, 15, darker(FROG, .1)), C(-44, 26, -66, 44, 10, darker(FROG, .1)), E(-72, 48, 11, 5, darker(FROG, .1), 20),
            C(-6, 18, -30, 38, 13, darker(FROG, .1)), C(-30, 38, -50, 56, 9, darker(FROG, .1)), E(-55, 60, 10, 5, darker(FROG, .1), 25),
            E(2, 2, 40, 25, FROG, -22), E(8, 10, 25, 13, BELLY, -22),
            C(22, -6, 44, -26, 9, FROG), E(48, -30, 7, 5, FROG, -40),
            C(26, 4, 52, -10, 9, FROG), E(56, -12, 7, 5, FROG, -30),
            E(14, -26, 12, 11, FROG), E(32, -18, 12, 11, FROG),
            EYEp(14, -28, 6), EYEp(32, -20, 6),
            L([(26, -2), (32, 2), (40, 0)], 2.2), DOT(38, -6, 3.5, CHEEK),
        ]
    if pose == "squat":
        return [
            E(-34, 34, 22, 13, darker(FROG, .1), -15), E(34, 34, 22, 13, darker(FROG, .1), 15),
            E(-44, 46, 12, 5, darker(FROG, .1)), E(44, 46, 12, 5, darker(FROG, .1)),
            E(0, 16, 36, 30, FROG), E(0, 26, 22, 16, BELLY),
            C(-12, 26, -14, 46, 9, FROG), C(12, 26, 14, 46, 9, FROG),
            E(-16, 48, 9, 4, FROG), E(16, 48, 9, 4, FROG),
            E(-17, -14, 13, 12, FROG), E(17, -14, 13, 12, FROG),
            EYEp(-17, -16, 6.5), EYEp(17, -16, 6.5),
            smile(0, 6, 14, .45), DOT(-24, 4, 4, CHEEK), DOT(24, 4, 4, CHEEK),
        ]
    return frog("squat")


MONKEY = "#B9784A"


def monkey(pose="stand", sleep=False):
    arms = {
        "stand": [C(-20, 2, -30, 30, 9, MONKEY), E(-31, 34, 6, 6, TAN), C(20, 2, 30, 30, 9, MONKEY), E(31, 34, 6, 6, TAN)],
        "open": [C(-20, 0, -54, -12, 9, MONKEY), E(-58, -13, 6, 6, TAN), C(20, 0, 54, -12, 9, MONKEY), E(58, -13, 6, 6, TAN)],
        "wave": [C(-20, 2, -30, 30, 9, MONKEY), E(-31, 34, 6, 6, TAN), C(20, 0, 40, -24, 9, MONKEY), E(43, -28, 7, 7, TAN)],
        "cross": [C(-18, 2, 16, 20, 9, MONKEY), E(19, 22, 6, 6, TAN), C(18, 0, -10, -40, 9, MONKEY), E(-12, -44, 6, 6, TAN)],
    }[pose]
    eyes = [SHUT(-9, -35, 4.5), SHUT(9, -35, 4.5)] if sleep else [EYEp(-9, -35, 4.2), EYEp(9, -35, 4.2)]
    return [
        C(18, 34, 40, 28, 6, MONKEY), C(40, 28, 46, 8, 6, MONKEY), C(46, 8, 38, -2, 6, MONKEY),
        C(-12, 30, -14, 52, 11, MONKEY), C(12, 30, 14, 52, 11, MONKEY), E(-17, 55, 9, 5, TAN), E(17, 55, 9, 5, TAN),
        E(0, 16, 24, 26, MONKEY), E(0, 20, 15, 18, TAN),
        E(-30, -36, 10, 10, MONKEY), E(30, -36, 10, 10, MONKEY), E(-30, -36, 5, 5, TAN), E(30, -36, 5, 5, TAN),
        E(0, -34, 28, 25, MONKEY), E(-9, -36, 11, 10, TAN), E(9, -36, 11, 10, TAN), E(0, -24, 19, 12, TAN),
    ] + eyes + [DOT(-4, -27, 1.6, EYE), DOT(4, -27, 1.6, EYE), smile(0, -21, 8, .5), DOT(-17, -24, 3.5, CHEEK), DOT(17, -24, 3.5, CHEEK)] + arms


GIRAFFE = "#F3C24B"
SPOT = "#D08A3A"


def giraffe():
    return [
        C(-20, 14, -22, 52, 8, GIRAFFE), C(-6, 16, -6, 52, 8, GIRAFFE), C(16, 14, 18, 52, 8, GIRAFFE), C(28, 12, 30, 52, 8, GIRAFFE),
        E(-22, 54, 5, 3, BROWN), E(-6, 54, 5, 3, BROWN), E(18, 54, 5, 3, BROWN), E(30, 54, 5, 3, BROWN),
        C(-28, 2, -36, 18, 3, GIRAFFE),
        E(2, 6, 34, 18, GIRAFFE), C(22, -2, 30, -52, 14, GIRAFFE),
        DOT(-14, 2, 5, SPOT), DOT(2, 12, 4, SPOT), DOT(12, -2, 4.5, SPOT), DOT(-4, -4, 3.5, SPOT), DOT(26, -20, 3.5, SPOT), DOT(28, -38, 3, SPOT),
        C(28, -66, 26, -80, 3, BROWN), C(38, -66, 40, -80, 3, BROWN), E(26, -82, 3.5, 3.5, BROWN), E(40, -82, 3.5, 3.5, BROWN),
        E(22, -66, 7, 4, GIRAFFE, -30),
        E(36, -60, 16, 11, GIRAFFE, 10), E(46, -54, 9, 7, TAN, 10),
        EYEp(34, -64, 3.6), DOT(50, -56, 1.4, EYE), L([(42, -49), (47, -47), (51, -49)], 1.8), DOT(30, -54, 3, CHEEK),
    ]


def penguin(sleep=False):
    eyes = [SHUT(-6, -20, 4), SHUT(10, -20, 4)] if sleep else [EYEp(-6, -20, 4), EYEp(10, -20, 4)]
    return [
        E(-10, 50, 9, 4, ORANGE), E(12, 50, 9, 4, ORANGE),
        E(0, 8, 28, 42, NAVY), E(2, 14, 20, 34, WHITE),
        E(-26, 10, 7, 18, NAVY, 20), E(28, 10, 7, 18, NAVY, -20),
    ] + eyes + [P([(-2, -12), (10, -12), (4, -4)], ORANGE), DOT(-14, -10, 3.5, CHEEK), DOT(18, -10, 3.5, CHEEK)]


CRAB = "#EE6A4D"


def crab():
    legs = []
    for i, (a, b) in enumerate(((-30, 20), (-26, 26), (-20, 30))):
        legs += [C(a, b - 6, a - 16, b + 12, 5, darker(CRAB, .08))]
    legs += mirror(legs)
    return legs + [
        C(-30, 0, -46, -16, 8, CRAB), E(-52, -24, 12, 9, CRAB, -30), E(-58, -36, 6, 9, CRAB, -10),
        C(30, 0, 46, -16, 8, CRAB), E(52, -24, 12, 9, CRAB, 30), E(58, -36, 6, 9, CRAB, 10),
        C(-10, -6, -12, -26, 4, CRAB), C(10, -6, 12, -26, 4, CRAB),
        E(0, 10, 40, 24, CRAB),
        E(-12, -30, 7, 7, WHITE), E(12, -30, 7, 7, WHITE), EYEp(-11, -30, 3.6), EYEp(13, -30, 3.6),
        smile(0, 10, 10, .5), DOT(-20, 6, 3.5, CHEEK), DOT(20, 6, 3.5, CHEEK),
    ]


DUCK = "#FFD64A"


def duck():
    return [
        C(-6, 36, -8, 50, 4, ORANGE), C(8, 36, 8, 50, 4, ORANGE), E(-4, 52, 8, 3.5, ORANGE), E(12, 52, 8, 3.5, ORANGE),
        P([(-34, 6), (-48, -6), (-30, -2)], DUCK),
        E(0, 18, 34, 24, DUCK), E(-4, 14, 18, 11, darker(DUCK, .08), -12),
        E(22, -20, 18, 17, DUCK), E(40, -16, 12, 6, ORANGE, 5),
        EYEp(26, -24, 4), DOT(18, -12, 3.5, CHEEK),
    ]


FLAMINGO = "#F48FB1"


def flamingo():
    fl = darker(FLAMINGO, .12)
    return [
        C(0, 12, 0, 54, 4, fl), C(0, 24, -16, 32, 4, fl), C(-16, 32, 2, 38, 4, fl), E(4, 56, 8, 3, fl),
        E(4, 2, 30, 17, FLAMINGO, -8), E(-2, 0, 20, 10, darker(FLAMINGO, .08), -8),
        P([(-24, 2), (-36, -4), (-24, 8)], FLAMINGO),
        C(22, -6, 28, -28, 7, FLAMINGO), C(28, -28, 20, -46, 7, FLAMINGO),
        E(24, -54, 11, 9, FLAMINGO),
        P([(32, -58), (46, -52), (42, -44), (32, -50)], WHITE), P([(42, -52), (46, -52), (42, -44)], EYE),
        EYEp(24, -57, 3.4), DOT(20, -50, 2.8, CHEEK),
    ]


BEAR = "#3E3A3D"
MUZZLE = "#C9A27E"


def bear(pose="crawl", sleep=False):
    eyes = [SHUT(40, -6, 3.5), SHUT(52, -6, 3.5)] if sleep else [EYEp(40, -6, 3.5), EYEp(52, -6, 3.5)]
    if pose == "lie":
        return [
            E(-6, 30, 46, 18, BEAR), C(-30, 40, -50, 44, 12, BEAR), C(16, 40, 34, 46, 12, BEAR),
            E(42, 26, 20, 18, BEAR), E(28, 12, 7, 7, BEAR), E(54, 10, 7, 7, BEAR),
            E(46, 34, 9, 7, MUZZLE), DOT(47, 30, 2.5, EYE), SHUT(38, 22, 3.5), SHUT(52, 22, 3.5),
        ]
    if pose == "stand":
        return [
            C(-12, 30, -14, 52, 13, BEAR), C(12, 30, 14, 52, 13, BEAR), E(-16, 55, 10, 5, BEAR), E(16, 55, 10, 5, BEAR),
            E(0, 14, 26, 28, BEAR), P([(-14, 0), (0, 12), (14, 0), (10, -2), (0, 6), (-10, -2)], "#F2EEE3"),
            C(-22, 4, -44, -18, 11, BEAR), C(22, 4, 44, -18, 11, BEAR),
            E(-22, -38, 8, 8, BEAR), E(22, -38, 8, 8, BEAR),
            E(0, -28, 26, 22, BEAR), E(0, -20, 11, 8, MUZZLE), DOT(0, -24, 3, EYE),
            EYEp(-10, -32, 3.6), EYEp(10, -32, 3.6), DOT(-17, -22, 3.5, CHEEK), DOT(17, -22, 3.5, CHEEK),
        ]
    return [
        C(-26, 6, -32, 44, 13, BEAR), C(-12, 10, -12, 46, 13, BEAR), C(22, 10, 26, 46, 13, BEAR), C(34, 8, 38, 46, 13, BEAR),
        E(-34, 47, 9, 4, BEAR), E(-12, 48, 9, 4, BEAR), E(28, 48, 9, 4, BEAR), E(40, 48, 9, 4, BEAR),
        E(0, -4, 42, 24, BEAR, 10),
        P([(28, 10), (36, 18), (44, 12), (42, 8), (36, 12), (30, 6)], "#F2EEE3"),
        E(34, -18, 7, 7, BEAR), E(58, -16, 7, 7, BEAR),
        E(46, -2, 19, 17, BEAR), E(52, 6, 9, 7, MUZZLE), DOT(54, 2, 2.6, EYE),
    ] + eyes + [DOT(38, 6, 3, CHEEK)]


TURTLE = "#5BAE8C"
TSKIN = "#A8D58A"


def turtle(pose="stretch", sleep=False):
    head = []
    if pose == "stretch":
        head = [C(30, 10, 48, -6, 11, TSKIN), E(56, -10, 13, 11, TSKIN)]
        eyes = [SHUT(58, -12, 3.5)] if sleep else [EYEp(58, -13, 3.6)]
        head += eyes + [L([(60, -4), (65, -5)], 1.8), DOT(52, -4, 3, CHEEK)]
    elif pose == "tuck":
        head = [E(40, 14, 8, 7, TSKIN), SHUT(42, 12, 2.5)]
    return [
        E(-28, 26, 10, 7, TSKIN), E(26, 26, 10, 7, TSKIN), E(-12, 30, 9, 6, TSKIN), E(12, 30, 9, 6, TSKIN),
        P([(-40, 14), (-50, 18), (-40, 20)], TSKIN),
    ] + head + [
        E(0, 6, 42, 26, TURTLE), E(0, 4, 26, 16, lighter(TURTLE, .15)),
        P([(-8, -4), (8, -4), (12, 6), (0, 14), (-12, 6)], darker(TURTLE, .05)),
    ]


ELE = "#9AA9C2"


def elephant(stomp=True):
    fl = 18 if stomp else 0
    return [
        C(-24, 16, -26, 50, 14, ELE), C(-6, 18, -6, 50, 14, ELE), C(10, 18, 14 + fl * .4, 50 - fl, 14, ELE), C(24, 16, 26, 50, 14, ELE),
        C(-36, 6, -44, 22, 3, ELE),
        E(0, 8, 36, 26, ELE),
        E(30, -14, 22, 21, ELE),
        C(46, -4, 52, 14, 10, ELE), C(52, 14, 48, 30, 9, ELE), C(48, 30, 54, 34, 7, ELE),
        E(18, -12, 15, 19, ELE, -10), E(18, -12, 9, 13, "#F2B8C6", -10),
        EYEp(36, -18, 3.6), DOT(42, -6, 3.5, CHEEK), L([(36, 2), (42, 4)], 2),
    ]


BUNNY = "#F4EEE6"


def bunny():
    return [
        E(-10, 46, 10, 5, BUNNY), E(12, 46, 10, 5, BUNNY), E(-24, 26, 7, 7, WHITE),
        E(0, 22, 22, 24, BUNNY),
        C(-8, -26, -14, -64, 12, BUNNY), C(-8, -30, -13, -60, 5, "#F7B8C8"),
        C(8, -26, 16, -62, 12, BUNNY), C(8, -30, 15, -58, 5, "#F7B8C8"),
        E(0, -14, 21, 18, BUNNY),
        EYEp(-8, -16, 3.8), EYEp(8, -16, 3.8), DOT(0, -8, 2.6, PINK),
        L([(-4, -3), (0, -1), (4, -3)], 1.8), DOT(-14, -6, 3.5, CHEEK), DOT(14, -6, 3.5, CHEEK),
        C(-12, 10, -16, 28, 7, BUNNY), C(12, 10, 16, 28, 7, BUNNY),
    ]


SNAKE = "#F2A33A"


def snake():
    pts = [(-58, 30), (-40, 14), (-20, 30), (0, 14), (20, 30), (34, 16)]
    parts = [C(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 15, SNAKE if i % 2 else darker(SNAKE, .06)) for i in range(len(pts) - 1)]
    for (x, y) in pts[1:-1]:
        parts.append(DOT(x, y, 3, YELLOW))
    return parts + [
        E(44, 6, 16, 13, SNAKE, -10),
        EYEp(42, 0, 3.8), EYEp(52, 2, 3.4),
        L([(58, 12), (66, 14), (70, 10)], 1.8, RED), L([(66, 14), (70, 18)], 1.8, RED),
        DOT(38, 10, 3, CHEEK),
    ]


SHIRT = "#4FA3E0"
PANTS = "#F2B33D"


def kid(pose="squat"):
    head = [E(0, -40, 15, 15, SKIN), E(0, -48, 16, 10, HAIR), E(-12, -42, 5, 8, HAIR), EYEp(-5, -38, 2.4), EYEp(5, -38, 2.4),
            L([(-3, -31), (0, -29), (3, -31)], 1.5), DOT(-9, -33, 2.4, CHEEK), DOT(9, -33, 2.4, CHEEK)]
    if pose == "squat":
        return [
            C(-8, 8, -26, -2, 10, PANTS), C(-26, -2, -22, 26, 9, SKIN), E(-24, 29, 8, 4, WHITE),
            C(8, 8, 26, -2, 10, PANTS), C(26, -2, 22, 26, 9, SKIN), E(24, 29, 8, 4, WHITE),
            C(0, -20, 0, 6, 20, SHIRT),
            C(-8, -16, -6, 26, 7, SKIN), C(8, -16, 6, 26, 7, SKIN),
        ] + head
    if pose == "jump":
        return [
            C(-6, 8, -12, 30, 9, PANTS), C(-12, 30, -10, 44, 8, SKIN), E(-12, 47, 8, 4, WHITE),
            C(6, 8, 12, 30, 9, PANTS), C(12, 30, 10, 44, 8, SKIN), E(12, 47, 8, 4, WHITE),
            C(0, -20, 0, 8, 20, SHIRT),
            C(-8, -16, -24, -40, 7, SKIN), C(8, -16, 24, -40, 7, SKIN),
        ] + head
    # standing, arms open wide (spinning to check the space)
    return [
        C(-6, 8, -8, 40, 9, PANTS), C(6, 8, 8, 40, 9, PANTS), E(-9, 43, 8, 4, WHITE), E(9, 43, 8, 4, WHITE),
        C(0, -20, 0, 10, 20, SHIRT),
        C(-8, -16, -40, -18, 7, SKIN), C(8, -16, 40, -18, 7, SKIN),
    ] + head


# ---------------------------------------------------------------- scenery parts
def tree(h=1.0, col=LEAF2):
    return [C(0, 0, 0, -40 * h, 10, BROWN),
            P([(-34, -30 * h), (34, -30 * h), (0, -86 * h)], col),
            P([(-28, -60 * h), (28, -60 * h), (0, -110 * h)], lighter(col, .1))]


def leaf(x, y, ln, ang, col):
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    w = ln * .28
    pts = [(x, y), (x + ux * ln * .4 + nx * w, y + uy * ln * .4 + ny * w), (x + ux * ln, y + uy * ln),
           (x + ux * ln * .4 - nx * w, y + uy * ln * .4 - ny * w)]
    return P(pts, col)


def palm(h=1.0):
    parts = [C(0, 0, 4, -50 * h, 9, BROWN), C(4, -50 * h, 2, -96 * h, 8, darker(BROWN, .05))]
    for ang, col in ((-160, LEAF3), (-120, LEAF2), (-60, LEAF), (-20, LEAF2), (-90, LEAF), (160, LEAF3), (20, LEAF3)):
        parts.append(leaf(2, -96 * h, 60, ang, col))
    return parts


def bush(col=LEAF):
    return [E(-20, 0, 22, 18, darker(col, .05)), E(18, 2, 20, 16, darker(col, .1)), E(0, -8, 24, 20, col)]


def cloud():
    return [E(-18, 4, 18, 12, WHITE), E(16, 4, 20, 13, WHITE), E(0, -6, 22, 16, WHITE)]


def sun():
    rays = []
    for i in range(8):
        a = math.radians(i * 45 + 10)
        rays.append(P([(math.cos(a - .14) * 30, math.sin(a - .14) * 30), (math.cos(a) * 44, math.sin(a) * 44), (math.cos(a + .14) * 30, math.sin(a + .14) * 30)], ORANGE))
    return rays + [E(0, 0, 26, 26, SUN), SHUT(-8, -2, 3.5), SHUT(8, -2, 3.5), smile(0, 6, 6, .5), DOT(-14, 6, 3.5, CHEEK), DOT(14, 6, 3.5, CHEEK)]


def lily(w=1.0):
    return [E(0, 0, 46 * w, 13 * w, LEAF2), E(0, -2, 38 * w, 9 * w, LEAF), P([(0, -2), (16 * w, -14 * w), (24 * w, -8 * w)], WATER)]


def jungle_bg(sky=SKY):
    out = f'<rect width="{W}" height="{H}" fill="{sky if STYLE == "origami" else ("#EBD9BC" if STYLE == "pompom" else BOARD)}"/>'
    if STYLE == "chalk":
        out += "".join(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#FFFFFF" opacity=".035"/>' for x, y, rx, ry in ((200, 120, 180, 60), (620, 220, 220, 70), (420, 330, 260, 40)))
    out += draw(sun(), 470, 62, .78, shadow=False)
    out += draw(cloud(), 330, 70, .9, shadow=False) + draw(cloud(), 600, 50, .7, shadow=False)
    out += draw([P([(-40, 240), (120, 150), (300, 240)], lighter(LEAF, .2)), P([(180, 240), (390, 140), (600, 240)], lighter(LEAF2, .25))], 0, 0, shadow=False)
    out += draw(palm(1.15), 40, 300) + draw(palm(.9), 520, 280) + draw(bush(LEAF), 90, 290) + draw(bush(LEAF2), 470, 284)
    out += draw([P([(-10, 264), (W + 10, 252), (W + 10, H + 10), (-10, H + 10)], WATER), P([(-10, 300), (300, 290), (560, 304), (W + 10, 296), (W + 10, H + 10), (-10, H + 10)], WATER2)], 0, 0, shadow=False)
    out += draw([P([(-10, 250), (W + 10, 240), (W + 10, 262), (-10, 272)], GRASS)], 0, 0, shadow=False)
    return out


# ================================================================ SCREEN 3: follow the animal (also the style page)
def progress_path(x0, y, n, cur, label):
    out = tx(x0, y + 7, label, 17, anchor="start")
    sx = x0 + 96
    step = 30
    lc = "#F3F0E6" if STYLE == "chalk" else "#FFFFFF"
    out += f'<line x1="{sx:.1f}" y1="{y:.1f}" x2="{sx + step * (n - 1):.1f}" y2="{y:.1f}" stroke="{lc}" stroke-width="5" stroke-linecap="round" opacity=".9"/>'
    for i in range(n):
        x = sx + i * step
        if i < cur:
            out += draw([E(0, 0, 9, 9, GO)], x, y, shadow=False) + icon_svg("check", x, y, 13, "#FFFFFF" if STYLE != "chalk" else "#F3F0E6")
        elif i == cur:
            out += draw([E(0, 0, 13, 13, ORANGE)], x, y) + draw(frog("squat"), x, y + 2, .17, shadow=False)
        else:
            out += draw([E(0, 0, 8, 8, WHITE if STYLE != "chalk" else "#9FB3AA")], x, y, shadow=False)
    return out


def screen_follow():
    out = jungle_bg()
    out += draw(lily(), 120, 318) + draw(lily(.9), 420, 330) + draw(lily(.6), 270, 362, shadow=False)
    lc = "#F3F0E6" if STYLE == "chalk" else "#FFFFFF"
    out += f'<path d="M150 300 Q270 90 400 302" fill="none" stroke="{lc}" stroke-width="4" stroke-dasharray="2 12" stroke-linecap="round" opacity=".95"/>'
    out += f'<polygon points="{fmt([(392, 286), (404, 306), (410, 284)])}" fill="{lc}" opacity=".95"/>'
    for i, (x, y) in enumerate(((150, 210), (140, 230), (158, 190))):
        out += f'<line x1="{x:.1f}" y1="{y:.1f}" x2="{x - 26:.1f}" y2="{y + 14:.1f}" stroke="{lc}" stroke-width="3.5" stroke-linecap="round" opacity=".8"/>'
    out += draw(frog("jump"), 268, 186, 1.55)
    # top bar
    out += round_btn(36, 34, 21, ORANGE, "pause")
    out += progress_path(76, 34, 7, 2, "叢林探險")
    # the coach card on the right
    cx0, cy0, cw, ch = 556, 58, 270, 316
    out += card(cx0, cy0, cw, ch, PAPER if STYLE != "pompom" else "#FFF4DF")
    out += tx(cx0 + 24, cy0 + 50, "青蛙跳", 40, anchor="start", extra='font-weight="bold"' if STYLE != "chalk" else "")
    out += tx(cx0 + 24, cy0 + 80, "蹲低低，跳過荷葉！", 18, SOFT if STYLE == "origami" else None, anchor="start")
    out += round_btn(cx0 + cw - 40, cy0 + 40, 18, BLUE, "again")
    # how a child does it
    bx, by, bw, bh = cx0 + 20, cy0 + 96, cw - 40, 104
    if STYLE == "origami":
        out += f'<path d="{rr_path(bx, by, bw, bh, 12)}" fill="{lighter(SKY, .25)}"/>'
    elif STYLE == "pompom":
        out += f'<path d="{rr_path(bx, by, bw, bh, 12)}" fill="#F3E6CF" stroke="#C9AE86" stroke-width="1.5" stroke-dasharray="5 4"/>'
    else:
        out += f'<path d="{rr_path(bx, by, bw, bh, 12)}" fill="none" stroke="#F3F0E6" stroke-width="1.4" stroke-dasharray="6 5" opacity=".6"/>'
    out += tx(bx + bw / 2 + 4, by + 22, "像這樣", 15, SOFT if STYLE == "origami" else None)
    out += draw(kid("squat"), bx + 62, by + 70, .9)
    arrow = "#F3F0E6" if STYLE == "chalk" else ORANGE
    out += f'<path d="M{bx + 106} {by + 74} Q{bx + 132} {by + 34} {bx + 156} {by + 66}" fill="none" stroke="{arrow}" stroke-width="3.5" stroke-linecap="round"/>'
    out += f'<polygon points="{fmt([(bx + 150, by + 60), (bx + 160, by + 74), (bx + 164, by + 58)])}" fill="{arrow}"/>'
    out += draw(kid("jump"), bx + 196, by + 52, .82)
    # counting along (up, never down)
    out += tx(cx0 + 24, cy0 + 236, "一起數", 17, SOFT if STYLE == "origami" else None, anchor="start")
    for i in range(3):
        x = cx0 + 116 + i * 46
        lit = i < 2
        out += draw([E(0, 0, 18, 9, LEAF2 if lit else ("#D9D3C7" if STYLE != "chalk" else "#6E857B"))], x, cy0 + 232, shadow=lit)
        out += tx(x, cy0 + 238, str(i + 1), 17, "#FFFFFF" if lit and STYLE != "chalk" else None)
    out += button(cx0 + 20, cy0 + 254, cw - 40, 50, GO, "做好了！", 26)
    return out


# ================================================================ SCREEN 1: home
def adventure_card(x, y, w, h, title, sub, scene, locked=False):
    out = card(x, y, w, h, PAPER, fold=False)
    cid = "cp" + _h("adv", x, y)
    D.add(cid, f'<clipPath id="{cid}"><path d="{rr_path(x + 8, y + 8, w - 16, h - 64, 10)}"/></clipPath>')
    out += f'<g clip-path="url(#{cid})">{scene(x + 8, y + 8, w - 16, h - 64)}</g>'
    out += tx(x + w / 2, y + h - 30, title, 21)
    out += tx(x + w / 2, y + h - 10, sub, 13, SOFT)
    if locked:
        out += round_btn(x + w - 22, y + 22, 14, "#B7AFC0", "lock")
    return out


def sc_jungle(x, y, w, h):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{SKY}"/>' +
            draw([P([(x - 10, y + h), (x + 60, y + 40), (x + 140, y + h)], lighter(LEAF, .2))], shadow=False) +
            draw(palm(.75), x + 22, y + h + 4) + draw(palm(.6), x + w - 18, y + h + 6) +
            draw([P([(x, y + h - 22), (x + w, y + h - 26), (x + w, y + h), (x, y + h)], WATER)], shadow=False) +
            draw(monkey("wave"), x + w / 2 + 10, y + h - 54, .62) + draw(frog("squat"), x + 36, y + h - 18, .38))


def sc_zoo(x, y, w, h):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#FCE9C8"/>' +
            draw([P([(x, y + h - 26), (x + w, y + h - 30), (x + w, y + h), (x, y + h)], GRASS)], shadow=False) +
            draw(giraffe(), x + 54, y + h - 34, .78) + draw(penguin(), x + w - 40, y + h - 30, .62))


def sc_ocean(x, y, w, h):
    out = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{WATER}"/>'
    out += draw([P([(x, y + h - 22), (x + w, y + h - 18), (x + w, y + h), (x, y + h)], "#F4DFA8")], shadow=False)
    for i in range(3):
        out += draw([C(0, 0, 6, -40 - i * 8, 7, LEAF2), C(6, -40 - i * 8, 0, -64 - i * 10, 6, LEAF)], x + 22 + i * 12, y + h - 16, .9, shadow=False)
    out += draw(crab(), x + w / 2 + 16, y + h - 40, .78)
    for i, (bx, by, r) in enumerate(((x + w - 26, y + 26, 6), (x + w - 40, y + 44, 4), (x + w - 22, y + 60, 3))):
        out += f'<circle cx="{bx}" cy="{by}" r="{r}" fill="none" stroke="#FFFFFF" stroke-width="2" opacity=".8"/>'
    return out


def sc_rain(x, y, w, h):
    out = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#CFD9EA"/>'
    out += draw(cloud(), x + 50, y + 22, .8, shadow=False) + draw(cloud(), x + w - 40, y + 18, .65, shadow=False)
    for i in range(9):
        dx = x + 18 + (i * 37) % (w - 20)
        dy = y + 44 + (i * 23) % 40
        out += draw([P([(0, -7), (4, 2), (0, 5), (-4, 2)], BLUE)], dx, dy, shadow=False)
    out += draw([P([(x, y + h - 20), (x + w, y + h - 24), (x + w, y + h), (x, y + h)], GRASS)], shadow=False)
    out += draw([E(0, 0, 34, 7, WATER)], x + 60, y + h - 12, shadow=False)
    out += draw(duck(), x + w / 2 + 14, y + h - 40, .7)
    return out


def sc_taiwan(x, y, w, h):
    out = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#DDEFD8"/>'
    out += draw([P([(x - 10, y + h), (x + 50, y + 20), (x + 110, y + h)], LEAF3), P([(x + 60, y + h), (x + 130, y + 36), (x + 200, y + h)], LEAF2)], shadow=False)
    out += draw(bear("stand"), x + 70, y + h - 46, .62)
    return out


def screen_home():
    out = f'<rect width="{W}" height="{H}" fill="{SKY}"/>'
    out += draw(cloud(), 120, 40, .8, shadow=False) + draw(cloud(), 760, 36, .7, shadow=False)
    out += draw([P([(-20, 300), (140, 230), (330, 300)], lighter(LEAF, .25)), P([(260, 300), (520, 220), (760, 300)], lighter(LEAF2, .3)),
                 P([(600, 300), (760, 240), (900, 300)], lighter(LEAF, .2)), P([(-10, 290), (W + 10, 284), (W + 10, H + 10), (-10, H + 10)], GRASS)], shadow=False)
    # title ribbon
    rb = [(260, 14), (584, 14), (600, 34), (584, 54), (260, 54), (244, 34)]
    out += draw([P([(232, 22), (262, 22), (262, 56), (232, 56), (244, 39)], darker(ORANGE, .1)), P([(612, 22), (582, 22), (582, 56), (612, 56), (600, 39)], darker(ORANGE, .1))], shadow=False)
    out += f'<polygon points="{fmt([(r[0] + 3, r[1] + 4) for r in rb])}" fill="#1E1428" opacity=".1"/><polygon points="{fmt(rb)}" fill="{ORANGE}"/>'
    out += f'<polygon points="{fmt([(260, 14), (584, 14), (590, 24), (254, 24)])}" fill="{lighter(ORANGE, .2)}"/>'
    out += tx(422, 45, "動物動一動", 30, "#FFFFFF", extra='font-weight="bold"')
    out += round_btn(34, 34, 19, "#B7AFC0", "lock")
    cw, chh, gap = 172, 196, 14
    x0, y0 = 26, 74
    data = [("叢林探險", "7 個動作 · 5 分鐘", sc_jungle, False), ("去動物園", "8 個動作 · 6 分鐘", sc_zoo, False),
            ("海底世界", "7 個動作 · 5 分鐘", sc_ocean, False), ("下雨天", "6 個動作 · 5 分鐘", sc_rain, False),
            ("台灣山林", "7 個動作", sc_taiwan, False)]
    for i, (t, s_, sc, lk) in enumerate(data):
        out += adventure_card(x0 + i * (cw + gap), y0, cw, chh, t, s_, sc, lk)
    # small stamp on the first card: done today
    out += draw([E(0, 0, 18, 18, RED)], x0 + 26, y0 + 22, shadow=True) + icon_svg("check", x0 + 26, y0 + 22, 18, "#FFFFFF")
    # bottom buttons
    by = 292
    out += button(26, by, 186, 70, PURPLE, "動物舞會", 23, icon="note", r=20)
    out += button(226, by, 186, 70, BLUE, "自己排", 23, icon="dice", r=20)
    out += button(426, by, 186, 70, TURTLE, r=20)
    out += draw(turtle("tuck"), 460, by + 36, .42, shadow=False) + tx(536, by + 43, "慢慢伸展", 23, "#FFFFFF")
    # the guide
    out += draw(monkey("wave"), 760, 316, .95)
    out += speech(626, 300, 112, 42, "去哪裡動？", 18, tail=[(730, 310), (750, 300), (730, 330)])
    return out


def speech(x, y, w, h, text, size=18, tail=None, fill=WHITE):
    out = ""
    if tail:
        out += f'<polygon points="{fmt(tail)}" fill="{fill}"/>'
    out = f'<path d="{rr_path(x + 2, y + 4, w, h, h / 2)}" fill="#1E1428" opacity=".08"/>' + out
    out += f'<path d="{rr_path(x, y, w, h, h / 2)}" fill="{fill}"/>'
    out += tx(x + w / 2, y + h / 2 + size * .36, text, size)
    return out


# ================================================================ SCREEN 2: look around first
def tile(x, y, w, h, icon_parts, l1, l2, done):
    out = card(x, y, w, h, PAPER, fold=False)
    out += f'<path d="{rr_path(x + 10, y + 10, 92, h - 20, 12)}" fill="{lighter(SKY, .2)}"/>'
    out += icon_parts
    out += tx(x + 116, y + 46, l1, 21, anchor="start")
    out += tx(x + 116, y + 74, l2, 16, SOFT, anchor="start")
    if done:
        out += draw([E(0, 0, 15, 15, GO)], x + w - 22, y + 22) + icon_svg("check", x + w - 22, y + 22, 18, "#FFFFFF")
    else:
        out += f'<circle cx="{x + w - 22}" cy="{y + 22}" r="13" fill="none" stroke="#D9D3C7" stroke-width="3"/>'
    return out


def icon_table(x, y):
    t = [P([(-34, -8), (30, -8), (36, -2), (-28, -2)], BROWN), C(-26, -2, -26, 26, 6, darker(BROWN, .1)), C(28, -2, 28, 26, 6, darker(BROWN, .1))]
    out = draw(t, x - 8, y + 4, .9)
    out += f'<polyline points="{fmt([(x + 18, y - 30), (x + 38, y - 30)])}" stroke="{RED}" stroke-width="4" stroke-linecap="round"/>'
    out += f'<polygon points="{fmt([(x + 36, y - 38), (x + 46, y - 30), (x + 36, y - 22)])}" fill="{RED}"/>'
    return out


def icon_bed(x, y):
    b = [P([(-38, 0), (36, 0), (36, 14), (-38, 14)], "#9FC6EA"), P([(-38, -18), (-30, -18), (-30, 24), (-38, 24)], BROWN), E(-18, -4, 12, 6, WHITE),
         P([(-24, 0), (36, -2), (36, 6), (-24, 6)], PINK)]
    out = draw(b, x, y + 6, .85)
    out += f'<g stroke="{RED}" stroke-width="6" stroke-linecap="round"><line x1="{x - 24}" y1="{y - 26}" x2="{x + 24}" y2="{y + 22}"/><line x1="{x + 24}" y1="{y - 26}" x2="{x - 24}" y2="{y + 22}"/></g>'
    return out


def icon_feet(x, y):
    f = [E(-14, 6, 11, 20, SKIN), E(-20, -16, 3, 3, SKIN), E(-14, -18, 3, 3, SKIN), E(-8, -17, 3, 3, SKIN),
         E(16, 6, 12, 21, "#F7C1CF"), DOT(12, 2, 2, WHITE), DOT(20, 8, 2, WHITE), DOT(14, 14, 2, WHITE), DOT(18, -6, 2, WHITE)]
    return draw(f, x, y + 4, 1.0)


def icon_phone(x, y):
    p = [P([(-36, 26), (36, 26), (36, 32), (-36, 32)], BROWN), P([(4, -2), (26, -2), (26, 26), (4, 26)], RED),
         P([(-26, -20), (2, -24), (6, 26), (-22, 26)], NAVY), P([(-22, -15), (-2, -18), (1, 20), (-19, 20)], "#BFE3F2")]
    out = draw(p, x, y, .95)
    out += draw(frog("squat"), x - 9, y + 4, .18, shadow=False)
    return out


def screen_space():
    out = f'<rect width="{W}" height="{H}" fill="#FCEFD9"/>'
    out += f'<ellipse cx="128" cy="320" rx="116" ry="30" fill="#F1D7AE"/>'
    out += round_btn(34, 32, 19, ORANGE, "home")
    out += tx(70, 42, "動之前，先看看四周", 26, anchor="start", extra='font-weight="bold"')
    # the guide spinning with arms out, the dashed circle on the floor
    out += f'<ellipse cx="128" cy="318" rx="104" ry="22" fill="none" stroke="{ORANGE}" stroke-width="4" stroke-dasharray="3 10" stroke-linecap="round"/>'
    out += draw(kid("open"), 128, 270, 1.45)
    for a in (0, 180):
        p = arc_pts(128, 250, 84, a - 22, a + 22, 6)
        out += f'<polyline points="{fmt(p)}" fill="none" stroke="{ORANGE}" stroke-width="3.5" stroke-linecap="round"/>'
        t = p[-1]
        d = 1 if a == 0 else -1
        out += f'<polygon points="{fmt([(t[0] - 7 * d, t[1] - 2), (t[0] + 5 * d, t[1] - 4 * d), (t[0] + 1 * d, t[1] + 9 * d)])}" fill="{ORANGE}"/>'
    out += speech(18, 70, 222, 70, "", 18)
    out += tx(129, 100, "手張開，轉一圈，", 18) + tx(129, 126, "碰不到東西就可以！", 18)
    # four checks
    xs, ys, tw, th = (258, 552), (66, 180), 278, 100
    tiles = [(icon_table(xs[0] + 56, ys[0] + 52), "推開桌椅", "找一塊空地", True),
             (icon_bed(xs[1] + 56, ys[0] + 50), "不在床上跳", "沙發、樓梯旁也不要", True),
             (icon_feet(xs[0] + 56, ys[1] + 50), "光腳丫", "或穿止滑襪", False),
             (icon_phone(xs[1] + 56, ys[1] + 48), "手機立在桌上", "不要放地上", False)]
    for i, (ic, a, b, d) in enumerate(tiles):
        out += tile(xs[i % 2], ys[i // 2], tw, th, ic, a, b, d)
    out += button(470, 304, 236, 60, GO, "準備好了！", 26)
    return out


# ================================================================ SCREEN 4: dance and freeze
def bunting(y=0):
    out = f'<path d="M-10 {y + 12} Q{W / 2} {y + 46} {W + 10} {y + 12}" fill="none" stroke="{INK}" stroke-width="1.5" opacity=".5"/>'
    cols = [RED, YELLOW, BLUE, GO, PINK, ORANGE, PURPLE]
    for i in range(16):
        t = i / 15
        x = -10 + (W + 20) * t
        yy = y + 12 + 34 * 4 * t * (1 - t) * .98
        out += draw([P([(-14, 0), (14, 0), (0, 26)], cols[i % len(cols)])], x, yy, shadow=False)
    return out


def screen_freeze():
    out = f'<rect width="{W}" height="{H}" fill="#EFE3F7"/>'
    for i in range(14):
        x, y = 40 + (i * 131) % 780, 70 + (i * 71) % 200
        out += draw([P([(-5, -3), (5, -5), (4, 4), (-4, 5)], [YELLOW, PINK, BLUE, GO][i % 4])], x, y, rot=i * 30, shadow=False)
    out += bunting(0)
    out += draw([P([(-10, 300), (W + 10, 296), (W + 10, H + 10), (-10, H + 10)], "#D7C2EC"), P([(-10, 300), (W + 10, 296), (W + 10, 306), (-10, 310)], "#C3A8E2")], shadow=False)
    # spot light circles on the floor
    out += f'<ellipse cx="250" cy="330" rx="120" ry="20" fill="#FFFFFF" opacity=".45"/>'
    out += draw(flamingo(), 260, 220, 2.25)
    out += draw(bunny(), 470, 286, .8, rot=-4) + draw(bear("stand"), 84, 266, .9)
    # frozen notes, grey
    for x, y in ((390, 120), (430, 90), (120, 120)):
        out += icon_svg("note", x, y, 26, "#B4A9C2")
    out += round_btn(36, 92, 21, ORANGE, "pause")
    # the freeze call
    bx, by = 528, 70
    burst = []
    for i in range(18):
        a = math.radians(i * 20)
        r = 106 if i % 2 == 0 else 88
        burst.append((bx + 140 + r * math.cos(a) * 1.25, by + 104 + r * math.sin(a) * .95))
    out += f'<polygon points="{fmt([(x + 3, y + 5) for x, y in burst])}" fill="#1E1428" opacity=".1"/>'
    out += draw([P(burst, YELLOW)], shadow=False)
    out += txo(bx + 140, by + 100, "停！", 64, RED, "#FFFFFF", 8)
    out += tx(bx + 140, by + 140, "變成紅鶴", 26)
    out += tx(bx + 140, by + 168, "單腳站好", 20, SOFT)
    out += card(560, 288, 248, 78, PAPER, fold=False)
    out += tx(582, 322, "一起數到 5", 17, SOFT, anchor="start")
    for i in range(5):
        x = 590 + i * 46
        lit = i < 3
        out += draw([E(0, 0, 15, 15, PINK if lit else "#E3DCE9")], x + 10, 344, shadow=lit)
        out += tx(x + 10, 350, str(i + 1), 16, "#FFFFFF" if lit else SOFT)
    return out


# ================================================================ SCREEN 5: make your own
def screen_build():
    out = f'<rect width="{W}" height="{H}" fill="#E6F1F8"/>'
    out += round_btn(34, 32, 19, ORANGE, "home")
    out += tx(68, 42, "自己排體操", 24, anchor="start", extra='font-weight="bold"')
    out += tx(214, 42, "點下面的動物卡，排進上面這一排", 15, SOFT, anchor="start")
    # the row of chosen cards
    out += card(18, 60, 640, 116, PAPER, fold=False)
    slots = [("青蛙跳", frog("squat"), .5), ("黑熊爬", bear("crawl"), .48), ("紅鶴站", flamingo(), .5), None, None]
    for i, s in enumerate(slots):
        x = 34 + i * 106
        if s:
            out += f'<path d="{rr_path(x, 72, 92, 92, 12)}" fill="{lighter(SKY, .1)}"/>'
            out += draw(s[1], x + 46 + (-8 if s[0] == "黑熊爬" else 0), 108 + (6 if s[0] == "紅鶴站" else 0), s[2] * (.85 if s[0] == "紅鶴站" else 1))
            out += tx(x + 46, 158, s[0], 14)
            out += draw([E(0, 0, 11, 11, ORANGE)], x + 10, 76, shadow=False) + tx(x + 10, 81, str(i + 1), 13, "#FFFFFF")
        else:
            out += f'<path d="{rr_path(x, 72, 92, 92, 12)}" fill="none" stroke="#C9C2CF" stroke-width="3" stroke-dasharray="6 6"/>'
            out += tx(x + 46, 124, "＋", 28, "#C9C2CF")
        if i < 4:
            out += f'<polygon points="{fmt([(x + 96, 112), (x + 104, 118), (x + 96, 124)])}" fill="#C9C2CF"/>'
    x = 34 + 5 * 106 + 2
    out += f'<path d="{rr_path(x, 72, 92, 92, 12)}" fill="#E4F2EA"/>'
    out += draw(turtle("tuck"), x + 44, 112, .7)
    out += tx(x + 46, 150, "最後", 13, SOFT) + tx(x + 46, 166, "慢慢伸展", 13, SOFT)
    out += button(672, 66, 152, 104, GO, "開始！", 28, r=24)
    # the card deck
    deck = [("青蛙跳", frog("squat"), .42, 0), ("黑熊爬", bear("crawl"), .4, -6), ("紅鶴站", flamingo(), .38, 8),
            ("螃蟹走", crab(), .42, 6), ("小蛇扭扭", snake(), .4, -4), ("大象踩踩", elephant(), .4, 0),
            ("兔子跳", bunny(), .34, 8), ("企鵝走", penguin(), .34, 0), ("猴子摸摸", monkey("cross"), .3, 0),
            ("長頸鹿", giraffe(), .28, 10), ("鴨子走", duck(), .38, -2), None]
    cw_, chh, gx, gy = 124, 88, 10, 8
    for i, d in enumerate(deck):
        r_, c_ = divmod(i, 6)
        x, y = 22 + c_ * (cw_ + gx), 188 + r_ * (chh + gy)
        if d is None:
            out += button(x, y, cw_, chh, PURPLE, r=16)
            out += icon_svg("dice", x + cw_ / 2, y + 36, 40, "#FFFFFF") + tx(x + cw_ / 2, y + 78, "隨便來一個", 15, "#FFFFFF")
            continue
        t, parts, s, dy = d
        out += card(x, y, cw_, chh, WHITE, r=14, fold=False)
        out += draw(parts, x + cw_ / 2 + (-8 if t == "黑熊爬" else 0), y + 42 + dy, s)
        out += tx(x + cw_ / 2, y + chh - 10, t, 16)
        if i < 3:
            out += draw([E(0, 0, 11, 11, ORANGE)], x + 14, y + 14, shadow=False) + tx(x + 14, y + 19, str(i + 1), 13, "#FFFFFF")
    return out


# ================================================================ SCREEN 6: slow stretch
def screen_calm():
    out = f'<rect width="{W}" height="{H}" fill="#E7E3F3"/>'
    out += draw([P([(-20, 300), (200, 236), (430, 300)], "#CFE5C8"), P([(300, 300), (560, 240), (860, 300)], "#D9EBD2"),
                 P([(-10, 292), (W + 10, 288), (W + 10, H + 10), (-10, H + 10)], "#BFDDB0")], shadow=False)
    out += round_btn(36, 34, 21, "#B7AFC0", "pause")
    out += tx(72, 44, "最後：慢慢伸展", 20, SOFT, anchor="start")
    out += draw([E(0, 0, 150, 16, "#9DC9A6")], 250, 316, shadow=False)
    out += draw(turtle("stretch"), 236, 262, 2.25)
    out += tx(250, 92, "烏龜慢慢把頭伸出來", 26)
    out += tx(250, 124, "手和腳也慢慢伸長……", 18, SOFT)
    # breathing: a paper flower that opens on the in-breath
    cx, cy = 640, 178
    petals = []
    for i in range(8):
        a = i * 45
        petals += [E(0, -58, 26, 46, lighter(PURPLE, .35) if i % 2 else lighter(PINK, .25), 0)]
        petals[-1] = ("ell",) + tuple(xform([petals[-1]], 0, 0, 1, a)[0][1:])
    out += draw(petals, cx, cy, 1.0)
    out += draw([E(0, 0, 44, 44, YELLOW)], cx, cy)
    out += tx(cx, cy + 11, "吸氣", 30, INK)
    out += f'<path d="{rr_path(cx - 118, 312, 236, 50, 25)}" fill="#FFFFFF" opacity=".75"/>'
    out += tx(cx, 345, "花開了，慢慢吸氣", 19, SOFT)
    return out


# ================================================================ SCREEN 7: rest
def screen_rest():
    out = f'<rect width="{W}" height="{H}" fill="#FDE7C9"/>'
    out += draw(sun(), 92, 70, .9, shadow=False)
    out += draw([P([(-20, 310), (210, 230), (460, 310)], "#C7E3A4"), P([(380, 310), (640, 220), (880, 310)], "#B5DA8F"),
                 P([(-10, 300), (W + 10, 296), (W + 10, H + 10), (-10, H + 10)], GRASS)], shadow=False)
    out += draw(tree(1.0), 760, 300) + draw(monkey("stand", sleep=True), 712, 300, .8)
    out += draw(bear("lie"), 120, 300, 1.1) + draw(turtle("tuck"), 300, 334, .8) + draw(penguin(sleep=True), 600, 302, .72)
    for x, y, s in ((170, 230, 18), (190, 206, 22), (744, 196, 16)):
        out += tx(x, y, "Z", s, SOFT)
    out += card(222, 60, 400, 214, PAPER)
    out += tx(422, 112, "今天動得好開心！", 24, SOFT)
    out += tx(422, 168, "換你去做了！", 44, INK, extra='font-weight="bold"')
    out += tx(422, 210, "關掉螢幕，去外面跑一跑、跳一跳", 18, SOFT)
    out += tx(422, 248, "動物們要睡午覺囉", 16, SOFT)
    out += button(704, 340, 120, 36, "#B7AFC0", "家長", 16, r=18)
    out += icon_svg("lock", 724, 357, 16, "#FFFFFF")
    return out


# ================================================================ SCREEN 8: parent mode
def seg(x, y, opts, sel, w=62, h=32):
    out = ""
    for i, o in enumerate(opts):
        xx = x + i * (w + 6)
        on = i == sel
        out += f'<path d="{rr_path(xx, y, w, h, 10)}" fill="{ORANGE if on else "#F1ECE4"}"/>'
        out += tx(xx + w / 2, y + h / 2 + 5.5, o, 15, "#FFFFFF" if on else INK)
    return out


def toggle(x, y, on=True):
    return (f'<path d="{rr_path(x, y, 52, 30, 15)}" fill="{GO if on else "#D9D3C7"}"/>'
            f'<circle cx="{x + (37 if on else 15)}" cy="{y + 15}" r="11" fill="#FFFFFF"/>')


def tag(x, y, t, col):
    w = 16 * len(t) + 16
    return f'<path d="{rr_path(x, y, w, 24, 12)}" fill="{lighter(col, .7)}"/>' + tx(x + w / 2, y + 17, t, 14, darker(col, .3)), w


def screen_parent():
    out = f'<rect width="{W}" height="{H}" fill="#F4F0EA"/>'
    out += round_btn(30, 28, 17, "#B7AFC0", "back")
    out += tx(58, 37, "家長模式", 22, anchor="start", extra='font-weight="bold"')
    out += tx(160, 37, "小朋友看不到這一頁", 14, SOFT, anchor="start")
    out += button(690, 12, 136, 34, ORANGE, "買完整版", 16, r=17)
    # settings
    out += card(14, 56, 404, 324, WHITE, fold=False)
    rows = [("年齡", lambda y: seg(170, y, ["2～3", "3～4", "4～5"], 1)),
            ("每次玩幾分鐘", lambda y: seg(170, y, ["10", "15", "20", "30"], 1, 50)),
            ("安靜模式", lambda y: toggle(346, y) + tx(170, y + 21, "不跳，樓下不會咚咚響", 13, SOFT, anchor="start")),
            ("動之前看四周", lambda y: seg(170, y, ["每次", "每天第一次"], 0, 92)),
            ("做好了才往下", lambda y: toggle(346, y, False) + tx(170, y + 21, "關：音樂完自己往下", 13, SOFT, anchor="start")),
            ("大人一起做", lambda y: toggle(346, y) + tx(170, y + 21, "語音說「和爸媽一起」", 13, SOFT, anchor="start")),
            ("要哪些動作", lambda y: tx(400, y + 21, "22 個開著 ›", 15, BLUE, anchor="end"))]
    for i, (lab, fn) in enumerate(rows):
        y = 70 + i * 44
        out += tx(32, y + 21, lab, 16, anchor="start") + fn(y)
        if i < len(rows) - 1:
            out += f'<line x1="30" y1="{y + 39}" x2="402" y2="{y + 39}" stroke="#EEE8DF" stroke-width="1.5"/>'
    # this week
    out += card(430, 56, 400, 150, WHITE, fold=False)
    out += tx(446, 82, "這一週跟著動了幾分鐘", 16, anchor="start")
    mins = [12, 8, 15, 0, 14, 20, 9]
    days = ["一", "二", "三", "四", "五", "六", "日"]
    for i, m in enumerate(mins):
        x = 470 + i * 50
        h = m * 3.4
        if m:
            out += draw([P([(-12, -h), (12, -h), (12, 0), (-12, 0)], GO if i < 6 else ORANGE)], x, 176, shadow=False)
        out += tx(x, 170 - h - 4, str(m), 12, SOFT)
        out += tx(x, 196, days[i], 13, SOFT)
    out += tx(822, 82, "今天 9 分", 14, ORANGE, anchor="end")
    # moves and skills
    out += card(430, 214, 400, 166, WHITE, fold=False)
    out += tx(446, 238, "動作練到什麼", 16, anchor="start") + tx(822, 238, "全部 ›", 14, BLUE, anchor="end")
    items = [(frog("squat"), .26, "青蛙跳", [("雙腳跳", GO), ("腿力", ORANGE)]),
             (flamingo(), .22, "紅鶴站", [("平衡", PURPLE)]),
             (monkey("cross"), .22, "猴子摸摸", [("跨中線", BLUE)]),
             (bear("crawl"), .24, "黑熊爬", [("核心", RED), ("手臂", ORANGE)])]
    for i, (parts, s, name, tags) in enumerate(items):
        y = 256 + i * 31
        out += draw(parts, 462 - (6 if name == "黑熊爬" else 0), y + 14, s, shadow=False)
        out += tx(490, y + 20, name, 15, anchor="start")
        tx0 = 580
        for t, col in tags:
            s_, w = tag(tx0, y + 3, t, col)
            out += s_
            tx0 += w + 6
    return out


# ================================================================ STYLE PAGE
def style_page():
    global STYLE
    pw, ph = 800, 370
    blocks = []
    info = [("origami", "A 摺紙風", "像一張色紙摺出來的動物：一面亮一面暗，有摺痕。", True),
            ("pompom", "B 毛球毛根風", "毛球當身體、毛根當手腳，加上會轉的大眼睛。", False),
            ("chalk", "C 黑板粉筆風", "畫在綠色黑板上的粉筆畫：斜斜的粉筆線、歪歪的框。", False)]
    for key, title, desc, rec in info:
        STYLE = key
        D.d = {}
        body = screen_follow()
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{pw}" height="{ph}" viewBox="0 0 {W} {H}" style="border-radius:16px;display:block">{D.svg()}{body}</svg>'
        badge = ('<span style="float:right;background:#5DBB63;color:#fff;border-radius:16px;padding:4px 16px;font-size:20px">建議</span>' if rec else "")
        blocks.append(f'<div style="background:#fff;border-radius:22px;padding:18px 20px 20px;margin:0 0 22px;'
                      f'box-shadow:0 6px 16px rgba(60,40,70,.12);{"outline:5px solid #5DBB63;" if rec else ""}">'
                      f'<div style="font-size:30px;color:{INK};margin-bottom:4px">{title}{badge}</div>'
                      f'<div style="font-size:19px;color:{SOFT};margin-bottom:14px">{desc}</div>{svg}</div>')
    STYLE = "origami"
    D.d = {}
    w = 880
    head = (f'<div style="text-align:center;font-size:40px;color:{INK};margin:26px 0 6px">畫風：三選一</div>'
            f'<div style="text-align:center;font-size:20px;color:{SOFT};margin-bottom:22px">同一個畫面「青蛙跳」，三種畫法（手機橫放）</div>')
    css = (f"@font-face {{ font-family: Huninn; src: url('file://{FONT}'); }} * {{ margin:0; padding:0 }} "
           f"body {{ width:{w}px; background:#F4F0EA; font-family:Huninn, sans-serif; padding:0 20px 4px; box-sizing:border-box }}")
    html = f'<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>{head}{"".join(blocks)}</body></html>'
    return html, w, 106 + 3 * (ph + 22 + 102)


# ================================================================ pages
def page(body, w=W, h=H):
    css = (f"@font-face {{ font-family: Huninn; src: url('file://{FONT}'); }}"
           f"* {{ margin: 0; padding: 0; }} body {{ width: {w}px; height: {h}px; overflow: hidden; background: #F4F0EA; }}")
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{D.svg()}{body}</svg>'
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>{svg}</body></html>'


def render(html, out, w, h, scale):
    with tempfile.TemporaryDirectory(dir=SCRATCH) as tmp:
        p = pathlib.Path(tmp) / "page.html"
        p.write_text(html)
        subprocess.run(["node", str(HERE / "render.js"), str(p), str(out), str(w), str(h), str(scale)], check=True)
    if pathlib.Path(out).stat().st_size > 400_000:
        from PIL import Image
        im = Image.open(out).convert("RGB")
        im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, kmeans=2, dither=Image.Dither.FLOYDSTEINBERG).save(out, optimize=True)


def contact_sheet(names):
    cw_, ch_, gap, m = 400, 185, 26, 28
    per = 2
    rows = (len(names) + per - 1) // per
    w = per * cw_ + (per - 1) * gap + 2 * m
    rowh = ch_ + 56
    h = rows * rowh + 30
    items = []
    for i, n in enumerate(names):
        r, c = divmod(i, per)
        x = m + c * (cw_ + gap)
        y = 24 + r * rowh
        items.append(f'<div style="position:absolute;left:{x}px;top:{y}px;width:{cw_}px;text-align:center">'
                     f'<img src="file://{HERE / (n + ".png")}" style="width:{cw_}px;height:{ch_}px;border-radius:14px;box-shadow:0 5px 14px rgba(60,40,70,.18)">'
                     f'<div style="font:19px Huninn, sans-serif;color:{INK};margin-top:8px">{n.replace("_", " ")}</div></div>')
    css = f"@font-face {{ font-family: Huninn; src: url('file://{FONT}'); }} * {{ margin:0; padding:0 }} body {{ width:{w}px; height:{h}px; background:#F4F0EA; position:relative }}"
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>{"".join(items)}</body></html>', w, h


SCREENS = {"1_首頁": screen_home, "2_先看看四周": screen_space, "3_跟著做": screen_follow, "4_動物舞會": screen_freeze,
           "5_自己排": screen_build, "6_慢慢伸展": screen_calm, "7_休息": screen_rest, "8_家長模式": screen_parent}


def main(only=None):
    names = list(SCREENS)
    if only in (None, "0"):
        html, w, h = style_page()
        render(html, HERE / "0_畫風選擇.png", w, h, 1.5)
    for i, n in enumerate(names, 1):
        if only not in (None, str(i)):
            continue
        D.d = {}
        render(page(SCREENS[n]()), HERE / f"{n}.png", W, H, 2)
    if only in (None, "c"):
        html, w, h = contact_sheet(names)
        render(html, HERE / "contact_sheet.png", w, h, 2)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
