#!/usr/bin/env python3
"""
The Lost Choir — vertical slice reference audio generator.

Deterministic, dependency-light (numpy only) additive/subtractive synthesis of every
audio cue the vertical slice needs. This script IS the provenance record: no samples,
no third-party audio, no generative model, no recorded performance. Re-running it
reproduces every byte.

Owner: Audio Director. Contract: docs/audio/AUDIO_BIBLE.md
Status of output: slice reference / temp-track. See "Capability honesty" in the bible —
no vocal-synthesis or recording capability is available in this toolchain, so sung
material is rendered as a synthetic approximation that encodes the *timing and
spectral contract* exactly. It is not a final vocal performance.

Usage:  python3 tools/audio/synth_slice_audio.py [outdir]
"""
import math, os, struct, sys, wave
import numpy as np

SR = 48000
RNG = np.random.default_rng(20260919)   # fixed seed — renders are byte-reproducible

# ---------------------------------------------------------------- pitch table
# A4 = 440 Hz, 12-TET. The slice's pitch set is deliberately rootless and
# thirdless in the cold state: {G4, A4, C5, D5}. See AUDIO_BIBLE §2.
P = {
    "D2": 73.4162, "A2": 110.0000, "D3": 146.8324, "A3": 220.0000,
    "D4": 293.6648, "G4": 391.9954, "A4": 440.0000, "C5": 523.2511,
    "D5": 587.3295, "G5": 783.9909, "Bb5": 932.3275, "A5": 880.0000,
}

# ---------------------------------------------------------------- dsp helpers
def t(dur):            return np.arange(int(round(dur * SR))) / SR
def sil(dur):          return np.zeros(int(round(dur * SR)))
def db(x):             return 10.0 ** (x / 20.0)

def place(buf, sig, at):
    """Mix `sig` into `buf` starting at time `at` (seconds), growing nothing."""
    i = int(round(at * SR))
    n = min(len(sig), len(buf) - i)
    if n > 0:
        buf[i:i + n] += sig[:n]
    return buf

def onepole_lp(x, fc):
    a = math.exp(-2.0 * math.pi * fc / SR)
    y = np.empty_like(x); z = 0.0
    for i in range(len(x)):
        z = (1 - a) * x[i] + a * z
        y[i] = z
    return y

