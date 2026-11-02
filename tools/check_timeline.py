#!/usr/bin/env python3
"""Python mirror of AyatTiming/Timeline.swift, running the same cases as TimelineTests.swift."""


def last_index(xs, p):
    lo, hi = 0, len(xs)
    while lo < hi:
        m = (lo + hi) // 2
        if p(xs[m]):
            lo = m + 1
        else:
            hi = m
    return None if lo == 0 else lo - 1


def validate(ayat, dur=None, tol=40):
    if not ayat:
        return ("empty",)
    last_ayah_end = -10**18
    for a in ayat:
        if not (a["end"] > a["start"] and a["start"] + tol >= last_ayah_end):
            return ("badSpan", a["ayah"])
        if dur is not None and a["end"] > dur + tol:
            return ("beyondAudio", a["ayah"])
        last_end, last_pos = a["start"] - tol, 0
        for w in a["words"]:
            if not (w[0] > last_pos and w[2] >= w[1] and w[1] + tol >= last_end):
                return ("outOfOrder", a["ayah"], w[0])
            if not (w[1] + tol >= a["start"] and w[2] <= a["end"] + tol):
                return ("wordOutsideAyah", a["ayah"], w[0])
            last_end, last_pos = w[2], w[0]
        last_ayah_end = a["end"]
    return None


def active(ayat, ms):
    ai = last_index(ayat, lambda a: a["start"] <= ms)
    if ai is None:
        return None
    a = ayat[ai]
    if ms >= a["end"] and ai == len(ayat) - 1:
        return None
    wi = last_index(a["words"], lambda w: w[1] <= ms)
    return (a["ayah"], None if wi is None else a["words"][wi][0])


def shift(ayat, o):
    return [{"ayah": a["ayah"], "start": a["start"] + o, "end": a["end"] + o,
             "words": [(w[0], w[1] + o, w[2] + o) for w in a["words"]]} for a in ayat]


T = [{"ayah": 1, "start": 0, "end": 3000, "words": [(1, 200, 900), (2, 1000, 2800)]},
     {"ayah": 2, "start": 3000, "end": 6000, "words": [(1, 3100, 4000), (2, 4200, 5900)]}]
checks = [
    validate(T, 6000) is None,
    active(T, 100) == (1, None), active(T, 500) == (1, 1), active(T, 950) == (1, 1),
    active(T, 1500) == (1, 2), active(T, 3050) == (2, None), active(T, 5000) == (2, 2),
    active(T, 6000) is None, active(T, -1) is None,
    validate([{"ayah": 1, "start": 0, "end": 3000, "words": [(1, 1000, 1500), (2, 500, 900)]}]) == ("outOfOrder", 1, 2),
    validate(T, 5000) == ("beyondAudio", 2),
    shift(T, 1200)[0]["words"][0][1] == 1400, active(shift(T, 1200), 1700) == (1, 1),
]
print(f"{sum(checks)}/{len(checks)} timeline checks passed")
raise SystemExit(0 if all(checks) else 1)
