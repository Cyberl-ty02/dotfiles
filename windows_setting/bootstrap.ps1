[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$InstallCorePackages,
    [switch]$InstallOptionalPackages,
    [switch]$InstallWindowsApps,
    [switch]$InstallEditorExtensions,
    [string]$GitName,
    [string]$GitEmail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$source = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $source "..")).Path
$homeDirectory = [Environment]::GetFolderPath("UserProfile")

function Get-ManifestItems {
    param([Parameter(Mandatory = $true)][string]$Path)

    Get-Content -LiteralPath $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
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

function Get-GitValue {
    param([Parameter(Mandatory = $true)][string]$Key)

    $git = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $git) { return $null }
    $value = @(& $git.Source config --global --get $Key 2>$null) |
        Select-Object -First 1
    if ($value) { return ([string]$value).Trim() }
    return $null
}

$scoop = Get-Command scoop.cmd -ErrorAction SilentlyContinue
$chezmoi = Get-Command chezmoi.exe -ErrorAction SilentlyContinue
if (-not $chezmoi) {
    if (-not $scoop) {
        throw "chezmoi is missing. Install Scoop first, then rerun this script."
    }
    Invoke-NativeCommand -FilePath $scoop.Source -ArgumentList @("install", "chezmoi")
    $chezmoi = Get-Command chezmoi.exe -ErrorAction Stop
}

if ($InstallCorePackages -or $InstallOptionalPackages) {
    if (-not $scoop) { $scoop = Get-Command scoop.cmd -ErrorAction Stop }
    $manifest = if ($InstallOptionalPackages) {
        "packages\scoop-optional.txt"
    } else {
        "packages\scoop-core.txt"
    }
    $packages = @(Get-ManifestItems -Path (Join-Path $source $manifest))
    if ($InstallCorePackages -and $InstallOptionalPackages) {
        $packages = @(
            Get-ManifestItems -Path (Join-Path $source "packages\scoop-core.txt")
            Get-ManifestItems -Path (Join-Path $source "packages\scoop-optional.txt")
        ) | Select-Object -Unique
    }
    Invoke-NativeCommand -FilePath $scoop.Source -ArgumentList (@("install") + $packages)
}

if ($InstallWindowsApps) {
    $winget = Get-Command winget.exe -ErrorAction Stop
    foreach ($package in Get-ManifestItems -Path (Join-Path $source "packages\winget-core.txt")) {
        Invoke-NativeCommand -FilePath $winget.Source -ArgumentList @(
            "install", "--id", $package, "--exact", "--silent",
            "--accept-package-agreements", "--accept-source-agreements"
        )
    }
}

if ($InstallEditorExtensions) {
    $codium = Get-Command codium.cmd -ErrorAction Stop
    $extensions = @(
        Get-ManifestItems -Path (Join-Path $repositoryRoot "vscodium\extensions-common.txt")
        Get-ManifestItems -Path (Join-Path $repositoryRoot "vscodium\extensions-windows.txt")
    ) | Select-Object -Unique
    foreach ($extension in $extensions) {
        Invoke-NativeCommand -FilePath $codium.Source -ArgumentList @(
            "--install-extension", $extension, "--force"
        )
    }
}

if (-not $GitName) { $GitName = Get-GitValue -Key "user.name" }
if (-not $GitEmail) { $GitEmail = Get-GitValue -Key "user.email" }
if (-not $GitName) { $GitName = Read-Host "Git author name" }
if (-not $GitEmail) { $GitEmail = Read-Host "Git author email" }
if (-not $GitName -or -not $GitEmail) {
    throw "Git author name and email are required and remain local to this machine."
}

$commonArguments = @("--source", $source, "--destination", $homeDirectory)
Invoke-NativeCommand -FilePath $chezmoi.Source -ArgumentList ($commonArguments + @(
    "init",
    "--promptString", "Git author name=$GitName",
    "--promptString", "Git author email=$GitEmail"
))

if ($DryRun) {
    Invoke-NativeCommand -FilePath $chezmoi.Source -ArgumentList ($commonArguments + @("diff"))
    Write-Host "Dry run complete; no managed files were changed."
    exit 0
}

Invoke-NativeCommand -FilePath $chezmoi.Source -ArgumentList ($commonArguments + @("apply", "--verbose"))

& (Join-Path $source "install_powershell_profile.ps1")
if (Get-Command nvim.exe -ErrorAction SilentlyContinue) {
    & (Join-Path $source "install_nvim.ps1")
}

Write-Host "Windows development settings are synchronized."
