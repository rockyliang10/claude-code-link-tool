Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $AppDir "aqua-claude-config.json"
$script:AllModelIds = New-Object System.Collections.Generic.List[string]

function Get-DefaultWorkingDirectory {
    $driveRoot = [System.IO.Path]::GetPathRoot($AppDir)
    if (-not [string]::IsNullOrWhiteSpace($driveRoot) -and (Test-Path -LiteralPath $driveRoot -PathType Container)) {
        return $driveRoot
    }

    return $AppDir
}

function Resolve-WorkingDirectory($Value) {
    $target = $Value
    if ([string]::IsNullOrWhiteSpace($target)) {
        return $null
    }

    try {
        $resolved = (Resolve-Path -LiteralPath $target -ErrorAction Stop).ProviderPath
        if (Test-Path -LiteralPath $resolved -PathType Container) {
            return $resolved
        }
    } catch {
        return $null
    }

    return $null
}

function Resolve-ClaudeTemplateDirectory($Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    try {
        $resolved = (Resolve-Path -LiteralPath $Value.Trim() -ErrorAction Stop).ProviderPath
        if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
            return $null
        }

        $leaf = Split-Path -Leaf $resolved
        if ($leaf -eq ".claude") {
            return $resolved
        }

        $nested = Join-Path $resolved ".claude"
        if (Test-Path -LiteralPath $nested -PathType Container) {
            return (Resolve-Path -LiteralPath $nested).ProviderPath
        }
    } catch {
        return $null
    }

    return $null
}

