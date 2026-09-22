@echo off
REM ============================================================
REM <PROJECT NAME>  |  Locate Git Bash for the .bat wrappers (shared)
REM ------------------------------------------------------------
REM `call "%~dp0shared\find_bash.cmd"` from a wrapper, then run
REM "%BASH_EXE%" ... . Sets BASH_EXE, or leaves it undefined if not found.
REM
REM Why this exists: Git's installer usually puts only Git\cmd on PATH
REM (git.exe), NOT Git\bin (bash.exe) -- so `where bash` alone often fails
REM even with Git Bash installed. Worse, `where bash` can find WSL's
REM C:\Windows\System32\bash.exe, which runs Linux bash with Linux paths and
REM cannot see this repo the same way. So: explicit override first, then
REM standard Git install locations, and PATH only as the last resort.
REM
REM Override: set GIT_BASH_BIN to the full path of bash.exe.
REM See: docs/toolchain/platform-contract.md
REM ============================================================
set "BASH_EXE="
if defined GIT_BASH_BIN if exist "%GIT_BASH_BIN%" set "BASH_EXE=%GIT_BASH_BIN%"
if not defined BASH_EXE if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramFiles%\Git\usr\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\usr\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH_EXE=%LocalAppData%\Programs\Git\bin\bash.exe"
if not defined BASH_EXE (
    for /f "delims=" %%B in ('where bash 2^>nul ^| findstr /v /i "System32"') do (
        if not defined BASH_EXE set "BASH_EXE=%%B"
    )
)
if not defined BASH_EXE (
    echo Could not find Git Bash. Install Git for Windows, or set GIT_BASH_BIN to bash.exe.
    echo See docs\toolchain\setup.md
)
