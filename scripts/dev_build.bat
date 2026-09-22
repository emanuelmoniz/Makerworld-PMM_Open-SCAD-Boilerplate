@echo off
REM ============================================================
REM <PROJECT NAME>  |  Build the local dev bundle (dist\<slug>_dev.scad)
REM Double-click, or run from a terminal. Optional first argument: a project
REM folder, e.g.  dev_build.bat examples\demo   (default: this repo's root project).
REM Implementation: scripts$2   See docs\toolchain\pipelines.md
REM ============================================================
setlocal
set "PROJECT_ARG="
if not "%~1"=="" set "PROJECT_ARG=-Project %~1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build\dev_build.ps1" %PROJECT_ARG%
if errorlevel 1 (
    echo.
    echo FAILED - see the error above.
    if not defined CI pause
    exit /b 1
)
echo.
if not defined CI pause