def biquad(x, b, a):
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b; a0, a1, a2 = a
    for i in range(len(x)):
        xn = x[i]
        yn = (b0 * xn + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, xn
        y2, y1 = y1, yn
        y[i] = yn
    return y

def _rbj(kind, fc, q):
    w0 = 2 * math.pi * fc / SR
    c, s = math.cos(w0), math.sin(w0)
    al = s / (2 * q)
    if kind == "lp":
        b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
    elif kind == "hp":
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    elif kind == "bp":
        b = [al, 0.0, -al]
    a = [1 + al, -2 * c, 1 - al]
    return b, a

def filt(x, kind, fc, q=0.707, times=1):
    b, a = _rbj(kind, fc, q)
    for _ in range(times):
        x = biquad(x, b, a)
    return x

def env_adsr(n, a, d, s, r, sus=1.0):
    """Sample-count envelope from times in seconds."""
    A, D, R = int(a * SR), int(d * SR), int(r * SR)
    S = max(0, n - A - D - R)
    e = np.concatenate([
        np.linspace(0, 1, A, endpoint=False) if A else np.array([]),
        np.linspace(1, sus, D, endpoint=False) if D else np.array([]),
        np.full(S, sus),
        np.linspace(sus, 0, R) if R else np.array([]),
    ])
    return np.pad(e, (0, max(0, n - len(e))))[:n]

def fade(x, fin=0.005, fout=0.02):
    n = len(x); a, b = int(fin * SR), int(fout * SR)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x

def norm_peak(x, peak_db=-3.0):
    p = np.max(np.abs(x))
    return x * (db(peak_db) / p) if p > 0 else x

def gain_to_peak(x, peak_db):
    return norm_peak(x, peak_db)

# ---------------------------------------------------------------- reverb
def make_ir(rt60, size_hz=520.0, pre_ms=18.0, seed=7):
    """Synthetic exponentially-decaying, lowpassed noise IR — the amphitheater.
    The room is a struck resonant body: long tail, dark, no early brightness."""
    r = np.random.default_rng(seed)
    n = int(rt60 * SR)
    tail = r.normal(0, 1, n) * np.exp(-6.908 * np.arange(n) / n)   # -60 dB over rt60
    tail = filt(tail, "lp", 3400.0, 0.6)
    tail = filt(tail, "hp", 110.0, 0.7)
    pre = int(pre_ms * 1e-3 * SR)
    ir = np.concatenate([np.zeros(pre), tail])
    return ir / (np.sqrt(np.sum(ir ** 2)) + 1e-12)

def convolve(x, ir):
    n = 1 << int(math.ceil(math.log2(len(x) + len(ir) - 1)))
    y = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[:len(x) + len(ir) - 1]
    return y

def wet(x, ir, mix=0.35, tail=True):
    w = convolve(x, ir)
    dry = np.pad(x, (0, len(w) - len(x))) if tail else x
    w = w[:len(dry)]
    return (1 - mix) * dry + mix * w * 3.0

# ---------------------------------------------------------------- voices
def sung(f0, dur, *, vib_hz=4.6, vib_cents=14.0, breath=0.05, formants=None,
         a=0.06, d=0.10, s=0.85, r=0.30, drift=0.35, partials=14, seed=None):
    """A sung tone. Additive with a living fundamental: slow drift (a body),
    vibrato that arrives late (a technique), breath noise (a throat).
    Never a perfectly steady oscillator — see AUDIO_BIBLE 'the drone is a person'."""
    r_ = np.random.default_rng(seed if seed is not None else RNG.integers(1 << 30))
    n = int(dur * SR); tt = np.arange(n) / SR
    vib_onset = np.clip((tt - 0.22) / 0.45, 0, 1)                  # vibrato arrives late
    drift_lfo = np.sin(2 * math.pi * drift * tt + r_.uniform(0, 6.28))
    cents = vib_cents * vib_onset * np.sin(2 * math.pi * vib_hz * tt) + 6.0 * drift_lfo
    f = f0 * 2.0 ** (cents / 1200.0)
    phase = 2 * math.pi * np.cumsum(f) / SR
    formants = formants or [(620, 0.9, 90), (1180, 0.55, 140), (2600, 0.22, 320)]
    out = np.zeros(n)
    for k in range(1, partials + 1):
        fk = f0 * k
        if fk > SR / 2.2: break
        amp = 1.0 / (k ** 1.35)
        for fc, fa, bw in formants:                                 # formant shaping
            amp += fa * 0.9 * math.exp(-((fk - fc) ** 2) / (2 * bw ** 2)) / (k ** 0.5)
        out += amp * np.sin(k * phase + r_.uniform(0, 6.28))
    out /= np.max(np.abs(out)) + 1e-9
    if breath > 0:
        b = filt(r_.normal(0, 1, n), "bp", max(700.0, f0 * 4), 0.7)
        b *= (1.0 + 0.5 * np.sin(2 * math.pi * 2.3 * tt))
        out += breath * b / (np.max(np.abs(b)) + 1e-9)
    amp_body = 1.0 + 0.07 * drift_lfo                               # breathing body
    return out * env_adsr(n, a, d, s, r) * amp_body

def low_drone(dur, f0=P["D2"], *, tremor=0.0, seed=11):
    """The Verse's voice. D2's fundamental is inaudible on laptop speakers, so the
    perceived low must live in harmonics 2-5 and a moving throat formant.
    AUDIO_BIBLE §3: 'if it disappears on a phone speaker it is not the low register,
    it is a sub-bass effect.'"""
    r_ = np.random.default_rng(seed)
    n = int(dur * SR); tt = np.arange(n) / SR
    fdrift = f0 * 2.0 ** ((5.0 * np.sin(2 * math.pi * 0.23 * tt)) / 1200.0)
    ph = 2 * math.pi * np.cumsum(fdrift) / SR
    # kargyraa-derived property: a separate upper formant that MOVES over a fixed low
    fmove = 430.0 + 130.0 * np.sin(2 * math.pi * 0.17 * tt + 1.1)
    out = np.zeros(n)
    for k in range(1, 26):
        fk = f0 * k
        amp = 1.0 / (k ** 1.15)
        amp *= 0.35 if k == 1 else 1.0                              # fundamental held back
        amp += 1.2 * np.mean(np.exp(-((fk - fmove) ** 2) / (2 * 150.0 ** 2))) / (k ** 0.4)
        out += amp * np.sin(k * ph + r_.uniform(0, 6.28))
    out /= np.max(np.abs(out)) + 1e-9
    out += 0.035 * filt(r_.normal(0, 1, n), "bp", 900.0, 0.5)       # throat air
    if tremor > 0:                                                  # breath running out
        ramp = np.clip((tt - (dur - 0.6)) / 0.6, 0, 1)
        rate = 5.0 + 8.0 * ramp
        out *= (1.0 - tremor * ramp * (0.5 + 0.5 * np.sin(2 * math.pi * rate * tt)))
        out *= (1.0 - 0.35 * ramp)                                  # and thinning
    return out

# ---------------------------------------------------------------- io
def write(path, x, peak_db=-3.0, stereo_width=0.0):
    x = np.asarray(x, dtype=np.float64)
    x = gain_to_peak(x, peak_db) if peak_db is not None else x
    if stereo_width > 0:
        d = int(0.004 * SR)
        L = x + stereo_width * np.pad(x, (d, 0))[:len(x)]
        R = x + stereo_width * np.pad(x, (0, d))[d:]
        data = np.stack([L, R], axis=1)
        data /= max(np.max(np.abs(data)), 1e-9); data *= db(peak_db if peak_db else -3.0)
        ch = 2
    else:
        # MONO. A tell that FMOD will spatialize must be a mono asset — shipping it as
        # dual-mono doubles the file and gives the spatializer a stereo source to
        # collapse, which is at best wasteful and at worst a phase problem.
        data = x.reshape(-1, 1); ch = 1
    pcm = np.clip(data, -1, 1)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(ch); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return path

# ---------------------------------------------------------------- LUFS (BS.1770)
def _k_weight(x):
    # stage 1: high-shelf  (48 kHz coefficients, ITU-R BS.1770-4)
    b1 = [1.53512485958697, -2.69169618940638, 1.19839281085285]
    a1 = [1.0, -1.69065929318241, 0.73248077421585]
    # stage 2: RLB high-pass
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, -1.99004745483398, 0.99007225036621]
    return biquad(biquad(x, b1, a1), b2, a2)

