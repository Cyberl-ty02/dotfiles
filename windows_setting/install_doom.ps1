[CmdletBinding()]
param(
    [switch]$BackupExisting,
    [switch]$SkipSync,
    [switch]$Upgrade
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$configSource = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot "dot_config\doom")).Path
$emacsDirectory = Join-Path $env:APPDATA ".emacs.d"
$legacyEmacsDirectories = @(
    (Join-Path $env:LOCALAPPDATA ".emacs.d"),
    (Join-Path $env:USERPROFILE ".emacs.d")
)
$doomConfigParent = Join-Path $env:APPDATA ".config"
$doomConfig = Join-Path $doomConfigParent "doom"
$legacyDoomConfig = Join-Path $env:LOCALAPPDATA ".config\doom"
$officialRemote = "https://github.com/doomemacs/core"

function Move-Aside {
    param([Parameter(Mandatory = $true)][string]$Path)

    $backup = "$Path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item -LiteralPath $Path -Destination $backup
    Write-Host "Existing path moved to $backup"
}

function Test-EmptyDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
    return -not (Get-ChildItem -LiteralPath $Path -Force | Select-Object -First 1)
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE."
    }
}

foreach ($required in @("config.el", "custom.el", "init.el", "packages.el", "README.md")) {
    if (-not (Test-Path -LiteralPath (Join-Path $configSource $required) -PathType Leaf)) {
        throw "The shared Doom configuration is incomplete: $configSource"
    }
}

$git = (Get-Command git.exe -CommandType Application -ErrorAction Stop).Source
$emacs = (Get-Command emacs.exe -CommandType Application -ErrorAction Stop).Source
$powershell = (Get-Command powershell.exe -CommandType Application -ErrorAction Stop).Source
$frameworkMigrated = $false
$userBin = Join-Path $env:USERPROFILE ".local\bin"
if ((Test-Path -LiteralPath $userBin) -and -not (($env:PATH -split ";") -contains $userBin)) {
    $env:PATH = "$userBin;$env:PATH"
}

# Native Windows Emacs uses %APPDATA%\.emacs.d when HOME is unset. Reuse that
# upstream default and migrate a recognized older checkout instead of carrying
# an EMACSDIR override in every shell and launcher.
if (Test-EmptyDirectory -Path $emacsDirectory) {
    Remove-Item -LiteralPath $emacsDirectory -Force
}

if (-not (Test-Path -LiteralPath $emacsDirectory)) {
    $migrationCandidates = @($legacyEmacsDirectories | Where-Object {
        Test-Path -LiteralPath (Join-Path $_ ".git") -PathType Container
    })
    if ($migrationCandidates.Count -gt 1) {
        throw "Multiple legacy Doom checkouts were found: $($migrationCandidates -join ', ')"
    }
    if ($migrationCandidates.Count -eq 1) {
        Move-Item -LiteralPath $migrationCandidates[0] -Destination $emacsDirectory
        $frameworkMigrated = $true
        Write-Host "Moved the Doom framework to Emacs' default directory: $emacsDirectory"
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $emacsDirectory ".git") -PathType Container)) {
    if (Test-Path -LiteralPath $emacsDirectory) {
        if ($BackupExisting) {
            Move-Aside -Path $emacsDirectory
        } else {
            throw "The Emacs destination exists but is not a Git checkout: $emacsDirectory"
        }
    }
}

if ($frameworkMigrated) {
    $generatedState = Join-Path $emacsDirectory ".local"
    if (Test-Path -LiteralPath $generatedState) {
        Remove-Item -LiteralPath $generatedState -Recurse -Force
        Write-Host "Removed path-dependent generated state; Doom will rebuild it."
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $emacsDirectory ".git") -PathType Container)) {
    Invoke-NativeCommand -FilePath $git -ArgumentList @(
        "clone", "--depth", "1", $officialRemote, $emacsDirectory
    )
}

