# ============================================================
# <PROJECT NAME>  |  Shared bundle-building module (PowerShell)
# ------------------------------------------------------------
# Imported by scripts/build/build.ps1 (MakerWorld bundle) and
# scripts/build/dev_build.ps1 (local dev bundle). Every rule for turning
# the multi-file source tree into ONE .scad file lives here, ONCE -- the
# original project carried two independent copies of this logic that
# could (and did) drift apart.
#
# Compatible with Windows PowerShell 5.1 AND PowerShell 7 (pwsh, used by
# CI on Linux). Do not use PS7-only syntax here (??, ?:, -AsHashtable).
#
# What a bundle build does, in order (see docs/toolchain/pipelines.md):
#   1. read scripts/project_config.sh + scripts/plates_config.sh
#      (bash files, parsed through scripts/shared/bash_config.py)
#   2. regenerate <project>/.build/plates.json
#   3. VALIDATE the assembly file's mw_plate_N() modules against it
#   4. validate ASSEMBLY_PLATE_VIEWS, resolve mw_plate_size, and inject
#      both (mw_plate_size, mw_assembly_views) after params.scad
#   5. concatenate SOURCE_FILES through Select-BundleLines (below)
#   6. write the result as UTF-8 WITHOUT a BOM (OpenSCAD rejects a BOM:
#      "syntax error ... line 1")
# ============================================================

Set-StrictMode -Version 2.0

$script:ScriptsDir = Split-Path -Parent $PSScriptRoot
$script:RepoRoot   = Split-Path -Parent $script:ScriptsDir
$script:SharedDir  = Join-Path $script:ScriptsDir "shared"

# ---- Python discovery ------------------------------------------------------
# PYTHON_BIN env var first; then the names that exist on each OS. Every
# candidate is actually executed, because on Windows `python3` is often
# the Microsoft Store stub that exists but only prints an install hint.
function Get-PythonCommand {
    $candidates = @()
    if ($env:PYTHON_BIN) { $candidates += $env:PYTHON_BIN }
    $candidates += @("python", "python3", "py")
    foreach ($c in $candidates) {
        try {
            & $c -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { return $c }
        } catch { }
    }
    throw "Python 3.8+ not found. Install it or set PYTHON_BIN. See docs/toolchain/setup.md"
}

function Invoke-SharedPython {
    param([Parameter(Mandatory = $true)][string]$Script, [string[]]$Arguments = @())
    $py = Get-PythonCommand
    $output = & $py (Join-Path $script:SharedDir $Script) @Arguments
    if ($LASTEXITCODE -ne 0) { throw "scripts/shared/$Script failed (exit $LASTEXITCODE)." }
    return $output
}

function Read-BashConfig {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path $Path)) { throw "Config file not found: $Path" }
    $json = (Invoke-SharedPython -Script "bash_config.py" -Arguments @($Path)) -join "`n"
    return ($json | ConvertFrom-Json)
}

# Returns $Default when the config object has no such property or it is empty.
function Get-ConfigValue {
    param($Config, [string]$Name, $Default = $null)
    $prop = $Config.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value -or "$($prop.Value)" -eq "") { return $Default }
    return $prop.Value
}

