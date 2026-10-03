[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "powershell\profile.ps1")).Path
$profileDirectory = Split-Path -Parent $PROFILE.CurrentUserAllHosts
$allHostsProfile = $PROFILE.CurrentUserAllHosts
$currentHostProfile = $PROFILE.CurrentUserCurrentHost
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$tokens = $null
$parseErrors = $null
[Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors) | Out-Null
if (@($parseErrors).Count) {
    throw "Tracked profile has $(@($parseErrors).Count) PowerShell parser error(s)."
}

if (-not (Test-Path -LiteralPath $profileDirectory)) {
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
}

$escapedSource = $source.Replace("'", "''")
$stub = @"
# Managed by the dotfiles repository. Edit the tracked source instead.
`$dotfilesProfile = '$escapedSource'
if (Test-Path -LiteralPath `$dotfilesProfile) {
    . `$dotfilesProfile
} else {
    Write-Warning "Tracked PowerShell profile not found: `$dotfilesProfile"
}
"@

function Backup-Profile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        $backup = "$Path.backup-$timestamp"
        Move-Item -LiteralPath $Path -Destination $backup
        Write-Host "Backed up $Path to $backup"
    }
}

$needsInstall = $true
if (Test-Path -LiteralPath $allHostsProfile) {
    $existing = Get-Content -LiteralPath $allHostsProfile -Raw
    $needsInstall = $existing.Trim() -ne $stub.Trim()
}

if ($needsInstall) {
    Backup-Profile -Path $allHostsProfile
    [IO.File]::WriteAllText($allHostsProfile, $stub, (New-Object Text.UTF8Encoding($true)))
    Write-Host "Installed profile loader at $allHostsProfile"
} else {
    Write-Host "Profile loader is already current: $allHostsProfile"
}

# The all-hosts loader supersedes the old ConsoleHost-only profile. Preserve it
# as a backup so its contents can be recovered without loading two profiles.
Backup-Profile -Path $currentHostProfile

& powershell.exe -NoLogo -NoProfile -Command ". '$escapedSource'; if (`$global:DotfilesPowerShellProfile -ne '$escapedSource') { exit 1 }"
if ($LASTEXITCODE -ne 0) {
    throw "Tracked PowerShell profile validation failed with exit code $LASTEXITCODE."
}

Write-Host "Windows PowerShell 5.1 profile is ready. Open a new shell to use it."
