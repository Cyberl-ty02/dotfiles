[CmdletBinding()]
param([switch]$Apply)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$codium = Get-Command codium.cmd, codium.exe, codium -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $codium) { throw "VSCodium CLI was not found." }

function Get-Manifest([string]$Name) {
    @(Get-Content -LiteralPath (Join-Path $PSScriptRoot $Name) |
        ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Where-Object { $_ -and -not $_.StartsWith("#") })
}
function Invoke-Codium([string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $lines = @(& $codium.Source @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    [pscustomobject]@{ Code = $code; Lines = $lines }
}
function Get-Installed {
    $result = Invoke-Codium -Arguments @("--list-extensions")
    if ($result.Code -ne 0) { throw "Could not read the installed extension list." }
    @($result.Lines | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } |
        Where-Object { $_ -match '^[a-z0-9_-]+[.][a-z0-9_.-]+$' } | Sort-Object -Unique)
}
$wanted = @((Get-Manifest "extensions-common.txt") +
    (Get-Manifest "extensions-windows.txt") | Sort-Object -Unique)
$excluded = @((Get-Manifest "extensions-excluded.txt") +
    (Get-Manifest "extensions-linux.txt") | Sort-Object -Unique)
if (@($wanted | Where-Object { $excluded -contains $_ }).Count) {
    throw "Conflicting desired and excluded extension IDs."
}
$installed = @(Get-Installed)
$pending = @($excluded | Where-Object { $installed -contains $_ })
if ($Apply) {
    while ($pending.Count) {
        $previousCount = $pending.Count
        foreach ($id in $pending) {
            $installed = @(Get-Installed)
            if ($installed -notcontains $id) { continue }
            Write-Host "Removing replaced extension: $id"
            $result = Invoke-Codium -Arguments @("--uninstall-extension", $id)
            # Dependents may be removed later in this pass. Recheck only on progress.
        }
        $installed = @(Get-Installed)
        $pending = @($excluded | Where-Object { $installed -contains $_ })
        if ($pending.Count -eq $previousCount) {
            throw "Excluded extensions still have dependents: $($pending -join ', ')"
        }
    }
} else {
    foreach ($id in $pending) { Write-Host "Would remove replaced extension: $id" }
}
$installed = @(Get-Installed)
foreach ($id in $wanted) {
    if ($installed -contains $id) { continue }
    if ($Apply) {
        Write-Host "Installing: $id"
        $result = Invoke-Codium -Arguments @("--install-extension", $id,
            "--do-not-include-pack-dependencies")
        if ($result.Code -ne 0) { throw "Extension install failed: $id" }
    } else { Write-Host "Would install: $id" }
}
if ($Apply) {
    $installed = @(Get-Installed)
    if (@($wanted | Where-Object { $installed -notcontains $_ }).Count -or
        @($excluded | Where-Object { $installed -contains $_ }).Count) {
        throw "Extension manifest verification failed."
    }
    Write-Host "Extension manifest verified. Restart existing editor windows normally if needed."
} else { Write-Host "Preview only. Run with -Apply to synchronize." }