# ---- Project context -------------------------------------------------------
# A "project" is any folder with lib/ parts/ assembly/ and a scripts/
# folder holding project_config.sh + plates_config.sh. The repo root is the
# default project; examples/demo is another one, built by the SAME scripts
# with `-Project examples/demo`.
function Get-ProjectContext {
    param([string]$Project = "")

    if ($Project -eq "") { $projectDir = $script:RepoRoot }
    elseif ([System.IO.Path]::IsPathRooted($Project)) { $projectDir = $Project }
    else { $projectDir = Join-Path $script:RepoRoot $Project }
    $projectDir = (Resolve-Path $projectDir).Path

    $cfg = Read-BashConfig (Join-Path $projectDir "scripts/project_config.sh")
    $slug = Get-ConfigValue $cfg "PROJECT_SLUG" "project"

    return [pscustomobject]@{
        Dir              = $projectDir
        Config           = $cfg
        Name             = Get-ConfigValue $cfg "PROJECT_NAME" "Untitled project"
        Slug             = $slug
        SourceFiles      = @(Get-ConfigValue $cfg "SOURCE_FILES" @())
        ParamsFile       = Get-ConfigValue $cfg "PARAMS_FILE" "lib/params.scad"
        PlateFile        = Get-ConfigValue $cfg "PLATE_ASSEMBLY_FILE" ""
        BundledLibraries = @(Get-ConfigValue $cfg "BUNDLED_LIBRARIES" @())
        FlattenColors    = ((Get-ConfigValue $cfg "FLATTEN_COLORS" "true") -eq "true")
        MakerWorldColor  = Get-ConfigValue $cfg "MAKERWORLD_COLOR" "#1a2f4a"
        ColorPassthrough = @(Get-ConfigValue $cfg "COLOR_PASSTHROUGH" @())
        TopLevelCall     = Get-ConfigValue $cfg "MAKERWORLD_TOP_LEVEL_CALL" ""
        DevViews         = @(Get-ConfigValue $cfg "DEV_VIEWS" @())
        ReadmeFile       = Get-ConfigValue $cfg "README_FILE" "README.md"
        DescStart        = Get-ConfigValue $cfg "README_DESCRIPTION_START" "<!-- BUNDLE-DESCRIPTION:START -->"
        DescEnd          = Get-ConfigValue $cfg "README_DESCRIPTION_END" "<!-- BUNDLE-DESCRIPTION:END -->"
        DistDir          = Join-Path $projectDir "dist"
        MakerWorldOut    = Join-Path $projectDir ("dist/{0}_makerworld.scad" -f $slug)
        DevOut           = Join-Path $projectDir ("dist/{0}_dev.scad" -f $slug)
        PlatesConfig     = Join-Path $projectDir "scripts/plates_config.sh"
        PlatesJson       = Join-Path $projectDir ".build/plates.json"
    }
}

# ---- Plates: regenerate, validate, size ------------------------------------
function Update-PlatesJson {
    param([Parameter(Mandatory = $true)]$Ctx)
    Invoke-SharedPython -Script "generate_plates_json.py" -Arguments @($Ctx.PlatesConfig, $Ctx.PlatesJson) | Out-Null
    return (Get-Content -Path $Ctx.PlatesJson -Raw | ConvertFrom-Json)
}

