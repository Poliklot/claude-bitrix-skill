[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Check,
    [string]$Version
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
                    Ref = (Convert-VersionToTag $RequestedVersion)
                }
            }
            continue
        }

        $latestTag = Get-LatestReleaseTag -Repo $repo
        if (-not [string]::IsNullOrWhiteSpace($latestTag)) {
            return @{
                Repo = $repo
                Version = (Normalize-Version $latestTag)
                Ref = $latestTag
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($branchVersion)) {
            return @{
                Repo = $repo
                Version = (Normalize-Version $branchVersion)
                Ref = $Branch
            }
        }
    }

    throw 'Could not resolve repository or target version.'
}

function Get-LocalVersion {
    if (Test-Path -LiteralPath $LocalVersionFile) {
        return (Get-Content -LiteralPath $LocalVersionFile -Raw).Trim()
    }

    return ''
}

function Convert-ToComparableVersion {
    param([string]$VersionValue)

    if ([string]::IsNullOrWhiteSpace($VersionValue)) {
        return [version]'0.0.0.0'
    }

    $parts = $VersionValue.Trim().TrimStart('v').Split('.')
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
    param([string]$RequestedVersion)

    $localVersion = Get-LocalVersion

    try {
        $remoteMeta = Resolve-RemoteRepo -RequestedVersion $RequestedVersion
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

$requestedVersion = Normalize-Version $Version

if ($Check) {
    Invoke-CheckMode -RequestedVersion $requestedVersion
    exit 0
}

Write-Host 'Checking versions'

$remoteMeta = Resolve-RemoteRepo -RequestedVersion $requestedVersion
$repo = $remoteMeta.Repo
$remoteVersion = $remoteMeta.Version
$installRef = $remoteMeta.Ref
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
$installScriptUrl = "https://raw.githubusercontent.com/$repo/$installRef/install.ps1"
$targetMode = Get-TargetMode

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    Write-Host 'Fetching installer from GitHub...'
    Invoke-WebRequestCompat -Uri $installScriptUrl -OutFile $tempScriptPath | Out-Null

    $installScript = [scriptblock]::Create((Get-Content -LiteralPath $tempScriptPath -Raw))
    $args = @()

    switch ($targetMode) {
        'claude' { $args += '-Claude' }
        'codex' { $args += '-Codex' }
        default { $args += '-Auto' }
    }

    if ($Force) {
        $args += '-Force'
    }

    if (-not [string]::IsNullOrWhiteSpace($requestedVersion)) {
        $args += '-Version'
        $args += $requestedVersion
    }

    & $installScript @args
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