function Read-Config {
    if (Test-Path -LiteralPath $ConfigPath) {
        try {
            return Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

function Save-Config($BaseUrl, $ApiKey, $Model, $ClearKeyOnClose = $true, $WorkingDirectory = "", $SyncSkills = $true, $SkillSourceDirectory = "") {
    $keyToSave = ""
    if (-not $ClearKeyOnClose) {
        $keyToSave = $ApiKey
    }
    $data = [ordered]@{
        baseUrl = $BaseUrl
        apiKey = $keyToSave
        model = $Model
        workingDirectory = $WorkingDirectory
        syncSkills = [bool]$SyncSkills
        skillSourceDirectory = $SkillSourceDirectory
        clearKeyOnClose = [bool]$ClearKeyOnClose
        updatedAt = (Get-Date).ToString("s")
    }
    $data | ConvertTo-Json | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}

function Normalize-BaseUrl($Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "https://apibeta.aquacloud.io/v1"
    }
    return $Value.Trim().TrimEnd("/")
}

function Get-ModelId($Item) {
    if ($null -eq $Item) { return $null }
    if ($Item -is [string]) { return $Item }
    foreach ($name in @("id", "model", "name", "platform_model_id", "platformModelId")) {
        if ($Item.PSObject.Properties.Name -contains $name) {
            $value = [string]$Item.$name
            if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
        }
    }
    return [string]$Item
}

function Set-AllModels($Ids) {
    $script:AllModelIds.Clear()
    foreach ($id in $Ids) {
        if (-not [string]::IsNullOrWhiteSpace($id) -and -not $script:AllModelIds.Contains($id)) {
            [void]$script:AllModelIds.Add($id)
        }
    }
}

function Test-ModelMatchesFilter($ModelId, $FilterText) {
    if ([string]::IsNullOrWhiteSpace($FilterText)) {
        return $true
    }

    $tokens = $FilterText.Trim() -split "\s+"
    foreach ($token in $tokens) {
        if ($ModelId.IndexOf($token, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            return $false
        }
    }

    return $true
}

function Update-ModelFilter($FilterText = "", $PreferredModel = "") {
    $currentModel = $PreferredModel
    if ([string]::IsNullOrWhiteSpace($currentModel)) {
        $currentModel = [string]$modelBox.Text
    }

    $modelBox.BeginUpdate()
    try {
        $modelBox.Items.Clear()
        foreach ($id in $script:AllModelIds) {
            if (Test-ModelMatchesFilter $id $FilterText) {
                [void]$modelBox.Items.Add($id)
            }
        }

        if ($modelBox.Items.Count -gt 0) {
            if (-not [string]::IsNullOrWhiteSpace($currentModel) -and $modelBox.Items.Contains($currentModel)) {
                $modelBox.SelectedItem = $currentModel
            } else {
                $modelBox.SelectedIndex = 0
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($currentModel)) {
            $modelBox.Text = $currentModel
        } else {
            $modelBox.Text = ""
        }
    } finally {
        $modelBox.EndUpdate()
    }
}

function Set-Status($Text, $ColorName = "DimGray") {
    $statusLabel.Text = $Text
    $statusLabel.ForeColor = [System.Drawing.Color]::$ColorName
}

function Add-Log($Text) {
    $time = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("[$time] $Text`r`n")
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
}

function Copy-DirectoryNoOverwrite($SourceDirectory, $TargetDirectory) {
    if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
        return 0
    }

    if (-not (Test-Path -LiteralPath $TargetDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $TargetDirectory | Out-Null
    }

    $copied = 0
    $sourceRoot = (Resolve-Path -LiteralPath $SourceDirectory).ProviderPath.TrimEnd("\")
    Get-ChildItem -LiteralPath $SourceDirectory -Recurse -Force | ForEach-Object {
        $relativePath = $_.FullName.Substring($sourceRoot.Length).TrimStart("\")
        $targetPath = Join-Path $TargetDirectory $relativePath

        if ($_.PSIsContainer) {
            if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
                New-Item -ItemType Directory -Path $targetPath | Out-Null
            }
        } elseif (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
            $parent = Split-Path -Parent $targetPath
            if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
                New-Item -ItemType Directory -Path $parent | Out-Null
            }
            Copy-Item -LiteralPath $_.FullName -Destination $targetPath
            $script:SyncCopiedCount++
        }
    }

    return $script:SyncCopiedCount
}

function Test-InstalledPluginsPresent($ClaudeDirectory) {
    $installedPath = Join-Path $ClaudeDirectory "plugins\installed_plugins.json"
    if (-not (Test-Path -LiteralPath $installedPath -PathType Leaf)) {
        return $false
    }

    try {
        $installed = Get-Content -LiteralPath $installedPath -Raw -Encoding UTF8 | ConvertFrom-Json
        return ($installed.plugins.PSObject.Properties.Count -gt 0)
    } catch {
        return $false
    }
}

function Sync-ClaudeSkills($WorkingDirectory, $SourceClaudeDirectory) {
    $sourceClaude = Resolve-ClaudeTemplateDirectory $SourceClaudeDirectory
    if ([string]::IsNullOrWhiteSpace($sourceClaude)) {
        throw "Skill 模板目录无效。请选择包含 .claude 的项目目录，或直接选择 .claude 目录。"
    }

    $targetClaude = Join-Path $WorkingDirectory ".claude"
    $resolvedTarget = $null
    if (Test-Path -LiteralPath $targetClaude -PathType Container) {
        $resolvedTarget = (Resolve-Path -LiteralPath $targetClaude).ProviderPath
    }
    if ($resolvedTarget -and ($resolvedTarget -eq $sourceClaude)) {
        Add-Log "Skill 模板目录和工作目录相同，已跳过同步。"
        return
    }

    if (-not (Test-Path -LiteralPath $targetClaude -PathType Container)) {
        New-Item -ItemType Directory -Path $targetClaude | Out-Null
    }

    $script:SyncCopiedCount = 0
    $sourceSkills = Join-Path $sourceClaude "skills"
    $targetSkills = Join-Path $targetClaude "skills"
    [void](Copy-DirectoryNoOverwrite $sourceSkills $targetSkills)

    $sourceSettings = Join-Path $sourceClaude "settings.json"
    $targetSettings = Join-Path $targetClaude "settings.json"
    if ((Test-Path -LiteralPath $sourceSettings -PathType Leaf) -and -not (Test-Path -LiteralPath $targetSettings -PathType Leaf)) {
        Copy-Item -LiteralPath $sourceSettings -Destination $targetSettings
        $script:SyncCopiedCount++
    }

    if (Test-InstalledPluginsPresent $sourceClaude) {
        $sourcePlugins = Join-Path $sourceClaude "plugins"
        $targetPlugins = Join-Path $targetClaude "plugins"
        [void](Copy-DirectoryNoOverwrite $sourcePlugins $targetPlugins)
    }

    Add-Log "Skill 同步完成：$script:SyncCopiedCount 个新文件。"
}

function Refresh-Models {
    $baseUrl = Normalize-BaseUrl $baseUrlBox.Text
    $apiKey = $keyBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        [System.Windows.Forms.MessageBox]::Show("请先输入 AquaCloud API Key。", "缺少 Key", "OK", "Warning") | Out-Null
        return
    }

    $refreshButton.Enabled = $false
    $modelBox.Items.Clear()
    $modelSearchBox.Text = ""
    Set-Status "正在拉取模型..." "DarkOrange"
    Add-Log "请求 $baseUrl/models"

    try {
        $headers = @{
            Authorization = "Bearer $apiKey"
            Accept = "application/json"
        }
        $response = Invoke-RestMethod -Method Get -Uri "$baseUrl/models" -Headers $headers -TimeoutSec 45
        $items = @()
        if ($response.data) {
            $items = @($response.data)
        } elseif ($response.models) {
            $items = @($response.models)
        } elseif ($response -is [array]) {
            $items = @($response)
        }

        $ids = New-Object System.Collections.Generic.List[string]
        foreach ($item in $items) {
            $id = Get-ModelId $item
            if (-not [string]::IsNullOrWhiteSpace($id) -and -not $ids.Contains($id)) {
                [void]$ids.Add($id)
            }
        }

        if ($ids.Count -eq 0) {
            Set-Status "没有读到模型，请手动填写" "DarkOrange"
            Add-Log "请求成功，但返回里没解析出模型 ID。"
            return
        }

        Set-AllModels $ids
        Update-ModelFilter "" ([string]$modelBox.Tag)

        Save-Config $baseUrl $apiKey ([string]$modelBox.SelectedItem) $clearKeyCheckBox.Checked $workingDirBox.Text.Trim() $syncSkillsCheckBox.Checked $skillSourceBox.Text.Trim()
        Set-Status "已拉取 $($ids.Count) 个模型" "SeaGreen"
        Add-Log "已拉取 $($ids.Count) 个模型。"
    } catch {
        Set-Status "拉取失败，可看日志" "Firebrick"
        Add-Log "拉取失败：$($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("拉取模型失败：$($_.Exception.Message)`r`n`r`n这版不是浏览器跨域问题了，通常是 Key、网络、接口路径或权限问题。", "刷新模型失败", "OK", "Error") | Out-Null
    } finally {
        $refreshButton.Enabled = $true
    }
}

function Invoke-Doctor {
    $baseUrl = Normalize-BaseUrl $baseUrlBox.Text
    $apiKey = $keyBox.Text.Trim()
    $model = [string]$modelBox.Text
    $workingDirectory = Resolve-WorkingDirectory $workingDirBox.Text.Trim()
    $results = New-Object System.Collections.Generic.List[string]
    $hasError = $false
    $hasWarning = $false

    $doctorButton.Enabled = $false
    Set-Status "正在诊断..." "DarkOrange"
    Add-Log "开始诊断当前配置。"

    try {
        try {
            $uri = [System.Uri]$baseUrl
            if ($uri.Scheme -notin @("http", "https")) {
                throw "Base URL 必须以 http 或 https 开头。"
            }
            [void]$results.Add("OK: Base URL 格式正常：$baseUrl")
        } catch {
            [void]$results.Add("错误: Base URL 无效。")
            $hasError = $true
        }

        $claudeCmd = Get-Command "claude" -ErrorAction SilentlyContinue
        if ($claudeCmd) {
            [void]$results.Add("OK: 已找到 claude 命令。")
        } else {
            [void]$results.Add("错误: 没有找到 claude 命令，请先安装 Claude Code 或加入 PATH。")
            $hasError = $true
        }

        if ([string]::IsNullOrWhiteSpace($workingDirectory)) {
            [void]$results.Add("警告: 工作目录还没有选择，连接前需要选择一个存在的目录。")
            $hasWarning = $true
        } else {
            [void]$results.Add("OK: 工作目录存在：$workingDirectory")
        }

        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            [void]$results.Add("警告: 还没有输入 API Key，已跳过接口检查。")
            $hasWarning = $true
        } else {
            try {
                $headers = @{
                    Authorization = "Bearer $apiKey"
                    Accept = "application/json"
                }
                $response = Invoke-RestMethod -Method Get -Uri "$baseUrl/models" -Headers $headers -TimeoutSec 45
                $items = @()
                if ($response.data) {
                    $items = @($response.data)
                } elseif ($response.models) {
                    $items = @($response.models)
                } elseif ($response -is [array]) {
                    $items = @($response)
                }

                $ids = New-Object System.Collections.Generic.List[string]
                foreach ($item in $items) {
                    $id = Get-ModelId $item
                    if (-not [string]::IsNullOrWhiteSpace($id) -and -not $ids.Contains($id)) {
                        [void]$ids.Add($id)
                    }
                }

                if ($ids.Count -gt 0) {
                    [void]$results.Add("OK: /models 可访问，读到 $($ids.Count) 个模型。")
                    if (-not [string]::IsNullOrWhiteSpace($model)) {
                        if ($ids.Contains($model)) {
                            [void]$results.Add("OK: 当前模型在模型列表中。")
                        } else {
                            [void]$results.Add("警告: 当前模型没有出现在 /models 返回中，可手动确认模型 ID 是否仍可用。")
                            $hasWarning = $true
                        }
                    } else {
                        [void]$results.Add("警告: 还没有选择模型，连接前需要选择或手动输入模型 ID。")
                        $hasWarning = $true
                    }
                } else {
                    [void]$results.Add("警告: /models 请求成功，但没有解析出模型 ID。")
                    $hasWarning = $true
                }
            } catch {
                [void]$results.Add("错误: /models 检查失败：$($_.Exception.Message)")
                $hasError = $true
            }
        }

        foreach ($line in $results) {
            Add-Log $line
        }

        if ($hasError) {
            Set-Status "诊断发现错误" "Firebrick"
        } elseif ($hasWarning) {
            Set-Status "诊断完成，有提醒" "DarkOrange"
        } else {
            Set-Status "诊断通过" "SeaGreen"
        }

        [System.Windows.Forms.MessageBox]::Show(($results -join "`r`n"), "诊断结果", "OK", $(if ($hasError) { "Error" } elseif ($hasWarning) { "Warning" } else { "Information" })) | Out-Null
    } finally {
        $doctorButton.Enabled = $true
    }
}

function Start-Claude {
    $baseUrl = Normalize-BaseUrl $baseUrlBox.Text
    $apiKey = $keyBox.Text.Trim()
    $model = [string]$modelBox.Text
    $workingDirectory = Resolve-WorkingDirectory $workingDirBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        [System.Windows.Forms.MessageBox]::Show("请先输入 AquaCloud API Key。", "缺少 Key", "OK", "Warning") | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($model)) {
        [System.Windows.Forms.MessageBox]::Show("请先刷新并选择模型。如果列表为空，可以直接在模型框里手动输入模型 ID。", "缺少模型", "OK", "Warning") | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($workingDirectory)) {
        [System.Windows.Forms.MessageBox]::Show("请选择一个存在的工作目录。Claude Code 会在这个目录里启动。", "工作目录无效", "OK", "Warning") | Out-Null
        return
    }

    $workingDirBox.Text = $workingDirectory
    Save-Config $baseUrl $apiKey $model $clearKeyCheckBox.Checked $workingDirectory $syncSkillsCheckBox.Checked $skillSourceBox.Text.Trim()

    $claudeCmd = Get-Command "claude" -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        [System.Windows.Forms.MessageBox]::Show("没有找到 claude 命令。请先安装 Claude Code，或确认 claude 已加入 PATH。", "找不到 Claude Code", "OK", "Error") | Out-Null
        return
    }

    if ($syncSkillsCheckBox.Checked) {
        try {
            Sync-ClaudeSkills $workingDirectory $skillSourceBox.Text.Trim()
        } catch {
            Set-Status "Skill 同步失败" "Firebrick"
            Add-Log "Skill 同步失败：$($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("Skill 同步失败：$($_.Exception.Message)`r`n`r`n为避免在缺少 Skill 的目录启动，已取消本次连接。", "Skill 同步失败", "OK", "Error") | Out-Null
            return
        }
    }

    $powerShellCmd = Get-Command "powershell.exe" -ErrorAction SilentlyContinue
    if (-not $powerShellCmd) {
        [System.Windows.Forms.MessageBox]::Show("没有找到 Windows PowerShell，无法打开 Claude Code 终端窗口。", "找不到 PowerShell", "OK", "Error") | Out-Null
        return
    }

    $claudePath = $claudeCmd.Source
    $escapedClaudePath = $claudePath.Replace("'", "''")
    $escapedModel = $model.Replace("'", "''")
    $launchScript = @"
`$Host.UI.RawUI.WindowTitle = 'Aqua Claude Code - PowerShell'
Write-Host 'AquaCloud -> Claude Code'
Write-Host ('Shell: PowerShell ' + `$PSVersionTable.PSVersion)
Write-Host ('Base URL: ' + `$env:ANTHROPIC_BASE_URL)
Write-Host ('Model: ' + `$env:ANTHROPIC_MODEL)
Write-Host ('Working directory: ' + (Get-Location).Path)
Write-Host 'Settings: project,local'
& '$escapedClaudePath' --setting-sources project,local --model '$escapedModel'
Read-Host 'Claude Code 已退出，按回车关闭窗口'
"@
    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($launchScript))
    $temporaryEnv = [ordered]@{
        ANTHROPIC_BASE_URL = $baseUrl
        ANTHROPIC_AUTH_TOKEN = $apiKey
        ANTHROPIC_MODEL = $model
        ANTHROPIC_CUSTOM_MODEL_OPTION = $model
        ANTHROPIC_CUSTOM_MODEL_OPTION_NAME = $model
        ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION = "AquaCloud model: $model"
        CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1"
        NO_PROXY = "127.0.0.1,localhost"
    }
    $previousEnv = @{}

    try {
        foreach ($name in $temporaryEnv.Keys) {
            $previousEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
            [Environment]::SetEnvironmentVariable($name, [string]$temporaryEnv[$name], "Process")
        }

        Add-Log "启动 Claude Code，模型：$model，目录：$workingDirectory"
        $process = Start-Process -FilePath $powerShellCmd.Source -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand" -WorkingDirectory $workingDirectory -WindowStyle Normal -PassThru
        Add-Log "Claude Code 窗口已打开，进程 ID：$($process.Id)"
    } catch {
        Set-Status "启动失败" "Firebrick"
        Add-Log "启动失败：$($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Claude Code 启动失败：$($_.Exception.Message)", "启动失败", "OK", "Error") | Out-Null
    } finally {
        foreach ($name in $temporaryEnv.Keys) {
            [Environment]::SetEnvironmentVariable($name, $previousEnv[$name], "Process")
        }
    }
}

