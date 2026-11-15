"""動物動一動: every sound in the app, made here from sine waves and noise: nothing recorded, nothing
downloaded, every tune written for this app (design/sounds/README.md lists every file).

- Music (WAV, 16,000 Hz, seamless loops of 18 to 22 s), each with a clear beat so children can move
  to it, at the tempo lib/core/sounds.dart gives it: home (a ukulele), the five adventures (jungle:
  xylophone and drums; zoo: a little trumpet and an accordion; sea: ukulele and bubbles; rain: piano
  and soft rain; mountain: a flute and birds), the party (a dance beat; it really stops at 「停！」),
  calm (a slow music box) and rest (a lullaby).
- Short sounds (WAV, 22,050 Hz): each animal's call as its move starts, each move's own sound on the
  beat, and the app's sounds (counting, ticks, breathing, the stop, done...).
- Quiet mode (an apartment, the evening) swaps the thumping ones for soft versions: boing, hop,
  stomp, leap, freeze and the elephant's and kangaroo's calls each have a *_soft twin, with no low
  thud (lib/core/moves.dart softSounds).
- Every random choice uses a fixed seed (from the sound's name), so each run writes the same files.
- Soft for 2 to 5 year olds: playful sounds, nothing harsh, no roar, no thunder.

    python3 design/sounds/make_sounds.py              # writes app/assets/sounds/*.wav
    python3 design/sounds/make_sounds.py frog boing   # only these
    python3 design/sounds/make_sounds.py preview OUT.m4a   # all of them in a row (needs ffmpeg)
"""
import pathlib
import subprocess
import sys
import tempfile
import wave
import zlib

import numpy as np
from scipy.signal import lfilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "app" / "assets" / "sounds"
SR = 22050
LOOP_SR = 16000
LIMIT = 8_000_000       # bytes, the whole folder

NOTE = {f"{n}{o}": 440 * 2 ** ((k - 9) / 12 + o - 4) for o in range(1, 9) for k, n in enumerate("C C# D D# E F F# G G# A A# B".split())}
for _o in range(1, 9):
    for _f, _s in (("Db", "C#"), ("Eb", "D#"), ("Gb", "F#"), ("Ab", "G#"), ("Bb", "A#")):
        NOTE[f"{_f}{_o}"] = NOTE[f"{_s}{_o}"]


# ---------------------------------------------------------------- helpers
def rng(name):
    return np.random.default_rng(zlib.crc32(name.encode()))


def t_of(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env(n, attack=.005, release=.05, sr=SR):
    e = np.ones(n)
    a, r = max(1, min(n, int(attack * sr))), max(1, min(n, int(release * sr)))
    e[:a] = np.linspace(0, 1, a) ** 2
    e[-r:] *= np.linspace(1, 0, r) ** 2
    return e


def adsr(n, a, d, s, r, sr=SR):
    """Attack, decay to sustain level s, release (seconds)."""
    e = np.full(n, s, float)
    ia, idd, ir = int(a * sr), int(d * sr), int(r * sr)
    ia = max(1, min(ia, n))
    e[:ia] = np.linspace(0, 1, ia)
    j = min(n, ia + idd)
    if j > ia:
        e[ia:j] = np.linspace(1, s, j - ia)
    ir = max(1, min(ir, n))
    e[-ir:] *= np.linspace(1, 0, ir) ** 1.5
    return e


def lowpass(x, cutoff, sr=SR):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    spec *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(spec, len(x))


def bandpass(x, lo, hi, sr=SR):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    spec *= 1 / (1 + (lo / np.maximum(f, 1)) ** 4) / (1 + (f / hi) ** 4)
    return np.fft.irfft(spec, len(x))


def partial(freq, t, sr):
    return np.sin(2 * np.pi * freq * t) if freq < .45 * sr else np.zeros_like(t)


def bell(freq, dur=.8, sr=SR, bright=.6):
    """A soft glockenspiel / music-box note."""
    t = t_of(dur, sr)
    x = (partial(freq, t, sr) * np.exp(-t / (dur * .35))
         + .3 * bright * partial(freq * 2.76, t, sr) * np.exp(-t / (dur * .12))
         + .12 * bright * partial(freq * 5.4, t, sr) * np.exp(-t / (dur * .06)))
    return x * env(len(t), .002, .04, sr)


def kalimba(freq, dur=.9, sr=SR):
    t = t_of(dur, sr)
    x = partial(freq, t, sr) * np.exp(-t / (dur * .3)) + .25 * partial(freq * 3.0, t, sr) * np.exp(-t / .04) + .1 * partial(freq * 5.2, t, sr) * np.exp(-t / .02)
    return x * env(len(t), .003, .05, sr)


def pad(freqs, dur, sr=SR, swell=.6):
    """A soft, slowly swelling chord (a few detuned sines)."""
    t = t_of(dur, sr)
    x = np.zeros_like(t)
    for f in freqs:
        for det in (-.15, .15):
            x += np.sin(2 * np.pi * (f + det) * t) + .25 * partial(2 * f + det, t, sr)
    return x / len(freqs) * adsr(len(t), dur * swell * .5, .1, .9, dur * .45, sr)


def place(total, parts, sr=SR):
    out = np.zeros(int(total * sr))
    for start, sig in parts:
        i = int(start * sr)
        j = min(len(out), i + len(sig))
        if j > i:
            out[i:j] += sig[: j - i]
    return out


def place_loop(total, parts, sr):
    """Like place, but what runs past the end comes back in at the start (a seamless loop)."""
    n = int(total * sr)
    out = np.zeros(n)
    for start, sig in parts:
        i = int(start * sr) % n
        k = 0
        while k < len(sig):
            j = min(n, i + len(sig) - k)
            out[i:j] += sig[k: k + j - i]
            k += j - i
            i = 0
    return out


def resonator(x, freq, bw, sr=SR):
    r = np.exp(-np.pi * bw / sr)
    th = 2 * np.pi * freq / sr
    return lfilter([1 - r], [1, -2 * r * np.cos(th), r * r], x)


def voice(f0, formants, dur, sr=SR, breath=.15, seed="v"):
    """A soft little hum: a buzz whose pitch follows f0 (an array or a number) through formants."""
    n = int(dur * sr)
    f = np.full(n, f0, float) if np.isscalar(f0) else np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(f0)), f0)
    ph = np.cumsum(f) / sr
    buzz = sum(np.sin(2 * np.pi * k * ph) / k ** 1.2 for k in range(1, 14) if True)
    buzz = buzz + breath * rng(seed).standard_normal(n)
    y = sum(g * resonator(buzz, fr, bw, sr) for fr, bw, g in formants)
    return y / max(1e-9, np.abs(y).max())


