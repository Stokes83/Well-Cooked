#!/usr/bin/env python3
"""Generate a mapping from full version to build ID for a given device."""

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

    version_to_build: dict[str, str] = {}

    with Path(sys.argv[1]).open(newline="", encoding="utf-8") as handle:
        rows = csv.reader((line for line in handle if not line.startswith("#")), delimiter="\t")
        for slug, name, product, board, cpid, majors in rows:
            if slug_filter and slug != slug_filter:
                continue
            available = firmwares(product)

            for fw in available:
                ver = str(fw.get("version", ""))
                # Apply major filter if given
                if major_filter and not ver.startswith(major_filter + "."):
                    continue
                build = str(fw.get("buildid", ""))
                if ver and build:
                    version_to_build[ver] = build

    if not version_to_build:
        raise SystemExit("no firmware found for the given filters")

    # Output exactly the desired JSON
    print(json.dumps(version_to_build, separators=(",", ":")))


if __name__ == "__main__":
    main()
