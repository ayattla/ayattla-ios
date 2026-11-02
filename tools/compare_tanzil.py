#!/usr/bin/env python3
"""Compare the pack's Quran text with Tanzil's own download (txt-2: "sura|aya|text").
Prints the number of differing ayat and a few examples; exit 1 if any differ.
Usage: python3 compare_tanzil.py pack.sqlite tanzil.txt
"""
import sqlite3
import sys
import unicodedata

db = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
pack = {(s, a): t for s, a, t in db.execute("SELECT surah, ayah, text_uthmani FROM ayah")}
tz = {}
for line in open(sys.argv[2], encoding="utf-8-sig"):
    parts = line.rstrip("\n").split("|")
    if len(parts) == 3 and parts[0].isdigit():
        tz[(int(parts[0]), int(parts[1]))] = parts[2]
basmala = db.execute("SELECT value FROM meta WHERE key='basmala'").fetchone()[0]
with_b = {sid for (sid,) in db.execute("SELECT id FROM surah WHERE basmala = 1")}
variants = (basmala + " ", basmala[0] + "\u0651" + basmala[1:] + " ")
for sid in with_b:   # Tanzil's download also prefixes ayah 1 with the opening line; compare without it
    t = tz.get((sid, 1), "")
    for v in variants:
        if t.startswith(v):
            tz[(sid, 1)] = t[len(v):]
            break
print(f"pack {len(pack)} ayat, tanzil {len(tz)} ayat")
diff = [k for k in pack if pack[k] != tz.get(k)]
nfc = [k for k in diff if unicodedata.normalize("NFC", pack[k]) != unicodedata.normalize("NFC", tz.get(k, ""))]
print(f"differ: {len(diff)} (after NFC: {len(nfc)})")
for k in nfc[:5]:
    a, b = pack[k], tz.get(k, "")
    i = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
    print(k, "first diff at", i, [hex(ord(c)) for c in a[i:i + 4]], [hex(ord(c)) for c in b[i:i + 4]], len(a), len(b))
sys.exit(1 if nfc or len(tz) != len(pack) else 0)
