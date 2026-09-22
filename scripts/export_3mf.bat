@echo off
REM ============================================================
REM <PROJECT NAME>  |  Export a multi-plate Bambu .3mf (optional pipeline)
REM Double-click, or run from a terminal. Optional first argument: a project
REM folder, e.g.  export_3mf.bat examples\demo   (default: this repo's root project).
REM Needs Git Bash (located by scripts\shared\find_bash.cmd).
REM Implementation: scripts$2   See docs\toolchain\pipelines.md
REM ============================================================
setlocal
call "%~dp0shared\find_bash.cmd"
if not defined BASH_EXE (
    if not defined CI pause
    exit /b 1
)
set "PROJECT_ARG="
if not "%~1"=="" set "PROJECT_ARG=-p %~1"
"%BASH_EXE%" "%~dp0export/export_3mf.sh" %PROJECT_ARG%
if errorlevel 1 (
    echo.
    echo FAILED - see the error above.
    if not defined CI pause
    exit /b 1
)
echo.
if not defined CI pause
