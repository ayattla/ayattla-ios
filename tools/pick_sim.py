#!/usr/bin/env python3
"""Pick an iPhone simulator from `xcrun simctl list devices available -j` (stdin).
Argument: "new" for the newest iOS runtime, "old" for the oldest. Prints "<udid> <runtime>"."""
import json
import re
import sys

d = json.load(sys.stdin)["devices"]
rt = sorted((k for k in d if "iOS" in k and any(x["name"].startswith("iPhone") for x in d[k])),
            key=lambda k: [int(n) for n in re.findall(r"\d+", k.split("iOS")[-1])])
k = rt[-1] if sys.argv[1] == "new" else rt[0]
print(next(x["udid"] for x in d[k] if x["name"].startswith("iPhone")), k)
