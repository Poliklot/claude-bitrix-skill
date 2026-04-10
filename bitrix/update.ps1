[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$RepoCandidates = @(
    'Poliklot/bitrix-agent-skill',
    'Poliklot/claude-bitrix-skill'
)
$Branch = 'master'
$LocalVersionFile = Join-Path $PSScriptRoot 'VERSION'

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

function Get-LocalVersion {
    if (Test-Path -LiteralPath $LocalVersionFile) {
        return (Get-Content -LiteralPath $LocalVersionFile -Raw).Trim()
    }

    return ''
}

function Convert-ToComparableVersion {
    param([string]$Version)

    if ([string]::IsNullOrWhiteSpace($Version)) {
        return [version]'0.0.0.0'
    }

    $parts = $Version.Trim().TrimStart('v').Split('.')
    while ($parts.Count -lt 4) {
        $parts += '0'
    }

    return [version]::new(
        [int]$parts[0],
        [int]$parts[1],
        [int]$parts[2],
        [int]$parts[3]
    )
}

function Test-VersionGreater {
    param(
        [string]$Left,
        [string]$Right
    )

    return (Convert-ToComparableVersion $Left) -gt (Convert-ToComparableVersion $Right)
}

function Get-TargetMode {
    $normalizedPath = $PSScriptRoot -replace '\\', '/'
    $codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
    $codexSkillPath = (Join-Path (Join-Path $codexRoot 'skills') 'bitrix') -replace '\\', '/'
    $claudeSkillPath = (Join-Path (Join-Path (Join-Path $HOME '.claude') 'skills') 'bitrix') -replace '\\', '/'

    if ($normalizedPath -eq $codexSkillPath -or $normalizedPath -like '*/.codex/skills/bitrix') {
        return 'codex'
    }

    if ($normalizedPath -eq $claudeSkillPath -or $normalizedPath -like '*/.claude/skills/bitrix') {
        return 'claude'
    }

    return 'auto'
}

function Invoke-CheckMode {
    $localVersion = Get-LocalVersion

    try {
        $remoteMeta = Resolve-RemoteRepo
    }
    catch {
        Write-Output 'CHECK_FAILED reason=remote_version_unavailable'
        return
    }

    $remoteVersion = $remoteMeta.Version

    if ([string]::IsNullOrWhiteSpace($localVersion)) {
        Write-Output "UPDATE_AVAILABLE local=none remote=$remoteVersion"
        return
    }

    if (Test-VersionGreater -Left $remoteVersion -Right $localVersion) {
        Write-Output "UPDATE_AVAILABLE local=$localVersion remote=$remoteVersion"
        return
    }

    Write-Output "UP_TO_DATE version=$localVersion"
}

if ($Check) {
    Invoke-CheckMode
    exit 0
}

Write-Host 'Checking versions'

$remoteMeta = Resolve-RemoteRepo
$repo = $remoteMeta.Repo
$remoteVersion = $remoteMeta.Version
$localVersion = Get-LocalVersion

if (-not $Force) {
    if (-not [string]::IsNullOrWhiteSpace($localVersion) -and $localVersion -eq $remoteVersion) {
        Write-Host "Already up to date ($localVersion)"
        exit 0
    }

    if (-not [string]::IsNullOrWhiteSpace($localVersion) -and (Test-VersionGreater -Left $localVersion -Right $remoteVersion)) {
        Write-Host "Installed version ($localVersion) is newer than remote ($remoteVersion)"
        exit 0
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bitrix-agent-skill-update-" + [guid]::NewGuid().ToString('N'))
$tempScriptPath = Join-Path $tempRoot 'install.ps1'
$installScriptUrl = "https://raw.githubusercontent.com/$repo/$Branch/install.ps1"
$targetMode = Get-TargetMode

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    Write-Host 'Fetching latest installer from GitHub...'
    Invoke-WebRequestCompat -Uri $installScriptUrl -OutFile $tempScriptPath | Out-Null

    $installScript = [scriptblock]::Create((Get-Content -LiteralPath $tempScriptPath -Raw))

    switch ($targetMode) {
        'claude' {
            if ($Force) { & $installScript -Claude -Force } else { & $installScript -Claude }
        }
        'codex' {
            if ($Force) { & $installScript -Codex -Force } else { & $installScript -Codex }
        }
        default {
            if ($Force) { & $installScript -Auto -Force } else { & $installScript -Auto }
        }
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