# Checks that each mw_plate_N() module in the plate assembly file calls
# the same part modules, the same number of times, as plates_config.sh
# says that plate holds. Fails the build on drift -- the single most
# valuable guard in this toolchain: it stops a MakerWorld bundle shipping
# a different part set than the Bambu 3mf export.
#
# Relies on the naming convention "a part file's main module has the same
# name as the file" (parts/lid.scad -> module lid()), see
# docs/conventions/naming.md.
#
# Heuristic, not a parser: finds the module by regex and extracts its body
# by counting braces per line (trailing // comments stripped first), then
# counts `\bname\s*\(` matches. Known limits: a call split across lines,
# or a brace inside a string literal, confuses it.
function Assert-PlateModulesMatch {
    param([Parameter(Mandatory = $true)]$Ctx, [Parameter(Mandatory = $true)]$Plates)

    if ($Ctx.PlateFile -eq "") { return }
    $plateFilePath = Join-Path $Ctx.Dir $Ctx.PlateFile
    if (-not (Test-Path $plateFilePath)) { throw "PLATE_ASSEMBLY_FILE not found: $($Ctx.PlateFile)" }
    $lines = @(Get-Content -Path $plateFilePath)

    foreach ($plate in @($Plates.plates)) {
        if ($null -eq $plate.PSObject.Properties["mw_plate"]) { continue }
        $moduleName = "mw_plate_$($plate.mw_plate)"

        $start = $null
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^\s*module\s+$moduleName\s*\(\s*\)") { $start = $i; break }
        }
        if ($null -eq $start) {
            throw "plates_config.sh plate '$($plate.name)' maps to $moduleName(), but " +
                  "$($Ctx.PlateFile) has no 'module $moduleName()'."
        }

        $depth = 0; $seenBrace = $false
        $body = New-Object System.Collections.Generic.List[string]
        for ($i = $start; $i -lt $lines.Count; $i++) {
            $line = $lines[$i] -replace '//.*$', ''
            $open = ([regex]::Matches($line, '\{')).Count
            $close = ([regex]::Matches($line, '\}')).Count
            if ($open -gt 0) { $seenBrace = $true }
            $depth += $open - $close
            $body.Add($line)
            if ($seenBrace -and $depth -le 0) { break }
        }
        $bodyText = $body -join "`n"

        $expected = @{}
        foreach ($part in @($plate.parts)) {
            $name = [System.IO.Path]::GetFileNameWithoutExtension($part.path)
            if ($expected.ContainsKey($name)) { $expected[$name] += 1 } else { $expected[$name] = 1 }
        }
        foreach ($name in $expected.Keys) {
            $actual = ([regex]::Matches($bodyText, "\b$([regex]::Escape($name))\s*\(")).Count
            if ($actual -ne $expected[$name]) {
                throw "Plate '$($plate.name)' ($moduleName) drift: plates_config.sh expects " +
                      "$($expected[$name]) call(s) to '$name(...)', $($Ctx.PlateFile) has $actual."
            }
        }
    }
}

function Get-AssemblyViews {
    param([Parameter(Mandatory = $true)]$Plates)
    $ap = $Plates.PSObject.Properties["assembly_plate"]
    if ($null -eq $ap -or $null -eq $ap.Value.views) { return @() }
    return @($ap.Value.views)
}

# Fails the build if an ASSEMBLY_PLATE_VIEWS entry (plates_config.sh section
# 3) cannot actually render. View "<name>" needs, somewhere in SOURCE_FILES,
# `module assembly_<name>()` and `function assembly_<name>_footprint()`,
# plus a `name == "<name>"` branch in BOTH dispatchers (assembly_view() and
# assembly_view_footprint()) in PLATE_ASSEMBLY_FILE. Without this check an
# unknown view would just be skipped and MakerWorld's preview silently
# loses it. Same line-regex heuristic as Assert-PlateModulesMatch.
function Assert-AssemblyViewsExist {
    param([Parameter(Mandatory = $true)]$Ctx, [Parameter(Mandatory = $true)]$Plates)

    $views = @(Get-AssemblyViews -Plates $Plates)
    if ($views.Count -eq 0) { return }
    if ($Ctx.PlateFile -eq "") {
        throw "ASSEMBLY_PLATE_VIEWS is set but PLATE_ASSEMBLY_FILE is empty (scripts/project_config.sh)."
    }
    $allText = ($Ctx.SourceFiles | ForEach-Object { Get-Content -Path (Join-Path $Ctx.Dir $_) -Raw }) -join "`n"
    $dispatchText = Get-Content -Path (Join-Path $Ctx.Dir $Ctx.PlateFile) -Raw

    foreach ($view in $views) {
        if ($view -notmatch '^[a-z0-9_]+$') {
            throw "ASSEMBLY_PLATE_VIEWS: invalid view name '$view' (lowercase letters, digits, _ only)."
        }
        if ($allText -notmatch "(?m)^\s*module\s+assembly_$view\s*\(") {
            throw "ASSEMBLY_PLATE_VIEWS lists '$view', but no SOURCE_FILES file defines module assembly_$view()."
        }
        if ($allText -notmatch "(?m)^\s*function\s+assembly_${view}_footprint\s*\(") {
            throw "ASSEMBLY_PLATE_VIEWS lists '$view', but no SOURCE_FILES file defines function assembly_${view}_footprint()."
        }
        $branches = ([regex]::Matches($dispatchText, "name\s*==\s*""$([regex]::Escape($view))""")).Count
        if ($branches -lt 2) {
            throw "ASSEMBLY_PLATE_VIEWS lists '$view', but $($Ctx.PlateFile)'s assembly_view() and " +
                  "assembly_view_footprint() do not both dispatch it (found $branches of 2 name == ""$view"" branches)."
        }
    }
}