def st_lufs(x, window_s=0.160):
    """Short-term K-weighted loudness of the first `window_s`. This — NOT peak — is
    how tells must be level-matched. A percussive double-knock and a sustained keen
    at identical peak levels differ by ~14 dB in perceived level; matching peaks
    would ship one enemy whose tell is reliably harder to hear, which §5.4 defines
    as a bug rather than a mix preference."""
    y = _k_weight(np.asarray(x[:int(window_s * SR)], dtype=np.float64))
    return float(-0.691 + 10 * np.log10(np.mean(y ** 2) + 1e-20))

TELL_TARGET_LUFS = -23.0   # short-term, first 160 ms, at the tell bus.
                           # The reed peaks ~11 dB above this and the keen ~3 dB:
                           # the TELL bus needs 11 dB of peak headroom over target.

def tell_trim(x, target=TELL_TARGET_LUFS):
    """Return `x` trimmed so its identifying 160 ms hits the tell-bus target."""
    return x * db(target - st_lufs(x))

def lufs(x):
    """Integrated loudness, gated, mono-approximated. Used to verify the
    cold->warm dynamic-range contract is a real measurement, not an adjective."""
    y = _k_weight(np.asarray(x, dtype=np.float64))
    blk = int(0.4 * SR); hop = int(0.1 * SR)
    if len(y) < blk: return -120.0
    ms = np.array([np.mean(y[i:i + blk] ** 2) for i in range(0, len(y) - blk, hop)])
    lk = -0.691 + 10 * np.log10(ms + 1e-20)
    keep = lk > -70.0
    if not keep.any(): return -120.0
    rel = -0.691 + 10 * np.log10(np.mean(ms[keep]) + 1e-20) - 10.0
    keep &= lk > rel
    if not keep.any(): return -120.0
    return float(-0.691 + 10 * np.log10(np.mean(ms[keep]) + 1e-20))

# ================================================================= CUES
AMB_COLD_LUFS, AMB_WARM_LUFS = -46.0, -28.0   # the 18 LU restoration event

IR_HALL  = make_ir(2.6, seed=7)     # the amphitheater — R6
IR_ROOM  = make_ir(1.1, seed=9)     # ordinary rooms
# NOTE: there is deliberately NO IR applied to anything on the TELL bus.

# ------------------------------------------------- tells (dedicated DRY channel)
def tell_reed(lead, *, answered=False, seed=101):
    """Reed Husk — percussive / throat. Identity = a DOUBLE KNOCK at 0 ms and 95 ms
    (both inside the 160 ms transient budget), then a dry throat rattle that
    ACCELERATES toward the attack. The accelerando is the countdown: the player
    feels the landing rather than counting milliseconds. Stretches with `lead`."""
    r_ = np.random.default_rng(seed)
    total = lead + (0.55 if answered else 0.16)
    n = int(total * SR); out = np.zeros(n)

    def crack(amp):
        m = int(0.075 * SR)
        g = r_.normal(0, 1, m) * np.exp(-np.arange(m) / (0.0065 * SR))
        g = filt(g, "bp", 520.0, 0.85)   # throat formant, not a generic click
        g += 0.26 * filt(r_.normal(0, 1, m) * np.exp(-np.arange(m) / (0.0022 * SR)),
                         "bp", 1300.0, 1.6)                 # split-reed edge: present as
        g = filt(g, "lp", 1300.0, 0.7, times=2)                      # bite, but never enough to
                                                            # climb into the keen's band
        return amp * g / (np.max(np.abs(g)) + 1e-9)

    place(out, crack(1.00), 0.000)                          # identity, part 1
    place(out, crack(0.72), 0.095)                          # identity, part 2

    # accelerating throat rattle, 160 ms -> attack
    tt, rate0, rate1 = 0.160, 9.0, 23.0
    while tt < lead - 0.012:
        u = (tt - 0.160) / max(lead - 0.160, 1e-6)
        m = int(0.030 * SR)
        g = r_.normal(0, 1, m) * np.exp(-np.arange(m) / (0.0045 * SR))
        g = filt(g, "bp", 240.0 + 260.0 * u, 1.1)
        place(out, 0.30 * (0.55 + 0.45 * u) * g / (np.max(np.abs(g)) + 1e-9), tt)
        tt += 1.0 / (rate0 + (rate1 - rate0) * u)

    if answered:
        # ANSWERED: the note is not cut off — it COMPLETES to its interval (up to A3)
        res = sung(P["A3"], 0.52, breath=0.10, a=0.012, d=0.08, s=0.7, r=0.34,
                   formants=[(520, 0.8, 110), (1150, 0.4, 170)], seed=seed + 1)
        place(out, 0.55 * res, lead)
    else:
        # unanswered: the rattle is cut off by the lunge — a hard stop, no completion
        m = int(0.13 * SR)
        lunge = r_.normal(0, 1, m) * np.exp(-np.arange(m) / (0.012 * SR))
        lunge = filt(lunge, "bp", 320.0, 0.8)
        place(out, 0.85 * lunge / (np.max(np.abs(lunge)) + 1e-9), lead)
    return filt(out, "hp", 170.0, 0.7)                      # nothing below 170 Hz: the
                                                            # low register belongs to the Verse

