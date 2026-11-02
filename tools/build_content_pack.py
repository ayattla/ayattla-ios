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
EXPECTED_BASMALA = 112      # every surah except Al-Fatiha (where it is ayah 1) and At-Tawbah
BOM = "\ufeff"
TASHKEEL = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")
ALEF = re.compile("[آأإٱ]")

SCHEMA = """
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE surah(id INTEGER PRIMARY KEY, name_ar TEXT NOT NULL, name_en TEXT,
  ayah_count INTEGER NOT NULL, revelation TEXT, page_start INTEGER,
  name_plain TEXT NOT NULL, basmala INTEGER NOT NULL DEFAULT 0);
CREATE TABLE ayah(surah INTEGER NOT NULL, ayah INTEGER NOT NULL, text_uthmani TEXT NOT NULL,
  text_clean TEXT NOT NULL, page INTEGER, juz INTEGER, hizb_quarter INTEGER,
  PRIMARY KEY(surah, ayah));
CREATE VIRTUAL TABLE ayah_fts USING fts5(text_clean, content='ayah', content_rowid='rowid');
CREATE TABLE translation(edition TEXT NOT NULL, surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
  text TEXT NOT NULL, PRIMARY KEY(edition, surah, ayah));
CREATE TABLE reciter(id TEXT PRIMARY KEY, name TEXT NOT NULL, folder TEXT NOT NULL,
  highlight INTEGER NOT NULL DEFAULT 0, ord INTEGER NOT NULL, qf_id INTEGER);
CREATE TABLE azkar_category(id INTEGER PRIMARY KEY, title TEXT NOT NULL);
CREATE TABLE azkar(id INTEGER PRIMARY KEY, category INTEGER NOT NULL REFERENCES azkar_category(id),
  text TEXT NOT NULL, count INTEGER NOT NULL DEFAULT 1, reference TEXT, note TEXT, audio_id INTEGER);
"""


def clean(text):
    """Search form only: strip tashkeel and unify alef. Never shown to users as Quran text."""
    t = TASHKEEL.sub("", text)
    t = ALEF.sub("ا", t)
    return re.sub(r"\s+", " ", t).strip()


def plain(text):
    """UI form of a surah name: tashkeel removed, alef wasla shown as plain alef (UI rule: no tashkeel)."""
    t = TASHKEEL.sub("", text).replace("ٱ", "ا")
    return re.sub(r"\s+", " ", t).strip()


def split_basmala(surahs):
    """AlQuran Cloud puts the basmala at the start of ayah 1 of every surah after Al-Fatiha.
    It is not part of that ayah, so it is moved to surah.basmala. The prefix is taken from the
    source itself (ayah 1:1); the remaining ayah text is left exactly as the source has it."""
    basmala = surahs[0]["ayahs"][0]["text"].replace(BOM, "").strip()
    prefix = basmala + " "
    # In 95 and 97 the source writes the same line with a shadda (U+0651) on the first letter,
    # carried over from the end of the previous surah. Only that exact variant is accepted.
    prefixes = (prefix, prefix[0] + "\u0651" + prefix[1:])
    flags = {}
    for s in surahs[1:]:
        first = s["ayahs"][0]
        text = first["text"].replace(BOM, "")
        p = next((p for p in prefixes if text.startswith(p)), None)
        if p:
            first["text"] = text[len(p):]
            flags[s["number"]] = 1
    return basmala, flags


def tasbih_from_site(path):
    """The tasbih phrases of ayattla.com/tools/tasbih (the page's `const Z=[...]`), as written there."""
    page = open(path, encoding="utf-8").read()
    m = re.search(r"const Z=\[(.*?)\];", page, re.S)
    if not m:
        raise ValueError("tasbih phrase list not found in the page")
    phrases = re.findall(r"'([^']+)'", m.group(1))
    if not phrases:
        raise ValueError("tasbih phrase list is empty")
    return phrases


