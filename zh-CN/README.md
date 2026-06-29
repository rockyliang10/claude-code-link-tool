# Aqua Claude Code 一键连接工具

这是给非技术用户使用的 Windows 纯净版小工具：双击打开，输入 AquaCloud Key，刷新模型，选择工作目录，然后在该目录中启动 Claude Code。

## 下载

[下载最新版中文包](https://github.com/PH110110/claude-code-/releases/latest/download/AquaClaudeCode-zh-CN.zip)

## 使用方法

1. 下载并解压最新版中文包。
2. 双击 `打开AquaClaudeCode工具.cmd`。
3. 输入 AquaCloud API Key。
4. 点击“刷新模型”。
5. 从“模型下拉选择”里选择模型。
6. 在“Claude Code 工作目录”里选择你的项目目录。
7. 可选：点击“诊断”，检查 `claude` 命令、工作目录和 AquaCloud `/models` 接口。
8. 点击“连接 Claude Code”。

默认勾选“关闭窗口时清除 Key（推荐）”。关闭工具后，本地配置文件不会保留 API Key。

启动 Claude Code 时，工具会把 Key 只传给新开的 Claude Code 子进程环境变量，不会再生成包含 Key 的临时 `.ps1` 启动脚本。

## 兼容性说明

这个工具会设置 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN` 和 `ANTHROPIC_MODEL` 后启动 Claude Code。

“诊断”只检查本机配置和 AquaCloud `/models`，不会消耗模型 token，也不等于证明上游网关完整支持 Claude Code 的所有协议能力。如果启动后 Claude Code 报 `/v1/messages`、streaming、tool use 或 token counting 相关错误，需要改用专门的 Claude Code router/proxy 做协议转换。

## 会保存什么

- Base URL
- 已选择的模型
- 已选择的工作目录
- 只有取消“关闭窗口时清除 Key”时，才会保存 API Key

## 纯净版说明

这个目录只包含启动脚本、双击入口和说明文档。本地配置文件、临时启动脚本、真实 Key 都会被 Git 忽略。
