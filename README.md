# Aqua Claude Code Launcher

中文 / English bilingual clean release for connecting AquaCloud models to Claude Code on Windows.

## 下载 / Download

- 中文版：[Download latest zh-CN](https://github.com/PH110110/claude-code-/releases/latest/download/AquaClaudeCode-zh-CN.zip)
- English: [Download latest en](https://github.com/PH110110/claude-code-/releases/latest/download/AquaClaudeCode-en.zip)

下载后解压：

- 中文版：双击 `打开AquaClaudeCode工具.cmd`
- English: double-click `Open-AquaClaudeCode.cmd`

## 功能 / Features

- 输入 AquaCloud API Key
- 拉取并选择可用模型
- 搜索过滤模型列表，适合模型数量很多的账号
- 自主选择 Claude Code 启动后的工作目录
- 一键启动 Claude Code
- 一键诊断本机 `claude` 命令、工作目录和 AquaCloud `/models` 接口
- 默认关闭窗口时清除 API Key
- 启动 Claude Code 时通过子进程环境变量传递 API Key，不再生成含 Key 的临时启动脚本

## Requirements

- Windows
- PowerShell 5+
- Claude Code installed and available as `claude` in PATH
- AquaCloud API key

## Compatibility Notes

This launcher sets `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and `ANTHROPIC_MODEL` before starting Claude Code.

The built-in Doctor checks local setup and AquaCloud `/models`. It does not spend tokens and does not prove that every Claude Code protocol feature is supported by the upstream gateway. If Claude Code reports `/v1/messages`, streaming, tool use, or token-counting errors after launch, use a dedicated Claude Code router/proxy mode for protocol translation.

## Release

Release zips can be rebuilt from this clean repository:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-release.ps1
```

The script writes language-specific zip files to `..\release-assets` and prints SHA256 hashes.

## Clean Release Notes

This repository intentionally contains only the launcher, command files, README files, and ignore rules.

Local user files are ignored and should not be committed:

- `aqua-claude-config.json`
- `aqua-claude-launch-*.tmp.ps1`
- Any real API key, key file, or private note