function Save-Only {
    $model = [string]$modelBox.Text
    Save-Config (Normalize-BaseUrl $baseUrlBox.Text) $keyBox.Text.Trim() $model $clearKeyCheckBox.Checked $workingDirBox.Text.Trim() $syncSkillsCheckBox.Checked $skillSourceBox.Text.Trim()
    Set-Status "已保存" "SeaGreen"
    if ($clearKeyCheckBox.Checked) {
        Add-Log "配置已保存，但 Key 不会写入本地文件。"
    } else {
        Add-Log "配置已保存到 $ConfigPath"
    }
}

function Select-WorkingDirectory {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "选择 Claude Code 启动后的工作目录"
    $current = Resolve-WorkingDirectory $workingDirBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($current)) {
        $current = Get-DefaultWorkingDirectory
    }
    $dialog.SelectedPath = $current

    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $workingDirBox.Text = $dialog.SelectedPath
        Add-Log "已选择工作目录：$($dialog.SelectedPath)"
    }

    $dialog.Dispose()
}

function Select-SkillSourceDirectory {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "选择 Skill 模板目录：可以选已有项目目录，也可以直接选 .claude 目录"
    $current = Resolve-ClaudeTemplateDirectory $skillSourceBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($current)) {
        $current = $env:USERPROFILE
    }
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        $dialog.SelectedPath = $current
    }

    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $resolved = Resolve-ClaudeTemplateDirectory $dialog.SelectedPath
        if ([string]::IsNullOrWhiteSpace($resolved)) {
            [System.Windows.Forms.MessageBox]::Show("请选择已有项目目录，或直接选择 .claude 目录。", "目录无效", "OK", "Warning") | Out-Null
        } else {
            $skillSourceBox.Text = $resolved
            $syncSkillsCheckBox.Checked = $true
            Add-Log "已选择 Skill 模板目录：$resolved"
        }
    }

    $dialog.Dispose()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Aqua Claude Code 一键连接工具"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 760)