$remote = (& $git -C $emacsDirectory remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0) { throw "Unable to read the Doom origin remote." }
switch -Regex ($remote) {
    '^https://github\.com/doomemacs/(core|doomemacs)(\.git)?$' {
        Invoke-NativeCommand -FilePath $git -ArgumentList @(
            "-C", $emacsDirectory, "remote", "set-url", "origin", $officialRemote
        )
    }
    '^git@github\.com:doomemacs/(core|doomemacs)(\.git)?$' {
        Invoke-NativeCommand -FilePath $git -ArgumentList @(
            "-C", $emacsDirectory, "remote", "set-url", "origin", $officialRemote
        )
    }
    default {
        throw "The existing Doom checkout uses an unrecognized origin: $remote"
    }
}

if (-not (Test-Path -LiteralPath $doomConfigParent -PathType Container)) {
    New-Item -ItemType Directory -Path $doomConfigParent -Force | Out-Null
}

$configLinked = $false
if (Test-Path -LiteralPath $doomConfig) {
    $existing = Get-Item -LiteralPath $doomConfig -Force
    $isReparsePoint = ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    $target = if ($isReparsePoint -and $existing.Target) {
        [IO.Path]::GetFullPath([string]@($existing.Target)[0])
    }
    if ($target -and $target.TrimEnd("\") -ieq $configSource.TrimEnd("\")) {
        $configLinked = $true
    } elseif ($BackupExisting) {
        Move-Aside -Path $doomConfig
    } else {
        throw "The Doom config destination already exists: $doomConfig"
    }
}

if (-not $configLinked) {
    New-Item -ItemType Junction -Path $doomConfig -Target $configSource | Out-Null
    Write-Host "Linked $doomConfig -> $configSource"
}

# Remove only the obsolete junction created by an earlier Windows layout. A
# real directory, or a link to any other source, is deliberately preserved.
if (Test-Path -LiteralPath $legacyDoomConfig) {
    $legacyConfig = Get-Item -LiteralPath $legacyDoomConfig -Force
    $legacyIsLink = ($legacyConfig.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    $legacyTarget = if ($legacyIsLink -and $legacyConfig.Target) {
        [IO.Path]::GetFullPath([string]@($legacyConfig.Target)[0])
    }
    if ($legacyTarget -and $legacyTarget.TrimEnd("\") -ieq $configSource.TrimEnd("\")) {
        [IO.Directory]::Delete($legacyDoomConfig)
        Write-Host "Removed obsolete Doom config junction: $legacyDoomConfig"
    }
}

$doom = Join-Path $emacsDirectory "bin\doom.ps1"
if (-not (Test-Path -LiteralPath $doom -PathType Leaf)) {
    throw "Doom's PowerShell launcher is missing: $doom"
}
$straightBootstrap = Join-Path $emacsDirectory ".local\straight\repos\straight.el\straight.el"

if (-not (Test-Path -LiteralPath $straightBootstrap -PathType Leaf)) {
    $incompleteStraight = Split-Path -Parent $straightBootstrap
    if (Test-Path -LiteralPath $incompleteStraight) {
        Remove-Item -LiteralPath $incompleteStraight -Recurse -Force
    }
    Invoke-NativeCommand -FilePath $powershell -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $doom,
        "install", "--no-config", "--env", "--force"
    )
}

if ($Upgrade) {
    Invoke-NativeCommand -FilePath $powershell -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $doom, "upgrade"
    )
}
if (-not $SkipSync) {
    Invoke-NativeCommand -FilePath $powershell -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $doom, "sync", "--env"
    )
}
Invoke-NativeCommand -FilePath $powershell -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $doom, "doctor"
)

if (-not (Test-Path -LiteralPath $straightBootstrap -PathType Leaf)) {
    throw "Doom's package manager was not installed: $straightBootstrap"
}

Invoke-NativeCommand -FilePath $emacs -ArgumentList @(
    "--batch", "--eval",
    "(princ (expand-file-name user-emacs-directory))"
)
Invoke-NativeCommand -FilePath $emacs -ArgumentList @(
    "--batch", "--load", (Join-Path $emacsDirectory "early-init.el"),
    "--eval", "(unless (and (featurep (quote doom)) (boundp (quote doom-user-dir))) (kill-emacs 1))"
)
Write-Host "Windows Doom Emacs is ready: framework=$emacsDirectory; config=$doomConfig"
