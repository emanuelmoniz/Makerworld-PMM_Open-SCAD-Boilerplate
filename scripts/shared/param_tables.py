#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  Parameter tables, generated from params.scad
# ------------------------------------------------------------
# lib/params.scad is the single source of truth for every customizer
# parameter; this script writes the parameter tables of the README and the
# MakerWorld listing from it, so they cannot drift from the code.
#
# WHERE: each file in PARAM_TABLES (scripts/project_config.sh) gets its
# table between two marker lines, replacing whatever is between them:
#     <!-- PARAMETERS:START -->
#     <!-- PARAMETERS:END -->
# Everything outside the markers stays hand-written.
#
# STYLES (the part after "|" in a PARAM_TABLES entry):
#   readme   one table per customizer tab: Parameter (the variable) |
#            Description | Default | Range
#   listing  one table for customers: Parameter (a readable label) |
#            Description | Compatibility, with a bold row per tab
#
# WHAT IT READS, per parameter in a user-facing tab (never [Hidden]):
#   // @label: Inside length          optional: customer label (listing)
#   // @note: Only with X on          optional: Compatibility (listing)
#   // Inside length (X), in mm       the help text: the comment line
#   inner_length = 80; // [30:1:200]  directly above; value; widget
# The @ lines must sit ABOVE the help line: OpenSCAD's customizer (and so
# PMM) only uses the one comment line directly above a parameter, and the
# MakerWorld build strips @ lines from the bundle. Without @label, the
# label is the variable name with spaces ("inner_length" -> "Inner length").
#
# Usage:
#   param_tables.py <project_dir>            rewrite the tables
#   param_tables.py <project_dir> --check    exit 1 if any table is stale
# The MakerWorld build (build.ps1) runs the rewrite; scripts/check/fresh.sh
# runs --check. See: docs/workflows/add-a-parameter.md
# ============================================================
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bash_config import parse_config  # noqa: E402

START = "<!-- PARAMETERS:START -->"
END = "<!-- PARAMETERS:END -->"

TAB_RE = re.compile(r'^\s*/\*\s*\[(.+?)\]\s*\*/\s*$')
PARAM_RE = re.compile(r'^\s*([A-Za-z_]\w*)\s*=\s*(.*)$')
META_RE = re.compile(r'^\s*//\s*@(label|note)\s*:\s*(.*?)\s*$')
COMMENT_RE = re.compile(r'^\s*//\s?(.*?)\s*$')
DEF_RE = re.compile(r'^\s*(module|function)\b')


def split_value(rest):
    """'80; // [30:1:200]' -> ('80', '[30:1:200]'): the value runs to the
    first ';' outside a string; the widget is the same-line // comment."""
    in_str = False
    for i, ch in enumerate(rest):
        if ch == '"' and (i == 0 or rest[i - 1] != '\\'):
            in_str = not in_str
        elif ch == ';' and not in_str:
            tail = rest[i + 1:].strip()
            widget = tail[2:].strip() if tail.startswith('//') else ''
            return rest[:i].strip(), widget
    return None, None


def parse_params(path):
    """[(tab, [param, ...]), ...] for the user-facing tabs, in file order."""
    tabs = []
    tab = None
    pending = []    # comment lines directly above the next statement
    with open(path, encoding='utf-8') as f:
        for line in f.read().splitlines():
            if DEF_RE.match(line):
                break                           # the customizer stops here
            m = TAB_RE.match(line)
            if m:
                name = m.group(1).strip()
                if name.lower() == 'hidden':
                    break
                tab = (name, [])
                tabs.append(tab)
                pending = []
                continue
            if not line.strip():
                pending = []
                continue
            if COMMENT_RE.match(line):
                pending.append(line)
                continue
            m = PARAM_RE.match(line)
            if m and tab is not None:
                value, widget = split_value(m.group(2))
                if value is not None:
                    meta = {}
                    help_text = ''
                    for c in pending:
                        mm = META_RE.match(c)
                        if mm:
                            meta[mm.group(1)] = mm.group(2)
                        else:
                            help_text = COMMENT_RE.match(c).group(1)
                    tab[1].append({'name': m.group(1), 'value': value, 'widget': widget,
                                   'help': help_text, 'label': meta.get('label', ''),
                                   'note': meta.get('note', '')})
            pending = []
    return [t for t in tabs if t[1]]


