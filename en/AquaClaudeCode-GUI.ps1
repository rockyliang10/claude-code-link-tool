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

function Save-Config($BaseUrl, $ApiKey, $Model, $ClearKeyOnClose = $true, $WorkingDirectory = "") {
    $keyToSave = ""
    if (-not $ClearKeyOnClose) {
        $keyToSave = $ApiKey
    }
    $data = [ordered]@{
        baseUrl = $BaseUrl
        apiKey = $keyToSave
        model = $Model
        workingDirectory = $WorkingDirectory
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

function Refresh-Models {
    $baseUrl = Normalize-BaseUrl $baseUrlBox.Text
    $apiKey = $keyBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter your AquaCloud API Key first.", "Missing Key", "OK", "Warning") | Out-Null
        return
    }

    $refreshButton.Enabled = $false
    $modelBox.Items.Clear()
    $modelSearchBox.Text = ""
    Set-Status "Fetching models..." "DarkOrange"
    Add-Log "Requesting $baseUrl/models"

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
            Set-Status "No models found. Enter one manually." "DarkOrange"
            Add-Log "Request succeeded, but no model ID was found in the response."
            return
        }

        Set-AllModels $ids
        Update-ModelFilter "" ([string]$modelBox.Tag)

        Save-Config $baseUrl $apiKey ([string]$modelBox.SelectedItem) $clearKeyCheckBox.Checked $workingDirBox.Text.Trim()
        Set-Status "Fetched $($ids.Count) models" "SeaGreen"
        Add-Log "Fetched $($ids.Count) models."
    } catch {
        Set-Status "Fetch failed. Check the log." "Firebrick"
        Add-Log "Fetch failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Model fetch failed: $($_.Exception.Message)`r`n`r`nThis is not a browser CORS issue. It is usually caused by the key, network, endpoint path, or account permissions.", "Model refresh failed", "OK", "Error") | Out-Null
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
    Set-Status "Running checks..." "DarkOrange"
    Add-Log "Starting configuration checks."

    try {
        try {
            $uri = [System.Uri]$baseUrl
            if ($uri.Scheme -notin @("http", "https")) {
                throw "Base URL must start with http or https."
            }
            [void]$results.Add("OK: Base URL looks valid: $baseUrl")
        } catch {
            [void]$results.Add("Error: Base URL is invalid.")
            $hasError = $true
        }

        $claudeCmd = Get-Command "claude" -ErrorAction SilentlyContinue
        if ($claudeCmd) {
            [void]$results.Add("OK: Found the claude command.")
        } else {
            [void]$results.Add("Error: The claude command was not found. Install Claude Code or add it to PATH.")
            $hasError = $true
        }

        if ([string]::IsNullOrWhiteSpace($workingDirectory)) {
            [void]$results.Add("Warning: No working directory is selected yet. Choose an existing folder before launching.")
            $hasWarning = $true
        } else {
            [void]$results.Add("OK: Working directory exists: $workingDirectory")
        }

        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            [void]$results.Add("Warning: No API key is entered, so the API check was skipped.")
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
                    [void]$results.Add("OK: /models is reachable and returned $($ids.Count) models.")
                    if (-not [string]::IsNullOrWhiteSpace($model)) {
                        if ($ids.Contains($model)) {
                            [void]$results.Add("OK: The selected model appears in the model list.")
                        } else {
                            [void]$results.Add("Warning: The selected model was not found in /models. Confirm the model ID is still available.")
                            $hasWarning = $true
                        }
                    } else {
                        [void]$results.Add("Warning: No model is selected yet. Select or type a model ID before launching.")
                        $hasWarning = $true
                    }
                } else {
                    [void]$results.Add("Warning: /models succeeded, but no model ID could be parsed.")
                    $hasWarning = $true
                }
            } catch {
                [void]$results.Add("Error: /models check failed: $($_.Exception.Message)")
                $hasError = $true
            }
        }

        foreach ($line in $results) {
            Add-Log $line
        }

        if ($hasError) {
            Set-Status "Checks found errors" "Firebrick"
        } elseif ($hasWarning) {
            Set-Status "Checks completed with notes" "DarkOrange"
        } else {
            Set-Status "Checks passed" "SeaGreen"
        }

        [System.Windows.Forms.MessageBox]::Show(($results -join "`r`n"), "Doctor Results", "OK", $(if ($hasError) { "Error" } elseif ($hasWarning) { "Warning" } else { "Information" })) | Out-Null
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
        [System.Windows.Forms.MessageBox]::Show("Please enter your AquaCloud API Key first.", "Missing Key", "OK", "Warning") | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($model)) {
        [System.Windows.Forms.MessageBox]::Show("Refresh and select a model first. If the list is empty, type the model ID directly into the model box.", "Missing Model", "OK", "Warning") | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($workingDirectory)) {
        [System.Windows.Forms.MessageBox]::Show("Please choose an existing working directory. Claude Code will start in that folder.", "Invalid Working Directory", "OK", "Warning") | Out-Null
        return
    }

    $workingDirBox.Text = $workingDirectory
    Save-Config $baseUrl $apiKey $model $clearKeyCheckBox.Checked $workingDirectory

    $claudeCmd = Get-Command "claude" -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        [System.Windows.Forms.MessageBox]::Show("The claude command was not found. Install Claude Code first, or make sure claude is in PATH.", "Claude Code Not Found", "OK", "Error") | Out-Null
        return
    }

    $launchScript = @"
