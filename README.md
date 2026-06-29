# Claude Code Link Tool for AquaCloud

A Windows launcher that connects AquaCloud-compatible models to Claude Code with a simple GUI for model selection, project launch, diagnostics, and reusable Skills synchronization.

## Quick Download

- 中文版：[Download AquaClaudeCode-zh-CN.zip](https://github.com/rockyliang10/claude-code-link-tool/releases/latest/download/AquaClaudeCode-zh-CN.zip)
- English: [Download AquaClaudeCode-en.zip](https://github.com/rockyliang10/claude-code-link-tool/releases/latest/download/AquaClaudeCode-en.zip)

下载后解压：

- 中文版：双击 `打开AquaClaudeCode工具.cmd`
- English: double-click `Open-AquaClaudeCode.cmd`

## What It Does

- Starts Claude Code with AquaCloud endpoint, API key, and selected model.
- Fetches available models from AquaCloud and filters them with a searchable selector.
- Lets users choose the Claude Code working directory before launch.
- Optionally syncs reusable Claude Skills from a selected template `.claude` directory.
- Includes a Doctor check for the local `claude` command, working directory, and AquaCloud `/models`.
- Keeps API keys out of generated launcher files by passing them through the child process environment.
- Clears API keys from local config by default when the launcher closes.

## Requirements

- Windows
- PowerShell 5+
- Claude Code installed and available as `claude` in PATH
- AquaCloud API key

## Compatibility Notes

This launcher sets `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and `ANTHROPIC_MODEL` before starting Claude Code.

The built-in Doctor checks local setup and AquaCloud `/models`. It does not spend tokens and does not prove that every Claude Code protocol feature is supported by the upstream gateway. If Claude Code reports `/v1/messages`, streaming, tool use, or token-counting errors after launch, use a dedicated Claude Code router/proxy mode for protocol translation.

## Skills Sync

The launcher can copy reusable Claude Skills from a template `.claude` directory into the selected working directory before launch. Choose the template folder manually the first time; the launcher saves that choice for later runs.

It copies:

- `.claude/skills`
- `.claude/settings.json` only when the target does not already have one
- `.claude/plugins` only when installed plugins are explicitly recorded

It does not overwrite existing files and does not copy session history, project logs, caches, or telemetry.

## Release

Download zips can be rebuilt from this repository:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-release.ps1
```

The script writes language-specific zip files to `downloads/` and prints SHA256 hashes.

## Repository Hygiene

This repository intentionally keeps source scripts, command files, documentation, packaging scripts, and small downloadable release zips only.

Local user files are ignored and should not be committed:

- `aqua-claude-config.json`
- `aqua-claude-launch-*.tmp.ps1`
- Any real API key, key file, or private note