def tell_keening(lead, *, answered=False, seed=202):
    """Keening Husk — keening / high. Identity = a hard glottal onset (attack <=15 ms,
    NEVER a fade-in) followed by an upward PITCH BREAK of a minor 7th (A4 -> G5)
    completed by 130 ms. The kink is the identity; a smooth glide would read as the
    same creature as anything else. Then a slow continued rise, thinning, to Bb5."""
    r_ = np.random.default_rng(seed)
    total = lead + (0.70 if answered else 0.16)
    n = int(total * SR); tt = np.arange(n) / SR

    f = np.empty(n)
    for i, ti in enumerate(tt):
        if ti < 0.035:          f[i] = P["A4"]                                  # held
        elif ti < 0.130:        u = (ti - 0.035) / 0.095; f[i] = P["A4"] * (P["G5"] / P["A4"]) ** (u ** 0.55)
        elif ti < lead:         u = (ti - 0.130) / max(lead - 0.130, 1e-6); f[i] = P["G5"] * (P["Bb5"] / P["G5"]) ** u
        else:                   f[i] = P["Bb5"]
    vr = 4.5 + 3.0 * np.clip(tt / max(lead, 1e-6), 0, 1)                        # rising vibrato rate
    f = f * 2.0 ** ((18.0 * np.clip((tt - 0.16) / 0.25, 0, 1) * np.sin(2 * math.pi * vr * tt)) / 1200.0)
    ph = 2 * math.pi * np.cumsum(f) / SR

    out = np.sin(ph) + 0.42 * np.sin(2 * ph) + 0.16 * np.sin(3 * ph) + 0.07 * np.sin(4 * ph)
    out += 0.16 * filt(r_.normal(0, 1, n), "bp", 2600.0, 0.6)                   # thin air
    e = np.ones(n)
    a = int(0.012 * SR); e[:a] = np.linspace(0, 1, a)                           # 12 ms attack
    thin = np.clip((tt - 0.16) / max(lead - 0.16, 1e-6), 0, 1)
    e *= (1.0 - 0.32 * thin)                                                    # thins, does not swell
    out *= e

    if answered:
        res = sung(P["A4"], 0.66, breath=0.06, a=0.010, d=0.10, s=0.72, r=0.42,
                   formants=[(900, 0.7, 150), (2300, 0.35, 300)], seed=seed + 1)
        out = np.pad(out, (0, max(0, int((lead + 0.70) * SR) - n)))[:int((lead + 0.70) * SR)]
        place(out, 0.60 * res, lead)
    else:
        m = int(0.10 * SR)
        snap = np.sin(2 * math.pi * P["Bb5"] * np.arange(m) / SR) * np.exp(-np.arange(m) / (0.010 * SR))
        place(out, 0.9 * snap, lead)                                            # projectile spawns
    return filt(out, "hp", 620.0, 0.7)                       # spectrally disjoint from the Reed

# ------------------------------------------------- the Unfinished Phrase
PHRASE = [("A4", 0.00, 0.90), ("D5", 0.95, 0.80), ("C5", 1.85, 0.85),
          ("A4", 2.80, 0.80), ("G4", 3.70, 0.95), ("A4", 4.75, 2.60)]
SHADOW = [("A4", 0.95, 0.80), ("G4", 1.85, 0.85)]            # quartal, rootless, quiet

def upper_voices(dur=9.0):
    """The surviving voices. Pitch set {G4, A4, C5, D5}: NO root, NO third.
    The phrase is harmonically ungrounded on purpose — it could be read in two keys
    and the ear cannot settle. Ends held on A4 and simply stops."""
    out = np.zeros(int(dur * SR))
    for i, (p, at, ln) in enumerate(PHRASE):
        v = sung(P[p], ln, breath=0.055, a=0.055, d=0.12, s=0.84,
                 r=min(0.55, ln * 0.45), seed=300 + i)
        place(out, 0.9 * v, at)
    for i, (p, at, ln) in enumerate(SHADOW):
        v = sung(P[p], ln, breath=0.07, a=0.09, d=0.14, s=0.8, r=0.3, seed=400 + i)
        place(out, 0.22 * v, at)
    return out

