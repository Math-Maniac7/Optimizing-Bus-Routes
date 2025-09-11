# script to query OSM Overpass API 

import sys, urllib.request, urllib.parse

if len(sys.argv) != 2:
    print("usage: overpass_fetch.py <query_file>", file=sys.stderr)
    sys.exit(2)

query_file = sys.argv[1]
with open(query_file, "r", encoding="utf-8") as f:
    overpass_ql = f.read()

data = urllib.parse.urlencode({"data": overpass_ql}).encode("utf-8")
req = urllib.request.Request(
    "https://overpass-api.de/api/interpreter",
    data=data,
    headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "User-Agent": "overpass-bridge/1.0"
    },
)
with urllib.request.urlopen(req, timeout=60) as resp:
    sys.stdout.buffer.write(resp.read())
