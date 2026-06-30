$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $repoRoot "downloads"

if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$packages = @(
    @{
        Name = "AquaClaudeCode-zh-CN.zip"
        Source = Join-Path $repoRoot "zh-CN"
        Files = @("AquaClaudeCode-GUI.ps1", "*.cmd", "README.md", "aqua-claude-config.json")
    },
    @{
        Name = "AquaClaudeCode-en.zip"
        Source = Join-Path $repoRoot "en"
        Files = @("AquaClaudeCode-GUI.ps1", "Open-AquaClaudeCode.cmd", "README.md", "aqua-claude-config.json")
    }
)

foreach ($package in $packages) {
    $zipPath = Join-Path $outputDir $package.Name
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    $paths = foreach ($file in $package.Files) {
        Get-ChildItem -LiteralPath $package.Source -Filter $file -File | Select-Object -ExpandProperty FullName
    }
    Compress-Archive -Path $paths -DestinationPath $zipPath -Force
}

Get-FileHash -Algorithm SHA256 -LiteralPath ($packages | ForEach-Object { Join-Path $outputDir $_.Name }) |
    Select-Object Algorithm, Hash, Path |
    Format-Table -AutoSize
