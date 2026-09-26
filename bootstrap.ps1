#Requires -RunAsAdministrator
<#
  Reproducible ham radio Windows build.
  Run from an elevated PowerShell in this folder:
    Set-ExecutionPolicy -Scope Process Bypass; .\bootstrap.ps1
  Safe to re-run: each step skips work that is already done.
#>
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# 1. WinGet 1.6+ is required for `winget configure`.
$wingetVersion = [version]((winget --version).TrimStart('v'))
if ($wingetVersion -lt [version]'1.6') {
    Write-Host "WinGet $wingetVersion is too old; installing the latest App Installer..."
    $ProgressPreference = 'SilentlyContinue'
    # Bundle and its framework dependencies (Windows App Runtime, VCLibs) from the same release.
    $release = 'https://github.com/microsoft/winget-cli/releases/latest/download'
    $bundle  = Join-Path $env:TEMP 'AppInstaller.msixbundle'
    $depsZip = Join-Path $env:TEMP 'winget-deps.zip'
    $depsDir = Join-Path $env:TEMP 'winget-deps'
    Invoke-WebRequest "$release/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile $bundle -UseBasicParsing
    Invoke-WebRequest "$release/DesktopAppInstaller_Dependencies.zip" -OutFile $depsZip -UseBasicParsing
    Remove-Item $depsDir -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $depsZip $depsDir
    $arch = @{ AMD64 = 'x64'; ARM64 = 'arm64'; x86 = 'x86' }[$env:PROCESSOR_ARCHITECTURE]
    $deps = Get-ChildItem $depsDir -Recurse -Filter *.appx |
        Where-Object { $_.DirectoryName -match "\\$arch$" } |
        Select-Object -ExpandProperty FullName
    Add-AppxPackage -Path $bundle -DependencyPath $deps -ForceApplicationShutdown
    Write-Host 'WinGet updated. Open a new elevated PowerShell and re-run this script.'
    exit 0
}

# 2. WinGet packages (declarative).
winget configure -f .\manpack.dsc.yaml --accept-configuration-agreements --disable-interactivity
if ($LASTEXITCODE -ne 0) { throw "winget configure failed ($LASTEXITCODE)" }

# 3. Chocolatey for packages WinGet doesn't have.
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host 'Installing Chocolatey...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path += ";$env:ProgramData\chocolatey\bin"
}
choco install .\choco-packages.config -y --no-progress
if ($LASTEXITCODE -notin 0, 3010) { throw "choco install failed ($LASTEXITCODE)" }

# 4. VARA modems and VarAC (no package in WinGet or Chocolatey).
& .\install-vara.ps1

Write-Host "`nDone. See README.md for the apps that still need a manual install."