Write-Host 'AquaCloud -> Claude Code'
Write-Host ('Base URL: ' + `$env:ANTHROPIC_BASE_URL)
Write-Host ('Model: ' + `$env:ANTHROPIC_MODEL)
Write-Host ('Working directory: ' + (Get-Location).Path)
claude
Read-Host 'Claude Code has exited. Press Enter to close this window.'
"@
    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($launchScript))
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.WorkingDirectory = $workingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $false
    $startInfo.Arguments = "-NoExit -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"
    $startInfo.EnvironmentVariables["ANTHROPIC_BASE_URL"] = $baseUrl
    $startInfo.EnvironmentVariables["ANTHROPIC_AUTH_TOKEN"] = $apiKey
    $startInfo.EnvironmentVariables["ANTHROPIC_MODEL"] = $model
    $startInfo.EnvironmentVariables["NO_PROXY"] = "127.0.0.1,localhost"

    Add-Log "Starting Claude Code with model: $model, directory: $workingDirectory"
    [void][System.Diagnostics.Process]::Start($startInfo)
}

function Save-Only {
    $model = [string]$modelBox.Text
    Save-Config (Normalize-BaseUrl $baseUrlBox.Text) $keyBox.Text.Trim() $model $clearKeyCheckBox.Checked $workingDirBox.Text.Trim()
    Set-Status "Saved" "SeaGreen"
    if ($clearKeyCheckBox.Checked) {
        Add-Log "Settings saved. The key will not be written to the local config file."
    } else {
        Add-Log "Settings saved to $ConfigPath"
    }
}

function Select-WorkingDirectory {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose the folder where Claude Code should start"
    $current = Resolve-WorkingDirectory $workingDirBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($current)) {
        $current = Get-DefaultWorkingDirectory
    }
    $dialog.SelectedPath = $current

    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $workingDirBox.Text = $dialog.SelectedPath
        Add-Log "Selected working directory: $($dialog.SelectedPath)"
    }

    $dialog.Dispose()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Aqua Claude Code One-Click Launcher"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 650)