VOWEL_M = [(300, 90, 1.0), (900, 160, .25), (2300, 220, .08)]      # a closed-mouth "mmm"
VOWEL_U = [(330, 90, 1.0), (850, 140, .3), (2250, 200, .1)]        # "uu"
VOWEL_A = [(750, 110, 1.0), (1200, 130, .6), (2500, 200, .2)]      # "aa"
VOWEL_E = [(450, 100, 1.0), (1900, 160, .4), (2600, 220, .15)]     # "eh"


def noise(n, name):
    return rng(name).standard_normal(n)


def norm(x, peak=.7):
    return x / max(1e-9, np.abs(x).max()) * peak


def fade_edges(x, sr=SR, ms=6):
    k = max(1, int(sr * ms / 1000))
    x = x.copy()
    x[:k] *= np.linspace(0, 1, k)
    x[-k:] *= np.linspace(1, 0, k)
    return x


# ---------------------------------------------------------------- instruments
def xylo(freq, dur=.5, sr=SR):
    """A wooden xylophone / marimba bar: a quick, woody decay."""
    t = t_of(dur, sr)
    x = (partial(freq, t, sr) * np.exp(-t / .16) + .35 * partial(freq * 3.93, t, sr) * np.exp(-t / .035)
         + .1 * partial(freq * 9.2, t, sr) * np.exp(-t / .012))
    return x * env(len(t), .002, .03, sr)


def harmonica(freq, dur=.5, sr=SR):
    """A soft reed: odd and even harmonics, a little vibrato, breathy."""
    t = t_of(dur, sr)
    vib = 1 + .006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / .15, 0, 1)
    ph = np.cumsum(freq * vib) / sr
    x = sum((.9 ** k) / k * np.sin(2 * np.pi * k * ph) for k in range(1, 8) if k * freq < .45 * sr)
    x = lowpass(x + .04 * rng(f"harm{freq:.0f}").standard_normal(len(t)), 2600, sr)
    return x * adsr(len(t), .03, .08, .75, min(.12, dur * .4), sr)


def piano(freq, dur=1.2, sr=SR):
    """A soft piano-like note."""
    t = t_of(dur, sr)
    x = (partial(freq, t, sr) * np.exp(-t / .7) + .4 * partial(freq * 2.001, t, sr) * np.exp(-t / .35)
         + .15 * partial(freq * 3.003, t, sr) * np.exp(-t / .18) + .06 * partial(freq * 4.01, t, sr) * np.exp(-t / .1))
    return x * env(len(t), .004, .08, sr)


def knock(dur, f, name, sr=SR, decay=.02, cut=1400):
    """A dull wooden knock (a toy's click)."""
    t = t_of(dur, sr)
    x = lowpass(noise(len(t), name), cut, sr) * np.exp(-t / decay) * .7 + np.sin(2 * np.pi * f * t) * np.exp(-t / (decay * 1.4))
    return x




# ---------------------------------------------------------------- more instruments
def pluck(freq, dur=.6, sr=SR, bright=.5):
    """A ukulele-ish plucked string."""
    t = t_of(dur, sr)
    x = sum((bright ** (k - 1)) / k * partial(freq * k, t, sr) * np.exp(-t * (3 + 2.5 * k)) for k in range(1, 6))
    return x * env(len(t), .003, .04, sr)


def brass(freq, dur=.4, sr=SR):
    """A soft little trumpet."""
    t = t_of(dur, sr)
    vib = 1 + .004 * np.sin(2 * np.pi * 5 * t)
    ph = np.cumsum(freq * vib) / sr
    x = sum((.75 ** k) * np.sin(2 * np.pi * (k + 1) * ph) for k in range(7) if (k + 1) * freq < .45 * sr)
    return lowpass(x, 2400, sr) * adsr(len(t), .025, .06, .7, min(.08, dur * .3), sr)


def flute(freq, dur=.5, sr=SR, seed="fl"):
    t = t_of(dur, sr)
    vib = 1 + .006 * np.sin(2 * np.pi * 5 * t) * np.clip(t / .2, 0, 1)
    ph = np.cumsum(freq * vib) / sr
    x = np.sin(2 * np.pi * ph) + .12 * np.sin(4 * np.pi * ph) + .05 * bandpass(rng(seed + f"{freq:.0f}").standard_normal(len(t)), freq * .8, freq * 3, sr)
    return x * adsr(len(t), .05, .05, .85, min(.1, dur * .3), sr)


def kick(sr=SR, dur=.25, f0=110, f1=45):
    t = t_of(dur, sr)
    return np.sin(2 * np.pi * np.cumsum(np.linspace(f0, f1, len(t))) / sr) * np.exp(-t / .08)


def clap(name, sr=SR, dur=.2):
    t = t_of(dur, sr)
    return sum(bandpass(noise(len(t), f"{name}{j}"), 900, 3500, sr) * np.exp(-np.maximum(t - j * .011, 0) / .03) * (t >= j * .011) for j in range(3))


def shaker(name, sr=SR, dur=.09):
    t = t_of(dur, sr)
    return bandpass(noise(len(t), name), 4000, 7500, sr) * np.sin(np.pi * t / dur) ** 2


def sweep(f0, f1, dur, sr=SR, shape=1.0):
    t = t_of(dur, sr)
    f = f0 + (f1 - f0) * (t / dur) ** shape
    return np.sin(2 * np.pi * np.cumsum(f) / sr)


def bubble(f0=400, f1=1200, dur=.09, sr=SR):
    t = t_of(dur, sr)
    return sweep(f0, f1, dur, sr, .6) * np.sin(np.pi * t / dur) ** 1.5


def thud(f=70, dur=.3, name="thud", sr=SR):
    """A low, soft floor thump (only in the loud sounds)."""
    t = t_of(dur, sr)
    return np.sin(2 * np.pi * np.cumsum(np.linspace(f * 1.6, f, len(t))) / sr) * np.exp(-t / .07) + .3 * lowpass(noise(len(t), name), 400, sr) * np.exp(-t / .03)