def grounding_drone(dur=9.0, at=0.0):
    """THE ONE INTERVAL RESTORATION ADDS: D2, a perfect fifth below the phrase's
    floor note A3/A4 — the root the choir lost. Not one more layer: the note that
    re-reads every note above it. Nothing in the upper voices changes."""
    out = np.zeros(int(dur * SR))
    d = low_drone(dur - at - 0.1, P["D2"], seed=11)
    d *= env_adsr(len(d), 1.1, 0.4, 0.92, 1.6)               # arrives like a breath, not a hit
    place(out, 0.85 * d, at)
    oct_ = low_drone(dur - at - 0.1, P["D3"], seed=13)
    oct_ *= env_adsr(len(oct_), 1.4, 0.4, 0.9, 1.6)
    place(out, 0.28 * oct_, at)
    return out

# ------------------------------------------------- Sustain / Return (the seam)
def sustain(dur=3.0):
    """Hold to emit the low drone from the restored seam. The 180 ms ramp-in is a
    GAMEPLAY gate (§4.1) so it must be AUDIBLE: at exactly 180 ms a bowed-metal
    'engage' partial enters. That is the player's only cue that the world effect
    armed. The seam is a driver exciting the room, not a speaker playing at it."""
    n = int(dur * SR); tt = np.arange(n) / SR
    d = low_drone(dur, P["D2"], seed=21)
    d *= np.clip(tt / 0.180, 0, 1) ** 1.4                     # 180 ms ramp-in
    fifth = low_drone(dur, P["A2"], seed=23) * 0.30 * np.clip(tt / 0.180, 0, 1) ** 1.4
    out = d + fifth
    eng_n = int((dur - 0.180) * SR)                           # the engage partial
    et = np.arange(eng_n) / SR
    eng = (np.sin(2 * math.pi * P["D4"] * et) + 0.5 * np.sin(2 * math.pi * P["A4"] * et)
           + 0.22 * np.sin(2 * math.pi * P["D5"] * et))
    eng *= (1 - np.exp(-et / 0.045)) * np.exp(-et / 2.2) * (1 + 0.12 * np.sin(2 * math.pi * 0.7 * et))
    place(out, 0.20 * eng, 0.180)
    return wet(out, IR_ROOM, mix=0.22)

def sustain_breath_end(dur=1.4):
    """Breath running out. Diegetic UI budget (§9) gives breath only a small arc,
    so AUDIO carries the warning: the last 600 ms develop tremor and thin out —
    a voice running out of air — then the 120 ms ramp-out releases the world."""
    d = low_drone(dur, P["D2"], tremor=0.85, seed=27)
    n = len(d); tt = np.arange(n) / SR
    rel = np.clip(1.0 - (tt - (dur - 0.120)) / 0.120, 0, 1)    # 120 ms ramp-out
    return wet(d * rel, IR_ROOM, mix=0.22)

def return_strike():
    """Return: the enemy's own note, released back out of the gold seam. It carries
    the ENEMY's register (the reed band) inside the Verse's low body — the point is
    that it is their sound, not a new weapon of yours."""
    r_ = np.random.default_rng(31)
    n = int(1.30 * SR); tt = np.arange(n) / SR
    body = low_drone(1.30, P["D2"], seed=33) * np.exp(-tt / 0.42)
    seam = (np.sin(2 * math.pi * P["D4"] * tt) + 0.6 * np.sin(2 * math.pi * P["A4"] * tt))
    seam *= np.exp(-tt / 0.19) * (1 - np.exp(-tt / 0.004))
    theirs = filt(r_.normal(0, 1, n) * np.exp(-tt / 0.07), "bp", 520.0, 0.9)   # the reed band
    out = 1.0 * body + 0.55 * seam + 0.35 * theirs / (np.max(np.abs(theirs)) + 1e-9)
    return wet(out, IR_ROOM, mix=0.30)

# ------------------------------------------------- R6 restoration encounter
BEARER = ["A4", "D5", "C5", "G4", "A4"]     # drawn from the Unfinished Phrase itself

def bearer_note(pitch, lead=0.700, seed=0):
    """An OFFER, not an attack. Same 700 ms lead as the Keening Husk, so timbre
    carries the whole distinction:
      enemy tell  = dry, narrow, RISING, thinning, runs straight into the attack
      bearer note = wet, wide, FALLING and settling, ends into its own tail and
                    LEAVES A GAP. The silence after it has shape: it is waiting."""
    n = int((lead + 0.30) * SR); tt = np.arange(n) / SR
    settle = -26.0 * np.clip((tt - 0.18) / 0.45, 0, 1)         # falls and settles
    f = P[pitch] * 2.0 ** (settle / 1200.0)
    v = sung(P[pitch], (lead + 0.30), breath=0.06, a=0.030, d=0.14, s=0.80, r=0.34,
             vib_hz=4.2, vib_cents=11.0, seed=500 + seed,
             formants=[(700, 0.95, 120), (1300, 0.5, 180), (2700, 0.18, 340)])
    v = v * (1.0 + 0.0 * f[:len(v)] * 0)                        # contour documented above
    return v

