[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Claude,
    [switch]$Codex,
    [switch]$Both,
    [switch]$Auto
)

$ErrorActionPreference = 'Stop'

$RepoCandidates = @(
    'Poliklot/bitrix-agent-skill',
    'Poliklot/claude-bitrix-skill'
)
$Branch = 'master'

$ClaudeInstallDir = Join-Path (Join-Path (Join-Path $HOME '.claude') 'skills') 'bitrix'
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$CodexInstallDir = Join-Path (Join-Path $CodexHome 'skills') 'bitrix'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  [ok] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [warn] $Message" -ForegroundColor Yellow
}

function Invoke-WebRequestCompat {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [string]$OutFile
    )

    $params = @{ Uri = $Uri }
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $params.UseBasicParsing = $true
    }
    if ($OutFile) {
        $params.OutFile = $OutFile
    }

    Invoke-WebRequest @params
}

function Get-TargetMode {
    if ($Both) { return 'both' }
    if ($Claude -and $Codex) { return 'both' }
    if ($Claude) { return 'claude' }
    if ($Codex) { return 'codex' }
    if ($Auto) { return 'auto' }
    return 'auto'
}

function Get-InstallTargets {
    param([string]$Mode)

    $targets = @()

    switch ($Mode) {
        'claude' {
            $targets += @{ Name = 'Claude'; Path = $ClaudeInstallDir }
        }
        'codex' {
            $targets += @{ Name = 'Codex'; Path = $CodexInstallDir }
        }
        'both' {
            $targets += @{ Name = 'Claude'; Path = $ClaudeInstallDir }
            $targets += @{ Name = 'Codex'; Path = $CodexInstallDir }
        }
        'auto' {
            if (Test-Path -LiteralPath (Join-Path $HOME '.claude')) {
                $targets += @{ Name = 'Claude'; Path = $ClaudeInstallDir }
            }
            if ($env:CODEX_HOME -or (Test-Path -LiteralPath (Join-Path $HOME '.codex'))) {
                $targets += @{ Name = 'Codex'; Path = $CodexInstallDir }
            }
            if ($targets.Count -eq 0) {
                Write-Warn 'Claude/Codex homes were not detected. Defaulting to both install paths.'
                $targets += @{ Name = 'Claude'; Path = $ClaudeInstallDir }
                $targets += @{ Name = 'Codex'; Path = $CodexInstallDir }
            }
        }
        default {
            throw "Unknown target mode: $Mode"
        }
    }

    return $targets
}

function Resolve-RemoteRepo {
    foreach ($repo in $RepoCandidates) {
        $url = "https://raw.githubusercontent.com/$repo/$Branch/bitrix/VERSION"
        try {
            $version = (Invoke-WebRequestCompat -Uri $url).Content.Trim()
            if (-not [string]::IsNullOrWhiteSpace($version)) {
                return @{
                    Repo = $repo
                    Version = $version
                }
            }
        }
        catch {
        }
    }

    throw 'Could not fetch remote version from current or legacy repository slug.'
}

function Get-InstalledVersion {
    param([string]$InstallDir)

    $versionFile = Join-Path $InstallDir 'VERSION'
    if (Test-Path -LiteralPath $versionFile) {
        return (Get-Content -LiteralPath $versionFile -Raw).Trim()
    }

    return ''
}

$targetMode = Get-TargetMode
$targets = Get-InstallTargets -Mode $targetMode

Write-Step 'Checking versions'

$remoteMeta = Resolve-RemoteRepo
$repo = $remoteMeta.Repo
$remoteVersion = $remoteMeta.Version
Write-Ok "Resolved repository: $repo"
Write-Ok "Remote version: $remoteVersion"

$requiresInstall = $false

foreach ($target in $targets) {
    $localVersion = Get-InstalledVersion -InstallDir $target.Path
    if ([string]::IsNullOrWhiteSpace($localVersion)) {
        Write-Warn "$($target.Name): no installed version found"
    }
    else {
        Write-Ok "$($target.Name): installed $localVersion"
    }

    if ($Force -or $localVersion -ne $remoteVersion) {
        $requiresInstall = $true
    }
}

if (-not $requiresInstall) {
    Write-Host "`nAlready up to date. ($remoteVersion)" -ForegroundColor Green
    exit 0
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bitrix-agent-skill-" + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $tempRoot 'skill.zip'
$zipUrl = "https://github.com/$repo/archive/refs/heads/$Branch.zip"

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    Write-Step 'Downloading'
    Invoke-WebRequestCompat -Uri $zipUrl -OutFile $zipPath | Out-Null
    Write-Ok 'Downloaded'

    Expand-Archive -LiteralPath $zipPath -DestinationPath $tempRoot -Force
    $extractedDir = Get-ChildItem -LiteralPath $tempRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bitrix') } |
        Select-Object -First 1

    if ($null -eq $extractedDir) {
        throw 'Unexpected zip structure.'
    }

    $skillSource = Join-Path $extractedDir.FullName 'bitrix'
    Write-Ok 'Extracted'

    foreach ($target in $targets) {
        $localVersion = Get-InstalledVersion -InstallDir $target.Path

        if (-not $Force -and $localVersion -eq $remoteVersion) {
            Write-Ok "$($target.Name): already up to date, skipping"
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($localVersion) -and $localVersion -ne $remoteVersion) {
            Write-Step "$($target.Name): updating $localVersion -> $remoteVersion"
        }
        else {
            Write-Step "$($target.Name): installing $remoteVersion"
        }

        New-Item -ItemType Directory -Path $target.Path -Force | Out-Null
        Get-ChildItem -LiteralPath $target.Path -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force

        Get-ChildItem -LiteralPath $skillSource -Force |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $target.Path -Recurse -Force
            }

        $installedVersion = Get-InstalledVersion -InstallDir $target.Path
        if ($installedVersion -ne $remoteVersion) {
            throw "$($target.Name): version mismatch after install"
        }

        Write-Ok "$($target.Name): files copied to $($target.Path)"
    }

    Write-Host "`nSuccess! Bitrix Agent Skill $remoteVersion installed" -ForegroundColor Green
    Write-Host 'Targets:'
    foreach ($target in $targets) {
        Write-Host "  - $($target.Name): $($target.Path)"
    }
    Write-Host 'Usage: /bitrix <your task>'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
