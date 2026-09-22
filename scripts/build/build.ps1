# ============================================================
# <PROJECT NAME>  |  MakerWorld bundle builder
# ------------------------------------------------------------
# Produces dist/<PROJECT_SLUG>_makerworld.scad: ONE self-contained .scad
# file with no local include/use, which is what MakerWorld's Parametric
# Model Maker (PMM) needs -- it takes a single .scad upload and does not
# support arbitrary local include trees (docs/pmm/compatibility-rules.md).
#
# Never edits sources; only writes the bundle. Re-run after ANY change
# to a file listed in SOURCE_FILES (scripts/project_config.sh) -- this is
# standing directive #1 in AGENTS.md.
#
# The transformation rules live in Bundle.psm1 (shared with dev_build.ps1).
# In MakerWorld mode:
#   - local include/use lines are dropped; PMM-bundled library includes
#     (BUNDLED_LIBRARIES) are kept verbatim
#   - // BUILD:EXCLUDE-START .. -END blocks are dropped (each source file
#     wraps its own standalone preview call in them)
#   - comments are dropped, EXCEPT params.scad comments in every tab other
#     than [Hidden] (they are PMM's in-UI help text) and same-line widget
#     syntax (// [..], // font, // color)
#   - color(<identifier>) calls are flattened to MAKERWORLD_COLOR unless
#     the identifier is listed in COLOR_PASSTHROUGH
#   - `mw_plate_size` and `mw_assembly_views` are injected right after
#     params.scad (values from scripts/plates_config.sh)
#   - the README description span is copied into the header comment
#   - MAKERWORLD_TOP_LEVEL_CALL (if set) is appended as the last line
#
# Usage:
#   scripts\build.bat                                   (double-click)
#   powershell -File scripts/build/build.ps1
#   powershell -File scripts/build/build.ps1 -Project examples/demo
# See: docs/toolchain/pipelines.md ("MakerWorld bundle")
# ============================================================
param([string]$Project = "")

$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSScriptRoot "Bundle.psm1") -Force

$ctx = Get-ProjectContext -Project $Project
$plates = Update-PlatesJson -Ctx $ctx
Assert-PlateModulesMatch -Ctx $ctx -Plates $plates
Assert-AssemblyViewsExist -Ctx $ctx -Plates $plates
$injected = @(Get-BundleInjectedLines -Ctx $ctx -Plates $plates)

$bundle = New-Object System.Collections.Generic.List[string]
$bundle.Add("// ============================================================")
$bundle.Add("// $($ctx.Name)  |  MAKERWORLD BUNDLE")
$bundle.Add("// ============================================================")
$bundle.Add("// GENERATED FILE -- do not edit. Built from this project's lib/,")
$bundle.Add("// parts/ and assembly/ sources by scripts/build/build.ps1.")
$bundle.Add("//")
$bundle.Add("// Made for the MakerWorld Parametric Model Maker (PMM) customizer.")
if ($ctx.TopLevelCall -eq "") {
    $bundle.Add("// It has no top-level render call: PMM invokes the mw_plate_N() and")
    $bundle.Add("// mw_assembly_view() modules itself, so opening this file in the")
    $bundle.Add("// OpenSCAD desktop app shows an empty preview. That is expected.")
}
$bundle.Add("// ============================================================")

$description = Get-ReadmeDescription -Ctx $ctx
if ($description.Count -gt 0) {
    $bundle.Add("//")
    $bundle.Add("// PROJECT DESCRIPTION")
    $bundle.Add("//")
    foreach ($l in $description) { $bundle.Add($l) }
    $bundle.Add("// ============================================================")
}
$bundle.Add("")

foreach ($file in $ctx.SourceFiles) {
    $path = Join-Path $ctx.Dir $file
    if (-not (Test-Path $path)) { throw "Source file not found (SOURCE_FILES): $file" }
    $isParams = ($file -eq $ctx.ParamsFile)
    $lines = @(Get-Content -Path $path -Encoding UTF8)

    $bundle.Add("// ---- from $file ----")
    foreach ($l in (Select-BundleLines -Lines $lines -IsParams $isParams -Mode "makerworld" -Ctx $ctx)) {
        $bundle.Add($l)
    }
    if ($isParams) {
        foreach ($l in $injected) { $bundle.Add($l) }
    }
    $bundle.Add("")
}

if ($ctx.TopLevelCall -ne "") {
    $bundle.Add("// ---- top-level render call (MAKERWORLD_TOP_LEVEL_CALL) ----")
    $bundle.Add($ctx.TopLevelCall)
}

Write-Utf8NoBom -Path $ctx.MakerWorldOut -Lines $bundle
Write-Host "MakerWorld bundle written: $($ctx.MakerWorldOut)"