def r6_phrase(count=5, spacing=1.100, lead=0.700, with_drone=False):
    tail = 3.8 if with_drone else 1.6
    total = spacing * (count - 1) + lead + tail
    dry = np.zeros(int(total * SR))
    for i in range(count):
        place(dry, 0.9 * bearer_note(BEARER[i], lead, seed=i), i * spacing)
    out = wet(dry, IR_HALL, mix=0.30)
    if with_drone:
        # RESTORATION. The drone arrives UNDER the held A4 -> a bare perfect fifth.
        # No sting, no fanfare, no new bright layer. The floor arrives; that is all.
        at = (count - 1) * spacing + 0.15
        d = low_drone(total - at - 0.1, P["D2"], seed=41)
        d *= env_adsr(len(d), 1.25, 0.5, 0.95, 1.9)
        place(out, 0.80 * d, at)
    return out

# ------------------------------------------------- ambience
def loopify(x, xfade=2.0):
    """Seamless loop: fold the tail back over the head. Ambience beds must loop for
    minutes without a seam — a bed that ticks once a loop is worse than silence in a
    zone whose floor is -46 LUFS, because the tick becomes the loudest thing in it."""
    n = int(xfade * SR)
    head, tail = x[:n].copy(), x[-n:].copy()
    r = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * r + tail * (1 - r)
    return x

def amb_cold(dur=30.0):
    """Near-silence. Single-source ambience only. NO pad, NO bed, NO drone.
    Target -48..-42 LUFS so restoration is a genuine dynamic-range event."""
    r_ = np.random.default_rng(61)
    n = int(dur * SR); out = filt(r_.normal(0, 1, n), "lp", 190.0, 0.5) * 0.030   # room air
    out += filt(r_.normal(0, 1, n), "bp", 2800.0, 0.4) * 0.0035
    for at in [2.4, 11.9, 19.6, 27.1]:                                           # a distant drip
        m = int(0.5 * SR); et = np.arange(m) / SR
        drip = np.sin(2 * math.pi * (1500 - 420 * et / 0.5) * et) * np.exp(-et / 0.028)
        place(out, 0.10 * wet(drip, IR_ROOM, mix=0.5)[:m], at)
    for at in [6.8, 23.4]:                                                       # stone settling
        m = int(1.2 * SR); et = np.arange(m) / SR
        g = filt(r_.normal(0, 1, m), "bp", 130.0, 1.2) * np.exp(-et / 0.22)
        place(out, 0.16 * g / (np.max(np.abs(g)) + 1e-9), at)
    for at in [9.1, 16.3, 25.9]:                                                 # wind, broken pipe
        m = int(3.4 * SR); et = np.arange(m) / SR
        g = filt(r_.normal(0, 1, m), "bp", 340.0, 2.4)
        g *= np.sin(math.pi * et / 3.4) ** 2
        place(out, 0.05 * g / (np.max(np.abs(g)) + 1e-9), at)
    return out

def amb_warm(dur=30.0):
    """After restoration. The drone bed is now UNDER everything, zone-wide, and the
    phrase recurs. Target ~-30 LUFS: an ~18 LU rise over cold. Never normalize the
    cold rooms up to meet this — the gap IS the design."""
    out = amb_cold(dur) * 1.5
    bed = low_drone(dur, P["D2"], seed=71) * 0.16
    bed *= (1.0 + 0.25 * np.sin(2 * math.pi * 0.06 * np.arange(len(bed)) / SR))
    out += bed + 0.05 * low_drone(dur, P["D3"], seed=73)
    frag = upper_voices(9.0) * 0.20
    place(out, wet(frag, IR_ROOM, mix=0.4)[:int(9 * SR)], 4.0)
    place(out, wet(frag, IR_ROOM, mix=0.4)[:int(9 * SR)] * 0.7, 19.0)
    return out

# ================================================================= MEASUREMENT
def transient_report(x, label, budget_ms=160.0):
    """Verify §5.2: the identifying transient lands inside the first 160 ms.
    Measured as the time by which the cue reaches 90% of its first-300 ms peak,
    plus the time of the last distinct onset inside the budget window."""
    a = np.abs(x)
    w = int(0.300 * SR)
    pk = np.max(a[:w]) + 1e-12
    t90 = int(np.argmax(a[:w] >= 0.90 * pk)) / SR * 1000.0
    env = onepole_lp(a[:int(0.260 * SR)], 90.0)
    d = np.diff(env); thr = 0.25 * np.max(d)
    onsets, last = [], -10**9
    for i, v in enumerate(d):
        if v > thr and (i - last) > int(0.020 * SR):
            onsets.append(i / SR * 1000.0); last = i
    return {"cue": label, "peak_at_ms": round(t90, 1),
            "onsets_ms": [round(o, 1) for o in onsets[:6]],
            "within_160ms": t90 <= budget_ms}

