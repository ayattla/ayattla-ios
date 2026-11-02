#!/usr/bin/env python3
"""Compare the pack's Quran text with Tanzil's own download (txt-2: "sura|aya|text").

Tanzil's download writes a tatweel (U+0640) before some superscript alefs and prefixes ayah 1
with the opening line; AlQuran Cloud does not. The two copies also come from different Tanzil
releases with small differences in marks. The check requires identical letters and words in
every ayah, and reports mark-level differences for information.
Exit 1 if any ayah differs. Usage: python3 compare_tanzil.py pack.sqlite tanzil.txt
"""
import re
import sqlite3
import sys

TATWEEL = "ـ"


def norm(t):
    return t.replace(TATWEEL, "").replace("﻿", "")


db = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
pack = {(s, a): norm(t) for s, a, t in db.execute("SELECT surah, ayah, text_uthmani FROM ayah")}
tz = {}
for line in open(sys.argv[2], encoding="utf-8-sig"):
    parts = line.rstrip("\n").split("|")
    if len(parts) == 3 and parts[0].isdigit():
        tz[(int(parts[0]), int(parts[1]))] = norm(parts[2])
basmala = norm(db.execute("SELECT value FROM meta WHERE key='basmala'").fetchone()[0])
with_b = {sid for (sid,) in db.execute("SELECT id FROM surah WHERE basmala = 1")}
variants = (basmala + " ", basmala[0] + "ّ" + basmala[1:] + " ")
stripped = 0
for sid in with_b:
    t = tz.get((sid, 1), "")
    for v in variants:
        if t.startswith(v):
            tz[(sid, 1)] = t[len(v):]
            stripped += 1
            break
print(f"pack {len(pack)} ayat, tanzil {len(tz)} ayat, opening line removed from {stripped} tanzil ayat")
# Tanzil's current download and the AlQuran Cloud copy use different Tanzil releases: the newer
# one drops some small marks (e.g. U+06ED) and writes some hamzas as U+0654 instead of U+0621.
# The hard check is on the letters: every ayah must have the same letters and words in order.
MARKS = re.compile("[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]")


def letters(t):
    return " ".join(MARKS.sub("", t.replace("\u0654", "\u0621")).split())


# Spelling differences between the two Tanzil releases, seen on 2026-11-02. The owner decided
# (2026-11-03) to keep the site's text (AlQuran Cloud), so these stay as the site has them: "بعد ما" as one word or two (2:181, 8:6, 13:37) and the alef in
# "يا صاحبي" (12:39, 12:41). Any other difference fails the build.
KNOWN = {(2, 181), (8, 6), (13, 37), (12, 39), (12, 41)}

marks_only = sum(1 for k in pack if pack[k] != tz.get(k))
diff = sorted(k for k in pack if letters(pack[k]) != letters(tz.get(k, "")))
print(f"ayat with mark-level differences only (informational): {marks_only - len(diff)}")
print(f"ayat whose letters differ: {len(diff)}")
for k in diff[:8]:
    a, b = letters(pack[k]), letters(tz.get(k, ""))
    i = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
    print(k, "at", i, [hex(ord(c)) for c in a[max(0, i - 2):i + 4]], [hex(ord(c)) for c in b[max(0, i - 2):i + 4]], len(a), len(b))
unknown = [k for k in diff if k not in KNOWN]
print(f"known spelling differences: {sorted(set(diff) & KNOWN)}; unexpected: {unknown}")
sys.exit(1 if unknown or len(tz) != len(pack) else 0)
