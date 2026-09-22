#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  mw_plate_size resolver (MakerWorld side)
# ------------------------------------------------------------
# `mw_plate_size` is the square layout bound (mm) your mw_plate_N()
# modules use to decide when to wrap parts into a new row/column, so a
# plate never grows past what PMM can arrange. The build injects it into
# the bundle right after params.scad -- params.scad deliberately does NOT
# define it, so there is exactly ONE place the number comes from.
#
# Resolution order (from the generated plates.json, i.e. plates_config.sh):
#   1. MW_PLATE_SIZE set to a number   -> used as-is (DEFAULT; deterministic,
#                                         identical on every machine and CI)
#   2. MW_PLATE_SIZE empty + PRINTER   -> min(bed_w, bed_d) - MARGIN, from the
#      set + Bambu presets found          real Bambu preset (printer_bed.py)
#   3. anything else                   -> MW_PLATE_SIZE_CEILING
# Every result is capped at MW_PLATE_SIZE_CEILING (default 235): PMM has a
# practical plate ceiling of about 240 x 235 mm (Bambu-employee-confirmed,
# see docs/pmm/compatibility-rules.md "Oversize / auto-arrange"). A bed-
# derived value from a 256 mm printer (250) would exceed it.
#
# Why is option 1 the default? A value derived from locally installed
# Bambu presets makes the tracked dist/ bundle depend on what software the
# builder has installed -- CI (no Bambu Studio) and your machine would
# produce different bundles. See docs/toolchain/pipelines.md.
#
# Usage:  resolve_mw_plate_size.py <plates.json>
# Output: the number on stdout; the reason on stderr.
# ============================================================
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from printer_bed import bed_info  # noqa: E402


def to_float(value, default):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def main():
    if len(sys.argv) != 2:
        print("Usage: resolve_mw_plate_size.py <plates.json>", file=sys.stderr)
        return 1
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)

    ceiling = to_float(data.get("mw_plate_size_ceiling"), 235.0)
    margin = to_float(data.get("mw_plate_size_margin"), 6.0)
    explicit = str(data.get("mw_plate_size", "")).strip()
    printer = str(data.get("printer", "")).strip()

    if explicit:
        value, reason = to_float(explicit, ceiling), "MW_PLATE_SIZE (explicit)"
    elif printer:
        try:
            info = bed_info(printer)
            value = min(info["BED_WIDTH"], info["BED_DEPTH"]) - margin
            reason = f"derived from printer '{printer}' bed minus {margin:g} mm margin"
        except LookupError as e:
            value, reason = ceiling, f"fallback to ceiling ({str(e).splitlines()[0]})"
    else:
        value, reason = ceiling, "fallback to ceiling (no MW_PLATE_SIZE, no PRINTER)"

    if value > ceiling:
        reason += f"; capped from {value:g} to PMM ceiling {ceiling:g}"
        value = ceiling

    print(f"mw_plate_size = {int(math.floor(value))} ({reason})", file=sys.stderr)
    print(int(math.floor(value)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