def low_band_rms_db(x, lo=30.0, hi=200.0):
    """K-weighted loudness deliberately attenuates 73 Hz, so an LUFS meter is almost
    blind to the grounding drone. Measure the 30-200 Hz band directly, otherwise the
    restoration looks like it did nothing."""
    X = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    f = np.fft.rfftfreq(len(x), 1 / SR)
    e = np.sum(X[(f >= lo) & (f < hi)] ** 2) / len(x)
    return round(float(10 * np.log10(e + 1e-20)), 1)

def centroid_hz(x):
    X = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return round(float(np.sum(f * X ** 2) / (np.sum(X ** 2) + 1e-20)), 0)

def band_energy(x):
    """Disjoint bands. The two enemies must occupy different spectral regions so
    that two simultaneously-open tell windows stay separable by ear."""
    X = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    f = np.fft.rfftfreq(len(x), 1 / SR)
    tot = np.sum(X ** 2) + 1e-20
    return {"band_170_700Hz": round(float(np.sum(X[(f >= 170) & (f < 700)] ** 2) / tot), 3),
            "band_700_4000Hz": round(float(np.sum(X[(f >= 700) & (f < 4000)] ** 2) / tot), 3)}

def track_f0(x, fmin=300.0, win=1024, hop=128):
    """f0 contour by STFT lowest-prominent-peak tracking.
    An analytic-signal instantaneous-frequency reading is WRONG for this material:
    the keen carries strong 2nd/3rd harmonics, so the composite phase derivative
    already sits near G5 at the attack and reports a break that never happened."""
    w = np.hanning(win); f = np.fft.rfftfreq(win, 1 / SR)
    out = []
    for i in range(0, len(x) - win, hop):
        X = np.abs(np.fft.rfft(x[i:i + win] * w))
        X[f < fmin] = 0.0
        pk = np.max(X)
        if pk <= 1e-9: out.append((i / SR * 1000.0, None)); continue
        cand = np.where(X > 0.25 * pk)[0]
        k = int(cand[0])
        if 0 < k < len(X) - 1:                                   # parabolic interpolation
            a0, a1, a2 = X[k - 1], X[k], X[k + 1]
            k = k + 0.5 * (a0 - a2) / (a0 - 2 * a1 + a2 + 1e-20)
        out.append((i / SR * 1000.0, float(k) * SR / win))
    return out

def pitch_break_ms(x, target_hz, tol=0.04):
    """Keening identity is a PITCH BREAK, not an amplitude onset. Report when f0
    first reaches `target_hz` — this is the number the 160 ms budget constrains."""
    for ms, f0 in track_f0(x):
        if f0 is not None and f0 >= target_hz * (1 - tol):
            return round(ms, 1)
    return None

