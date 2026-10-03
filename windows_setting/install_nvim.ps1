[CmdletBinding()]
param(
    [switch]$BackupExisting,
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$source = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot "dot_config\nvim")).Path
$destination = Join-Path $env:LOCALAPPDATA "nvim"

if (-not (Test-Path -LiteralPath (Join-Path $source "init.lua") -PathType Leaf)) {
    throw "The shared Neovim source is incomplete: $source"
}

$alreadyLinked = $false
if (Test-Path -LiteralPath $destination) {
    $existing = Get-Item -LiteralPath $destination -Force
    $isReparsePoint = ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    $target = if ($isReparsePoint -and $existing.Target) {
        [IO.Path]::GetFullPath([string]@($existing.Target)[0])
    }

    if ($target -and $target.TrimEnd("\") -ieq $source.TrimEnd("\")) {
        $alreadyLinked = $true
        Write-Host "Neovim configuration is already linked to $source"
    } elseif ($BackupExisting) {
        $backup = "$destination.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item -LiteralPath $destination -Destination $backup
        Write-Host "Existing Neovim configuration moved to $backup"
    } else {
        throw "The destination already exists: $destination`nRerun with -BackupExisting to preserve it before linking."
    }
}

if (-not $alreadyLinked) {
    $parent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    New-Item -ItemType Junction -Path $destination -Target $source | Out-Null
    Write-Host "Linked $destination -> $source"
}

if (-not $SkipValidation) {
    $nvim = Get-Command nvim.exe -ErrorAction Stop
    $previousAutoUpdate = $env:LAZYVIM_AUTO_UPDATE

    try {
        $env:LAZYVIM_AUTO_UPDATE = "0"
        & $nvim.Source --headless "+lua print('Loaded shared config from ' .. vim.fn.stdpath('config'))" "+qa"
        if ($LASTEXITCODE -ne 0) {
            throw "Neovim configuration validation failed with exit code $LASTEXITCODE."
        }
    } finally {
        $env:LAZYVIM_AUTO_UPDATE = $previousAutoUpdate
    }
}

Write-Host "Windows Neovim configuration is ready. Run :Lazy sync for an immediate upstream update."
