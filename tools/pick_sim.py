#!/usr/bin/env python3
"""Pick a simulator from `xcrun simctl list devices available -j` (stdin).
Arguments: "new" or "old" (newest or oldest supported iOS runtime), then optionally "iPad"
(default "iPhone"). Prints "<udid> <runtime>", or nothing when there is none."""
import json
import re
import sys

d = json.load(sys.stdin)["devices"]
MIN_IOS = [18, 2]  # the app's deployment target (app/project.yml)
ver = lambda k: [int(n) for n in re.findall(r"\d+", k.split("iOS")[-1])]
kind = sys.argv[2] if len(sys.argv) > 2 else "iPhone"
rt = sorted((k for k in d if "iOS" in k and ver(k) and ver(k) >= MIN_IOS
             and any(x["name"].startswith(kind) for x in d[k])), key=ver)
if rt:
    k = rt[-1] if sys.argv[1] == "new" else rt[0]
    print(next(x["udid"] for x in d[k] if x["name"].startswith(kind)), k)
