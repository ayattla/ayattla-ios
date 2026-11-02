#!/usr/bin/env python3
"""Compare the pack's Quran text with Tanzil's own download (txt-2: "sura|aya|text").

Tanzil's download writes a tatweel (U+0640) before some superscript alefs and prefixes ayah 1
with the opening line; AlQuran Cloud does not. Both are layout choices, so the comparison
ignores U+0640 and the opening line, and requires every other code point to be identical.
Exit 1 if any ayah differs. Usage: python3 compare_tanzil.py pack.sqlite tanzil.txt
"""
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
diff = sorted(k for k in pack if pack[k] != tz.get(k))
print(f"differ (ignoring tatweel): {len(diff)}")
for k in diff[:8]:
    a, b = pack[k], tz.get(k, "")
    i = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
    print(k, "at", i, [hex(ord(c)) for c in a[max(0, i - 2):i + 4]], [hex(ord(c)) for c in b[max(0, i - 2):i + 4]], len(a), len(b))
sys.exit(1 if diff or len(tz) != len(pack) else 0)