def spring(f=180, dur=.5, sr=SR, depth=.5, rate=22):
    """「啵嚶」: a spring's boing, the pitch wobbling down as it settles."""
    t = t_of(dur, sr)
    fr = f * (1 + depth * np.exp(-t / .12) * np.sin(2 * np.pi * rate * t)) * (1 + .6 * np.exp(-t / .05))
    x = np.sin(2 * np.pi * np.cumsum(fr) / sr) + .3 * np.sin(4 * np.pi * np.cumsum(fr) / sr)
    return x * np.exp(-t / (dur * .35)) * env(len(t), .004, .05, sr)


def chirp(f0, f1, dur, sr=SR):
    t = t_of(dur, sr)
    return sweep(f0, f1, dur, sr, .7) * np.sin(np.pi * t / dur)


# ---------------------------------------------------------------- the app's own sounds
def s_tap():
    t = t_of(.12)
    return norm(lowpass(noise(len(t), "tap"), 900) * np.exp(-t / .02) * .6 + np.sin(2 * np.pi * 200 * t) * np.exp(-t / .03), .5)


def s_pop():
    return norm(chirp(500, 1100, .14), .5)


def s_count():
    """「叮」: one number of 「一起數」 lighting up."""
    return norm(bell(NOTE["E6"], .5, bright=.4), .38)


def s_tick():
    """「嗒」: a card of 「先看看四周」 ticked."""
    return norm(place(.2, [(0, knock(.12, 900, "tick", decay=.01, cut=3000)), (0, .5 * xylo(NOTE["C6"], .2))]), .45)


def s_breath():
    """「呼——」: catching a breath between moves."""
    t = t_of(1.1)
    x = bandpass(noise(len(t), "breath"), 300, 1800) * np.sin(np.pi * t / 1.1) ** 1.5
    return norm(x, .35)


def s_breath_in():
    t = t_of(1.4)
    x = bandpass(noise(len(t), "bin"), 400, 2400) * (t / 1.4) ** .8 * np.sin(np.pi * t / 1.4) + .25 * sweep(NOTE["C5"], NOTE["G5"], 1.4) * np.sin(np.pi * t / 1.4)
    return norm(x, .3)


def s_breath_out():
    t = t_of(1.4)
    x = bandpass(noise(len(t), "bout"), 250, 1600) * (1 - t / 1.4) ** .8 * np.sin(np.pi * t / 1.4) + .25 * sweep(NOTE["G5"], NOTE["C5"], 1.4) * np.sin(np.pi * t / 1.4)
    return norm(x, .3)


def s_done():
    return norm(place(1.4, [(0, xylo(NOTE["C6"])), (.12, xylo(NOTE["E6"])), (.24, xylo(NOTE["G6"])), (.4, bell(NOTE["C7"], .9, bright=.5)), (.4, .6 * xylo(NOTE["E6"], .7))]), .55)


def s_look():
    """The start of 「先看看四周」: a little two-note chime."""
    return norm(place(1.0, [(0, bell(NOTE["G5"], .7, bright=.4)), (.22, bell(NOTE["C6"], .8, bright=.4))]), .45)


def s_ready():
    return norm(place(.9, [(0, xylo(NOTE["G5"])), (.1, xylo(NOTE["C6"])), (.2, xylo(NOTE["E6"])), (.3, xylo(NOTE["G6"], .6))]), .55)


def s_freeze():
    """「停！」: a round drum 「咚！」 and a bright tap."""
    return norm(place(.7, [(0, thud(85, .5, "freeze")), (0, .5 * xylo(NOTE["C5"], .5)), (.02, .3 * bell(NOTE["C6"], .6, bright=.3))]), .6)


def s_freeze_soft():
    return norm(place(.7, [(0, bell(NOTE["E6"], .6, bright=.3)), (.08, .7 * bell(NOTE["C6"], .6, bright=.3))]), .4)


def s_go():
    """「動起來！」: a little rising whoosh and a bell."""
    t = t_of(.45)
    whoosh = bandpass(noise(len(t), "go"), 800, 3500) * np.sin(np.pi * t / .45) ** 2
    return norm(place(.8, [(0, .4 * whoosh), (.25, bell(NOTE["G6"], .5, bright=.4))]), .45)


def s_clap():
    return norm(clap("pclap"), .3)


def s_bow():
    return norm(place(1.2, [(0, xylo(NOTE["G6"])), (.14, xylo(NOTE["E6"])), (.28, xylo(NOTE["C6"])), (.5, bell(NOTE["C6"], .7, bright=.4))]), .5)


def s_party():
    return norm(place(1.0, [(0, brass(NOTE["C5"], .15)), (.16, brass(NOTE["E5"], .15)), (.32, brass(NOTE["G5"], .15)), (.48, brass(NOTE["C6"], .45))]), .5)


def s_card():
    t = t_of(.2)
    slide = bandpass(noise(len(t), "card"), 1500, 5000) * np.sin(np.pi * t / .2) ** 2
    return norm(place(.4, [(0, .4 * slide), (.12, xylo(NOTE["A5"], .3))]), .45)


def s_dice():
    parts = [(i * .055 + kit_r * .01, knock(.06, 600 + 120 * (i % 3), f"dice{i}", decay=.008, cut=4000)) for i, kit_r in enumerate([0, 1, 0, 2, 1, 0, 1])]
    parts.append((.45, xylo(NOTE["E6"], .4)))
    return norm(place(.9, parts), .45)


def s_stamp():
    return norm(place(.5, [(0, knock(.25, 160, "stamp", decay=.04, cut=900)), (.05, .4 * xylo(NOTE["C6"], .3))]), .5)


def s_night():
    return norm(place(1.5, [(0, bell(NOTE["G5"], .9, bright=.3)), (.3, bell(NOTE["E5"], .9, bright=.3)), (.6, bell(NOTE["C5"], .9, bright=.3))]), .45)


def s_calm():
    return norm(place(1.3, [(0, bell(NOTE["E5"], 1.0, bright=.25)), (.4, bell(NOTE["B5"], .9, bright=.25))]), .35)


# ---------------------------------------------------------------- the animals' calls
VOWEL_O = [(500, 100, 1.0), (850, 140, .5), (2400, 200, .1)]