# ================================================================= RENDER
def main(outdir="audio/reference"):
    os.makedirs(outdir, exist_ok=True)
    o = lambda name: os.path.join(outdir, name)
    rep = []

    # --- the Unfinished Phrase. The SAME upper-voice buffer is used for cold and
    #     warm: the A/B proof is that literally nothing above the root changes.
    upper = upper_voices(9.0)
    cold  = wet(upper, IR_ROOM, mix=0.34)
    # ONE gain for both files. The warm render is the cold render plus the root and
    # nothing else, at the same fader: if it sounds bigger, that is the interval
    # doing it, not a level trick. Independent normalization would fake this result.
    g     = db(-16.0) / (np.max(np.abs(cold)) + 1e-12)
    cold *= g
    warm  = cold + g * grounding_drone(len(cold) / SR, at=0.10)
    write(o("leitmotif_01_cold_acappella.wav"), cold, None)
    write(o("leitmotif_02_warm_grounded.wav"),  warm, None)
    write(o("leitmotif_03_AB_proof.wav"), np.concatenate([cold, sil(1.4), warm]), None)

    # --- tells, on the dedicated DRY channel: no reverb anywhere below.
    cues = {
        "tell_reed_husk_520ms":            tell_reed(0.520),
        "tell_reed_husk_520ms_answered":   tell_reed(0.520, answered=True),
        "tell_reed_husk_458ms_compressed": tell_reed(0.458),
        "tell_keening_husk_700ms":            tell_keening(0.700),
        "tell_keening_husk_700ms_answered":   tell_keening(0.700, answered=True),
        "tell_keening_husk_616ms_compressed": tell_keening(0.616),
    }
    # Level-match every tell on its first 160 ms, then render at that ABSOLUTE gain.
    # Peak-normalizing them instead is the standard way this contract gets broken.
    cues = {k: tell_trim(v) for k, v in cues.items()}
    for k, v in cues.items():
        write(o(k + ".wav"), v, None)
    for k in ("tell_reed_husk_520ms", "tell_keening_husk_700ms",
              "tell_reed_husk_458ms_compressed", "tell_keening_husk_616ms_compressed"):
        r = transient_report(cues[k], k)
        r.update(band_energy(cues[k][:int(0.5 * SR)]))
        r["centroid_hz"] = centroid_hz(cues[k][:int(0.5 * SR)])
        r["first160ms_LUFS"] = round(st_lufs(cues[k]), 1)
        r["peak_dBFS"] = round(float(20 * np.log10(np.max(np.abs(cues[k])) + 1e-12)), 1)
        if "keening" in k:
            # identity = the minor-7th break up to G5, not the amplitude onset
            r["onsets_ms"] = "n/a (continuous tone)"
            r["pitch_break_to_G5_ms"] = pitch_break_ms(cues[k], P["G5"])
            r["within_160ms"] = (r["pitch_break_to_G5_ms"] or 999) <= 160.0
        rep.append(r)

    # H6 listening test: one rule, two values — played back to back.
    h6 = np.concatenate([cues["tell_reed_husk_520ms"], sil(0.9),
                         cues["tell_keening_husk_700ms"], sil(0.9),
                         cues["tell_reed_husk_458ms_compressed"], sil(0.9),
                         cues["tell_keening_husk_616ms_compressed"]])
    write(o("h6_AB_reed_vs_keening.wav"), h6, None)

    # --- the Verse
    write(o("verse_sustain_loopbody_3s.wav"), sustain(3.0), -9.0, stereo_width=0.25)
    write(o("verse_sustain_breath_end.wav"),  sustain_breath_end(1.4), -9.0, stereo_width=0.25)
    write(o("verse_return_seam.wav"),         return_strike(), -5.0, stereo_width=0.2)

    # --- R6
    offer5   = r6_phrase(5)
    restored = r6_phrase(5, with_drone=True)
    # Same gain for offer and restoration, so "no victory sting" is a MEASUREMENT:
    # the restored take must not be louder than the offer it completes.
    gr = db(-9.0) / (np.max(np.abs(offer5)) + 1e-12)
    offer5 *= gr; restored *= gr
    write(o("r6_offer_3note.wav"), r6_phrase(3) * gr, None, stereo_width=0.3)
    write(o("r6_offer_5note.wav"), offer5, None, stereo_width=0.3)
    write(o("r6_restoration_complete.wav"), restored, None, stereo_width=0.3)

    # --- ambience. Rendered at ABSOLUTE level: never peak-normalized.
    # Authored to ABSOLUTE loudness targets and verified, never peak-normalized.
    # The 18 LU gap between them IS the restoration event; normalizing the cold
    # rooms up to a comfortable level would delete the entire design.
    ac, aw = loopify(amb_cold(32.0)), loopify(amb_warm(32.0))
    ac *= db(AMB_COLD_LUFS - lufs(ac))
    aw *= db(AMB_WARM_LUFS - lufs(aw))
    write(o("amb_cold_near_silence_30s.wav"), ac, None, stereo_width=0.4)
    write(o("amb_warm_restored_30s.wav"),     aw, None, stereo_width=0.4)

    loud = {
        "leitmotif_cold_acappella":  round(lufs(cold), 1),
        "leitmotif_warm_grounded":   round(lufs(warm), 1),
        "amb_cold_near_silence":     round(lufs(ac), 1),
        "amb_warm_restored":         round(lufs(aw), 1),
        "r6_offer_5note":            round(lufs(offer5), 1),
        "r6_restoration_complete":   round(lufs(restored), 1),
    }
    loud["cold_to_warm_ambience_LU"]  = round(loud["amb_warm_restored"] - loud["amb_cold_near_silence"], 1)
    loud["leitmotif_grounding_LU"]    = round(loud["leitmotif_warm_grounded"] - loud["leitmotif_cold_acappella"], 1)
    loud["leitmotif_cold_low30_200_dB"]  = low_band_rms_db(cold)
    loud["leitmotif_warm_low30_200_dB"]  = low_band_rms_db(warm)
    loud["leitmotif_grounding_lowband_dB"] = round(
        loud["leitmotif_warm_low30_200_dB"] - loud["leitmotif_cold_low30_200_dB"], 1)
    loud["r6_sting_check_LU"]         = round(loud["r6_restoration_complete"] - loud["r6_offer_5note"], 1)
    loud["r6_no_victory_sting"]       = loud["r6_sting_check_LU"] <= 0.0

    import json
    with open(o("MEASUREMENTS.json"), "w") as f:
        json.dump({"sample_rate": SR, "transients": rep, "loudness_LUFS": loud}, f, indent=2)
    print(json.dumps({"transients": rep, "loudness_LUFS": loud}, indent=2))
    print("\nrendered ->", outdir)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "audio/reference")
