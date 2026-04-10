[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Claude,
    [switch]$Codex,
    [switch]$Both,
    [switch]$Auto,
    [string]$Version
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

function Normalize-Version {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return $Value.Trim().TrimStart('v')
}

function Convert-VersionToTag {
    param([string]$Value)

    $normalized = Normalize-Version $Value
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return ''
    }

    return "v$normalized"
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

function Get-BranchVersion {
    param([string]$Repo)

    try {
        $url = "https://raw.githubusercontent.com/$Repo/$Branch/bitrix/VERSION"
        return (Invoke-WebRequestCompat -Uri $url).Content.Trim()
    }
    catch {
        return ''
    }
}

function Get-LatestReleaseTag {
    param([string]$Repo)

    try {
        $response = Invoke-WebRequestCompat -Uri "https://github.com/$Repo/releases/latest"
        $uri = $response.BaseResponse.ResponseUri.AbsoluteUri
        if ($uri -match '/releases/tag/(?<tag>[^/]+)$') {
            return $Matches.tag
        }
    }
    catch {
    }

    return ''
}

function Resolve-RemoteRepo {
    param([string]$RequestedVersion)

    foreach ($repo in $RepoCandidates) {
        $branchVersion = Get-BranchVersion -Repo $repo

        if (-not [string]::IsNullOrWhiteSpace($RequestedVersion)) {
            if (-not [string]::IsNullOrWhiteSpace($branchVersion)) {
                return @{
                    Repo = $repo
                    Version = (Normalize-Version $RequestedVersion)
                    Tag = (Convert-VersionToTag $RequestedVersion)
                }
            }
            continue
        }

        $latestTag = Get-LatestReleaseTag -Repo $repo
        if (-not [string]::IsNullOrWhiteSpace($latestTag)) {
            return @{
                Repo = $repo
                Version = (Normalize-Version $latestTag)
                Tag = $latestTag
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($branchVersion)) {
            return @{
                Repo = $repo
                Version = (Normalize-Version $branchVersion)
                Tag = (Convert-VersionToTag $branchVersion)
            }
        }
    }

    throw 'Could not resolve repository or target version.'
}

function Get-InstalledVersion {
    param([string]$InstallDir)

    $versionFile = Join-Path $InstallDir 'VERSION'
    if (Test-Path -LiteralPath $versionFile) {
        return (Get-Content -LiteralPath $versionFile -Raw).Trim()
    }

    return ''
}

function Download-Archive {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [string]$ReleaseTag,
        [switch]$ExplicitVersion
    )

    if (-not [string]::IsNullOrWhiteSpace($ReleaseTag)) {
        $tagUrl = "https://github.com/$Repo/archive/refs/tags/$ReleaseTag.zip"
        try {
            Invoke-WebRequestCompat -Uri $tagUrl -OutFile $OutputPath | Out-Null
            return "release:$ReleaseTag"
        }
        catch {
            if ($ExplicitVersion) {
                throw "Could not download release archive $ReleaseTag from $Repo."
            }

            Write-Warn "Could not download release archive $ReleaseTag. Falling back to $Branch."
        }
    }

    $branchUrl = "https://github.com/$Repo/archive/refs/heads/$Branch.zip"
    Invoke-WebRequestCompat -Uri $branchUrl -OutFile $OutputPath | Out-Null
    return "branch:$Branch"
}

$requestedVersion = Normalize-Version $Version
$targetMode = Get-TargetMode
$targets = Get-InstallTargets -Mode $targetMode

Write-Step 'Checking versions'

$remoteMeta = Resolve-RemoteRepo -RequestedVersion $requestedVersion
$repo = $remoteMeta.Repo
$remoteVersion = $remoteMeta.Version
$releaseTag = $remoteMeta.Tag
Write-Ok "Resolved repository: $repo"
Write-Ok "Target version: $remoteVersion"
if (-not [string]::IsNullOrWhiteSpace($releaseTag)) {
    Write-Ok "Preferred release tag: $releaseTag"
}

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

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    Write-Step 'Downloading'
    $archiveSource = Download-Archive -Repo $repo -OutputPath $zipPath -ReleaseTag $releaseTag -ExplicitVersion:([bool]$requestedVersion)
    Write-Ok "Downloaded from $archiveSource"

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
    Write-Host "Source: $archiveSource"
    Write-Host 'Usage: /bitrix <your task>'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
