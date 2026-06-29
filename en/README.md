# Aqua Claude Code One-Click Launcher

This is a clean Windows launcher for non-technical users. Double-click it, enter an AquaCloud API key, fetch models, choose a working directory, and launch Claude Code in that folder.

## Download

[Download latest English version](https://github.com/PH110110/claude-code-/releases/latest/download/AquaClaudeCode-en.zip)

## How To Use

1. Download and unzip the latest English package.
2. Double-click `Open-AquaClaudeCode.cmd`.
3. Enter your AquaCloud API key.
4. Click `Fetch Models`.
5. Type a keyword into the search box, such as `deepseek`, then pick a model from the filtered dropdown.
6. Choose the `Claude Code working directory`.
7. Optional: click `Doctor` to check the `claude` command, working directory, and AquaCloud `/models`.
8. Click `Launch Claude Code`.

The `Clear key when closing` option is enabled by default. When the window closes, the local config file will not keep the API key.

When launching Claude Code, the tool passes the key only through the child process environment. It no longer creates a temporary `.ps1` launcher file containing the key.

## Compatibility Notes

This launcher sets `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and `ANTHROPIC_MODEL` before starting Claude Code.

`Doctor` checks local setup and AquaCloud `/models`. It does not spend model tokens, and it does not prove that every Claude Code protocol feature is supported by the upstream gateway. If Claude Code reports `/v1/messages`, streaming, tool use, or token-counting errors after launch, use a dedicated Claude Code router/proxy for protocol translation.

## What Gets Saved

- Base URL
- Selected model
- Selected working directory
- API key only when you disable `Clear key when closing`

## Clean Release

This folder contains only the launcher script, the command file, and this README. Local config and temporary launch files are ignored by Git.
