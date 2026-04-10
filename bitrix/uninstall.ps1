[CmdletBinding()]
param(
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$TargetDir = $PSScriptRoot

if (-not $Yes) {
    $answer = Read-Host "Удалить Bitrix Agent Skill из $TargetDir? [y/N]"
    if ($answer -notmatch '^(y|yes)$') {
        Write-Host 'Отменено.'
        exit 0
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bitrix-agent-skill-uninstall-" + [guid]::NewGuid().ToString('N'))
$cleanupScript = Join-Path $tempRoot 'cleanup.ps1'
$escapedTargetDir = $TargetDir.Replace("'", "''")
$escapedCleanupScript = $cleanupScript.Replace("'", "''")

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

$cleanupBody = @"
Start-Sleep -Milliseconds 500
if (Test-Path -LiteralPath '$escapedTargetDir') {
    Remove-Item -LiteralPath '$escapedTargetDir' -Recurse -Force
}
if (Test-Path -LiteralPath '$escapedCleanupScript') {
    Remove-Item -LiteralPath '$escapedCleanupScript' -Force
}
"@

Set-Content -LiteralPath $cleanupScript -Value $cleanupBody -Encoding UTF8

$powershellBinary = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
Start-Process -FilePath $powershellBinary -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $cleanupScript
) -WindowStyle Hidden | Out-Null

Write-Host "Удаление запущено: $TargetDir"
Write-Host 'Если каталог ещё виден несколько секунд, это нормально.'
