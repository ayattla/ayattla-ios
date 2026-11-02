#!/usr/bin/env python3
"""Convert osamayy/azkar-db's azkar.json (a SQLite table export) to the normalized azkar JSON
that build_content_pack.py reads. Text, description, count and reference are copied as they are.

Usage: python3 normalize_azkar.py azkar-db/azkar.json --source "osamayy/azkar-db@<commit>" --out azkar.json
"""
import argparse
import json
import sys


def normalize(doc, source):
    cols = [c["name"] for c in doc["columns"]]
    need = {"category", "zekr", "description", "count", "reference"}
    missing = need - set(cols)
    if missing:
        raise ValueError(f"azkar.json is missing columns {sorted(missing)}")
    idx = {c: cols.index(c) for c in need}
    cats, order = {}, []
    n = 0
    for row in doc["rows"]:
        title = (row[idx["category"]] or "").strip()
        text = row[idx["zekr"]]
        if not title or not text or not text.strip():
            continue
        if title not in cats:
            cats[title] = {"id": len(order) + 1, "title": title, "items": []}
            order.append(title)
        n += 1
        try:
            count = int(row[idx["count"]] or 1)
        except (TypeError, ValueError):
            count = 1
        cats[title]["items"].append({
            "id": n, "text": text, "count": max(count, 1),
            "reference": (row[idx["reference"]] or None), "note": (row[idx["description"]] or None),
            "audio_id": None})
    return {"source": source, "categories": [cats[t] for t in order]}, n


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("path")
    p.add_argument("--source", required=True)
    p.add_argument("--out", required=True)
    a = p.parse_args(argv)
    with open(a.path, encoding="utf-8") as f:
        out, n = normalize(json.load(f), a.source)
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)
    print(json.dumps({"categories": len(out["categories"]), "items": n}, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
