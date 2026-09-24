# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

The canonical, tool-agnostic instructions live in **AGENTS.md** and are imported below, so every
AI tool follows the same rules. **Edit AGENTS.md, not this file**, and keep only
Claude-specific notes here.

@AGENTS.md

## Claude-specific notes

- On Windows the default shell may be PowerShell 5.1. Run `.sh` scripts through Git Bash
  (`bash scripts/check/check.sh`). `&&` doesn't exist in PowerShell 5.1.
- For file edits, prefer the dedicated edit tools over shell heredocs. The configs and scripts
  contain apostrophes and `$` signs that shell quoting mangles.
- **Multi-line scripts go in a file, never through a heredoc.** Write a helper script with the
  file tool, then run it (`python path/to/script.py`). A heredoc passed through the shell tool
  breaks on apostrophes, `$`, backslashes and `\r` in the payload, sometimes after part of it
  already ran: that has left a half-edited script behind. Python patch scripts should assert that
  each search string occurs exactly once before writing, so a mismatch changes nothing.
- A Python raw string can't end in a backslash (`r'...\'` escapes the quote): end a search string
  before a line-continuation `\` instead.
- The VS Code OpenSCAD extension's diagnostics can go stale after an edit; the source of truth is
  OpenSCAD itself (`scripts/check/check.sh`).