$form.MinimumSize = New-Object System.Drawing.Size(720, 720)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Aqua Claude Code 一键连接工具"
$title.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(24, 20)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "输入 Key，刷新模型，下拉选择，然后启动 Claude Code。"
$subtitle.AutoSize = $true
$subtitle.ForeColor = [System.Drawing.Color]::DimGray
$subtitle.Location = New-Object System.Drawing.Point(26, 58)
$form.Controls.Add($subtitle)

$baseUrlLabel = New-Object System.Windows.Forms.Label
$baseUrlLabel.Text = "Base URL"
$baseUrlLabel.Location = New-Object System.Drawing.Point(28, 100)
$baseUrlLabel.Size = New-Object System.Drawing.Size(160, 24)
$form.Controls.Add($baseUrlLabel)

$baseUrlBox = New-Object System.Windows.Forms.TextBox
$baseUrlBox.Location = New-Object System.Drawing.Point(28, 126)
$baseUrlBox.Size = New-Object System.Drawing.Size(690, 30)
$baseUrlBox.Text = "https://apibeta.aquacloud.io/v1"
$form.Controls.Add($baseUrlBox)

$keyLabel = New-Object System.Windows.Forms.Label
$keyLabel.Text = "AquaCloud API Key"
$keyLabel.Location = New-Object System.Drawing.Point(28, 174)
$keyLabel.Size = New-Object System.Drawing.Size(200, 24)
$form.Controls.Add($keyLabel)