class _GuideParser(__import__("html.parser").parser.HTMLParser):
    """Reads /tools/prayer-guide: <h2> sections, each followed by <article class="xt-hadith"> items
    (text in p.ref, source and grade in p.hint span.ref, explanation link to hadeethenc.com)."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.sections, self.lead = [], ""
        self._tag, self._buf, self._item, self._spans, self._in_hint, self._in_ref = None, "", None, [], False, False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = a.get("class") or ""
        if tag == "h2" or (tag == "p" and cls == "lead"):
            self._tag, self._buf = tag, ""
        elif tag == "article" and "xt-hadith" in cls:
            self._item = {"text": "", "source": "", "grade": "", "url": ""}
            self._spans = []
        elif self._item is not None and tag == "p" and cls == "ref":
            self._in_ref, self._buf = True, ""
        elif self._item is not None and tag == "p" and cls == "hint":
            self._in_hint = True
        elif self._item is not None and self._in_hint and tag == "span":
            self._tag, self._buf = "span", ""
        elif self._item is not None and tag == "a" and "hadeethenc.com" in (a.get("href") or ""):
            self._item["url"] = a["href"]

    def handle_endtag(self, tag):
        if tag == "h2" and self._tag == "h2":
            self.sections.append({"title": self._buf.strip(), "items": []})
            self._tag = None
        elif tag == "p" and self._tag == "p":
            self.lead, self._tag = self._buf.strip(), None
        elif tag == "p" and self._in_ref:
            self._item["text"], self._in_ref = self._buf.strip(), False
        elif tag == "span" and self._tag == "span":
            self._spans.append(self._buf.strip())
            self._tag = None
        elif tag == "p" and self._in_hint:
            self._in_hint = False
            if self._spans:
                self._item["source"] = self._spans[0]
                self._item["grade"] = self._spans[1] if len(self._spans) > 1 else ""
        elif tag == "article" and self._item is not None:
            if self.sections and self._item["text"]:
                self.sections[-1]["items"].append(self._item)
            self._item = None

    def handle_data(self, data):
        if self._tag in ("h2", "p", "span") or self._in_ref:
            self._buf += data


def guide_from_site(path):
    p = _GuideParser()
    p.feed(open(path, encoding="utf-8").read())
    sections = [s for s in p.sections if s["items"]]
    if not sections:
        raise ValueError("no prayer-guide sections found")
    return {"lead": p.lead, "source": "موسوعة الأحاديث النبوية", "source_url": "https://hadeethenc.com",
            "sections": sections}


def duas_from_site(path):
    """/api/duas: Quran duas are kept as references only (their text comes from this pack);
    duas by need (Hisn al-Muslim chapters) are kept as the site serves them."""
    d = json.load(open(path, encoding="utf-8"))
    quran = [{"s": q["s"], "a": q["a"], "b": q["b"]} for q in d["quran"]]
    if not quran or not d.get("needs"):
        raise ValueError("duas: empty sections")
    return {"quran": quran, "needs": d["needs"]}


# Quran.com chapter reciters for the site's word-highlight reciters, matched by name and style in
# Quran.com's own list (/api/v4/resources/chapter_reciters), never by a typed id.
QF_MATCH = {
    "basit_murattal": (["abdul basit"], "murattal"), "basit_mujawwad": (["abdul basit", "abdulbaset"], "mujawwad"),
    "sudais": (["sudais"], None), "minshawi_murattal": (["minshawi"], "murattal"),
    "minshawi_mujawwad": (["minshawi"], "mujawwad"), "shuraim": (["shuraym", "shuraim"], None),
    "alafasy": (["afasy"], None), "husary": (["husary"], "murattal"), "shatri": (["shatri"], None),
    "rifai": (["rifai"], None), "tablawy": (["tablaw"], None),
}


def qf_ids(path, site_reciters):
    qf = json.load(open(path, encoding="utf-8"))["reciters"]
    out = {}
    for r in site_reciters:
        if not r.get("highlight"):
            continue
        rule = QF_MATCH.get(r["id"])
        if not rule:
            raise ValueError(f"no Quran.com match rule for highlight reciter {r['id']}")
        names, style = rule
        cands = [q for q in qf if any(n in (q.get("name", "") + " " + q.get("translated_name", {}).get("name", "")).lower()
                                      for n in names)
                 and (style is None or (q.get("style") or {}).get("name", "").lower() == style)]
        if not cands:
            raise ValueError(f"Quran.com reciter not found for {r['id']}")
        out[r["id"]] = min(c["id"] for c in cands)
    return out


def ruqya_from_site(path, db):
    """/api/ruqya: Quran passages only; kept as references, their text comes from this pack."""
    d = json.load(open(path, encoding="utf-8"))
    refs = [{"s": i["s"], "a": i["a"], "b": i["b"]} for i in d["items"]]
    for q in refs:
        n = db.execute("SELECT count(*) FROM ayah WHERE surah=? AND ayah BETWEEN ? AND ?", (q["s"], q["a"], q["b"])).fetchone()[0]
        if n != q["b"] - q["a"] + 1:
            raise ValueError(f"ruqya reference {q} not in the pack")
    return {"title": d.get("source_chapter", ""), "items": refs}


def asma_from_site(path):
    """The 99 names from /tools/asma-ul-husna (the page's `const AS=[...]`), as written there."""
    page = open(path, encoding="utf-8").read()
    i = page.find("const AS=")
    j = page.find("];", i)
    if i < 0 or j < 0:
        raise ValueError("asma list not found")
    names = json.loads(page[i + 9:j + 1])
    if len(names) != 99:
        raise ValueError(f"asma: {len(names)} names, expected 99")
    return names


def load_surahs(path):
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
    surahs = doc["data"]["surahs"]
    if len(surahs) != EXPECTED_SURAHS:
        raise ValueError(f"{path}: {len(surahs)} surahs, expected {EXPECTED_SURAHS}")
    return doc, surahs


def build(args):
    qdoc, surahs = load_surahs(args.quran)
    basmala, basmala_flags = split_basmala(surahs)
    if len(basmala_flags) != EXPECTED_BASMALA and not args.allow_partial:
        b = surahs[0]["ayahs"][0]["text"].replace(BOM, "").strip()
        missing = [x["number"] for x in surahs[1:] if x["number"] not in basmala_flags and x["number"] != 9]
        for n in missing:
            t = surahs[n - 1]["ayahs"][0]["text"].replace(BOM, "")
            i = next((i for i, (p, q) in enumerate(zip(b + " ", t)) if p != q), None)
            print(f"surah {n}: differs at char {i}: source {[hex(ord(c)) for c in t[max(0, i - 2):i + 6]]}"
                  f" vs 1:1 {[hex(ord(c)) for c in (b + ' ')[max(0, i - 2):i + 6]]}", file=sys.stderr)
        raise ValueError(f"basmala found in {len(basmala_flags)} surahs, expected {EXPECTED_BASMALA}: {missing}")
    db = sqlite3.connect(args.out)
    db.executescript(SCHEMA)
    total = 0
    for s in surahs:
        ayahs = s["ayahs"]
        db.execute("INSERT INTO surah VALUES(?,?,?,?,?,?,?,?)",
                   (s["number"], s["name"], s.get("englishName"), len(ayahs),
                    s.get("revelationType"), ayahs[0].get("page"), plain(s["name"]),
                    basmala_flags.get(s["number"], 0)))
        for a in ayahs:
            text = a["text"].replace(BOM, "")
            db.execute("INSERT INTO ayah VALUES(?,?,?,?,?,?,?)",
                       (s["number"], a["numberInSurah"], text, clean(text),
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

    reciters = 0
    qf_map = {}
    if getattr(args, "reciters", None):
        with open(args.reciters, encoding="utf-8") as f:
            rs = json.load(f)["reciters"]
        if getattr(args, "qf_reciters", None):
            qf_map = qf_ids(args.qf_reciters, rs)
        for i, r in enumerate(rs):
            if not r.get("folder"):
                raise ValueError(f"reciter {r.get('id')} has no EveryAyah folder")
            db.execute("INSERT INTO reciter VALUES(?,?,?,?,?,?)",
                       (r["id"], r["name"], r["folder"], 1 if r.get("highlight") else 0, i, qf_map.get(r["id"])))
            reciters += 1
    ruqya = ruqya_from_site(args.ruqya, db) if getattr(args, "ruqya", None) else None
    asma = asma_from_site(args.asma_html) if getattr(args, "asma_html", None) else None

    tasbih = tasbih_from_site(args.tasbih_html) if getattr(args, "tasbih_html", None) else []
    guide = guide_from_site(args.guide_html) if getattr(args, "guide_html", None) else None
    duas = duas_from_site(args.duas) if getattr(args, "duas", None) else None
    if duas:
        for q in duas["quran"]:
            n = db.execute("SELECT count(*) FROM ayah WHERE surah=? AND ayah BETWEEN ? AND ?",
                           (q["s"], q["a"], q["b"])).fetchone()[0]
            if n != q["b"] - q["a"] + 1:
                raise ValueError(f"dua reference {q} not in the pack")

    sources = {"quran": qdoc["data"].get("edition", {}).get("identifier", "unknown"),
               "editions": sorted(editions), "azkar": azkar_source}
    meta = {"content_version": str(args.version), "basmala": basmala,
            "tasbih_phrases": json.dumps(tasbih, ensure_ascii=False),
            "prayer_guide": json.dumps(guide, ensure_ascii=False) if guide else "",
            "duas": json.dumps(duas, ensure_ascii=False) if duas else "",
            "ruqya": json.dumps(ruqya, ensure_ascii=False) if ruqya else "",
            "asma": json.dumps(asma, ensure_ascii=False) if asma else "",
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
    return {"ayat": total, "editions": editions, "reciters": reciters, "qf_ids": qf_map, "tasbih": len(tasbih),
            "ruqya": len(ruqya["items"]) if ruqya else 0, "asma": len(asma) if asma else 0,
            "guide_items": sum(len(x["items"]) for x in guide["sections"]) if guide else 0,
            "duas": (len(duas["quran"]), len(duas["needs"])) if duas else None, "basmala_surahs": len(basmala_flags), "sha256": digest}


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--version", type=int, required=True)
    p.add_argument("--quran", required=True)
    p.add_argument("--edition", action="append")
    p.add_argument("--azkar")
    p.add_argument("--qf-reciters", help="api.quran.com /api/v4/resources/chapter_reciters JSON")
    p.add_argument("--ruqya", help="saved ayattla.com/api/ruqya JSON")
    p.add_argument("--asma-html", help="saved ayattla.com/tools/asma-ul-husna page")
    p.add_argument("--guide-html", help="saved ayattla.com/tools/prayer-guide page")
    p.add_argument("--duas", help="saved ayattla.com/api/duas JSON")
    p.add_argument("--tasbih-html", help="saved ayattla.com/tools/tasbih page (phrase list)")
    p.add_argument("--reciters", help="ayattla.com /api/meta JSON (reciter ids, names, EveryAyah folders)")
    p.add_argument("--out", required=True)
    p.add_argument("--allow-partial", action="store_true", help="tests only")
    r = build(p.parse_args(argv))
    print(json.dumps(r, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