def s_frog():
    """「呱、呱」: two buzzy croaks."""
    one = lambda k: voice(np.array([150, 170, 120]), [(500, 120, 1), (1300, 180, .5)], .18, breath=.05, seed=f"frog{k}") * env(int(.18 * SR), .01, .05)
    return norm(place(.5, [(0, one(0)), (.24, one(1))]), .5)


def s_bunny():
    """A soft sniff-sniff and a squeak."""
    t = t_of(.08)
    sniff = lambda k: bandpass(noise(len(t), f"sniff{k}"), 2000, 6000) * np.sin(np.pi * t / .08)
    return norm(place(.6, [(0, .4 * sniff(0)), (.12, .4 * sniff(1)), (.3, chirp(1800, 2600, .14))]), .4)


def s_kangaroo():
    return norm(place(.8, [(0, spring(150, .6, depth=.6)), (.5, .7 * thud(70, .3, "kthud"))]), .6)


def s_kangaroo_soft():
    return norm(lowpass(spring(220, .5, depth=.35), 1500), .35)


def s_bear():
    """「嗚哈！」: a friendly low hum, up and down."""
    return norm(voice(np.array([110, 150, 165, 120]), VOWEL_U, .55, breath=.1, seed="bear") * adsr(int(.55 * SR), .05, .1, .8, .15), .5)


def s_crab():
    """「喀喀、喀喀」: claws clicking."""
    c = lambda k: bandpass(noise(int(.03 * SR), f"crab{k}"), 2500, 6000) * np.exp(-t_of(.03) / .006)
    return norm(place(.55, [(0, c(0)), (.07, c(1)), (.25, c(2)), (.32, c(3))]), .5)


def s_penguin():
    return norm(voice(np.array([380, 520, 440]), VOWEL_A, .3, breath=.25, seed="peng") * env(int(.3 * SR), .01, .08), .45)


def s_duck():
    one = lambda k: voice(np.array([320, 300]), [(900, 90, 1), (1400, 120, .7), (2600, 200, .3)], .16, breath=.2, seed=f"duck{k}") * env(int(.16 * SR), .01, .04)
    return norm(place(.45, [(0, one(0)), (.22, one(1))]), .45)


def s_shh():
    """The leopard cat's 「噓——」 (tiptoe quietly)."""
    t = t_of(1.0)
    return norm(bandpass(noise(len(t), "shh"), 2200, 6500) * np.sin(np.pi * t / 1.0) ** 1.2, .3)


def s_deer():
    """「呦！」: a high little call."""
    return norm(voice(np.array([600, 900, 700]), VOWEL_U, .35, breath=.1, seed="deer") * env(int(.35 * SR), .02, .1), .45)


def _trumpet(f0, f1, dur):
    t = t_of(dur)
    f = np.interp(t, [0, dur * .4, dur], [f0, f1, f1 * .95]) * (1 + .02 * np.sin(2 * np.pi * 6 * t))
    ph = np.cumsum(f) / SR
    x = sum((.8 ** k) * np.sin(2 * np.pi * (k + 1) * ph) for k in range(8))
    return lowpass(x, 3000) * adsr(len(t), .06, .1, .8, .2)


def s_elephant():
    return norm(place(1.1, [(0, _trumpet(300, 520, .8)), (.82, .8 * thud(60, .28, "ethud"))]), .55)


def s_elephant_soft():
    return norm(lowpass(_trumpet(320, 480, .7), 1400), .3)


def s_hiss():
    """「嘶——」: a gentle snake hiss."""
    t = t_of(.8)
    return norm(bandpass(noise(len(t), "hiss"), 3500, 8500) * np.sin(np.pi * t / .8) ** .8, .3)


def s_bubbles():
    parts = [(i * .09, bubble(300 + 120 * (i % 3), 900 + 200 * (i % 2))) for i in range(6)]
    return norm(place(.75, parts), .45)


def s_tweet():
    return norm(place(.6, [(0, chirp(2200, 3400, .1)), (.14, chirp(2400, 3600, .1)), (.3, chirp(2000, 3800, .16))]), .4)


def s_magpie():
    """The blue magpie's 「嘎嘎」."""
    one = lambda k: voice(np.array([520, 480]), [(1100, 150, 1), (1800, 200, .7), (3000, 260, .3)], .14, breath=.5, seed=f"mag{k}") * env(int(.14 * SR), .01, .04)
    return norm(place(.45, [(0, one(0)), (.2, one(1))]), .45)


def s_splash():
    t = t_of(.35)
    sp = bandpass(noise(len(t), "splash"), 600, 5000) * np.exp(-t / .1)
    return norm(place(.8, [(0, sp), (.25, .6 * bubble()), (.38, .5 * bubble(500, 1300))]), .45)


def s_flamingo():
    return norm(voice(np.array([340, 380, 330]), [(700, 110, 1), (1100, 140, .7), (2600, 220, .2)], .32, breath=.15, seed="fla") * env(int(.32 * SR), .02, .08), .42)


def s_giraffe():
    """A slide whistle going up: stretch up high!"""
    return norm(sweep(400, 1300, .8, shape=.8) * adsr(int(.8 * SR), .05, .1, .8, .15), .35)


def s_sloth():
    """A long, slow yawn."""
    return norm(voice(np.array([230, 260, 200, 150]), VOWEL_A, 1.2, breath=.2, seed="sloth") * adsr(int(1.2 * SR), .2, .2, .7, .4), .4)


def s_sparkle():
    return norm(place(.9, [(i * .07, bell(NOTE[n], .45, bright=.3)) for i, n in enumerate(["C7", "E7", "G7", "C8"])]), .35)


def s_jelly():
    t = t_of(.6)
    f = np.linspace(700, 300, len(t)) * (1 + .08 * np.sin(2 * np.pi * 9 * t))
    return norm(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / .6) ** 1.2, .4)


def s_octopus():
    parts = [(i * .07, bubble(180 + 60 * (i % 3), 420 + 80 * (i % 2), .1)) for i in range(7)]
    return norm(place(.7, parts), .45)


def s_seaturtle():
    parts = [(0, .5 * bubble(150, 300, .25))] + [(.15 + i * .1, bubble(250, 600, .08)) for i in range(4)]
    return norm(place(.7, parts), .4)


def s_monkey():
    """「吱吱吱」: quick happy chirps."""
    one = lambda k: voice(np.array([900, 1200, 1000]), VOWEL_E, .09, breath=.1, seed=f"mon{k}") * env(int(.09 * SR), .005, .03)
    return norm(place(.45, [(i * .12, one(i)) for i in range(3)]), .42)


