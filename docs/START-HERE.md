# Start here

## What this is

A **GitHub template** for parametric OpenSCAD models published through **MakerWorld's
Parametric Model Maker (PMM)**, plus a **reference library** of everything PMM-specific, written
for both humans and AI assistants.

It was extracted from a real, released multi-part PMM project and generalized. It gives you:

| You get | Where |
|---|---|
| A source layout that scales past one file (`lib/` → `parts/` → `assembly/`) | repo root |
| A build that flattens it into the single `.scad` PMM accepts | `scripts/build/` |
| A PMM compatibility **lint** (12 rules) and a **smoke** check that builds every plate from the shipped file | `scripts/check/` |
| A render manager with crop-free camera fitting | `scripts/render/` |
| A Bambu Studio multi-plate `.3mf` exporter | `scripts/export/` |
| One plates config shared by the MakerWorld build and the Bambu export, checked at build time | `scripts/plates_config.sh` |
| Agent directives any AI tool reads | `AGENTS.md` (imported by `CLAUDE.md`) |
| PMM specification, rules, sources, and inventory snapshots | `docs/pmm/` |
| Conventions, toolchain and workflow docs | `docs/` |
| A runnable two-part example | `examples/demo/` |

Everything is project-agnostic: `<ANGLE BRACKET>` tokens and `REPLACE ME` markers show what to
fill in.

## Three ways to use it

1. **Start a new project:** [workflows/new-project.md](workflows/new-project.md).
2. **Bring an existing OpenSCAD model to PMM:** follow new-project, move your code into `parts/`
   and `lib/`, then let `scripts\check.bat` tell you what PMM won't accept.
3. **As a reference only:** read [INDEX.md](INDEX.md), or point your AI assistant at
   `AGENTS.md` and `llms.txt`.

## Five-minute tour

```bat
scripts\build.bat examples\demo      :: flatten the demo into one PMM file
scripts\check.bat examples\demo      :: lint it and build every plate from it
```

Open `examples/demo/dist/sliding_lid_box_makerworld.scad` to see what PMM receives, and
`examples/demo/assembly/assembly_main.scad` in OpenSCAD to see the model.

## How the pieces tie together

```
lib/params.scad ──include──> parts/*.scad ──use──> assembly/assembly_main.scad
      │                                                  │ mw_plate_N()
      │            scripts/project_config.sh (SOURCE_FILES, colors, libraries)
      │            scripts/plates_config.sh ──validates──┘
      ▼
scripts/build/build.ps1 ──> dist/<slug>_makerworld.scad ──> scripts/check/ ──> MakerWorld
      ▲
README.md (BUNDLE-DESCRIPTION span is copied into the bundle header)
```

Every file's header comment names the files it's coupled to and the doc that explains it.

## Requirements

OpenSCAD (a development snapshot is recommended), Python 3, PowerShell and Git Bash. Optional:
Bambu Studio, BOSL2. Details: [toolchain/setup.md](toolchain/setup.md).

## About the boilerplate itself

History: [BOILERPLATE-CHANGELOG.md](BOILERPLATE-CHANGELOG.md). A project created from the template
keeps its own `CHANGELOG.md` at the root.