# The lines both builds inject: values that live in scripts/plates_config.sh,
# so each is written in exactly one place. See Set-InjectedValues for where
# they land.
function Get-BundleInjectedLines {
    param([Parameter(Mandatory = $true)]$Ctx, [Parameter(Mandatory = $true)]$Plates)
    $size = Get-MwPlateSize -Ctx $Ctx
    $views = @(Get-AssemblyViews -Plates $Plates | ForEach-Object { """$_""" })
    return @(
        "mw_plate_size = $size; // layout bound -- see scripts/plates_config.sh",
        "mw_assembly_views = [$($views -join ', ')]; // ASSEMBLY_PLATE_VIEWS -- see scripts/plates_config.sh"
    )
}

# Puts the injected values into params.scad's selected lines, in place: when
# params.scad itself assigns one of them (a placeholder in its [Hidden]
# section, e.g. `mw_plate_size = 235;`), that line is REPLACED, so derived
# values below it can read the real value -- OpenSCAD evaluates top-level
# assignments in order, and a variable assigned further down is undef where
# it is read. $Lines is modified; the injected lines params.scad does not
# assign are returned, for the caller to append right after params.scad.
function Set-InjectedValues {
    param([System.Collections.Generic.List[string]]$Lines, [string[]]$Injected)
    $rest = New-Object System.Collections.Generic.List[string]
    foreach ($inj in $Injected) {
        $name = ($inj -split '=', 2)[0].Trim()
        $found = $false
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match ('^\s*' + [regex]::Escape($name) + '\s*=')) {
                $Lines[$i] = $inj
                $found = $true
                break
            }
        }
        if (-not $found) { $rest.Add($inj) }
    }
    return , $rest
}

function Get-MwPlateSize {
    param([Parameter(Mandatory = $true)]$Ctx)
    $value = Invoke-SharedPython -Script "resolve_mw_plate_size.py" -Arguments @($Ctx.PlatesJson)
    return [int](@($value)[-1])
}

# ---- Line filtering --------------------------------------------------------
# Strips a trailing `// ...` comment from a code line -- EXCEPT customizer
# syntax that OpenSCAD/PMM parses off the same line as the value:
# `// [min:step:max]`, `// [a:A, b:B]`, `// font`, `// color`.
# Losing one of those silently removes that parameter's widget in PMM.
function Remove-TrailingComment {
    param([string]$Line)
    if ($Line -match '^(.*?\S)\s*(//.*)$') {
        $code = $Matches[1]; $comment = $Matches[2]
        if ($comment -match '^//\s*(\[|font\s*$|color\s*$)') { return $Line }
        # Do not cut inside a string literal: an odd number of quotes
        # before the `//` means it belongs to a string (e.g. a URL).
        if ((([regex]::Matches($code, '"')).Count % 2) -eq 1) { return $Line }
        return $code
    }
    return $Line
}

function Test-BundledInclude {
    param([string]$Line, [string[]]$Libraries)
    if ($Line -notmatch '^\s*(include|use)\s*<([^>]+)>') { return $false }
    $target = $Matches[2]
    foreach ($lib in $Libraries) {
        if ($lib -ne "" -and $target.StartsWith($lib)) { return $true }
    }
    return $false
}

