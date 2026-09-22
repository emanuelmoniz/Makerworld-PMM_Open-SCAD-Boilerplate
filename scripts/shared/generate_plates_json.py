#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  Plate config -> plates.json generator (shared)
# ------------------------------------------------------------
# Reads scripts/plates_config.sh (hand-edited, heavily commented -- the
# ONE source of truth for printer + plates + parts) and writes
# <project>/.build/plates.json, the machine-readable form BOTH pipelines
# consume:
#   - the MakerWorld build (scripts/build/*.ps1) uses plate names + part
#     lists to VALIDATE that the assembly file's mw_plate_N() modules still
#     call the same parts, and uses MW_PLATE_SIZE / PRINTER to inject
#     `mw_plate_size` into the bundle;
#   - the Bambu 3mf export (scripts/export/export_3mf.sh, via
#     plates_config.py) uses everything, including per-part overrides.
#
# plates.json is regenerated on EVERY run and is gitignored -- never
# hand-edit it (see docs/conventions/repo-hygiene.md).
#
# Part entry syntax (see plates_config.sh section 2 for the full story):
#   "parts/foo.scad"                                   plain
#   "parts/foo.scad|enable_support=1;wall_loops=3"     per-part overrides
#   "parts/foo.scad|auto_orient=1"                     per-part auto-orient
#
# Usage: generate_plates_json.py <plates_config.sh> <plates.json>
# ============================================================
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bash_config import parse_config  # noqa: E402


def parse_part_entry(entry):
    """Inverse of plates_config.py's part_entry()."""
    if "|" not in entry:
        return {"path": entry}

    path, suffix = entry.split("|", 1)
    part = {"path": path}
    overrides = {}
    for kv in suffix.split(";"):
        kv = kv.strip()
        if not kv:
            continue
        if kv == "auto_orient=1":
            part["auto_orient"] = True
            continue
        if "=" in kv:
            key, value = kv.split("=", 1)
            overrides[key] = value
    if overrides:
        part["overrides"] = overrides
    return part


def to_bool(value, default):
    if value is None or value == "":
        return default
    return str(value).strip().lower() == "true"


def main():
    if len(sys.argv) != 3:
        print("Usage: generate_plates_json.py <plates_config.sh> <plates.json>", file=sys.stderr)
        return 1

    config_path, output_path = sys.argv[1], sys.argv[2]
    variables = parse_config(config_path)

    names = variables.get("PLATE_NAMES", [])
    plates = []
    for index, name in enumerate(names, start=1):
        parts_raw = variables.get(f"PLATE_{index}_PARTS", [])
        if not parts_raw:
            print(f"{config_path}: PLATE_{index}_PARTS is empty or missing (plate '{name}')",
                  file=sys.stderr)
            return 1

        plate = {"name": name, "parts": [parse_part_entry(p) for p in parts_raw]}

        mw_plate_raw = variables.get(f"PLATE_{index}_MW_PLATE", None)
        if mw_plate_raw is None:
            plate["mw_plate"] = index        # default: same order as mw_plate_N()
        elif mw_plate_raw != "":
            plate["mw_plate"] = int(mw_plate_raw)
        # else: explicitly Bambu-only, no MakerWorld equivalent -> omit key

        if not to_bool(variables.get(f"PLATE_{index}_ARRANGE"), True):
            plate["arrange"] = False
        if to_bool(variables.get(f"PLATE_{index}_AUTO_ORIENT"), False):
            plate["auto_orient"] = True

        plates.append(plate)

    # Section 3: the assembly preview plate (mw_assembly_view() + the 3mf's
    # last plate). A one-line `ASSEMBLY_PLATE_VIEWS=()` parses as the plain
    # string "()" -- treat it the same as the multi-line empty array.
    views = variables.get("ASSEMBLY_PLATE_VIEWS", [])
    if isinstance(views, str):
        views = [] if views.strip() in ("", "()") else [views]
    assembly_plate = {
        "name": variables.get("ASSEMBLY_PLATE_NAME", "") or "_preview assembly DO NOT PRINT",
        "views": views,
    }

    data = {
        "_comment": "GENERATED from scripts/plates_config.sh by scripts/shared/"
                    "generate_plates_json.py -- do not hand-edit.",
        "printer": variables.get("PRINTER", ""),
        "mw_plate_size": variables.get("MW_PLATE_SIZE", ""),
        "mw_plate_size_margin": variables.get("MW_PLATE_SIZE_MARGIN", "6"),
        "mw_plate_size_ceiling": variables.get("MW_PLATE_SIZE_CEILING", "235"),
        "plates": plates,
        "assembly_plate": assembly_plate,
    }

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