$keyBox = New-Object System.Windows.Forms.TextBox
$keyBox.Location = New-Object System.Drawing.Point(28, 200)
$keyBox.Size = New-Object System.Drawing.Size(548, 30)
$keyBox.UseSystemPasswordChar = $true
$form.Controls.Add($keyBox)

$showKeyButton = New-Object System.Windows.Forms.Button
$showKeyButton.Text = "显示"
$showKeyButton.Location = New-Object System.Drawing.Point(590, 199)
$showKeyButton.Size = New-Object System.Drawing.Size(60, 32)
$showKeyButton.Add_Click({
    $keyBox.UseSystemPasswordChar = -not $keyBox.UseSystemPasswordChar
    $showKeyButton.Text = if ($keyBox.UseSystemPasswordChar) { "显示" } else { "隐藏" }
})
$form.Controls.Add($showKeyButton)

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = "保存"
$saveButton.Location = New-Object System.Drawing.Point(658, 199)
$saveButton.Size = New-Object System.Drawing.Size(60, 32)
$saveButton.Add_Click({ Save-Only })
$form.Controls.Add($saveButton)

$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Text = "搜索模型 / 模型下拉选择"
$modelLabel.Location = New-Object System.Drawing.Point(28, 252)
$modelLabel.Size = New-Object System.Drawing.Size(260, 24)
$form.Controls.Add($modelLabel)

