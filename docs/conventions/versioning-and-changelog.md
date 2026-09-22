# Versioning and changelog

> **Scope.** How versions are numbered and how the two changelogs (`CHANGELOG.md` and the listing
> changelog in `dist/makerworld_listing.md`) are kept.

## Semantic Versioning for a parametric model

The customizer parameters are the model's **public API**: customers save presets and remix
against them.

| Bump | When | Examples |
|---|---|---|
| **MAJOR** `x.0.0` | Existing customer settings no longer produce the same object | renaming/removing a parameter; changing a dropdown's *value*; changing what a parameter means; changing a mating interface so old prints no longer fit new prints |
| **MINOR** `0.x.0` | New capability, old settings still work | new parameter, new part, new style option |
| **PATCH** `0.0.x` | Fixes, no new capability | geometry bug fix, default tweak, doc fix, script fix |

## Two changelogs, two audiences

| File | Audience | Contents |
|---|---|---|
| `CHANGELOG.md` | maintainers | **Everything**: geometry, parameters, scripts, docs, refactors |
| `dist/makerworld_listing.md` → *Changelog* | MakerWorld customers | Only what affects **what they print or customize**: features, fixes, parameter changes, and "reprint part X" advice. No scripts, refactors or tooling. |

## `CHANGELOG.md` format

[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/):

```markdown
## [Unreleased]

### Added
- ...
### Changed
### Fixed
### Removed
```

- Every change gets an entry **in the same change** that makes it (standing directive).
- Say **why** as well as what, especially for fixes: what was wrong, who is affected, and what
  to reprint.
- Omit empty groups.

## Releasing

Only when asked. Steps are in [../workflows/release.md](../workflows/release.md): move
`[Unreleased]` under `## [x.y.z] - YYYY-MM-DD`, update the compare links at the bottom, mirror the
customer-facing subset into the listing, then tag `vX.Y.Z`.

Compare-link format at the bottom of `CHANGELOG.md`:

```markdown
[Unreleased]: https://github.com/<OWNER>/<REPO>/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/<OWNER>/<REPO>/compare/v1.1.0...v1.2.0
[1.0.0]: https://github.com/<OWNER>/<REPO>/releases/tag/v1.0.0
```

Commit message convention for a release: `Bump to vX.Y.Z: <one-line summary>`.
