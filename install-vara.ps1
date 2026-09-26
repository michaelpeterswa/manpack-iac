#Requires -RunAsAdministrator
<#
  VARA modems (EA5HVK) and VarAC. Neither is in WinGet or Chocolatey.

  VARA: downloads the latest zip for each product from downloads.winlink.org and
  runs its Inno Setup installer silently. A product that is already installed is
  never reinstalled, because reinstalling can overwrite VARA.ini, which holds your
  registration key. Newer versions are reported; upgrade those by hand.

  VarAC: the current installer is only sent by email (varac-hamradio.com/download),
  so download it yourself into .\installers\ and this script installs it silently.
#>
$ErrorActionPreference = 'Stop'

# Product name (as listed on the download server) -> the exe its installer creates.
# VARA doesn't register in Add/Remove Programs, so the exe is how we detect it.
# Remove any you don't want.
$varaProducts = [ordered]@{
    'VARA HF'       = 'C:\VARA\VARA.exe'
    'VARA FM'       = 'C:\VARA FM\VARAFM.exe'
    'VARA SAT'      = 'C:\VARA SAT\VARASAT.exe'
    'VARA Chat'     = 'C:\VARA\VARA Chat.exe'
    'VARA Terminal' = 'C:\VARA\VARA Terminal.exe'
}

$listingUrl = 'https://downloads.winlink.org/VARA%20Products/'
# The server returns 403 to curl's and PowerShell's default user agents.
$userAgent  = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
$work       = Join-Path $env:TEMP 'manpack-vara'

function Get-InstalledApp([string]$namePattern) {
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match $namePattern } |
        Select-Object -First 1
}

# VARA exes carry zero-padded versions ("4.09", "4.04.0005"); the server lists
# "4.9.0" and "4.4.5". Normalize both to a 3-part [version].
function ConvertTo-Version([string]$s) {
    $parts = @($s -split '\.' | ForEach-Object { [int]$_ }) + @(0, 0, 0)
    [version]::new($parts[0], $parts[1], $parts[2])
}

function Invoke-Curl([string[]]$curlArgs) {
    & curl.exe -s -f -L -A $userAgent @curlArgs
    if ($LASTEXITCODE -ne 0) { throw "curl failed ($LASTEXITCODE): $($curlArgs -join ' ')" }
}

New-Item -ItemType Directory -Force $work | Out-Null

# --- VARA ------------------------------------------------------------------
$listing = (Invoke-Curl @($listingUrl)) -join "`n"
$available = [regex]::Matches($listing, '(?i)<a href="([^"]+)">\s*(VARA [A-Za-z]+) v([\d.]+)\s+setup\.zip</a>') |
    ForEach-Object { [pscustomobject]@{ Name = $_.Groups[2].Value; Version = $_.Groups[3].Value; Href = $_.Groups[1].Value } }

foreach ($product in $varaProducts.Keys) {
    $latest = $available | Where-Object Name -eq $product | Select-Object -First 1
    if (-not $latest) { Write-Warning "$product not found in $listingUrl"; continue }

    $exe = $varaProducts[$product]
    if (Test-Path $exe) {
        $current = ConvertTo-Version (Get-Item $exe).VersionInfo.FileVersion
        if ($current -ge (ConvertTo-Version $latest.Version)) {
            Write-Host "$product $current already installed."
        } else {
            Write-Host "$product $current is installed; $($latest.Version) is available. Upgrade by hand to keep your VARA.ini."
        }
        continue
    }

    Write-Host "Installing $product $($latest.Version)..."
    $zip = Join-Path $work "$($product -replace ' ', '-').zip"
    $dir = Join-Path $work ($product -replace ' ', '-')
    Invoke-Curl @('-o', $zip, "https://downloads.winlink.org$($latest.Href)")
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $zip $dir
    $setup = Get-ChildItem $dir -Recurse -Filter *.exe | Select-Object -First 1
    if (-not $setup) { throw "No setup .exe in $zip" }
    $p = Start-Process $setup.FullName -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-' -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "$product setup failed ($($p.ExitCode))" }
    if (-not (Test-Path $exe)) { Write-Warning "$product setup finished but $exe is missing" }
}

# --- VarAC -----------------------------------------------------------------
if (Get-InstalledApp '^VarAC\b') {
    Write-Host 'VarAC already installed.'
} else {
    $varac = Get-ChildItem (Join-Path $PSScriptRoot 'installers') -Filter 'VarAC_Installer_*.exe' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($varac) {
        Write-Host "Installing $($varac.Name)..."
        $p = Start-Process $varac.FullName -ArgumentList '/S' -Wait -PassThru
        if ($p.ExitCode -ne 0) { throw "VarAC setup failed ($($p.ExitCode))" }
    } else {
        Write-Warning 'VarAC skipped: get the installer from https://www.varac-hamradio.com/download and put it in .\installers\'
    }
}

Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
