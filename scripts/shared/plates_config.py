#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  plates.json -> bash assignments (Bambu side)
# ------------------------------------------------------------
# Used by scripts/export/export_3mf.sh: reads the generated plates.json
# and prints shell-eval-able assignments -- PRINTER, PLATE_NAMES, one
# PLATE_<N>_PARTS / PLATE_<N>_ARRANGE / PLATE_<N>_AUTO_ORIENT per plate
# (folding each part's overrides back into the "path|k=v;k2=v2" suffix the
# export loop parses), plus ASSEMBLY_PLATE_NAME / ASSEMBLY_PLATE_VIEWS.
#
# Why round-trip through JSON instead of just sourcing plates_config.sh?
# The PowerShell side cannot source bash, and having BOTH sides read the
# same generated file guarantees they agree on what the config says.
#
# Usage: plates_config.py <path/to/plates.json>
# ============================================================
import json
import shlex
import sys


def part_entry(part):
    entry = part["path"]
    kv_pairs = []
    if part.get("auto_orient"):
        kv_pairs.append("auto_orient=1")
    if part.get("multicolor"):
        kv_pairs.append("multicolor=1")
    for key, value in part.get("overrides", {}).items():
        kv_pairs.append(f"{key}={value}")
    if kv_pairs:
        entry += "|" + ";".join(kv_pairs)
    return entry


def bash_array(name, values):
    return f"{name}=({' '.join(shlex.quote(v) for v in values)})"


def main():
    if len(sys.argv) != 2:
        print("Usage: plates_config.py <path/to/plates.json>", file=sys.stderr)
        return 1

    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)

    print(f"PRINTER={shlex.quote(data.get('printer', ''))}")
    plates = data["plates"]
    print(bash_array("PLATE_NAMES", [p["name"] for p in plates]))
    for index, plate in enumerate(plates, start=1):
        print(bash_array(f"PLATE_{index}_PARTS", [part_entry(p) for p in plate["parts"]]))
        print(f"PLATE_{index}_ARRANGE={'true' if plate.get('arrange', True) else 'false'}")
        print(f"PLATE_{index}_AUTO_ORIENT={'true' if plate.get('auto_orient', False) else 'false'}")

    # Assembly preview plate (plates_config.sh section 3) -- never arranged.
    assembly_plate = data.get("assembly_plate", {})
    print(f"ASSEMBLY_PLATE_NAME={shlex.quote(assembly_plate.get('name', ''))}")
    print(bash_array("ASSEMBLY_PLATE_VIEWS", assembly_plate.get("views", [])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
