#!/usr/bin/env python3
"""Run every SQL statement found in ContentStore.swift against a content pack,
so a schema/query mismatch is caught without Xcode. Usage:
  python3 check_content_sql.py <ContentStore.swift> <pack.sqlite>
"""
import re
import sqlite3
import sys

src = open(sys.argv[1], encoding="utf-8").read()
sqls = re.findall(r'rows\("([^"]+)"', src) + [s.strip() for s in re.findall(r'"""(.*?)"""', src, re.S)]
db = sqlite3.connect(f"file:{sys.argv[2]}?mode=ro", uri=True)
samples = {"meta": ["content_version"], "MATCH": ['"نص"', 5]}
ok = 0
for q in sqls:
    n = q.count("?")
    if "MATCH" in q:
        args = samples["MATCH"]
    elif "meta" in q:
        args = samples["meta"]
    elif "translation" in q:
        args = ["muyassar", 1, 1][:n]
    else:
        args = [1, 1, 2][:n]
    rows = db.execute(q, args).fetchall()
    print(f"OK {len(rows):4d} rows  {' '.join(q.split())[:70]}")
    ok += 1
print(f"{ok}/{len(sqls)} statements ran")
sys.exit(0 if ok == len(sqls) and ok > 0 else 1)