$modelSearchBox = New-Object System.Windows.Forms.TextBox
$modelSearchBox.Location = New-Object System.Drawing.Point(28, 278)
$modelSearchBox.Size = New-Object System.Drawing.Size(260, 32)
$modelSearchBox.Add_TextChanged({ Update-ModelFilter $modelSearchBox.Text ([string]$modelBox.Text) })
$form.Controls.Add($modelSearchBox)

$modelBox = New-Object System.Windows.Forms.ComboBox
$modelBox.Location = New-Object System.Drawing.Point(300, 278)
$modelBox.Size = New-Object System.Drawing.Size(276, 32)
$modelBox.DropDownStyle = "DropDown"
$modelBox.AutoCompleteMode = "SuggestAppend"
$modelBox.AutoCompleteSource = "ListItems"
$form.Controls.Add($modelBox)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "刷新模型"
$refreshButton.Location = New-Object System.Drawing.Point(590, 277)
$refreshButton.Size = New-Object System.Drawing.Size(128, 34)
$refreshButton.Add_Click({ Refresh-Models })
$form.Controls.Add($refreshButton)

$workingDirLabel = New-Object System.Windows.Forms.Label
$workingDirLabel.Text = "Claude Code 工作目录"
$workingDirLabel.Location = New-Object System.Drawing.Point(28, 328)
$workingDirLabel.Size = New-Object System.Drawing.Size(240, 24)
$form.Controls.Add($workingDirLabel)

