#!/usr/bin/env python3
"""Resolve the newest available IPSW in each requested major-version line."""

from __future__ import annotations

import csv
import json
import sys
import urllib.request
from pathlib import Path


def firmwares(product: str) -> list[dict[str, object]]:
    url = f"https://api.ipsw.me/v4/device/{product}?type=ipsw"
    with urllib.request.urlopen(url, timeout=60) as response:
        data = json.load(response)
    return data["firmwares"]


def main() -> None:
    if not 2 <= len(sys.argv) <= 4:
        raise SystemExit("usage: resolve_matrix.py TARGETS.tsv [SLUG] [MAJOR]")

    slug_filter = sys.argv[2] if len(sys.argv) >= 3 else ""
    major_filter = sys.argv[3] if len(sys.argv) >= 4 else ""

    entries: list[dict[str, str]] = []
    with Path(sys.argv[1]).open(newline="", encoding="utf-8") as handle:
        rows = csv.reader((line for line in handle if not line.startswith("#")), delimiter="\t")
        for slug, name, product, board, cpid, majors in rows:
            if slug_filter and slug != slug_filter:
                continue
            available = firmwares(product)
            for major in majors.split(","):
                if major_filter and major != major_filter:
                    continue
                matches = [
                    fw
                    for fw in available
                    if str(fw.get("version", "")).split(".", 1)[0] == major
                ]
                if not matches:
                    print(
                        f"skip {product} {name}: no iOS/iPadOS {major} IPSW",
                        file=sys.stderr,
                    )
                    continue
                selected = max(matches, key=lambda fw: str(fw.get("releasedate", "")))
                entries.append(
                    {
                        "slug": slug,
                        "name": name,
                        "product": product,
                        "board": board,
                        "cpid": cpid,
                        "major": major,
                        "version": str(selected["version"]),
                        "build": str(selected["buildid"]),
                    }
                )

    if not entries:
        raise SystemExit("no firmware targets matched the requested filters")
    print(json.dumps({"include": entries}, separators=(",", ":")))


if __name__ == "__main__":
    main()
