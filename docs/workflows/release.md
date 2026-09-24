# Workflow: cut a release

> **Goal.** A tagged version whose bundle, docs, changelog and assets all agree. **Only when the
> user asks for a release** (standing directive).

## Checklist

1. **Pick the version** by the rules in
   [versioning-and-changelog.md](../conventions/versioning-and-changelog.md).
2. **Refresh inventories:** `python scripts/shared/pmm_inventory.py`. If they changed, re-run the
   checks.
3. **Build and check:** `scripts\build.bat`, `scripts\dev_build.bat`, `scripts\check.bat`. Everything
   must be green.
4. **`CHANGELOG.md`:** move `[Unreleased]` entries under `## [x.y.z] - YYYY-MM-DD`, leave an empty
   `## [Unreleased]`, and update the compare links at the bottom.
5. **`dist/makerworld_listing.md`:** add a `### x.y.z` entry to its changelog with the
   **customer-facing** subset only. Say which parts to reprint if a fix changes one.
6. **README:** confirm the features and parts match the release (the parameter tables are
   generated, and the freshness check confirms they match).
7. **Assets (only if geometry changed and the user asked):** re-render images
   (`scripts\render.bat`), re-export default STLs into `stl/`, regenerate or re-save curated
   `printables/`. Delete stale ones.
8. **Commit:** `Bump to vX.Y.Z: <summary>`.
9. **Tag:** `git tag vX.Y.Z` and push the commit and tag when asked.
10. **Publish:** [publish-to-makerworld.md](publish-to-makerworld.md).