$workingDirBox = New-Object System.Windows.Forms.TextBox
$workingDirBox.Location = New-Object System.Drawing.Point(28, 354)
$workingDirBox.Size = New-Object System.Drawing.Size(548, 30)
$workingDirBox.Text = ""
$form.Controls.Add($workingDirBox)

$browseDirButton = New-Object System.Windows.Forms.Button
$browseDirButton.Text = "选择目录"
$browseDirButton.Location = New-Object System.Drawing.Point(590, 353)
$browseDirButton.Size = New-Object System.Drawing.Size(128, 32)
$browseDirButton.Add_Click({ Select-WorkingDirectory })
$form.Controls.Add($browseDirButton)

$syncSkillsCheckBox = New-Object System.Windows.Forms.CheckBox
$syncSkillsCheckBox.Text = "启动前同步 Skills"
$syncSkillsCheckBox.Checked = $false
$syncSkillsCheckBox.Location = New-Object System.Drawing.Point(28, 398)
$syncSkillsCheckBox.Size = New-Object System.Drawing.Size(260, 28)
$form.Controls.Add($syncSkillsCheckBox)

$skillSourceLabel = New-Object System.Windows.Forms.Label
$skillSourceLabel.Text = "Skill 模板目录（已有项目或 .claude）"
$skillSourceLabel.Location = New-Object System.Drawing.Point(28, 430)
$skillSourceLabel.Size = New-Object System.Drawing.Size(320, 24)
$form.Controls.Add($skillSourceLabel)