$form.MinimumSize = New-Object System.Drawing.Size(720, 610)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Aqua Claude Code One-Click Launcher"
$title.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(24, 20)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Enter your key, fetch models, choose one, then launch Claude Code."
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
$showKeyButton.Text = "Show"
$showKeyButton.Location = New-Object System.Drawing.Point(590, 199)
$showKeyButton.Size = New-Object System.Drawing.Size(60, 32)
$showKeyButton.Add_Click({
    $keyBox.UseSystemPasswordChar = -not $keyBox.UseSystemPasswordChar
    $showKeyButton.Text = if ($keyBox.UseSystemPasswordChar) { "Show" } else { "Hide" }
})
$form.Controls.Add($showKeyButton)

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = "Save"
$saveButton.Location = New-Object System.Drawing.Point(658, 199)
$saveButton.Size = New-Object System.Drawing.Size(60, 32)
$saveButton.Add_Click({ Save-Only })
$form.Controls.Add($saveButton)

$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Text = "Search / model selection"
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
$refreshButton.Text = "Fetch Models"
$refreshButton.Location = New-Object System.Drawing.Point(590, 277)
$refreshButton.Size = New-Object System.Drawing.Size(128, 34)
$refreshButton.Add_Click({ Refresh-Models })
$form.Controls.Add($refreshButton)

$workingDirLabel = New-Object System.Windows.Forms.Label
$workingDirLabel.Text = "Claude Code working directory"
$workingDirLabel.Location = New-Object System.Drawing.Point(28, 328)
$workingDirLabel.Size = New-Object System.Drawing.Size(260, 24)
$form.Controls.Add($workingDirLabel)

$workingDirBox = New-Object System.Windows.Forms.TextBox
$workingDirBox.Location = New-Object System.Drawing.Point(28, 354)
$workingDirBox.Size = New-Object System.Drawing.Size(548, 30)
$workingDirBox.Text = ""
$form.Controls.Add($workingDirBox)

$browseDirButton = New-Object System.Windows.Forms.Button
$browseDirButton.Text = "Browse"
$browseDirButton.Location = New-Object System.Drawing.Point(590, 353)
$browseDirButton.Size = New-Object System.Drawing.Size(128, 32)
$browseDirButton.Add_Click({ Select-WorkingDirectory })
$form.Controls.Add($browseDirButton)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Launch Claude Code"
$startButton.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$startButton.Location = New-Object System.Drawing.Point(28, 408)
$startButton.Size = New-Object System.Drawing.Size(548, 46)
$startButton.Add_Click({ Start-Claude })
$form.Controls.Add($startButton)

$doctorButton = New-Object System.Windows.Forms.Button
$doctorButton.Text = "Doctor"
$doctorButton.Location = New-Object System.Drawing.Point(590, 408)
$doctorButton.Size = New-Object System.Drawing.Size(128, 46)
$doctorButton.Add_Click({ Invoke-Doctor })
$form.Controls.Add($doctorButton)

$clearKeyCheckBox = New-Object System.Windows.Forms.CheckBox
$clearKeyCheckBox.Text = "Clear key when closing (recommended)"
$clearKeyCheckBox.Checked = $true
$clearKeyCheckBox.Location = New-Object System.Drawing.Point(28, 462)
$clearKeyCheckBox.Size = New-Object System.Drawing.Size(260, 28)
$form.Controls.Add($clearKeyCheckBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Waiting for settings"
$statusLabel.ForeColor = [System.Drawing.Color]::DimGray
$statusLabel.Location = New-Object System.Drawing.Point(300, 466)
$statusLabel.Size = New-Object System.Drawing.Size(690, 24)
$form.Controls.Add($statusLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(28, 500)
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
    Add-Log "Loaded local settings."
}

$form.Add_FormClosing({
    if ($clearKeyCheckBox.Checked) {
        Save-Config (Normalize-BaseUrl $baseUrlBox.Text) "" ([string]$modelBox.Text) $true $workingDirBox.Text.Trim()
        $keyBox.Text = ""
    }
})

Add-Log "Ready."
[void]$form.ShowDialog()



