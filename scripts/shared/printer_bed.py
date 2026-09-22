#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  Bambu printer bed-size resolver (shared)
# ------------------------------------------------------------
# Resolves a Bambu Studio machine preset NAME (e.g. "Bambu Lab A1 0.4
# nozzle") to its real printable area, height, and bed exclusion zone.
#
# Bambu presets are layered: a specific printer typically leaves
# printable_area / bed_exclude_area undefined and inherits them from a base
# preset via its "inherits" key (which names the OTHER preset's "name"
# field, not necessarily its filename). This walks that chain by name.
#
# Deliberately plain -- it reports the bed exactly as Bambu Studio defines
# it and never shrinks or adjusts it. Any safety margin is applied by the
# CALLER (see resolve_mw_plate_size.py), where the reason for it lives.
#
# Preset directory resolution, first hit wins:
#   1. second CLI argument
#   2. env BAMBU_PROFILES_DIR
#   3. OS default install location (Windows / macOS / Linux, see below)
#
# Usage:  printer_bed.py "<printer preset name>" [machine/profiles/dir]
# Output: shell-eval-able lines -- BED_WIDTH=.. BED_DEPTH=.. BED_HEIGHT=..
#         BED_MIN_X=.. BED_MIN_Y=.. PRINTABLE_AREA=.. BED_EXCLUDE_AREA=..
# Tip:    pass a bogus printer name to print every available preset name.
# See:    docs/toolchain/pipelines.md ("3MF export")
# ============================================================
import json
import os
import sys
from pathlib import Path

DEFAULT_MACHINE_DIRS = [
    Path("C:/Program Files/Bambu Studio/resources/profiles/BBL/machine"),
    Path("/Applications/BambuStudio.app/Contents/Resources/profiles/BBL/machine"),
    Path("/usr/share/BambuStudio/profiles/BBL/machine"),
    Path("/opt/bambu-studio/resources/profiles/BBL/machine"),
]


def find_machine_dir(explicit=None):
    candidates = []
    if explicit:
        candidates.append(Path(explicit))
    if os.environ.get("BAMBU_PROFILES_DIR"):
        candidates.append(Path(os.environ["BAMBU_PROFILES_DIR"]))
    candidates.extend(DEFAULT_MACHINE_DIRS)
    for c in candidates:
        if c.is_dir():
            return c
    return None


def load_index(machine_dir):
    index = {}
    for f in machine_dir.glob("*.json"):
        if " template " in f.name:
            continue
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        name = data.get("name")
        if name:
            index[name] = data
    return index


def resolve(index, name, key, seen=None):
    seen = seen or set()
    if name in seen or name not in index:
        return None
    seen.add(name)
    data = index[name]
    value = data.get(key)
    if isinstance(value, list):
        if value:
            return value
    elif value not in (None, ""):
        return value
    parent = data.get("inherits")
    return resolve(index, parent, key, seen) if parent else None


def parse_point(s):
    x, y = s.lower().split("x")
    return float(x), float(y)


def bed_info(printer_name, machine_dir=None):
    """Returns a dict of bed facts, or raises LookupError with a helpful message."""
    mdir = find_machine_dir(machine_dir)
    if mdir is None:
        raise LookupError("Bambu Studio machine presets not found (set BAMBU_PROFILES_DIR).")
    index = load_index(mdir)
    if printer_name not in index:
        available = ", ".join(sorted(n for n in index if not n.startswith("fdm_")))
        raise LookupError(f"Unknown printer preset {printer_name!r} under {mdir}.\n"
                          f"Available: {available}")

    printable_area = resolve(index, printer_name, "printable_area")
    printable_height = resolve(index, printer_name, "printable_height")
    bed_exclude_area = resolve(index, printer_name, "bed_exclude_area") or []
    if not printable_area or not printable_height:
        raise LookupError(f"Could not resolve printable_area/height for {printer_name!r}")

    points = [parse_point(p) for p in printable_area]
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return {
        "BED_WIDTH": max(xs) - min(xs),
        "BED_DEPTH": max(ys) - min(ys),
        "BED_HEIGHT": printable_height,
        "BED_MIN_X": min(xs),
        "BED_MIN_Y": min(ys),
        "PRINTABLE_AREA": ",".join(printable_area),
        "BED_EXCLUDE_AREA": ",".join(bed_exclude_area),
    }


def main():
    if len(sys.argv) not in (2, 3):
        print('Usage: printer_bed.py "<printer preset name>" [machine/profiles/dir]',
              file=sys.stderr)
        return 1
    try:
        info = bed_info(sys.argv[1], sys.argv[2] if len(sys.argv) == 3 else None)
    except LookupError as e:
        print(str(e), file=sys.stderr)
        return 1
    for key, value in info.items():
        print(f"{key}={value}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
