#!/usr/bin/env python3
"""Pick an iPhone simulator from `xcrun simctl list devices available -j` (stdin).
Argument: "new" for the newest iOS runtime, "old" for the oldest. Prints "<udid> <runtime>"."""
import json
import re
import sys

d = json.load(sys.stdin)["devices"]
MIN_IOS = 18  # the app's deployment target (app/project.yml)
ver = lambda k: [int(n) for n in re.findall(r"\d+", k.split("iOS")[-1])]
rt = sorted((k for k in d if "iOS" in k and ver(k) and ver(k)[0] >= MIN_IOS
             and any(x["name"].startswith("iPhone") for x in d[k])), key=ver)
k = rt[-1] if sys.argv[1] == "new" else rt[0]
print(next(x["udid"] for x in d[k] if x["name"].startswith("iPhone")), k)
