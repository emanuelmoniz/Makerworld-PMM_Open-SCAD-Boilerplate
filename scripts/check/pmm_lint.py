#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  PMM compatibility lint
# ------------------------------------------------------------
# Static checks of the MakerWorld bundle (the file that actually ships)
# against the PMM rules in docs/pmm/compatibility-rules.md. Each check
# carries its rule ID, so a finding points straight at the doc explaining it.
#
#   ID    level  rule
#   P01   ERROR  no local include/use (only PMM-bundled libraries)
#   P02   ERROR  bundled-library includes must be in PMM's inventory
#   P03   ERROR  `// color` parameters must be hex strings
#   P04   ERROR  `// font` parameters / literal font names must be INSTALLED
#                in PMM (WARN when only in the display catalog)
#   P05   ERROR  no `// preview[...]` comments (not a PMM feature)
#   P06   ERROR  never call mw_plate_N() / mw_assembly_view() yourself
#   P07   ERROR  import() only of default.stl / default.svg / default.png
#   P08   ERROR  a module/function name defined twice (last one wins silently)
#   P09   ERROR  a name colliding with a BOSL2 symbol, when BOSL2 is included
#                (checked only if a local BOSL2 checkout is found)
#   P10   ERROR  file must not start with a UTF-8 BOM
#   P11   WARN   mw_plate_size above the ~235 mm practical PMM ceiling
#   P12   WARN   mw_plate_N() modules defined AND a top-level call present
#
# Inventories come from docs/pmm/data/ (refresh:
# python scripts/shared/pmm_inventory.py) -- the lint never needs network.
#
# Usage:  pmm_lint.py [-p project_dir] [bundle.scad]
#         (default bundle: <project>/dist/<PROJECT_SLUG>_makerworld.scad)
# Exit:   1 if any ERROR, else 0.
# See:    docs/pmm/compatibility-rules.md, docs/toolchain/pipelines.md
# ============================================================
import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO_ROOT, "scripts", "shared"))
from bash_config import parse_config  # noqa: E402

DATA_DIR = os.path.join(REPO_ROOT, "docs", "pmm", "data")
DEFAULT_ASSETS = {"default.stl", "default.svg", "default.png"}
PMM_PLATE_CEILING = 235

DEF_RE = re.compile(r'^\s*(module|function)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
INCLUDE_RE = re.compile(r'^\s*(include|use)\s*<([^>]+)>')
PARAM_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]*)"\s*;\s*//\s*(color|font)\s*$')
FONT_LITERAL_RE = re.compile(r'\bfont\s*=\s*"([^"]+)"')
FONT_VAR_RE = re.compile(r'\bfont\s*=\s*([A-Za-z_][A-Za-z0-9_]*)\b')
STRING_ASSIGN_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]*)"\s*;')
CALL_START_RE = re.compile(r'^([A-Za-z_$][\w$]*)\s*\(')
NOT_GEOMETRY = {"module", "function", "include", "use", "let", "assert", "echo"}
IMPORT_RE = re.compile(r'\bimport\s*\(\s*(?:file\s*=\s*)?"([^"]+)"')
MW_CALL_RE = re.compile(r'\b(mw_plate_\d+|mw_assembly_view)\s*\(')
HEX_RE = re.compile(r'^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8}|[0-9A-Fa-f]{3})$')


class Report:
    def __init__(self):
        self.errors = 0
        self.warnings = 0

    def add(self, level, rule, line_no, message):
        where = f"line {line_no}" if line_no else "file"
        print(f"{level:5} {rule}  {where}: {message}")
        if level == "ERROR":
            self.errors += 1
        else:
            self.warnings += 1


def load_json(name):
    path = os.path.join(DATA_DIR, name)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def library_prefixes(libs):
    """'include <BOSL2/*.scad>;' -> 'BOSL2/', 'include <ub.scad>;' -> 'ub.scad'."""
    prefixes = []
    for lib in (libs or {}).get("Libraries", []):
        m = re.search(r'<([^>]+)>', lib.get("includeMethod", ""))
        if m:
            target = m.group(1)
            prefixes.append(target.split("*")[0] if "*" in target else target)
    return prefixes


def strip_comment(line):
    """Code part of a line, ignoring // inside string literals."""
    in_str = False
    for i, ch in enumerate(line):
        if ch == '"' and (i == 0 or line[i - 1] != "\\"):
            in_str = not in_str
        elif not in_str and line.startswith("//", i):
            return line[:i]
    return line


