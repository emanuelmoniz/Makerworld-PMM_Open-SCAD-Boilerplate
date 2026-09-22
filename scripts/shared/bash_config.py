#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  Constrained bash-config parser (shared)
# ------------------------------------------------------------
# Every hand-edited config in this repo (scripts/*_config.sh) is written
# in bash syntax -- because bash has comments and JSON does not, and these
# files are meant to be read by humans as documentation first. But the
# PowerShell build scripts cannot `source` a bash file. This module is the
# ONE parser every non-bash consumer goes through, so the configs are read
# identically no matter which pipeline reads them:
#   - bash scripts (render.sh, export_3mf.sh) `source` the file directly;
#   - PowerShell scripts (build.ps1, dev_build.ps1) call
#     `python bash_config.py <file>` and get JSON back;
#   - Python scripts import parse_config() directly.
#
# It is NOT a general bash parser. It understands exactly the subset the
# configs are written in -- keep every config inside this subset:
#   NAME="value"                    plain assignment (quotes optional)
#   NAME=(                          array: opening paren alone on its line,
#       "item one"                  one quoted item per line,
#       "item two"                  full-line `#` comments allowed inside,
#   )                               closing paren alone on its line
# NOT supported (silently ignored): inline arrays `A=("x" "y")`, variable
# expansion `$OTHER`, command substitution, conditionals, functions.
# A trailing `# comment` after an item or a plain assignment is stripped,
# exactly as bash itself would.
#
# Usage (CLI): bash_config.py <path/to/config.sh>   -> JSON on stdout
# See: docs/toolchain/pipelines.md ("Config files")
# ============================================================
import json
import re
import shlex
import sys

ASSIGN_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$')
ARRAY_START_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)=\(\s*$')
ARRAY_END_RE = re.compile(r'^\s*\)\s*$')
COMMENT_OR_BLANK_RE = re.compile(r'^\s*(#.*)?$')


def unquote(value):
    """First shell token of `value`, quotes removed, trailing `# comment`
    dropped (shlex with comments=True treats `#` at a token boundary as a
    comment start -- the same rule bash uses)."""
    tokens = shlex.split(value.strip(), comments=True)
    return tokens[0] if tokens else ""


def parse_config(path):
    """Returns {name: str} for assignments and {name: [str, ...]} for arrays."""
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()

    variables = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        if COMMENT_OR_BLANK_RE.match(line):
            i += 1
            continue

        array_match = ARRAY_START_RE.match(line)
        if array_match:
            name = array_match.group(1)
            items = []
            i += 1
            while i < len(lines) and not ARRAY_END_RE.match(lines[i]):
                if not COMMENT_OR_BLANK_RE.match(lines[i]):
                    item = unquote(lines[i])
                    if item != "":
                        items.append(item)
                i += 1
            variables[name] = items
            i += 1  # skip the closing ")"
            continue

        assign_match = ASSIGN_RE.match(line)
        if assign_match:
            name, raw_value = assign_match.groups()
            variables[name] = unquote(raw_value)

        i += 1  # unrecognized lines are ignored rather than failing the build

    return variables


def main():
    if len(sys.argv) != 2:
        print("Usage: bash_config.py <path/to/config.sh>", file=sys.stderr)
        return 1
    json.dump(parse_config(sys.argv[1]), sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
