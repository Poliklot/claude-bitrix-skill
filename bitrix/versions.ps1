[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoCandidates = @(
    'Poliklot/bitrix-agent-skill',
    'Poliklot/claude-bitrix-skill'
)

function Invoke-WebRequestCompat {
    param(
        [Parameter(Mandatory = $true)][string]$Uri
    )

    $params = @{ Uri = $Uri }
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $params.UseBasicParsing = $true
    }

    Invoke-WebRequest @params
}

function Resolve-Repo {
    foreach ($repo in $RepoCandidates) {
        try {
            Invoke-WebRequestCompat -Uri "https://github.com/$repo" | Out-Null
            return $repo
        }
        catch {
        }
    }

    throw 'Could not resolve repository.'
}

$repo = Resolve-Repo
$response = Invoke-WebRequestCompat -Uri "https://api.github.com/repos/$repo/releases?per_page=15"
$releases = $response.Content | ConvertFrom-Json

if (-not $releases -or $releases.Count -eq 0) {
    throw 'No releases found.'
}

Write-Host "Available releases for $repo:"
for ($i = 0; $i -lt $releases.Count; $i++) {
    $release = $releases[$i]
    $tag = $release.tag_name
    if ([string]::IsNullOrWhiteSpace($tag)) {
        continue
    }

    $date = if ($release.published_at) { "$($release.published_at)".Substring(0, 10) } elseif ($release.created_at) { "$($release.created_at)".Substring(0, 10) } else { '' }
    $suffix = if ($i -eq 0) { ' [latest]' } else { '' }

    if ([string]::IsNullOrWhiteSpace($date)) {
        Write-Host "  - $tag$suffix"
    }
    else {
        Write-Host "  - $tag ($date)$suffix"
    }
}

Write-Host ''
Write-Host 'Examples:'
Write-Host '  powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\bitrix\update.ps1" -Version 1.5.0'
Write-Host '  powershell -ExecutionPolicy Bypass -File "$HOME\.codex\skills\bitrix\update.ps1" -Version 1.5.0'