def s_squirrel():
    parts = [(i * .045, knock(.03, 1800, f"sq{i}", decay=.004, cut=6000)) for i in range(6)]
    parts.append((.32, chirp(2600, 3400, .1)))
    return norm(place(.5, parts), .4)


def s_lion():
    """A funny 「哈——」: a big breath out, never a roar."""
    t = t_of(.9)
    breath = bandpass(noise(len(t), "lion"), 500, 2600)
    y = sum(g * resonator(breath, fr, bw) for fr, bw, g in VOWEL_A)
    return norm(y * np.sin(np.pi * t / .9) ** .7, .4)


def s_turtle():
    return norm(place(.8, [(0, kalimba(NOTE["C4"], .6)), (.2, .6 * bubble(200, 400, .15))]), .45)


def s_meow():
    n = int(.5 * SR)
    f0 = np.array([520, 700, 620, 460])
    a = voice(f0, VOWEL_E, .5, breath=.1, seed="meow")
    b = voice(f0, VOWEL_U, .5, breath=.1, seed="meow2")
    mixk = np.linspace(0, 1, n)
    return norm((a * (1 - mixk) + b * mixk) * env(n, .03, .12), .4)


def s_flutter():
    parts = [(i * .05, .6 * bandpass(noise(int(.04 * SR), f"flt{i}"), 600, 2400) * np.sin(np.pi * t_of(.04) / .04)) for i in range(8)]
    return norm(place(.5, parts), .35)


def s_pangolin():
    """「咕嚕咕嚕」: curling into a ball, rolling."""
    parts = [(i * .08, knock(.07, 180 + 20 * (i % 3), f"pg{i}", decay=.02, cut=700)) for i in range(7)]
    return norm(place(.7, parts), .45)


def s_rainbow():
    return norm(place(1.1, [(i * .06, kalimba(NOTE[n], .5)) for i, n in enumerate(["C5", "E5", "G5", "C6", "E6", "G6", "C7"])]), .4)


# ---------------------------------------------------------------- each move's sound on the beat
def s_boing():
    """「啵嚶」 and a soft landing 「咚」 (quiet mode: boing_soft)."""
    return norm(place(.7, [(0, spring(190, .45)), (.38, .8 * thud(75, .3, "bthud"))]), .55)


def s_boing_soft():
    return norm(lowpass(spring(260, .35, depth=.3), 1800), .3)


def s_hop():
    return norm(place(.5, [(0, spring(330, .25, depth=.35, rate=30)), (.2, .5 * thud(110, .2, "hthud"))]), .45)


def s_hop_soft():
    return norm(lowpass(spring(420, .2, depth=.25, rate=30), 2200), .28)


def s_shuffle():
    t = t_of(.16)
    s = lambda k: bandpass(noise(len(t), f"shuf{k}"), 1500, 5000) * np.sin(np.pi * t / .16) ** 2
    return norm(place(.45, [(0, s(0)), (.2, .8 * s(1))]), .32)


def s_click():
    c = lambda k: bandpass(noise(int(.025 * SR), f"clk{k}"), 2500, 6500) * np.exp(-t_of(.025) / .005)
    return norm(place(.2, [(0, c(0)), (.07, c(1))]), .4)


def s_pitter():
    return norm(place(.35, [(0, knock(.08, 300, "pit0", decay=.012, cut=1500)), (.15, knock(.08, 260, "pit1", decay=.012, cut=1500))]), .4)


def s_tiptoe():
    return norm(.6 * pluck(NOTE["E6"], .25, bright=.3), .25)


def s_leap():
    t = t_of(.3)
    whoosh = bandpass(noise(len(t), "leap"), 700, 3000) * np.sin(np.pi * t / .3) ** 2
    return norm(place(.6, [(0, .5 * whoosh), (.3, .7 * thud(90, .25, "lthud"))]), .45)


def s_leap_soft():
    t = t_of(.3)
    return norm(bandpass(noise(len(t), "leaps"), 700, 3000) * np.sin(np.pi * t / .3) ** 2, .2)


def s_stomp():
    """The elephant's 「咚」 (quiet mode: stomp_soft)."""
    return norm(place(.4, [(0, thud(58, .4, "stomp")), (0, .3 * knock(.2, 120, "stomp2", decay=.03, cut=600))]), .6)


def s_stomp_soft():
    return norm(lowpass(knock(.15, 220, "stomps", decay=.02, cut=900), 1200), .25)


def s_wiggle():
    """「咻咻」: wiggling."""
    t = t_of(.12)
    w = lambda k: bandpass(noise(len(t), f"wig{k}"), 1200 + 600 * k, 4000) * np.sin(np.pi * t / .12) ** 2
    return norm(place(.35, [(0, w(0)), (.16, w(1))]), .3)


def s_swish():
    t = t_of(.35)
    x = np.zeros(len(t))
    nz = noise(len(t), "swish")
    for i, cf in enumerate(np.linspace(500, 1600, 6)):
        seg = slice(i * len(t) // 6, (i + 1) * len(t) // 6)
        x[seg] = bandpass(nz, cf * .7, cf * 1.4)[seg]
    return norm(x * np.sin(np.pi * t / .35) ** 2, .3)


def s_flap():
    parts = [(i * .12, bandpass(noise(int(.08 * SR), f"flp{i}"), 400, 1800) * np.sin(np.pi * t_of(.08) / .08)) for i in range(2)]
    return norm(place(.3, parts), .32)


def s_wobble():
    t = t_of(.5)
    f = NOTE["A5"] * (1 + .03 * np.sin(2 * np.pi * 6 * t))
    return norm(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / .5), .2)


def s_stretch():
    return norm(sweep(NOTE["C5"], NOTE["C6"], .6, shape=.7) * np.sin(np.pi * t_of(.6) / .6), .22)


def s_slowdrum():
    return norm(place(.6, [(0, xylo(NOTE["C4"], .6)), (0, .5 * xylo(NOTE["G4"], .6))]), .32)


def s_open():
    t = t_of(.3)
    whoosh = bandpass(noise(len(t), "open"), 1000, 4000) * np.sin(np.pi * t / .3) ** 2
    return norm(place(.6, [(0, .4 * whoosh), (.2, bell(NOTE["E7"], .35, bright=.3))]), .35)