$skillSourceBox = New-Object System.Windows.Forms.TextBox
$skillSourceBox.Location = New-Object System.Drawing.Point(28, 456)
$skillSourceBox.Size = New-Object System.Drawing.Size(548, 30)
$skillSourceBox.Text = ""
$form.Controls.Add($skillSourceBox)

$browseSkillSourceButton = New-Object System.Windows.Forms.Button
$browseSkillSourceButton.Text = "选择模板"
$browseSkillSourceButton.Location = New-Object System.Drawing.Point(590, 455)
$browseSkillSourceButton.Size = New-Object System.Drawing.Size(128, 32)
$browseSkillSourceButton.Add_Click({ Select-SkillSourceDirectory })
$form.Controls.Add($browseSkillSourceButton)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "连接 Claude Code"
$startButton.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$startButton.Location = New-Object System.Drawing.Point(28, 506)
$startButton.Size = New-Object System.Drawing.Size(548, 46)
$startButton.Add_Click({ Start-Claude })
$form.Controls.Add($startButton)

$doctorButton = New-Object System.Windows.Forms.Button
$doctorButton.Text = "诊断"
$doctorButton.Location = New-Object System.Drawing.Point(590, 506)
$doctorButton.Size = New-Object System.Drawing.Size(128, 46)
$doctorButton.Add_Click({ Invoke-Doctor })
$form.Controls.Add($doctorButton)

$clearKeyCheckBox = New-Object System.Windows.Forms.CheckBox
$clearKeyCheckBox.Text = "关闭窗口时清除 Key（推荐）"
$clearKeyCheckBox.Checked = $true
$clearKeyCheckBox.Location = New-Object System.Drawing.Point(28, 560)
$clearKeyCheckBox.Size = New-Object System.Drawing.Size(260, 28)
$form.Controls.Add($clearKeyCheckBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "等待配置"
$statusLabel.ForeColor = [System.Drawing.Color]::DimGray
$statusLabel.Location = New-Object System.Drawing.Point(300, 564)
$statusLabel.Size = New-Object System.Drawing.Size(690, 24)
$form.Controls.Add($statusLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(28, 598)
$logBox.Size = New-Object System.Drawing.Size(690, 76)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
$form.Controls.Add($logBox)

$config = Read-Config
if ($config) {
    if ($config.baseUrl) { $baseUrlBox.Text = [string]$config.baseUrl }
    if ($null -ne $config.clearKeyOnClose) {
        $clearKeyCheckBox.Checked = [bool]$config.clearKeyOnClose
    }
    if (-not $clearKeyCheckBox.Checked -and $config.apiKey) {
        $keyBox.Text = [string]$config.apiKey
    }
    if ($config.model) {
        $modelBox.Text = [string]$config.model
        $modelBox.Tag = [string]$config.model
    }
    if ($config.workingDirectory) {
        $savedWorkingDirectory = Resolve-WorkingDirectory ([string]$config.workingDirectory)
        if (-not [string]::IsNullOrWhiteSpace($savedWorkingDirectory)) {
            $workingDirBox.Text = $savedWorkingDirectory
        }
    }
    if ($null -ne $config.syncSkills) {
        $syncSkillsCheckBox.Checked = [bool]$config.syncSkills
    }
    if ($config.skillSourceDirectory) {
        $skillSourceBox.Text = [string]$config.skillSourceDirectory
    }
    Add-Log "已读取本地配置。"
}

$form.Add_FormClosing({
    if ($clearKeyCheckBox.Checked) {
        Save-Config (Normalize-BaseUrl $baseUrlBox.Text) "" ([string]$modelBox.Text) $true $workingDirBox.Text.Trim() $syncSkillsCheckBox.Checked $skillSourceBox.Text.Trim()
        $keyBox.Text = ""
    }
})

Add-Log "准备就绪。"
[void]$form.ShowDialog()