# Mode "makerworld": strip comments (except params.scad user-facing help
#   text and same-line widget syntax -- minus the @label / @note lines,
#   which feed the parameter tables), flatten color() calls, drop blanks.
# Mode "dev": keep comments and colors; drop params.scad's own $fa/$fs so
#   the dev bundle's quality override does not re-assign them.
# Both modes: drop BUILD:EXCLUDE blocks and every local include/use; keep
# includes of PMM-bundled libraries (BUNDLED_LIBRARIES).
function Select-BundleLines {
    param(
        [string[]]$Lines,
        [bool]$IsParams,
        [ValidateSet("makerworld", "dev")][string]$Mode,
        $Ctx
    )

    $result = New-Object System.Collections.Generic.List[string]
    $excluding = $false
    $keepComments = $false   # params.scad only: inside a non-Hidden tab

    foreach ($line in $Lines) {
        if ($line -match '^\s*//\s*BUILD:EXCLUDE-START') { $excluding = $true; continue }
        if ($line -match '^\s*//\s*BUILD:EXCLUDE-END') { $excluding = $false; continue }
        if ($excluding) { continue }

        if (Test-BundledInclude $line $Ctx.BundledLibraries) { $result.Add($line.Trim()); continue }
        if ($line -match '^\s*(include|use)\s*<[^>]+>\s*;?\s*(//.*)?$') { continue }

        if ($Mode -eq "dev") {
            if ($IsParams -and $line -match '^\s*\$f[as]\s*=\s*[\d.]+\s*;') { continue }
            $result.Add($line)
            continue
        }

        # ---- makerworld mode ----
        if ($IsParams -and $line -match '^\s*/\*\s*\[(.+)\]\s*\*/\s*$') {
            $keepComments = ($Matches[1].Trim().ToLower() -ne 'hidden')
            $result.Add($line)
            continue
        }
        # @label / @note lines are for the generated parameter tables
        # (scripts/shared/param_tables.py), not for the PMM UI.
        if ($IsParams -and $keepComments -and $line -match '^\s*//\s*@(label|note)\s*:') { continue }
        if ($IsParams -and $keepComments) { $result.Add($line); continue }

        if ($line -match '^\s*//') { continue }          # full-line comment
        if ($line.Trim() -eq '') { continue }             # blank line

        if ($Ctx.FlattenColors -and $line -match '^\s*color\((\w+)\)') {
            if ($Ctx.ColorPassthrough -notcontains $Matches[1]) {
                $line = $line -replace '^(\s*)color\(\w+\)\s*', ('$1color("' + $Ctx.MakerWorldColor + '") ')
            }
        }
        $result.Add((Remove-TrailingComment $line))
    }
    return , $result
}

# Returns the README lines between the two description markers, as
# `// ` comment lines. Markers are HTML comments, so they are invisible on
# GitHub and immune to heading renames (the original project keyed this
# on literal heading text, which broke silently if a heading changed).
function Get-ReadmeDescription {
    param([Parameter(Mandatory = $true)]$Ctx)
    $path = Join-Path $Ctx.Dir $Ctx.ReadmeFile
    $out = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path $path)) { return , $out }
    $inside = $false
    foreach ($line in (Get-Content -Path $path -Encoding UTF8)) {
        if ($line.Trim() -eq $Ctx.DescEnd) { break }
        if ($inside) {
            # Single-line HTML comments are authoring notes, not description text.
            if ($line.Trim() -match '^<!--.*-->$') { continue }
            $text = ($line -replace '^\s*#+\s*', '').TrimEnd()
            if ($text -eq "") { $out.Add("//") } else { $out.Add("// $text") }
        }
        if ($line.Trim() -eq $Ctx.DescStart) { $inside = $true }
    }
    return , $out
}

function Write-Utf8NoBom {
    param([string]$Path, [System.Collections.Generic.List[string]]$Lines)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $text = ($Lines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

Export-ModuleMember -Function Get-ProjectContext, Update-PlatesJson, Assert-PlateModulesMatch,
    Assert-AssemblyViewsExist, Get-BundleInjectedLines, Get-AssemblyViews,
    Get-MwPlateSize, Select-BundleLines, Get-ReadmeDescription, Write-Utf8NoBom, Read-BashConfig,
    Get-PythonCommand, Invoke-SharedPython, Set-InjectedValues