def s_bloop():
    return norm(bubble(300, 700, .14), .35)


def s_pat():
    return norm(lowpass(knock(.1, 240, "pat", decay=.015, cut=1200), 1500), .35)


def s_pick():
    return norm(place(.4, [(0, chirp(600, 1000, .06)), (.1, .6 * xylo(NOTE["A6"], .25))]), .35)


def s_ha():
    t = t_of(.45)
    breath = bandpass(noise(len(t), "ha"), 500, 2400)
    y = sum(g * resonator(breath, fr, bw) for fr, bw, g in VOWEL_A)
    return norm(y * np.sin(np.pi * t / .45) ** .8, .3)


def s_roll():
    parts = [(i * .05, knock(.06, 160, f"roll{i}", decay=.02, cut=600)) for i in range(6)]
    return norm(place(.45, parts), .35)


# ---------------------------------------------------------------- the music
def loop(total, parts, sr=LOOP_SR, peak=.42):
    x = place_loop(total, parts, sr)
    return x / max(1e-9, np.abs(x).max()) * peak


def _drums(beats, b, sr, kick_on=(0,), clap_on=(), shake=True, kick_amp=.5, clap_amp=.25, shake_amp=.08, name="d"):
    parts = []
    for k in range(beats):
        if k % 4 in kick_on:
            parts.append((k * b, kick_amp * kick(sr)))
        if k % 4 in clap_on:
            parts.append((k * b, clap_amp * clap(f"{name}c{k % 3}", sr)))
        if shake:
            for h in (0, .5):
                parts.append(((k + h) * b, shake_amp * (1.4 if h == 0 else 1) * shaker(f"{name}s{(k * 2 + int(h * 2)) % 4}", sr)))
    return parts


def _bass(chords, b, sr, inst=xylo, amp=.5, pattern=(0, 2)):
    parts = []
    for beat, root in chords:
        for k in pattern:
            parts.append(((beat + k) * b, amp * inst(NOTE[root] * (1 if k == pattern[0] else 1.5), .45, sr)))
    return parts


def _tempo(name):
    return {"home": 104, "jungle": 100, "zoo": 104, "sea": 96, "rain": 92, "mountain": 100, "party": 120, "calm": 64, "rest": 56}[name]


def m_home():
    """Home and 自己排: a happy ukulele in C with a shaker, 104 bpm, 32 beats."""
    bpm, beats = _tempo("home"), 32
    b, sr = 60 / bpm, LOOP_SR
    mel = [(0, "E5"), (1, "G5"), (2, "A5"), (3, "G5"), (4, "E5"), (5, "C5"), (6, "D5"), (8, "E5"), (9, "G5"), (10, "C6"), (11, "B5"), (12, "A5"),
           (14, "G5"), (16, "F5"), (17, "A5"), (18, "C6"), (19, "A5"), (20, "G5"), (21, "E5"), (22, "D5"), (24, "E5"), (25, "D5"), (26, "C5"),
           (27, "D5"), (28, "E5"), (29, "G5"), (30, "C6")]
    parts = [(beat * b, .7 * pluck(NOTE[n], .6, sr)) for beat, n in mel]
    for beat, ch in ((0, ["C4", "E4", "G4"]), (8, ["A3", "C4", "E4"]), (16, ["F3", "A3", "C4"]), (24, ["G3", "B3", "D4"])):
        for k in range(0, 8, 2):
            for j, n in enumerate(ch):
                parts.append(((beat + k) * b + j * .015, .3 * pluck(NOTE[n], .5, sr, .4)))
    parts += _drums(beats, b, sr, kick_on=(0, 2), clap_on=(), kick_amp=.35, shake_amp=.07, name="home")
    return loop(beats * b, parts)


def m_jungle():
    """叢林探險: a xylophone tune over tom drums and a shaker, 100 bpm, 32 beats."""
    bpm, beats = _tempo("jungle"), 32
    b, sr = 60 / bpm, LOOP_SR
    mel = [(0, "C6"), (1, "A5"), (2, "G5"), (2.5, "A5"), (3, "C6"), (4, "D6"), (5, "C6"), (6, "A5"), (8, "G5"), (9, "E5"), (10, "G5"), (11, "A5"),
           (12, "G5"), (14, "E5"), (16, "C6"), (17, "A5"), (18, "G5"), (18.5, "A5"), (19, "C6"), (20, "E6"), (21, "D6"), (22, "C6"), (24, "A5"),
           (25, "G5"), (26, "E5"), (27, "D5"), (28, "C5"), (30, "G5")]
    parts = [(beat * b, .8 * xylo(NOTE[n], .5, sr)) for beat, n in mel]
    parts += _bass([(0, "C3"), (4, "A2"), (8, "F2"), (12, "G2"), (16, "C3"), (20, "A2"), (24, "F2"), (28, "G2")], b, sr)
    for k in range(beats):
        tom = knock(.18, 140 if k % 2 == 0 else 190, f"tom{k % 4}", sr, decay=.05, cut=900)
        parts.append((k * b, (.55 if k % 4 == 0 else .35) * tom))
        if k % 4 == 3:
            parts.append(((k + .5) * b, .3 * knock(.15, 230, "tomx", sr, decay=.04, cut=900)))
    parts += _drums(beats, b, sr, kick_on=(0,), kick_amp=.4, shake_amp=.07, name="jun")
    return loop(beats * b, parts)


