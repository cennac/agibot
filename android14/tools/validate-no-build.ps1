param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$failures = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

$baselinePath = Join-Path $Root 'baseline\radxa-android14-rkr6.json'
Assert-True (Test-Path $baselinePath) "Missing baseline JSON: $baselinePath"

if (Test-Path $baselinePath) {
    try {
        $baseline = Get-Content -Raw $baselinePath | ConvertFrom-Json
        Assert-True ($baseline.baseline.manifest_revision -eq 'ac6785b31865b06223ae262c8ed42b14b11f5aaa') 'Unexpected manifest revision'
        Assert-True ($baseline.baseline.rockchip_release -eq 'RKR6') 'Unexpected Rockchip release'
        Assert-True ($baseline.external_references.Count -ge 4) 'Missing external reference provenance'

        foreach ($reference in $baseline.external_references) {
            $path = Join-Path $Root $reference.path
            Assert-True (Test-Path $path) "Missing external reference: $($reference.path)"
            if (Test-Path $path) {
                $hash = (Get-FileHash -Algorithm SHA256 $path).Hash
                Assert-True ($hash -eq $reference.sha256) "Hash mismatch: $($reference.path)"
            }
        }
    }
    catch {
        $failures.Add("Baseline JSON parsing failed: $($_.Exception.Message)")
    }
}

foreach ($relative in @(
    'README.md',
    'VERSIONING.md',
    'dts\agibot-display-bringup.dtsi',
    'overlay\device\rockchip\rk3588\agibot_mb0002\AndroidProducts.mk',
    'overlay\device\rockchip\rk3588\agibot_mb0002\agibot_mb0002.mk',
    'overlay\device\rockchip\rk3588\agibot_mb0002\BoardConfig.mk',
    'overlay\device\rockchip\rk3588\agibot_mb0002\device.mk'
)) {
    Assert-True (Test-Path (Join-Path $Root $relative)) "Required file missing: $relative"
}

foreach ($directory in @('.repo', 'out', 'build-out', 'obj', 'dist')) {
    Assert-True (-not (Test-Path (Join-Path $Root $directory))) "Build/source-tree directory exists: $directory"
}

$prohibitedExtensions = '.img', '.dtb', '.ko', '.so', '.bin', '.7z', '.zip'
$trackedFiles = Get-ChildItem $Root -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\.git(\\|$)'
}
foreach ($file in $trackedFiles) {
    if ($prohibitedExtensions -contains $file.Extension.ToLowerInvariant()) {
        $failures.Add("Binary/build artifact tracked in workspace: $($file.FullName)")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "ERROR: $_" }
    exit 1
}

Write-Host 'AGIBOT Android 14 phase 0 validation passed (no build invoked).'
