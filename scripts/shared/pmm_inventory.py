#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  PMM inventory snapshot refresher
# ------------------------------------------------------------
# Downloads MakerWorld's own public PMM inventories into docs/pmm/data/ so
# that humans, LLMs, and scripts/check/pmm_lint.py can check what PMM
# actually has installed -- without network access at lint time.
#
#   libraries.json       bundled OpenSCAD libraries + their include method
#   fonts-installed.json fonts INSTALLED in the PMM runtime   <- authoritative
#   fonts-catalog.json   the broader DISPLAY catalog          <- NOT a guarantee
#
# The installed-vs-catalog distinction is the whole point: a font that
# appears in the catalog but not the installed inventory can show up in
# PMM's picker and still be silently substituted at render time (see
# docs/pmm/compatibility-rules.md "Fonts"). Always check installed.
#
# Endpoint note: the working URLs carry a /makerworld/ path segment. The
# form WITHOUT it (as listed in some community docs) returns HTTP 403 --
# verified 2026-09-22. See docs/pmm/sources.md.
#
# Usage: pmm_inventory.py [output_dir]        (default: docs/pmm/data)
# Run it when starting a project and before every MakerWorld release.
# ============================================================
import datetime
import json
import os
import sys
import urllib.request

BASE = "https://makerworld.bblmw.com/makerworld/makerlab/content-generator/openscad"
SOURCES = {
    "libraries.json": f"{BASE}/libraries-0.8.0.json",
    "fonts-installed.json": f"{BASE}/fonts-0.8.0.json",
    "fonts-catalog.json": f"{BASE}/fonts-show-0.0.1.json",
}


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "pmm-boilerplate-inventory/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(repo_root, "docs", "pmm", "data")
    os.makedirs(out_dir, exist_ok=True)

    manifest = {"fetched_utc": datetime.datetime.now(datetime.timezone.utc)
                .strftime("%Y-%m-%dT%H:%M:%SZ"), "sources": {}}
    failures = 0
    for filename, url in SOURCES.items():
        try:
            data = fetch(url)
        except Exception as e:  # noqa: BLE001 -- report and keep the old snapshot
            print(f"FAILED  {filename}: {e} (kept existing snapshot, if any)", file=sys.stderr)
            failures += 1
            continue
        with open(os.path.join(out_dir, filename), "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        manifest["sources"][filename] = url
        print(f"OK      {filename}  <-  {url}")

    if manifest["sources"]:
        with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(manifest, f, indent=2)
            f.write("\n")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
