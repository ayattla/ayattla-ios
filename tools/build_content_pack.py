#!/usr/bin/env python3
"""Build the offline content pack (content-vN.sqlite) for the Ayat Tutla iOS app.

Religious text is copied byte for byte from approved sources. Nothing here
writes, completes or edits Quran, tafsir or dhikr text.

Inputs (all local files, fetched beforehand on a machine that can reach the sources):
  --quran      AlQuran Cloud full edition JSON, e.g. /v1/quran/quran-uthmani
  --edition    extra AlQuran Cloud edition JSON (tafsir/translation), repeatable,
               given as  key=path  (key becomes translation.edition)
  --azkar      normalized azkar JSON:
               {"source": "...", "categories": [{"id": 1, "title": "...",
                 "items": [{"id": 1, "text": "...", "count": 1,
                            "reference": "...", "note": "", "audio_id": null}]}]}

Usage:
  python3 build_content_pack.py --version 1 --quran quran-uthmani.json \
      --edition muyassar=ar.muyassar.json --azkar azkar.json --out content-v1.sqlite
"""
import argparse
import hashlib
import json
import re
import sqlite3
import sys
from datetime import datetime, timezone

EXPECTED_SURAHS = 114
EXPECTED_AYAT = 6236
TASHKEEL = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")
ALEF = re.compile("[آأإٱ]")

SCHEMA = """
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE surah(id INTEGER PRIMARY KEY, name_ar TEXT NOT NULL, name_en TEXT,
  ayah_count INTEGER NOT NULL, revelation TEXT, page_start INTEGER);
CREATE TABLE ayah(surah INTEGER NOT NULL, ayah INTEGER NOT NULL, text_uthmani TEXT NOT NULL,
  text_clean TEXT NOT NULL, page INTEGER, juz INTEGER, hizb_quarter INTEGER,
  PRIMARY KEY(surah, ayah));
CREATE VIRTUAL TABLE ayah_fts USING fts5(text_clean, content='ayah', content_rowid='rowid');
CREATE TABLE translation(edition TEXT NOT NULL, surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
  text TEXT NOT NULL, PRIMARY KEY(edition, surah, ayah));
CREATE TABLE azkar_category(id INTEGER PRIMARY KEY, title TEXT NOT NULL);
CREATE TABLE azkar(id INTEGER PRIMARY KEY, category INTEGER NOT NULL REFERENCES azkar_category(id),
  text TEXT NOT NULL, count INTEGER NOT NULL DEFAULT 1, reference TEXT, note TEXT, audio_id INTEGER);
"""


def clean(text):
    """Search form only: strip tashkeel and unify alef. Never shown to users as Quran text."""
    t = TASHKEEL.sub("", text)
    t = ALEF.sub("ا", t)
    return re.sub(r"\s+", " ", t).strip()


def load_surahs(path):
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
    surahs = doc["data"]["surahs"]
    if len(surahs) != EXPECTED_SURAHS:
        raise ValueError(f"{path}: {len(surahs)} surahs, expected {EXPECTED_SURAHS}")
    return doc, surahs


def build(args):
    qdoc, surahs = load_surahs(args.quran)
    db = sqlite3.connect(args.out)
    db.executescript(SCHEMA)
    total = 0
    for s in surahs:
        ayahs = s["ayahs"]
        db.execute("INSERT INTO surah VALUES(?,?,?,?,?,?)",
                   (s["number"], s["name"], s.get("englishName"), len(ayahs),
                    s.get("revelationType"), ayahs[0].get("page")))
        for a in ayahs:
            db.execute("INSERT INTO ayah VALUES(?,?,?,?,?,?,?)",
                       (s["number"], a["numberInSurah"], a["text"], clean(a["text"]),
                        a.get("page"), a.get("juz"), a.get("hizbQuarter")))
            total += 1
    if total != EXPECTED_AYAT and not args.allow_partial:
        raise ValueError(f"{total} ayat, expected {EXPECTED_AYAT}")
    db.execute("INSERT INTO ayah_fts(ayah_fts) VALUES('rebuild')")

    editions = {}
    for spec in args.edition or []:
        key, path = spec.split("=", 1)
        _, esurahs = load_surahs(path)
        n = 0
        for s in esurahs:
            for a in s["ayahs"]:
                db.execute("INSERT INTO translation VALUES(?,?,?,?)",
                           (key, s["number"], a["numberInSurah"], a["text"]))
                n += 1
        if n != total:
            raise ValueError(f"edition {key}: {n} rows, quran has {total}")
        editions[key] = n

    azkar_source = None
    if args.azkar:
        with open(args.azkar, encoding="utf-8") as f:
            az = json.load(f)
        azkar_source = az.get("source")
        for c in az["categories"]:
            db.execute("INSERT INTO azkar_category VALUES(?,?)", (c["id"], c["title"]))
            for it in c["items"]:
                db.execute("INSERT INTO azkar VALUES(?,?,?,?,?,?,?)",
                           (it["id"], c["id"], it["text"], int(it.get("count") or 1),
                            it.get("reference"), it.get("note"), it.get("audio_id")))

    sources = {"quran": qdoc["data"].get("edition", {}).get("identifier", "unknown"),
               "editions": sorted(editions), "azkar": azkar_source}
    meta = {"content_version": str(args.version),
            "built_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "ayah_count": str(total), "sources_json": json.dumps(sources, ensure_ascii=False)}
    db.executemany("INSERT INTO meta VALUES(?,?)", meta.items())
    db.commit()
    db.execute("VACUUM")
    db.close()

    h = hashlib.sha256()
    with open(args.out, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    digest = h.hexdigest()
    with open(args.out + ".sha256", "w") as f:
        f.write(f"{digest}  {args.out.rsplit('/', 1)[-1]}\n")
    return {"ayat": total, "editions": editions, "sha256": digest}


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--version", type=int, required=True)
    p.add_argument("--quran", required=True)
    p.add_argument("--edition", action="append")
    p.add_argument("--azkar")
    p.add_argument("--out", required=True)
    p.add_argument("--allow-partial", action="store_true", help="tests only")
    r = build(p.parse_args(argv))
    print(json.dumps(r, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
