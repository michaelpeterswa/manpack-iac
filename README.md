# manpack-iac

Declarative install of ham radio software on Windows.

| File | What it does |
|---|---|
| `manpack.dsc.yaml` | WinGet Configuration (DSC): apps in the WinGet repo |
| `choco-packages.config` | Chocolatey: apps WinGet doesn't have |
| `bootstrap.ps1` | Updates WinGet if needed, then applies both of the above |

## Usage
```powershell
# elevated PowerShell, in this folder
Set-ExecutionPolicy -Scope Process Bypass; .\bootstrap.ps1
```
To preview without installing anything: `winget configure show -f manpack.dsc.yaml`

## Not automated yet (no package, or silent install unverified)
- **VARA HF / FM**: downloads.winlink.org/VARA Products/ (zip containing a setup exe; probably Inno Setup `/VERYSILENT`)
- **DXLab Launcher**: dxlabsuite.com (self-extractor, no known silent mode)
- **Direwolf**: github.com/wb2osz/direwolf/releases (zip only; extract it)
- **QLog**: github.com/foldynl/QLog/releases (Qt IFW: `install --accept-licenses --default-answer --confirm-command`)
- **SDRangel** (`f4exb.sdrangel`), **SDR#** (`Airspy.SDRSharp`), **Ham Radio Deluxe** (`HamRadioDeluxe.HamRadioDeluxe`): in WinGet; add them to the YAML if you want them
- **com0com**: virtual COM ports; needs a decision about driver signing

## Ideas for later
- Back up and restore app settings too (e.g. `%LOCALAPPDATA%\WSJT-X\WSJT-X.ini`, fldigi's `%USERPROFILE%\fldigi.files`, the N1MM database) so rig and CAT setup comes back as well as the binaries.
- Install radio USB drivers (Silicon Labs CP210x, FTDI) for your specific rigs.
