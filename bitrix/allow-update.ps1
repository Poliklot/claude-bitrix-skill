[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Claude helper: writes permission rules into ~/.claude/settings.json

$SettingsFile = if ($env:CLAUDE_SETTINGS_FILE) {
    $env:CLAUDE_SETTINGS_FILE
}
else {
    Join-Path (Join-Path $HOME '.claude') 'settings.json'
}

$Rules = @(
    'Bash(bash ~/.claude/skills/bitrix/update.sh:*)',
    'Bash(powershell -ExecutionPolicy Bypass -File ~/.claude/skills/bitrix/update.ps1:*)',
    'Bash(powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/bitrix/update.ps1:*)',
    'Bash(pwsh -File ~/.claude/skills/bitrix/update.ps1:*)'
)

function New-EmptyObject {
    return [pscustomobject]@{}
}

if (-not (Test-Path -LiteralPath (Split-Path -Parent $SettingsFile))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $SettingsFile) -Force | Out-Null
}

$data = New-EmptyObject
if (Test-Path -LiteralPath $SettingsFile) {
    $raw = Get-Content -LiteralPath $SettingsFile -Raw
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $data = $raw | ConvertFrom-Json
    }
}

if ($data -isnot [pscustomobject]) {
    throw "Ошибка: $SettingsFile должен содержать JSON-объект"
}

if (-not ($data.PSObject.Properties.Name -contains 'permissions')) {
    $data | Add-Member -NotePropertyName permissions -NotePropertyValue (New-EmptyObject)
}

if ($data.permissions -isnot [pscustomobject]) {
    throw 'Ошибка: поле permissions должно быть объектом'
}

if (-not ($data.permissions.PSObject.Properties.Name -contains 'allow')) {
    $data.permissions | Add-Member -NotePropertyName allow -NotePropertyValue @()
}

$allow = @($data.permissions.allow)
$changed = $false

foreach ($rule in $Rules) {
    if ($allow -notcontains $rule) {
        $allow += $rule
        $changed = $true
    }
}

$data.permissions.allow = $allow
$json = $data | ConvertTo-Json -Depth 10
Set-Content -LiteralPath $SettingsFile -Value ($json + [Environment]::NewLine) -Encoding UTF8

if ($changed) {
    Write-Output 'updated'
}
else {
    Write-Output 'already_present'
}

Write-Host "Готово: разрешения для update.sh/update.ps1 записаны в $SettingsFile"