def dropdown(widget):
    """'[a:Label A, b:Label B]' -> [('a', 'Label A'), ...]; None otherwise."""
    if not (widget.startswith('[') and widget.endswith(']')):
        return None
    body = widget[1:-1]
    if re.fullmatch(r'\s*-?[\d.]+\s*(:\s*-?[\d.]+\s*){1,2}', body):
        return None                             # a slider
    items = []
    for part in body.split(','):
        part = part.strip()
        if ':' in part:
            v, label = part.split(':', 1)
            items.append((v.strip(), label.strip()))
        else:
            items.append((part, part))
    return items


def unquote(value):
    return value[1:-1] if len(value) >= 2 and value[0] == value[-1] == '"' else value


def fmt_default(p, customer):
    v = p['value']
    if v in ('true', 'false'):
        return 'on' if v == 'true' else 'off'
    items = dropdown(p['widget'])
    if items and customer:
        for val, label in items:
            if unquote(val) == unquote(v):
                return label
    return unquote(v)


def fmt_range(p):
    w, v = p['widget'], p['value']
    if w == 'color':
        return 'color picker'
    if w == 'font':
        return 'font picker'
    if re.fullmatch(r'\d+', w):
        return f'text, up to {w} characters'
    m = re.fullmatch(r'\[\s*(-?[\d.]+)\s*:\s*(-?[\d.]+)\s*(?::\s*(-?[\d.]+)\s*)?\]', w)
    if m:
        lo, a, b = m.group(1), m.group(2), m.group(3)
        return f'{lo}–{b}, step {a}' if b is not None else f'{lo}–{a}'
    items = dropdown(w)
    if items:
        return ', '.join(unquote(val) for val, _ in items)
    if v in ('true', 'false'):
        return 'on/off'
    if v.startswith('"'):
        return 'text'
    return '—'


def cell(text):
    return (text or '').replace('|', '\\|')


def label_of(p):
    if p['label']:
        return p['label']
    words = p['name'].replace('_', ' ').strip()
    return words[:1].upper() + words[1:]


def table_readme(tabs):
    out = []
    for name, params in tabs:
        out += ['', f'### {name}', '',
                '| Parameter | Description | Default | Range |', '|---|---|---|---|']
        for p in params:
            out.append(f"| `{p['name']}` | {cell(p['help'])} | {cell(fmt_default(p, False))} "
                       f"| {cell(fmt_range(p))} |")
    return out + ['']


def table_listing(tabs):
    out = ['', '| Parameter | Description | Compatibility |', '|---|---|---|']
    for name, params in tabs:
        out.append(f'| **{cell(name)}** | | |')
        for p in params:
            out.append(f"| {cell(label_of(p))} | {cell(p['help'])} | {cell(p['note'])} |")
    return out + ['']


STYLES = {'readme': table_readme, 'listing': table_listing}


def render(text, table_lines, path):
    lines = text.splitlines()
    try:
        s = next(i for i, l in enumerate(lines) if l.strip() == START)
        e = next(i for i, l in enumerate(lines) if l.strip() == END and i > s)
    except StopIteration:
        raise SystemExit(f'{path}: missing {START} / {END} markers (PARAM_TABLES)')
    new = lines[:s + 1] + table_lines + lines[e:]
    nl = '\r\n' if '\r\n' in text else '\n'      # keep the file's line endings
    return nl.join(new) + (nl if text.endswith('\n') else '')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    check = '--check' in sys.argv
    if len(args) != 1:
        raise SystemExit('usage: param_tables.py <project_dir> [--check]')
    project = args[0]
    cfg = parse_config(os.path.join(project, 'scripts', 'project_config.sh'))
    entries = cfg.get('PARAM_TABLES', [])
    if not entries:
        return 0
    tabs = parse_params(os.path.join(project, cfg.get('PARAMS_FILE', 'lib/params.scad')))

    stale = []
    for entry in entries:
        rel, _, style = entry.partition('|')
        style = style.strip() or 'readme'
        if style not in STYLES:
            raise SystemExit(f'PARAM_TABLES: unknown style "{style}" in "{entry}"')
        path = os.path.join(project, rel.strip())
        with open(path, encoding='utf-8', newline='') as f:
            text = f.read()
        new = render(text, STYLES[style](tabs), rel)
        if new != text:
            stale.append(rel.strip())
            if not check:
                with open(path, 'w', encoding='utf-8', newline='') as f:
                    f.write(new)

    if check:
        for rel in stale:
            print(f'  STALE  {rel}: parameter table differs from params.scad -- run the MakerWorld build')
        return 1 if stale else 0
    for rel in stale:
        print(f'Parameter table updated: {rel}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