def m_zoo():
    """去動物園: a little trumpet and an accordion, oom-pah, 104 bpm, 32 beats."""
    bpm, beats = _tempo("zoo"), 32
    b, sr = 60 / bpm, LOOP_SR
    mel = [(0, "G5", 1), (1, "E5", .5), (1.5, "G5", .5), (2, "C6", 1), (3, "G5", 1), (4, "A5", 1), (5, "G5", 1), (6, "E5", 2),
           (8, "F5", 1), (9, "D5", .5), (9.5, "F5", .5), (10, "B5", 1), (11, "A5", 1), (12, "G5", 2), (14, "D5", 2),
           (16, "G5", 1), (17, "E5", .5), (17.5, "G5", .5), (18, "C6", 1), (19, "E6", 1), (20, "D6", 1), (21, "C6", 1), (22, "A5", 2),
           (24, "G5", 1), (25, "F5", 1), (26, "E5", 1), (27, "D5", 1), (28, "C5", 2), (30, "G4", 2)]
    parts = [(beat * b, .55 * brass(NOTE[n], ln * b * .9, sr)) for beat, n, ln in mel]
    chords = [(0, "C3", ["E4", "G4", "C5"]), (8, "G2", ["D4", "F4", "B4"]), (16, "C3", ["E4", "G4", "C5"]), (24, "G2", ["D4", "F4", "B4"])]
    for beat, root, ch in chords:
        for k in range(8):
            if k % 2 == 0:
                parts.append(((beat + k) * b, .5 * xylo(NOTE[root] * (1 if k % 4 == 0 else 1.5), .4, sr)))
            else:
                for n in ch:
                    parts.append(((beat + k) * b, .12 * harmonica(NOTE[n], b * .6, sr)))
    parts += _drums(beats, b, sr, kick_on=(0, 2), clap_on=(1, 3), kick_amp=.3, clap_amp=.12, shake=False, name="zoo")
    return loop(beats * b, parts)


def m_sea():
    """海底世界: a ukulele, a soft beat and bubbles, 96 bpm, 32 beats."""
    bpm, beats = _tempo("sea"), 32
    b, sr = 60 / bpm, LOOP_SR
    mel = [(0, "D5"), (1, "F#5"), (2, "A5"), (3, "F#5"), (4, "G5"), (5, "B5"), (6, "A5"), (8, "F#5"), (9, "E5"), (10, "D5"), (11, "E5"),
           (12, "F#5"), (14, "A4"), (16, "D5"), (17, "F#5"), (18, "A5"), (19, "D6"), (20, "B5"), (21, "G5"), (22, "A5"), (24, "F#5"),
           (25, "E5"), (26, "D5"), (27, "E5"), (28, "D5"), (30, "A4")]
    parts = [(beat * b, .7 * pluck(NOTE[n], .7, sr)) for beat, n in mel]
    for beat, ch in ((0, ["D4", "F#4", "A4"]), (8, ["G3", "B3", "D4"]), (16, ["D4", "F#4", "A4"]), (24, ["A3", "C#4", "E4"])):
        for k in (0, 1.5, 3, 4, 5.5, 7):
            for j, n in enumerate(ch):
                parts.append(((beat + k) * b + j * .012, .25 * pluck(NOTE[n], .5, sr, .35)))
    for k in range(0, beats, 3):
        parts.append(((k + .75) * b, .18 * bubble(300 + 70 * (k % 5), 900, .1, sr)))
    parts += _drums(beats, b, sr, kick_on=(0,), clap_on=(2,), kick_amp=.4, clap_amp=.12, shake_amp=.05, name="sea")
    return loop(beats * b, parts)


def m_rain():
    """下雨天: a piano with soft rain under it, 92 bpm, 32 beats."""
    bpm, beats = _tempo("rain"), 32
    b, sr = 60 / bpm, LOOP_SR
    mel = [(0, "A5"), (1, "C6"), (2, "E6"), (3, "C6"), (4, "D6"), (5, "B5"), (6, "G5"), (8, "A5"), (9, "B5"), (10, "C6"), (11, "A5"),
           (12, "E5"), (14, "G5"), (16, "F5"), (17, "A5"), (18, "C6"), (19, "F6"), (20, "E6"), (21, "C6"), (22, "D6"), (24, "C6"),
           (25, "B5"), (26, "A5"), (27, "G5"), (28, "A5"), (30, "E5")]
    parts = [(beat * b, .7 * piano(NOTE[n], 1.2, sr)) for beat, n in mel]
    for beat, ch in ((0, ["A3", "C4", "E4"]), (8, ["E3", "G3", "B3"]), (16, ["F3", "A3", "C4"]), (24, ["E3", "G#3", "B3"])):
        for k in range(0, 8, 2):
            parts.append(((beat + k) * b, .3 * piano(NOTE[ch[0]] / 2, 1.0, sr)))
            for j, n in enumerate(ch):
                parts.append(((beat + k + 1) * b, .16 * piano(NOTE[n], .8, sr)))
    total = beats * b
    n = int(total * sr)
    rain = bandpass(rng("rainloop").standard_normal(n), 1500, 6000, sr) * .05
    drops = [((k * .37) % total, .12 * bubble(1500, 2500, .03, sr)) for k in range(int(total / .37))]
    parts += [(0, rain)] + drops
    parts += _drums(beats, b, sr, kick_on=(0, 2), clap_on=(), kick_amp=.3, shake_amp=.05, name="rain")
    return loop(total, parts)


def m_mountain():
    """台灣山林: a flute over a light drum, with birds, 100 bpm, 32 beats."""
    bpm, beats = _tempo("mountain"), 32
    b, sr = 60 / bpm, LOOP_SR
    mel = [(0, "G5", 1), (1, "A5", 1), (2, "C6", 1.5), (3.5, "D6", .5), (4, "E6", 1), (5, "D6", 1), (6, "C6", 2), (8, "A5", 1), (9, "C6", 1),
           (10, "D6", 1), (11, "C6", 1), (12, "A5", 2), (14, "G5", 2), (16, "E5", 1), (17, "G5", 1), (18, "A5", 1.5), (19.5, "C6", .5),
           (20, "D6", 1), (21, "E6", 1), (22, "D6", 2), (24, "C6", 1), (25, "A5", 1), (26, "G5", 1), (27, "E5", 1), (28, "G5", 4)]
    parts = [(beat * b, .5 * flute(NOTE[n], ln * b * .95, sr, "mt")) for beat, n, ln in mel]
    parts += _bass([(0, "C3"), (4, "A2"), (8, "F2"), (12, "C3"), (16, "A2"), (20, "D3"), (24, "F2"), (28, "C3")], b, sr, inst=pluck, amp=.5)
    for k in (3, 13, 21, 29):
        parts.append(((k + .5) * b, .2 * chirp(2600, 3600, .08, sr)))
        parts.append(((k + .7) * b, .16 * chirp(2800, 3800, .07, sr)))
    parts += _drums(beats, b, sr, kick_on=(0, 2), clap_on=(1, 3), kick_amp=.35, clap_amp=.08, shake_amp=.05, name="mtn")
    return loop(beats * b, parts)


