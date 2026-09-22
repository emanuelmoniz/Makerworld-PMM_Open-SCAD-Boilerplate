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
