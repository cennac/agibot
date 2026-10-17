[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$Image,

    [Parameter(Mandatory = $true)]
    [ValidateSet('armbian', 'android', 'openwrt', 'fnos')]
    [string]$Platform,

    [Parameter(Mandatory = $true)]
    [ValidateSet('validated', 'candidates', 'archive', 'quarantine', 'derived')]
    [string]$Channel,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$Variant,

    [datetime]$BuildDate = (Get-Date),

    [string]$ReleaseRoot = 'E:\AIPorject\101\agibot-releases',

    [switch]$Move
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $Image).Path
$hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
$directoryName = '{0:yyyy-MM-dd}-{1}-{2}' -f $BuildDate, $Variant, $hash.Substring(0, 8)
$destinationDirectory = Join-Path $ReleaseRoot (Join-Path $Platform (Join-Path $Channel $directoryName))
$destination = Join-Path $destinationDirectory ([IO.Path]::GetFileName($source))

if (Test-Path -LiteralPath $destination) {
    $existingHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($existingHash -ne $hash) {
        throw "Destination exists with different content: $destination"
    }
    Write-Host "Already archived: $destination"
} else {
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    if ($Move) {
        Move-Item -LiteralPath $source -Destination $destination
    } else {
        # Use a real copy. Hard links can let a later in-place build corrupt the archive.
        Copy-Item -LiteralPath $source -Destination $destination
    }
}

$actualHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $hash) {
    throw "Post-archive SHA-256 verification failed: $destination"
}

$sumLine = "$actualHash  $([IO.Path]::GetFileName($destination))`n"
[IO.File]::WriteAllText((Join-Path $destinationDirectory 'SHA256SUMS.txt'), $sumLine,
    [Text.UTF8Encoding]::new($false))

Write-Host "Archived: $destination"
Write-Host "SHA-256: $actualHash"
