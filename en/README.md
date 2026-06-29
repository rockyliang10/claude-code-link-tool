# Claude Code Link Tool for AquaCloud

This Windows launcher connects AquaCloud-compatible models to Claude Code and provides model selection, working-directory launch, diagnostics, and reusable Skills synchronization.

## Download

[Download latest English version](https://github.com/rockyliang10/claude-code-link-tool/releases/latest/download/AquaClaudeCode-en.zip)

## How To Use

1. Download and unzip the latest English package.
2. Double-click `Open-AquaClaudeCode.cmd`.
3. Enter your AquaCloud API key.
4. Click `Fetch Models`.
5. Type a keyword into the search box, such as `deepseek`, then pick a model from the filtered dropdown.
6. Choose the `Claude Code working directory`.
7. To reuse Skills, click `Browse`, choose a project folder that already has Skills configured or choose its `.claude` folder directly. The tool will enable `Sync Skills before launch` after you choose a template.
8. Optional: click `Doctor` to check the `claude` command, working directory, and AquaCloud `/models`.
9. Click `Launch Claude Code`.

The `Clear key when closing` option is enabled by default. When the window closes, the local config file will not keep the API key.

When launching Claude Code, the tool passes the key only through the child process environment. It no longer creates a temporary `.ps1` launcher file containing the key.

## Compatibility Notes

This launcher sets `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and `ANTHROPIC_MODEL` before starting Claude Code.

`Doctor` checks local setup and AquaCloud `/models`. It does not spend model tokens, and it does not prove that every Claude Code protocol feature is supported by the upstream gateway. If Claude Code reports `/v1/messages`, streaming, tool use, or token-counting errors after launch, use a dedicated Claude Code router/proxy for protocol translation.

## Skills Sync

The launcher can copy reusable Claude Skills from a template `.claude` directory into the selected working directory before launch. Choose the template folder manually the first time; the tool saves that choice for later runs.

It copies:

- `.claude/skills`
- `.claude/settings.json` only when the target does not already have one
- `.claude/plugins` only when installed plugins are explicitly recorded

It does not overwrite existing files and does not copy session history, project logs, caches, or telemetry.

## What Gets Saved

- Base URL
- Selected model
- Selected working directory
- Whether Skills sync is enabled
- Skill template folder
- API key only when you disable `Clear key when closing`

## Clean Release

The English package contains only the launcher script, the command file, and this README. Local config and temporary launch files are ignored by Git.
