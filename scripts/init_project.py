#!/usr/bin/env python3
# ============================================================
# MakerWorld PMM OpenSCAD boilerplate  |  Project initializer
# ------------------------------------------------------------
# Turns the template into YOUR project in one step:
#   - replaces the template tokens in every project text file:
#       <PROJECT NAME>  <OWNER>  <REPO>  <YEAR>  <COPYRIGHT HOLDER>
#   - sets PROJECT_SLUG in scripts/project_config.sh and the 3MF output name
#   - removes the TEMPLATE banner from README.md
#   - optionally deletes examples/ (--drop-examples)
# Then it lists the MANUAL placeholders still left (README sections, the
# AGENTS.md project overview, REPLACE ME markers in the .scad stubs).
#
# docs/ is deliberately NOT rewritten: the reference docs mention these
# tokens as documentation, and stay generic.
#
# Usage:
#   python scripts/init_project.py --name "Spice Rack" --slug spice_rack \
#       --owner my-github-user --repo spice-rack --holder "Jane Doe"
#   python scripts/init_project.py --check        # just list what is left
#   add --dry-run to see what would change, --drop-examples to delete examples/
# See: docs/workflows/new-project.md
# ============================================================
import argparse
import datetime
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXT_SUFFIXES = {".md", ".scad", ".sh", ".ps1", ".psm1", ".py", ".bat", ".cmd", ".txt",
                 ".json", ".yml", ".yaml", ".code-workspace", ""}
SKIP_DIRS = {".git", "docs", "examples", ".build", "__pycache__", ".claude", ".vscode"}
SKIP_FILES = {"scripts/init_project.py"}
BANNER_RE = re.compile(r"<!-- TEMPLATE-BANNER:START.*?<!-- TEMPLATE-BANNER:END -->\n*", re.S)
SLUG_RE = re.compile(r"^[a-z][a-z0-9_]*$")
# Manual placeholders: <UPPER CASE WORDS ...> (containing a space), the known
# one-word tokens, and REPLACE ME markers. One-word forms like <PERSPECTIVE>
# or <PROJECT_SLUG> are naming PATTERNS in comments, not placeholders.
MANUAL_RE = re.compile(r"<[A-Z][A-Z0-9_\-]* [A-Z0-9 _\-]+(?::[^>]*)?>|<(?:OWNER|REPO|YEAR)>|REPLACE ME")
GENERATED_RE = re.compile(r"^(?:.*/)?dist/[^/]+\.scad$")
# In the project's own prose docs, ANY <text with spaces> is a placeholder
# (e.g. <Part name>, <what it does>); HTML comments and <https://...> are not.
PROSE_DOCS = {"README.md", "AGENTS.md", "CHANGELOG.md", "LICENSE", "dist/makerworld_listing.md"}
PROSE_RE = re.compile(r"<(?![!/]|https?:)[^<>]*\s[^<>]*>")


def project_files():
    for path in ROOT.rglob("*"):
        rel = path.relative_to(ROOT)
        if not path.is_file() or any(part in SKIP_DIRS for part in rel.parts):
            continue
        if rel.as_posix() in SKIP_FILES or GENERATED_RE.match(rel.as_posix()):
            continue   # generated bundles are rebuilt, never edited
        if path.suffix.lower() in TEXT_SUFFIXES or path.name in {"LICENSE", ".gitignore",
                                                                 ".gitattributes", ".editorconfig"}:
            yield path


def report_leftovers():
    found = 0
    for path in sorted(project_files()):
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        rel = path.relative_to(ROOT).as_posix()
        pattern = PROSE_RE if rel in PROSE_DOCS else MANUAL_RE
        for no, line in enumerate(lines, start=1):
            if pattern is PROSE_RE and "REPLACE ME" in line:
                print(f"  {rel}:{no}: REPLACE ME")
                found += 1
            for m in pattern.finditer(line):
                print(f"  {path.relative_to(ROOT).as_posix()}:{no}: {m.group(0)}")
                found += 1
    print(f"{found} placeholder(s) left to fill by hand." if found else "No placeholders left.")
    return found


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--name", help='human-readable project name, e.g. "Parametric Spice Rack"')
    ap.add_argument("--slug", help="lowercase_underscore slug for output files, e.g. spice_rack")
    ap.add_argument("--owner", help="GitHub user or organization")
    ap.add_argument("--repo", help="GitHub repository name")
    ap.add_argument("--holder", help="copyright holder for LICENSE")
    ap.add_argument("--year", default=str(datetime.date.today().year))
    ap.add_argument("--drop-examples", action="store_true", help="delete examples/")
    ap.add_argument("--check", action="store_true", help="only list remaining placeholders")
    ap.add_argument("--dry-run", action="store_true", help="show changes without writing")
    args = ap.parse_args()

    if args.check:
        return 1 if report_leftovers() else 0

    if args.slug and not SLUG_RE.match(args.slug):
        print(f"--slug must match {SLUG_RE.pattern} (e.g. spice_rack)", file=sys.stderr)
        return 1

    tokens = {}
    if args.name:
        tokens["<PROJECT NAME>"] = args.name
    if args.owner:
        tokens["<OWNER>"] = args.owner
    if args.repo:
        tokens["<REPO>"] = args.repo
    if args.holder:
        tokens["<COPYRIGHT HOLDER>"] = args.holder
    tokens["<YEAR>"] = args.year

    old_slug = None
    if args.slug:
        m = re.search(r'^PROJECT_SLUG="(.*)"$',
                      (ROOT / "scripts" / "project_config.sh").read_text(encoding="utf-8"), re.M)
        old_slug = m.group(1) if m and m.group(1) != args.slug else None

    changed = 0
    for path in project_files():
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        new = text
        for token, value in tokens.items():
            new = new.replace(token, value)
        rel = path.relative_to(ROOT).as_posix()
        if rel == "README.md":
            new = BANNER_RE.sub("", new, count=1)
        if args.slug and rel == "scripts/project_config.sh":
            new = re.sub(r'^PROJECT_SLUG=".*"$', f'PROJECT_SLUG="{args.slug}"', new, flags=re.M)
        if args.slug and rel == "scripts/export_3mf_config.sh":
            new = new.replace('OUTPUT="printables/project_generated.3mf"',
                              f'OUTPUT="printables/{args.slug}_generated.3mf"')
        if new != text:
            changed += 1
            print(f"{'would update' if args.dry_run else 'updated'}  {rel}")
            if not args.dry_run:
                # Preserve each file's existing line endings (.bat/.ps1 are CRLF).
                with open(path, "w", encoding="utf-8", newline="") as f:
                    f.write(new)

    # Bundles named after the old slug would be orphaned: remove them. The
    # next build writes dist/<new slug>_makerworld.scad.
    if old_slug:
        for stale in (ROOT / "dist").glob(f"{old_slug}_*.scad"):
            print(f"{'would delete' if args.dry_run else 'deleted'}  dist/{stale.name} (old slug)")
            if not args.dry_run:
                stale.unlink()

    if args.drop_examples and (ROOT / "examples").exists():
        print(f"{'would delete' if args.dry_run else 'deleted'}  examples/")
        if not args.dry_run:
            shutil.rmtree(ROOT / "examples")

    print(f"{changed} file(s) {'would change' if args.dry_run else 'changed'}.")
    print("\nStill to fill in by hand:")
    report_leftovers()
    print("\nNext: rebuild (scripts\\build.bat), then docs/workflows/new-project.md step 4 onwards.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
