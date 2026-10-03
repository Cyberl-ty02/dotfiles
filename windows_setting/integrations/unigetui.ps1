[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        "Status",
        "ExportSettings",
        "ImportPortableSettings",
        "OpenBundle",
        "ImportBundle",
        "ExportBundle",
        "CreateLocalBackup",
        "CreateCloudBackup",
        "RestoreCloudBackup"
    )]
    [string]$Action,
    [string]$Path,
    [string]$Key,
    [switch]$Install
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$installRoots = @(
    (Join-Path $env:ProgramFiles "UniGetUI"),
    (Join-Path $env:LOCALAPPDATA "Programs\UniGetUI")
)
$gui = $installRoots |
    ForEach-Object { Join-Path $_ "UniGetUI.exe" } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
$cli = $installRoots |
    ForEach-Object { Join-Path $_ "uniget.exe" } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1

if (-not $gui) {
    throw "UniGetUI is not installed. Install Devolutions.UniGetUI with winget first."
}

function Invoke-UniGetCli {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    if (-not $script:cli) {
        throw "This UniGetUI build does not include uniget.exe; use the GUI or update UniGetUI."
    }
    & $script:cli @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "uniget.exe failed with exit code $LASTEXITCODE."
    }
}

function Invoke-UniGetGuiCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $quotedPath = '"' + $FilePath.Replace('"', '\"') + '"'
    $process = Start-Process -FilePath $script:gui -ArgumentList @($Command, $quotedPath) `
        -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(30000)) {
        throw "UniGetUI did not finish $Command within 30 seconds."
    }
    if ($process.ExitCode -ne 0) {
        throw "UniGetUI $Command failed with exit code $($process.ExitCode)."
    }
}

switch ($Action) {
    "Status" {
        $version = (Get-Item -LiteralPath $gui).VersionInfo.FileVersion
        [PSCustomObject]@{
            GuiPath      = $gui
            GuiVersion   = $version
            CliAvailable = [bool]$cli
            CliPath      = $cli
        }
        if ($cli) {
            Invoke-UniGetCli -Arguments @("status")
            Invoke-UniGetCli -Arguments @("backup", "status")
        }
    }
    "ExportSettings" {
        if (-not $Path) { throw "-Path is required for ExportSettings." }
        $target = [IO.Path]::GetFullPath($Path)
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            throw "The export directory does not exist: $parent"
        }
        Invoke-UniGetGuiCommand -Command "--export-settings" -FilePath $target
        Write-Host "UniGetUI settings exported to $target"
    }
    "ImportPortableSettings" {
        $portableSettings = Join-Path $PSScriptRoot "unigetui-portable-settings.json"
        Invoke-UniGetGuiCommand -Command "--import-settings" -FilePath $portableSettings
        Write-Host "Portable UniGetUI settings imported. Restart UniGetUI if it was open."
    }
    "OpenBundle" {
        if (-not $Path) { throw "-Path is required for OpenBundle." }
        $bundle = (Resolve-Path -LiteralPath $Path).Path
        Start-Process -FilePath $gui -ArgumentList ('"' + $bundle.Replace('"', '\"') + '"')
    }
    "ImportBundle" {
        if (-not $Path) { throw "-Path is required for ImportBundle." }
        $bundle = (Resolve-Path -LiteralPath $Path).Path
        Invoke-UniGetCli -Arguments @("bundle", "reset")
        Invoke-UniGetCli -Arguments @("bundle", "import", "--path", $bundle)
        if ($Install) {
            Invoke-UniGetCli -Arguments @(
                "bundle", "install", "--include-installed", "false",
                "--elevated", "false", "--interactive", "false", "--skip-hash", "false"
            )
        }
    }
    "ExportBundle" {
        if (-not $Path) { throw "-Path is required for ExportBundle." }
        Invoke-UniGetCli -Arguments @("bundle", "export", "--path", [IO.Path]::GetFullPath($Path))
    }
    "CreateLocalBackup" {
        Invoke-UniGetCli -Arguments @("backup", "local", "create")
    }
    "CreateCloudBackup" {
        Invoke-UniGetCli -Arguments @("backup", "cloud", "create")
    }
    "RestoreCloudBackup" {
        if (-not $Key) { throw "-Key is required for RestoreCloudBackup." }
        Invoke-UniGetCli -Arguments @("backup", "cloud", "restore", "--key", $Key)
        if ($Install) {
            Invoke-UniGetCli -Arguments @(
                "bundle", "install", "--include-installed", "false",
                "--elevated", "false", "--interactive", "false", "--skip-hash", "false"
            )
        }
    }
}
