"""Offline synthesis of the Indigo Plateau fireworks (TEST208).

Rendered at 44.1 kHz, mono, then encoded to OGG Vorbis for the mod.
Design rules (the previous in-game set read as TV static on a phone):
  * no sustained broadband hiss: anything noisy is either a few
    milliseconds long (a transient) or kept under ~2.5 kHz;
  * every boom is a real event with a sharp front, a heavy low thump and a
    long outdoor tail (a valley's echoes and rolling reverb);
  * crackle is made of discrete pops rung through resonances, never noise;
  * no pitched whistle anywhere.
"""
import numpy as np, sys, os
from scipy import signal

SR = 44100


def sos(kind, f, order=2):
    return signal.butter(order, f, btype=kind, fs=SR, output="sos")


def filt(x, kind, f, order=2):
    return signal.sosfilt(sos(kind, f, order), x)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def env_ad(t, a, d):
    """attack a seconds (linear), then exponential decay with time constant d"""
    e = np.minimum(1.0, t / max(a, 1e-6))
    return e * np.exp(-np.maximum(0, t - a) / d)


def softclip(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


def valley_ir(rng, sec=3.2, t60=2.4, echoes=((.29, .42), (.63, .30), (1.07, .20), (1.62, .11)),
              dark=1.0):
    """an outdoor impulse response: a few distinct echoes off the valley walls
    and a diffuse tail that darkens as it decays (air absorbs the top first)"""
    t = t_axis(sec)
    n = len(t)
    ir = np.zeros(n)
    ir[0] = 1.0
    # the diffuse tail: noise, decaying, filtered progressively darker
    tail = rng.standard_normal(n) * np.exp(-6.9 * t / t60)
    tail *= np.minimum(1, t / .05)
    lo = filt(tail, "low", 1800 * dark, 2)
    lo2 = filt(tail, "low", 450 * dark, 2)
    mixk = np.exp(-t / .5)                 # bright early, dark late
    tail = lo * mixk + lo2 * (1 - mixk) * 1.6
    ir += tail * .055
    # discrete echoes, each softened (a smeared copy of the source)
    for d, g in echoes:
        i0 = int(d * SR)
        L = int(.09 * SR)
        if i0 + L >= n:
            continue
        blob = rng.standard_normal(L) * np.exp(-np.arange(L) / (SR * .02))
        blob = filt(blob, "low", 900 * dark, 2)
        blob /= np.max(np.abs(blob)) + 1e-9
        ir[i0:i0 + L] += blob * g * .55
    return ir


def reverb(x, ir, wet, dry=1.0):
    y = signal.fftconvolve(x, ir)[:len(x) + len(ir) - 1]
    out = np.zeros(len(y))
    out[:len(x)] += x * dry
    out += y * wet
    return out


def finish(x, peak=.92, fade=.25):
    x = x - np.mean(x)
    x = filt(x, "high", 28, 2)             # no DC or sub rumble a speaker can't play
    n = len(x)
    f = int(fade * SR)
    x[-f:] *= np.linspace(1, 0, f) ** 2
    x[:32] *= np.linspace(0, 1, 32)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


# ------------------------------------------------------------------ the sounds
def boom(seed, far=False):
    """a shell bursting, in the style of a close, loud recording: the blast
    hits at full strength at once and HOLDS for a moment (the air itself
    shoved), heavy in the 100-250 Hz chest-thump range, saturated the way a
    big boom overloads a microphone, then rolls away down the valley.
    (Matched against the reference clip: crest ~5, the first 0.5 s within a
    few dB of the peak, about -25 dB by 1.5 s.)"""
    rng = np.random.default_rng(seed)
    t = t_axis(2.6 if not far else 3.0)
    n = len(t)
    hold = rng.uniform(.10, .16) if not far else .05
    def held(a, h, d):
        e = np.minimum(1.0, t / a)
        return np.where(t < a + h, e, np.exp(-(t - a - h) / d))
    nz = rng.standard_normal(n)
    low = filt(nz, "band", (85, 270) if not far else (70, 200), 2)
    mid = filt(nz, "band", (230, 1100 if not far else 600), 2)
    hi = filt(nz, "band", (1100, 4000), 2)
    eB = held(.0012, hold, .42 if not far else .55) + .22 * np.exp(-t / 1.1) * np.minimum(1, t / .2)
    eH = held(.0008, .02, .09)
    # the thump: a sine falling fast, the punch under the blast
    f0 = (125 if not far else 95) + rng.uniform(-10, 10)
    f = 72 + (f0 - 72) * np.exp(-t / .05)
    th = np.sin(2 * np.pi * np.cumsum(f) / SR) * held(.002, .04, .22)
    # the crack: the first few ms hit everything at once (the hard front
    # you hear in a close recording), then it's gone
    cr = filt(rng.standard_normal(n), "band", (180, 4500 if not far else 1200), 2) * held(.0003, .006, .012)
    x = low * 3.2 * eB + mid * 1.7 * eB + hi * (.30 if not far else .04) * eH + th * 1.4 + cr * (5.0 if not far else 1.5)
    # a bass boost, then into saturation: dense and loud, not peaky
    x = x + filt(x, "band", (95, 230), 2) * 1.3
    x = x / (np.sqrt(np.mean(x[:int(.4 * SR)] ** 2)) + 1e-9)
    x = softclip(x * .55, 3.2 if not far else 2.0)
    if far:
        x = filt(x, "low", 900, 2)
    ir = valley_ir(rng, sec=2.4 if not far else 3.0, t60=1.9 if not far else 2.6,
                   echoes=((.31, .14), (.70, .08), (1.15, .05)), dark=.8 if far else 1.0)
    y = reverb(x, ir, wet=.35 if not far else .5)
    y = filt(y, "high", 32, 2)
    return finish(y, .97, fade=.4)


def launch(seed):
    """the mortar's deep thoomp, then the shell rushing up and away (a soft,
    dark whoosh that falls in pitch as it climbs; no hiss, no whistle)"""
    rng = np.random.default_rng(seed)
    t = t_axis(1.25)
    n = len(t)
    f = 75 + 110 * np.exp(-t / .03)
    th = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(t, .0015, .055)
    th = softclip(th, 3.5)
    pop = filt(rng.standard_normal(n), "low", 1400, 2) * env_ad(t, .0008, .012)
    # the rush: band noise, its band sliding down as the shell goes away
    x = rng.standard_normal(n)
    seg = int(.02 * SR)
    rush = np.zeros(n)
    zi = None
    hi_curve = 2200 * np.exp(-t / .55) + 700
    out = []
    for i in range(0, n, seg):
        hi = hi_curve[min(i, n - 1)]
        s = signal.butter(2, (260, hi), btype="band", fs=SR, output="sos")
        if zi is None:
            zi = signal.sosfilt_zi(s) * 0
        y, zi = signal.sosfilt(s, x[i:i + seg], zi=zi)
        out.append(y)
    rush = np.concatenate(out)[:n]
    renv = np.minimum(1, t / .06) * np.exp(-np.maximum(0, t - .06) / .38)
    rush *= renv * (1 + .18 * np.sin(2 * np.pi * 7.5 * t))
    dry = th * .8 + pop * .9 + rush * .75
    dry = filt(dry, "high", 70, 2)
    ir = valley_ir(rng, sec=1.6, t60=1.1, echoes=((.24, .25), (.55, .14)))
    y = reverb(dry, ir, wet=.45)
    return finish(y, .85)


def pop_kernel(rng, f, bw, length):
    """one snap: a click rung through a resonance"""
    L = int(length * SR)
    imp = np.zeros(L)
    k = rng.integers(1, 4)
    imp[:k] = rng.standard_normal(k)
    b, a = signal.iirpeak(f, f / bw, fs=SR)
    y = signal.lfilter(b, a, imp)
    y *= np.exp(-np.arange(L) / (SR * length * .3))
    return y


def crackle(seed, sec=2.4, rate=70, bright=1.0):
    """glitter: discrete snaps in clusters, thickening then thinning out"""
    rng = np.random.default_rng(seed)
    t = t_axis(sec)
    n = len(t)
    out = np.zeros(n)
    shape = np.sin(np.pi * np.minimum(1, t / sec)) ** .7
    i = int(.02 * SR)
    while i < n - 2000:
        r = rate * shape[i] + 2
        gap = rng.exponential(1 / r)
        # clusters: now and then a quick run of snaps
        burst = 1 if rng.random() > .18 else rng.integers(3, 7)
        for b in range(burst):
            j = i + int(b * rng.uniform(.004, .012) * SR)
            if j >= n - 2000:
                break
            amp = rng.lognormal(-.35, .55)
            f = rng.uniform(1400, 3600) * bright
            k = pop_kernel(rng, f, rng.uniform(1.2, 2.2), rng.uniform(.006, .016))
            # a little low body under the bigger snaps
            if amp > 1.0:
                k2 = pop_kernel(rng, rng.uniform(500, 900), 1.5, .02)
                k = np.pad(k, (0, max(0, len(k2) - len(k))))
                k[:len(k2)] += k2 * .8
            out[j:j + len(k)] += k * amp
        i += int(gap * SR) + 1
    out = filt(out, "low", 6500 * bright, 2)
    ir = valley_ir(rng, sec=2.0, t60=1.4, echoes=((.29, .22), (.63, .12)), dark=1.2)
    y = reverb(out, ir, wet=.5)
    return finish(y, .8)


def sizzle(seed):
    """a willow's slow fall: a soft, dark fizz that breathes, with sparse
    snaps -- kept quiet and under ~2.5 kHz so it never reads as static"""
    rng = np.random.default_rng(seed)
    sec = 3.0
    t = t_axis(sec)
    n = len(t)
    fz = filt(rng.standard_normal(n), "band", (700, 2400), 2)
    flick = filt(rng.standard_normal(n), "low", 9, 2)
    flick = 1 + 1.4 * flick / (np.max(np.abs(flick)) + 1e-9)
    fz *= np.maximum(0, flick) * np.minimum(1, t / .3) * np.exp(-t / 1.3) * .35
    snaps = crackle(seed + 7, sec=sec, rate=16, bright=.75)
    snaps = snaps[:n] if len(snaps) >= n else np.pad(snaps, (0, n - len(snaps)))
    y = fz + snaps * .9
    ir = valley_ir(rng, sec=1.8, t60=1.3, echoes=((.3, .2),))
    y = reverb(y, ir, wet=.4)
    return finish(y, .7)


SET = {
    "fw-boom1": lambda: boom(37),
    "fw-boom2": lambda: boom(41),
    "fw-boom3": lambda: boom(43),
    "fw-far1": lambda: boom(53, far=True),
    "fw-far2": lambda: boom(59, far=True),
    "fw-launch1": lambda: launch(11),
    "fw-launch2": lambda: launch(23),
    "fw-crackle1": lambda: crackle(61),
    "fw-crackle2": lambda: crackle(67, rate=95),
    "fw-sizzle1": lambda: sizzle(71),
}

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    from scipy.io import wavfile
    for name, fn in SET.items():
        y = fn()
        wavfile.write(os.path.join(out, name + ".wav"), SR, (y * 32767).astype(np.int16))
        print(name, f"{len(y)/SR:.2f}s")
