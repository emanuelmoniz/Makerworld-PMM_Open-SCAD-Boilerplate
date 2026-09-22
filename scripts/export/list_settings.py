#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  List print-setting keys in REFERENCE_3MF
# ------------------------------------------------------------
# Prints every key in a Bambu .3mf's Metadata/project_settings.config with
# its current value, in the exact "key=value" form that
# PRINT_SETTINGS_OVERRIDES (scripts/export_3mf_config.sh) and per-part
# "|key=value" suffixes (scripts/plates_config.sh) accept.
#
# Replaces the ~580-line commented dump the original project pasted into
# its config: generated on demand, so it always matches YOUR reference file.
#
# Usage:
#   list_settings.py                          # scripts/export/base_settings.3mf
#   list_settings.py path/to/reference.3mf
#   list_settings.py --grep support           # filter keys by substring
# ============================================================
import argparse
import json
import os
import zipfile

DEFAULT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "base_settings.3mf")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("reference", nargs="?", default=DEFAULT)
    parser.add_argument("--grep", default="", help="only keys containing this substring")
    args = parser.parse_args()

    with zipfile.ZipFile(args.reference) as z:
        data = json.loads(z.read("Metadata/project_settings.config"))

    shown = 0
    for key in sorted(data):
        if args.grep and args.grep.lower() not in key.lower():
            continue
        value = data[key]
        note = ""
        if isinstance(value, list):
            if any("\n" in str(v) for v in value):
                continue  # multi-line g-code blocks are not sensible one-liners
            note = "  # per-extruder list" if len(value) != 1 else ""
            value = ",".join(str(v) for v in value)
        elif "\n" in str(value):
            continue
        print(f'"{key}={value}"{note}')
        shown += 1
    print(f"# {shown} keys from {args.reference}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