def m_party():
    """動物舞會: a bouncy dance beat (kick on every beat, claps, a marimba tune), 120 bpm, 40 beats."""
    bpm, beats = _tempo("party"), 40
    b, sr = 60 / bpm, LOOP_SR
    mel = [(0, "C6"), (.5, "C6"), (1, "G5"), (2, "A5"), (2.5, "C6"), (3, "D6"), (4, "E6"), (4.5, "E6"), (5, "D6"), (6, "C6"), (7, "G5"),
           (8, "A5"), (8.5, "A5"), (9, "F5"), (10, "A5"), (10.5, "C6"), (11, "D6"), (12, "C6"), (13, "A5"), (14, "G5"),
           (16, "C6"), (16.5, "C6"), (17, "G5"), (18, "A5"), (18.5, "C6"), (19, "E6"), (20, "G6"), (21, "E6"), (22, "D6"), (23, "C6"),
           (24, "D6"), (25, "C6"), (26, "A5"), (27, "G5"), (28, "C6"), (30, "G5"), (32, "E5"), (33, "G5"), (34, "A5"), (35, "C6"),
           (36, "D6"), (37, "E6"), (38, "D6"), (39, "G5")]
    parts = [(beat * b, .7 * xylo(NOTE[n], .45, sr)) for beat, n in mel]
    for beat, root in ((0, "C3"), (4, "A2"), (8, "F2"), (12, "G2"), (16, "C3"), (20, "A2"), (24, "F2"), (28, "G2"), (32, "F2"), (36, "G2")):
        for k in range(4):
            parts.append(((beat + k + .5) * b, .45 * pluck(NOTE[root], .35, sr, .6)))
    parts += _drums(beats, b, sr, kick_on=(0, 1, 2, 3), clap_on=(1, 3), kick_amp=.5, clap_amp=.22, shake_amp=.08, name="party")
    return loop(beats * b, parts)


def m_calm():
    """慢慢伸展: a slow music box over a soft pad, 64 bpm, 20 beats."""
    bpm, beats = _tempo("calm"), 20
    b, sr = 60 / bpm, LOOP_SR
    mel = [(0, "E5", 2), (2, "G5", 1), (3, "E5", 1), (4, "D5", 2), (6, "C5", 2), (8, "D5", 2), (10, "E5", 1), (11, "G5", 1), (12, "A5", 4),
           (16, "G5", 2), (18, "E5", 2)]
    parts = [(beat * b, .6 * bell(NOTE[n], max(1.0, ln * b * 1.4), sr, .25)) for beat, n, ln in mel]
    for beat, ch in ((0, ["C4", "E4", "G4"]), (4, ["A3", "C4", "E4"]), (8, ["F3", "A3", "C4"]), (12, ["F3", "A3", "D4"]), (16, ["C4", "E4", "G4"])):
        parts.append((beat * b, .4 * pad([NOTE[x] for x in ch], 4 * b * 1.1, sr)))
    return loop(beats * b, parts, peak=.36)


def m_rest():
    """The rest: a glockenspiel lullaby, 56 bpm, 20 beats."""
    bpm, beats = _tempo("rest"), 20
    b, sr = 60 / bpm, LOOP_SR
    mel = [(0, "G5", 2), (2, "E5", 2), (4, "F5", 1), (5, "D5", 1), (6, "C5", 2), (8, "E5", 2), (10, "G5", 2), (12, "A5", 2), (14, "G5", 2),
           (16, "E5", 2), (18, "C5", 2)]
    parts = [(beat * b, .6 * bell(NOTE[n], max(.8, ln * b * 1.5), sr, .25)) for beat, n, ln in mel]
    for beat, ch in ((0, ["C4", "E4", "G4"]), (4, ["F3", "A3", "C4"]), (8, ["C4", "E4", "G4"]), (12, ["F3", "A3", "C4"]), (16, ["G3", "B3", "D4"])):
        parts.append((beat * b, .42 * pad([NOTE[x] for x in ch], 4 * b * 1.15, sr)))
    return loop(beats * b, parts, peak=.38)


SOUNDS = {name[2:]: f for name, f in list(globals().items()) if name.startswith("s_") and callable(f)}
MUSIC = {f"music_{name[2:]}": f for name, f in list(globals().items()) if name.startswith("m_") and callable(f)}
LONG = {}


def write(path, x, sr):
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def make(names=None):
    OUT.mkdir(parents=True, exist_ok=True)
    wanted = set(names or [*SOUNDS, *MUSIC])
    for name, f in SOUNDS.items():
        if name not in wanted:
            continue
        x = fade_edges(np.asarray(f(), float))
        d = len(x) / SR
        if d > LONG.get(name, 1.5):
            raise SystemExit(f"{name}: {d:.2f} s is too long")
        if np.abs(x).max() > .75:
            raise SystemExit(f"{name}: too loud")
        write(OUT / f"{name}.wav", x, SR)
        print(f"  {name:20s} {d:5.2f} s  peak {np.abs(x).max():.2f}")
    for name, f in MUSIC.items():
        if name not in wanted:
            continue
        x = np.asarray(f(), float)
        d = len(x) / LOOP_SR
        jump = abs(x[0] - x[-1])
        if not 18 <= d <= 30 or jump > .05:
            raise SystemExit(f"{name}: {d:.1f} s, seam jump {jump:.3f}")
        write(OUT / f"{name}.wav", x, LOOP_SR)
        print(f"  {name:20s} {d:5.2f} s  loop seam {jump:.3f}")
    known = {f"{n}.wav" for n in [*SOUNDS, *MUSIC]}
    extra = [p.name for p in OUT.glob("*.wav") if p.name not in known]
    if extra:
        raise SystemExit(f"files nobody makes: {extra}")
    size = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    if size > LIMIT:
        raise SystemExit(f"{size} bytes: over {LIMIT}")
    print(f"{len(known)} sounds, {size:,} bytes")


def preview(out):
    with tempfile.TemporaryDirectory(dir="/dev/shm") as tmp:
        parts = []
        for name in [*MUSIC, *SOUNDS]:
            parts.append(str(OUT / f"{name}.wav"))
        lst = pathlib.Path(tmp) / "list.txt"
        lst.write_text("".join(f"file '{p}'\n" for p in parts))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-ar", "22050", "-c:a", "aac", "-b:a", "96k", out], check=True)
    print(out)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["preview"]:
        preview(args[1])
    else:
        make(args or None)
