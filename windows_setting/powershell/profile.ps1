# Shared Windows PowerShell 5.1 profile. Keep this file compatible with the
# in-box powershell.exe; PowerShell 7 is not required.

$global:DotfilesPowerShellProfile = $MyInvocation.MyCommand.Path
$dotfilesInteractiveConsole =
    $Host.Name -eq "ConsoleHost" -and
    -not [Console]::IsInputRedirected -and
    -not [Console]::IsOutputRedirected

# Keep legacy .NET clients compatible with modern HTTPS endpoints.
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    Write-Verbose "Unable to enable TLS 1.2: $($_.Exception.Message)"
}

# Use UTF-8 for native development tools while avoiding a BOM in pipelines.
try {
    $dotfilesUtf8 = New-Object Text.UTF8Encoding($false)
    $global:OutputEncoding = $dotfilesUtf8
    if ($dotfilesInteractiveConsole) {
        [Console]::InputEncoding = $dotfilesUtf8
        [Console]::OutputEncoding = $dotfilesUtf8
    }
} catch {
    Write-Verbose "Unable to configure UTF-8 console I/O: $($_.Exception.Message)"
}

if (Get-Command nvim.exe -ErrorAction SilentlyContinue) {
    $env:EDITOR = "nvim"
    $env:VISUAL = "nvim"
    $env:GIT_EDITOR = "nvim"
}
if (-not $env:PYTHONUTF8) {
    $env:PYTHONUTF8 = "1"
}
if (-not $env:FZF_DEFAULT_COMMAND -and (Get-Command fd.exe -ErrorAction SilentlyContinue)) {
    $env:FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git"
}

function Enable-Proxy {
    [CmdletBinding()]
    param(
        [string]$Server,
        [Nullable[int]]$HttpPort,
        [Nullable[int]]$SocksPort
    )

    if (-not $Server) {
        $Server = if ($env:PROXY_HOST) { $env:PROXY_HOST } else { "127.0.0.1" }
    }
    if ($null -eq $HttpPort) {
        $HttpPort = if ($env:PROXY_HTTP_PORT -as [int]) { [int]$env:PROXY_HTTP_PORT } else { 7890 }
    }
    if ($null -eq $SocksPort) {
        $SocksPort = if ($env:PROXY_SOCKS_PORT -as [int]) { [int]$env:PROXY_SOCKS_PORT } else { $HttpPort }
    }
    if ($HttpPort -lt 1 -or $HttpPort -gt 65535 -or $SocksPort -lt 1 -or $SocksPort -gt 65535) {
        throw "Proxy ports must be between 1 and 65535."
    }

    $env:HTTP_PROXY = "http://${Server}:$HttpPort"
    $env:HTTPS_PROXY = $env:HTTP_PROXY
    $env:ALL_PROXY = "socks5h://${Server}:$SocksPort"
    $env:NO_PROXY = "localhost,127.0.0.1,::1"

    Write-Host "Proxy enabled: HTTP $env:HTTP_PROXY; SOCKS $env:ALL_PROXY"
}

function Disable-Proxy {
    [CmdletBinding()]
    param()

    "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY" | ForEach-Object {
        Remove-Item -LiteralPath "Env:$_" -ErrorAction SilentlyContinue
    }
    Write-Host "Proxy disabled"
}

function Get-ProxyStatus {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        HTTP_PROXY  = $env:HTTP_PROXY
        HTTPS_PROXY = $env:HTTPS_PROXY
        ALL_PROXY   = $env:ALL_PROXY
        NO_PROXY    = $env:NO_PROXY
    }
}

Set-Alias -Name proxy -Value Enable-Proxy -Scope Global -Force
Set-Alias -Name nproxy -Value Disable-Proxy -Scope Global -Force

function ll { Get-ChildItem @args }
function la { Get-ChildItem -Force @args }
function which { Get-Command @args }

function Enter-NewDirectory {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)][string]$Path)

    $directory = New-Item -ItemType Directory -Path $Path -Force
    Set-Location -LiteralPath $directory.FullName
}

function Edit-PowerShellProfile {
    if (-not (Test-Path -LiteralPath $global:DotfilesPowerShellProfile)) {
        throw "Tracked profile not found: $global:DotfilesPowerShellProfile"
    }
    & $env:EDITOR $global:DotfilesPowerShellProfile
}

function Reload-PowerShellProfile {
    . $global:DotfilesPowerShellProfile
}

Set-Alias -Name mkcd -Value Enter-NewDirectory -Scope Global -Force
if (Get-Command nvim.exe -ErrorAction SilentlyContinue) {
    Set-Alias -Name vi -Value nvim.exe -Scope Global -Force
    Set-Alias -Name vim -Value nvim.exe -Scope Global -Force
}
if (Get-Command lazygit.exe -ErrorAction SilentlyContinue) {
    Set-Alias -Name lg -Value lazygit.exe -Scope Global -Force
}

# Calling scoop.ps1 can be blocked by the machine execution policy. Prefer the
# official cmd shim without changing that security policy.
$dotfilesScoopCmd = Join-Path $env:USERPROFILE "scoop\shims\scoop.cmd"
if (Test-Path -LiteralPath $dotfilesScoopCmd) {
    function global:scoop { & (Join-Path $env:USERPROFILE "scoop\shims\scoop.cmd") @args }
}

if ($dotfilesInteractiveConsole) {
    try {
        Import-Module PSReadLine -MinimumVersion 2.2 -ErrorAction Stop
        Set-PSReadLineOption -BellStyle None
        Set-PSReadLineOption -HistoryNoDuplicates
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
        Set-PSReadLineOption -MaximumHistoryCount 10000
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

        try {
            Set-PSReadLineOption -PredictionSource History
            Set-PSReadLineOption -PredictionViewStyle ListView
        } catch {
            Write-Verbose "PSReadLine prediction is unavailable in this host: $($_.Exception.Message)"
        }
    } catch {
        Write-Verbose "PSReadLine initialization skipped: $($_.Exception.Message)"
    }

    try {
        $dotfilesPosh = Get-Command oh-my-posh.exe -ErrorAction Stop
        $dotfilesThemeName = if ($env:POSH_THEME) { $env:POSH_THEME } else { "paradox.omp.json" }
        $dotfilesThemeRoot = if ($env:POSH_THEMES_PATH) {
            $env:POSH_THEMES_PATH
        } else {
            Join-Path $env:USERPROFILE "scoop\apps\oh-my-posh\current\themes"
        }
        $dotfilesTheme = if ([IO.Path]::IsPathRooted($dotfilesThemeName)) {
            $dotfilesThemeName
        } else {
            Join-Path $dotfilesThemeRoot $dotfilesThemeName
        }

        if (Test-Path -LiteralPath $dotfilesTheme) {
            (& $dotfilesPosh.Source init powershell --config $dotfilesTheme | Out-String) |
                Invoke-Expression
        }
    } catch {
        Write-Verbose "oh-my-posh initialization skipped: $($_.Exception.Message)"
    }
}

Remove-Variable -Name dotfilesInteractiveConsole, dotfilesUtf8, dotfilesScoopCmd,
    dotfilesPosh, dotfilesThemeName, dotfilesThemeRoot, dotfilesTheme -ErrorAction SilentlyContinue
