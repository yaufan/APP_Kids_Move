"""The six guides the child picks from (docs/design.md 「已經決定的事」 9): 台灣獼猴, 石虎, 台灣黑熊,
台灣藍鵲, 梅花鹿 and 穿山甲, front on, in three poses: idle, wave (announcing a move) and sleep (the
rest screen). The same pom-pom puppets as the moves (animals.py), on a square 240 x 240 canvas.

    python3 build.py guides       # writes app/assets/art/guides/<guide>_<idle|wave|sleep>.svg
"""
import animals
import kit

LOOKS = {
    "macaque": animals.monkey_look,
    "leopardcat": animals.leopardcat_front_look,
    "bear": animals.bear_front_look,
    "magpie": lambda: animals.bird_look(True),
    "deer": animals.deer_front_look,
    "pangolin": animals.pangolin_front_look,
}

POSES = {
    "idle": dict(la=(-25, -12), ra=(25, 12), look=(0, .25)),
    "wave": dict(la=(-25, -12), ra=(140, 175), mouth=.5, look=(-.2, .1), htilt=-6),
    "sleep": dict(dy=22, ll=(-62, -5), rl=(62, 5), la=(25, 70), ra=(-25, -70), eyes="closed", htilt=14),
}


def draw(guide, pose):
    c = kit.Ctx(240, 240)
    s = 1.12
    c.begin(f"translate(120 {animals.G}) scale({s}) translate(-150 -{animals.G})")
    P = dict(POSES[pose])
    if guide == "magpie" and pose == "wave":
        P["ra"] = (120, 140)
    animals.biped(c, P, LOOKS[guide](), f"guide{guide}{pose}")
    c.end()
    return c


def build():
    out = kit.ART / "guides"
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.svg"):
        old.unlink()
    total = 0
    for g in LOOKS:
        for pose in POSES:
            total += kit.write_svg(out / f"{g}_{pose}.svg", draw(g, pose).svg(), (240, 240))
    print(f"guides: {len(LOOKS) * len(POSES)} pictures, {total:.0f} KB")


if __name__ == "__main__":
    build()