def find_bosl2_dir():
    candidates = []
    for p in os.environ.get("OPENSCADPATH", "").split(os.pathsep):
        if p:
            candidates.append(p)
    home = os.path.expanduser("~")
    candidates += [
        os.path.join(home, "Documents", "OpenSCAD", "libraries"),
        os.path.join(home, "OneDrive", "Documents", "OpenSCAD", "libraries"),
        os.path.join(home, ".local", "share", "OpenSCAD", "libraries"),
        "C:/Program Files/OpenSCAD/libraries",
        "C:/Program Files/OpenSCAD (Nightly)/libraries",
    ]
    for c in candidates:
        d = os.path.join(c, "BOSL2")
        if os.path.isfile(os.path.join(d, "std.scad")):
            return d
    return None


def bosl2_symbols(bosl2_dir):
    names = set()
    for fname in os.listdir(bosl2_dir):
        if fname.endswith(".scad"):
            with open(os.path.join(bosl2_dir, fname), encoding="utf-8", errors="replace") as f:
                for line in f:
                    m = DEF_RE.match(line)
                    if m:
                        names.add(m.group(2))
    return names


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--project", default="")
    parser.add_argument("bundle", nargs="?")
    args = parser.parse_args()

    project_dir = os.path.abspath(os.path.join(REPO_ROOT, args.project)) if args.project else REPO_ROOT
    cfg = parse_config(os.path.join(project_dir, "scripts", "project_config.sh"))
    slug = cfg.get("PROJECT_SLUG", "project")
    bundle = args.bundle or os.path.join(project_dir, "dist", f"{slug}_makerworld.scad")
    if not os.path.exists(bundle):
        print(f"ERROR bundle not found: {bundle} -- run the MakerWorld build first.")
        return 1

    with open(bundle, "rb") as f:
        raw = f.read()
    report = Report()
    print(f"PMM lint: {os.path.relpath(bundle, REPO_ROOT)}")

    if raw.startswith(b"\xef\xbb\xbf"):
        report.add("ERROR", "P10", 0, "UTF-8 BOM at start of file (OpenSCAD reports a syntax error on line 1)")
    lines = raw.decode("utf-8-sig", errors="replace").splitlines()

    libs = load_json("libraries.json")
    fonts_installed = set((load_json("fonts-installed.json") or {}).get("fontNames", []))
    fonts_catalog_data = load_json("fonts-catalog.json")
    fonts_catalog = set()
    if isinstance(fonts_catalog_data, dict):
        for v in fonts_catalog_data.values():
            if isinstance(v, list):
                fonts_catalog.update(x for x in v if isinstance(x, str))
    elif isinstance(fonts_catalog_data, list):
        fonts_catalog.update(x for x in fonts_catalog_data if isinstance(x, str))
    installed_families = {f.split(":")[0] for f in fonts_installed}
    prefixes = library_prefixes(libs)
    if libs is None:
        report.add("WARN", "P02", 0, "docs/pmm/data/libraries.json missing -- library check skipped")
    if not fonts_installed:
        report.add("WARN", "P04", 0, "docs/pmm/data/fonts-installed.json missing -- font check skipped")

    definitions = {}
    uses_bosl2 = False
    has_plates = False
    brace_depth = 0
    paren_depth = 0
    stmt_open = False          # inside an unfinished top-level statement
    top_level_calls = []
    string_vars = {}           # name -> (value, line) for `name = "text";`
    font_var_uses = []         # (variable name, line) for `font = name`

    def check_font(name, line_no):
        if not fonts_installed:
            return
        if name in fonts_installed or (":" not in name and name in installed_families):
            return
        if name in fonts_catalog or name.split(":")[0] in {c.split(":")[0] for c in fonts_catalog}:
            report.add("ERROR", "P04", line_no, f'font "{name}" is only in PMM\'s DISPLAY catalog, '
                       "not its INSTALLED inventory -- PMM may substitute another font")
        else:
            report.add("ERROR", "P04", line_no, f'font "{name}" is not in PMM\'s installed inventory')

    for no, line in enumerate(lines, start=1):
        if "// preview[" in line or "//preview[" in line:
            report.add("ERROR", "P05", no, "`// preview[...]` is a Thingiverse convention PMM ignores")

        m = INCLUDE_RE.match(line)
        if m:
            target = m.group(2)
            if target.startswith("BOSL2/"):
                uses_bosl2 = True
            if not any(target.startswith(p) for p in prefixes) and libs is not None:
                report.add("ERROR", "P01", no, f"include/use <{target}> is not a PMM-bundled library; "
                           "local includes must be flattened by the build")
            continue

        pm = PARAM_RE.match(line)
        if pm:
            name, value, kind = pm.groups()
            if kind == "color" and not HEX_RE.match(value):
                report.add("ERROR", "P03", no, f'{name} = "{value}" -- PMM color picker needs a hex '
                           'string like "#RRGGBB"')
            if kind == "font":
                check_font(value, no)

        code = strip_comment(line)
        for fm in FONT_LITERAL_RE.finditer(code):
            check_font(fm.group(1), no)
        for fv in FONT_VAR_RE.finditer(code):
            font_var_uses.append((fv.group(1), no))
        sa = STRING_ASSIGN_RE.match(code)
        if sa:
            string_vars[sa.group(1)] = (sa.group(2), no)
        for im in IMPORT_RE.finditer(code):
            if os.path.basename(im.group(1)) not in DEFAULT_ASSETS:
                report.add("ERROR", "P07", no, f'import("{im.group(1)}") -- PMM only supports uploads '
                           "named default.stl / default.svg / default.png")

        dm = DEF_RE.match(code)
        call_zone = code
        if dm:
            name = dm.group(2)
            if name.startswith("mw_plate_"):
                has_plates = True
            definitions.setdefault((dm.group(1), name), []).append(no)
            call_zone = code[dm.end():]   # the definition's own name is not a call
        for cm in MW_CALL_RE.finditer(call_zone):
            report.add("ERROR", "P06", no, f"{cm.group(1)}() is called directly -- PMM calls "
                       "output modules itself; put shared geometry in a helper module")

        # Top-level geometry detection: a statement START (depth 0, previous
        # statement finished) that begins with a call. Multi-line function
        # bodies (`function f() = let(...)` ...) stay inside one statement
        # until their closing `;`, so their continuation lines never count.
        stripped = code.strip()
        if stripped:
            if brace_depth == 0 and paren_depth == 0 and not stmt_open:
                cm2 = CALL_START_RE.match(stripped)
                if cm2 and cm2.group(1) not in NOT_GEOMETRY and not dm:
                    top_level_calls.append(no)
            no_strings = re.sub(r'"(?:\\.|[^"\\])*"', '""', code)
            brace_depth += no_strings.count("{") - no_strings.count("}")
            paren_depth += no_strings.count("(") - no_strings.count(")")
            stmt_open = not (brace_depth == 0 and paren_depth == 0
                             and (stripped.endswith(";") or stripped.endswith("}")))

        sm = re.match(r'^\s*mw_plate_size\s*=\s*([\d.]+)\s*;', line)
        if sm and float(sm.group(1)) > PMM_PLATE_CEILING:
            report.add("WARN", "P11", no, f"mw_plate_size = {sm.group(1)} exceeds the ~{PMM_PLATE_CEILING} mm "
                       "practical PMM plate ceiling; oversize plates can fail 3MF generation")

    # Fonts passed through a variable: `font = my_font` -> check my_font's string.
    checked = set()
    for var, use_line in font_var_uses:
        if var in string_vars and var not in checked:
            checked.add(var)
            value, def_line = string_vars[var]
            check_font(value, def_line)

    for (kind, name), where in definitions.items():
        if len(where) > 1:
            report.add("ERROR", "P08", where[-1], f"{kind} {name}() defined {len(where)} times "
                       f"(lines {', '.join(map(str, where))}) -- the LAST definition silently wins")

    if uses_bosl2:
        bosl2_dir = find_bosl2_dir()
        if bosl2_dir is None:
            report.add("WARN", "P09", 0, "bundle includes BOSL2 but no local BOSL2 checkout was found -- "
                       "name-collision check skipped (set OPENSCADPATH)")
        else:
            symbols = bosl2_symbols(bosl2_dir)
            for (kind, name), where in definitions.items():
                if name in symbols:
                    report.add("ERROR", "P09", where[0], f"{kind} {name}() collides with a BOSL2 "
                               "symbol -- rename it (docs/openscad/libraries-and-fonts.md)")

    if has_plates and top_level_calls:
        report.add("WARN", "P12", top_level_calls[0], "mw_plate_N() modules are defined but the bundle "
                   "also has top-level geometry calls -- PMM renders plates itself")

    print(f"PMM lint: {report.errors} error(s), {report.warnings} warning(s)")
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
