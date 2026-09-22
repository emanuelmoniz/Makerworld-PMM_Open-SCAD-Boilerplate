# PMM sources and evidence

> **Scope.** Where the claims in [specification.md](specification.md) and
> [compatibility-rules.md](compatibility-rules.md) come from, and how to re-verify them. When a
> source disagrees with observed PMM behavior, observed behavior wins. Record it here and update
> the affected doc.

## Primary reference: the unofficial PMM docs

**<https://github.com/nelsonjchen/unofficial-makerworld-parametric-model-maker-openscad-docs>**

A community-maintained, evidence-labelled compilation of everything known about PMM, written
to be read by both humans and agents. Its recommended read order:

1. `AGENTS.md`
2. `docs/pmm-openscad-api.md`: the author-facing API surface
3. `docs/agent-workflow.md`: procedure for porting a script to PMM
4. `docs/feature-reference.md`: every feature, with its release version and evidence
5. `docs/compatibility-rules.md`: constraints, with severity
6. `docs/gotchas.md`: pitfalls, with provenance
7. `docs/changelog.md`
8. `patterns/pmm-ready-template.scad`: a minimal PMM-ready script

It also has `checklists/` (migration, packaging, validation) and `data/` JSON indexes.

## Public PMM endpoints (no authentication)

The snapshot in [data/](data/) comes from these. Refresh it with
`python scripts/shared/pmm_inventory.py`.

| Data | URL |
|---|---|
| Bundled libraries | `https://makerworld.bblmw.com/makerworld/makerlab/content-generator/openscad/libraries-0.8.0.json` |
| **Installed** fonts | `https://makerworld.bblmw.com/makerworld/makerlab/content-generator/openscad/fonts-0.8.0.json` |
| Display font catalog | `https://makerworld.bblmw.com/makerworld/makerlab/content-generator/openscad/fonts-show-0.0.1.json` |
| Language → font family map | `https://makerworld.bblmw.com/makerworld/makerlab/content-generator/openscad/language2family-0.0.1.zip` |

> **URL correction (verified 2026-09-22):** the working URLs include a **`/makerworld/`** path
> segment. The same paths without it (as listed in the unofficial docs' `web-discovery.md`)
> return **HTTP 403**.
>
> The inventory files are versioned (`0.8.0`) independently of the PMM app version (`v1.1.x`).
> The live app may know fonts or libraries the snapshot doesn't. If a lint finding contradicts
> what you see working in PMM, test in PMM and note the result here.

## Official channels

- **PMM app:** <https://makerworld.com/makerlab/parametricModelMaker>. May show a Cloudflare
  challenge to non-browser clients.
- **Release notes:** MakerWorld forum announcements titled "Parametric Model Maker V0.x.0 …"
  (upload support v0.8.0, multi-color v0.9.0, multi-plate 3MF and font picker v0.10.0,
  backend refresh v1.1.0).
- **Employee answers:** MakerWorld forum threads on includes, "3MF cannot be generated"
  (oversize), and colors/`preview[]`. These are the source of the *Employee* evidence level.

## OpenSCAD language references

- Customizer manual: <https://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Customizer>
- `include` / `use`: <https://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Include_Statement>
- Text and fonts: <https://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Text>
- Development snapshots (Manifold): <https://openscad.org/downloads.html#snapshots>

## Verification log

| Date | What | Result |
|---|---|---|
| 2026-09-22 | Endpoint URLs with and without `/makerworld/` | with: 200, without: 403 |
| 2026-09-22 | `B612 Mono` in installed vs catalog inventories | catalog only |
| 2026-09-22 | Inventory snapshot | 7 libraries, 1615 installed font styles (280 families) |
