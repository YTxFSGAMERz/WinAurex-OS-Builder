<#
.SYNOPSIS
    WinAurex OS Builder - Tier 1: Stable Workstation Edition
.DESCRIPTION
    Builds a rock-solid, production-ready, debloated Windows 11 ISO:
    - Model: WinAurex Stable Workstation Edition
    - Windows Updates: 100% FULLY FUNCTIONAL & UNTOUCHED (Security updates & drivers work natively)
    - WinGet & Microsoft Store: 100% PRESERVED & FUNCTIONAL
    - Drivers & Hardware: 100% INTACT (Zero driver removal; DriverStore, PnP, Wi-Fi, GPU intact)
    - Bloatware: Purges consumer advertising, promo games, tips, and cloud sponsored apps
    - Pre-stages "Post Install" application suite to the Public Desktop and ISO root
    - Dual-boot UEFI & BIOS ISO compilation via oscdimg.exe
.NOTES
    Author: Farhan Shaikh (@FFShaikh69) // WinAurex Framework
#>

[CmdletBinding()]
param (
    [string]$ISO,
    [string]$SCRATCH,
    [int]$EditionIndex = 6,
    [switch]$Auto,
    [switch]$EnableNetFX3,
    [string]$OutISO
)

$ErrorActionPreference = 'Stop'
$hostArchitecture = $Env:PROCESSOR_ARCHITECTURE

# Check and run as Administrator
$adminSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$adminGroup = $adminSID.Translate([System.Security.Principal.NTAccount])
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $myWindowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[*] Requesting Administrator elevation..." -ForegroundColor Yellow
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell"
    $newProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $newProcess.Verb = "runas"
    [System.Diagnostics.Process]::Start($newProcess) | Out-Null
    Exit
}

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "            WINAUREX OS BUILDER - TIER 1: STABLE WORKSTATION         " -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  * Edition Name   : WinAurex Stable Workstation Edition" -ForegroundColor Green
Write-Host "  * Windows Update : 100% FULLY FUNCTIONAL (Native Updates & Patches)" -ForegroundColor Green
Write-Host "  * WinGet & Store : 100% PRESERVED & WORKING OUT-OF-THE-BOX" -ForegroundColor Green
Write-Host "  * Hardware Drivers: 100% INTACT (Wi-Fi, Bluetooth, GPU, Audio Preserved)" -ForegroundColor Green
Write-Host "  * Post Install   : Pre-staged to Desktop with Browsers, Office & Tools" -ForegroundColor Green
Write-Host "======================================================================`n" -ForegroundColor Cyan

# 1. Resolve Scratch Disk
if (-not $SCRATCH) {
    $ScratchDisk = $PSScriptRoot -replace '[\\]+$', ''
    if ($ScratchDisk.Length -eq 2 -and $ScratchDisk[1] -eq ':') {
        # Root of drive
    } else {
        $ScratchDisk = $env:SystemDrive
    }
} else {
    $ScratchDisk = $SCRATCH.TrimEnd(':') + ":"
}
Write-Host "[*] Scratch working directory: $ScratchDisk" -ForegroundColor DarkGray

# 2. Resolve or Auto-Discover Installation Media
$mountedDrive = $null
$wasMountedByScript = $false

if ($ISO) {
    if ((Test-Path $ISO -PathType Leaf) -and ($ISO -like "*.iso")) {
        Write-Host "[*] Mounting provided ISO: $ISO" -ForegroundColor Cyan
        $mountResult = Mount-DiskImage -ImagePath (Resolve-Path $ISO).Path -PassThru
        $volume = Get-Volume -DiskImage $mountResult
        $mountedDrive = $volume.DriveLetter + ":"
        $wasMountedByScript = $true
    } elseif ($ISO.Length -le 3) {
        $mountedDrive = $ISO.TrimEnd(':') + ":"
    }
}

if (-not $mountedDrive) {
    Write-Host "[*] Scanning for Windows Installation Media..." -ForegroundColor DarkGray
    $drives = Get-Volume | Where-Object { $_.DriveType -in @('Removable', 'CD-ROM', 'Fixed') -and $_.DriveLetter }
    foreach ($drive in $drives) {
        $letter = $drive.DriveLetter + ":"
        if ((Test-Path "$letter\sources\boot.wim") -and ((Test-Path "$letter\sources\install.wim") -or (Test-Path "$letter\sources\install.esd"))) {
            $mountedDrive = $letter
            break
        }
    }
}

if (-not $mountedDrive) {
    $downloadsIso = Get-ChildItem -Path "$env:USERPROFILE\Downloads\*.iso" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($downloadsIso) {
        Write-Host "[*] Found Windows ISO in Downloads: $($downloadsIso.FullName)" -ForegroundColor Cyan
        $mountResult = Mount-DiskImage -ImagePath $downloadsIso.FullName -PassThru
        $volume = Get-Volume -DiskImage $mountResult
        $mountedDrive = $volume.DriveLetter + ":"
        $wasMountedByScript = $true
    }
}

if (-not $mountedDrive -and -not $Auto) {
    $promptDrive = Read-Host "Enter Windows Installation Media Drive Letter (e.g. E)"
    if ($promptDrive) { $mountedDrive = $promptDrive.TrimEnd(':') + ":" }
}

if (-not $mountedDrive -or -not (Test-Path "$mountedDrive\sources\boot.wim")) {
    Write-Error "Could not find valid Windows installation media (missing sources\boot.wim). Aborting."
    Exit 1
}

Write-Host "[+] Installation media resolved at: $mountedDrive" -ForegroundColor Green

# 3. Destination ISO Path
if (-not $OutISO) {
    $OutISO = Join-Path $PSScriptRoot "WinAurex_Stable.iso"
}

try {
    # 4. Prepare Staging Directories
    $stagingDir = "$ScratchDisk\WinAurex_Staging"
    $mountDir = "$ScratchDisk\scratchdir"

    if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $mountDir) {
        try { dism /unmount-image /mountdir:$mountDir /discard | Out-Null } catch {}
        Remove-Item $mountDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Path "$stagingDir\sources" -Force | Out-Null
    New-Item -ItemType Directory -Path $mountDir -Force | Out-Null

    # 5. Handle install.esd / install.wim Conversion
    $sourceWim = "$mountedDrive\sources\install.wim"
    $sourceEsd = "$mountedDrive\sources\install.esd"

    if (-not (Test-Path $sourceWim) -and (Test-Path $sourceEsd)) {
        Write-Host "`n[*] Found install.esd. Converting edition index $EditionIndex to install.wim..." -ForegroundColor Cyan
        & dism /Export-Image /SourceImageFile:$sourceEsd /SourceIndex:$EditionIndex /DestinationImageFile:"$stagingDir\sources\install.wim" /Compress:max /CheckIntegrity
    }

    # 6. Copy Windows Installation Base Media
    Write-Host "`n[*] Copying Windows installation files to scratch directory..." -ForegroundColor Cyan
    robocopy "$mountedDrive" "$stagingDir" /E /MT:16 /R:1 /W:1 /XD "System Volume Information" "`$RECYCLE.BIN" | Out-Null
    cmd.exe /c "attrib -r `"$stagingDir\*`" /s /d >nul 2>&1"

    if ((Test-Path "$stagingDir\sources\install.esd") -and -not (Test-Path "$stagingDir\sources\install.wim")) {
        Write-Host "[*] Exporting install.esd to install.wim in staging..." -ForegroundColor Cyan
        & dism /Export-Image /SourceImageFile:"$stagingDir\sources\install.esd" /SourceIndex:$EditionIndex /DestinationImageFile:"$stagingDir\sources\install.wim" /Compress:max /CheckIntegrity
        Remove-Item "$stagingDir\sources\install.esd" -Force -ErrorAction SilentlyContinue
    }

    # Remove Read-Only attributes from target WIM
    $wimPath = "$stagingDir\sources\install.wim"
    Set-ItemProperty -Path $wimPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue

    # 7. Mount install.wim
    Write-Host "`n[*] Mounting install.wim (Index: $EditionIndex) to $mountDir..." -ForegroundColor Cyan
    & dism /English /mount-image "/imagefile:$wimPath" "/index:$EditionIndex" "/mountdir:$mountDir"

    # Detect Image Architecture
    $targetArch = "amd64"
    foreach ($line in (& dism /English /Get-WimInfo "/wimfile:$wimPath" "/index:$EditionIndex")) {
        if ($line -match 'Architecture\s*:\s*(\S+)') {
            $rawArch = $matches[1].Trim()
            if ($rawArch -eq 'x64') { $targetArch = 'amd64' } else { $targetArch = $rawArch }
            break
        }
    }
    Write-Host "  [+] Architecture detected: $targetArch" -ForegroundColor DarkGray

    # 8. Surgical Debloating (Consumer Bloat ONLY — PRESERVE STORE, WINGET & DRIVERS)
    Write-Host "`n[*] Debloating consumer promo packages (preserving WinGet, Store, Drivers)..." -ForegroundColor Cyan
    $packagesRaw = & dism /English "/image:$mountDir" /Get-ProvisionedAppxPackages
    $allPackages = @()
    foreach ($line in ($packagesRaw -split "`r?`n")) {
        if ($line -match 'PackageName\s*:\s*(.*)') {
            $allPackages += $matches[1].Trim()
        }
    }

    # Consumer advertising & promo apps to remove
    $consumerBloatPrefixes = @(
        'Clipchamp.Clipchamp_',
        'Microsoft.BingNews_',
        'Microsoft.BingWeather_',
        'Microsoft.GetHelp_',
        'Microsoft.Getstarted_',
        'Microsoft.MicrosoftOfficeHub_',
        'Microsoft.MicrosoftSolitaireCollection_',
        'Microsoft.People_',
        'Microsoft.PowerAutomateDesktop_',
        'Microsoft.Todos_',
        'Microsoft.WindowsFeedbackHub_',
        'Microsoft.WindowsMaps_',
        'Microsoft.WindowsSoundRecorder_',
        'Microsoft.YourPhone_',
        'MicrosoftCorporationII.MicrosoftFamily_',
        'MicrosoftCorporationII.QuickAssist_',
        'MicrosoftTeams_',
        'MSTeams_',
        'Microsoft.OutlookForWindows_',
        'Microsoft.Windows.Teams_'
    )

    foreach ($pkg in $allPackages) {
        # STRICT PROTECTION: Never remove WinGet, Store, Terminal, or Core Frameworks
        if ($pkg -match 'DesktopAppInstaller|WindowsStore|WindowsTerminal|VCLibs|UI\.Xaml|SecHealthUI') {
            continue
        }

        foreach ($prefix in $consumerBloatPrefixes) {
            if ($pkg -like "$prefix*") {
                Write-Host "  [-] Removing: $pkg" -ForegroundColor DarkGray
                & dism /English "/image:$mountDir" /Remove-ProvisionedAppxPackage "/PackageName:$pkg" | Out-Null
                break
            }
        }
    }

    # 9. Optional .NET 3.5 Feature
    if ($EnableNetFX3 -and (Test-Path "$stagingDir\sources\sxs")) {
        Write-Host "`n[*] Enabling .NET Framework 3.5 offline..." -ForegroundColor Cyan
        & dism "/image:$mountDir" /enable-feature /featurename:NetFX3 /All "/source:$stagingDir\sources\sxs" | Out-Null
    }

    # 10. Load Offline Registry Hives
    Write-Host "`n[*] Loading offline registry hives..." -ForegroundColor Cyan
    reg load HKLM\zCOMPONENTS "$mountDir\Windows\System32\config\COMPONENTS" | Out-Null
    reg load HKLM\zDEFAULT "$mountDir\Windows\System32\config\default" | Out-Null
    reg load HKLM\zNTUSER "$mountDir\Users\Default\ntuser.dat" | Out-Null
    reg load HKLM\zSOFTWARE "$mountDir\Windows\System32\config\SOFTWARE" | Out-Null
    reg load HKLM\zSYSTEM "$mountDir\Windows\System32\config\SYSTEM" | Out-Null

    # 11. Injects WinAurex Stable Workstation OEM Branding
    Write-Host "[*] Injecting 'WinAurex Stable Workstation Edition' OEM Branding..." -ForegroundColor Cyan
    $oemKey = "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
    & reg add $oemKey /v Manufacturer /t REG_SZ /d "WinAurex" /f | Out-Null
    & reg add $oemKey /v Model /t REG_SZ /d "WinAurex Stable Workstation Edition" /f | Out-Null
    & reg add $oemKey /v SupportURL /t REG_SZ /d "https://www.winaurex.tech" /f | Out-Null
    & reg add $oemKey /v SupportPhone /t REG_SZ /d "Telegram: @FFShaikh69" /f | Out-Null
    & reg add $oemKey /v SupportHours /t REG_SZ /d "24/7 Community Support" /f | Out-Null
    & reg add $oemKey /v Logo /t REG_SZ /d "C:\Windows\System32\oemlogo.bmp" /f | Out-Null
    & reg add $oemKey /v Author /t REG_SZ /d "Farhan Shaikh" /f | Out-Null
    & reg add $oemKey /v "Author Info" /t REG_SZ /d "https://github.com/YTxFSGAMERz" /f | Out-Null

    # Copy OEM logo
    $oemFolder = Join-Path $PSScriptRoot "OEM Info"
    if (Test-Path "$oemFolder\oemlogo.bmp") {
        $logoDest = "$mountDir\Windows\System32\oemlogo.bmp"
        if (Test-Path $logoDest) { & takeown /f $logoDest /a 2>&1 | Out-Null; & icacls $logoDest /grant Administrators:F /c /q 2>&1 | Out-Null }
        Copy-Item "$oemFolder\oemlogo.bmp" $logoDest -Force -ErrorAction SilentlyContinue
    }

    # 12. Hardware Bypasses & Clean Setup
    Write-Host "[*] Injecting hardware bypasses (TPM 2.0, Secure Boot, RAM, CPU, Storage, BitLocker)..." -ForegroundColor Cyan
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassStorageCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\MoSetup" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\ControlSet001\Control\BitLocker" /v PreventDeviceEncryption /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f | Out-Null

    # Disable consumer ads, promo pins, and telemetry
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableConsumerAccountStateContent /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f | Out-Null
    & reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f | Out-Null
    & reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null

    # TIER 1 STABLE: WINDOWS UPDATE IS FULLY ENABLED & UNTOUCHED
    # wuauserv, WaaSMedicSVC, and UsoSvc remain 100% active and native.

    # 13. Pre-Stage "Post Install" Application Suite & autounattend.xml
    Write-Host "[*] Pre-staging 'Post Install' folder to Public Desktop..." -ForegroundColor Cyan
    $postInstallSource = Join-Path $PSScriptRoot "Post Install"
    if (Test-Path $postInstallSource) {
        $desktopPostInstall = "$mountDir\Users\Public\Desktop\Post Install"
        if (-not (Test-Path $desktopPostInstall)) { New-Item -ItemType Directory -Path $desktopPostInstall -Force | Out-Null }
        robocopy $postInstallSource $desktopPostInstall /E /NJH /NJS /NDL /NC /NS | Out-Null

        # Also copy to root of ISO
        $isoPostInstall = "$stagingDir\Post Install"
        robocopy $postInstallSource $isoPostInstall /E /NJH /NJS /NDL /NC /NS | Out-Null
    }

    # 13. Pre-Stage Unattended Configuration (Offline Sysprep Injection)
    Write-Host "[*] Staging unattended answer file to offline system..." -ForegroundColor Cyan
    $xmlSource = Join-Path $PSScriptRoot "autounattend.xml"
    if (Test-Path $xmlSource) {
        $sysprepDir = "$mountDir\Windows\System32\Sysprep"
        $pantherDir = "$mountDir\Windows\Panther"
        if (-not (Test-Path $sysprepDir)) { New-Item -ItemType Directory -Path $sysprepDir -Force | Out-Null }
        if (-not (Test-Path $pantherDir)) { New-Item -ItemType Directory -Path $pantherDir -Force | Out-Null }
        Copy-Item $xmlSource "$sysprepDir\unattend.xml" -Force | Out-Null
        Copy-Item $xmlSource "$pantherDir\unattend.xml" -Force | Out-Null
        # Register unattended answer file for Phase 2 OOBE execution
        & reg add "HKLM\zSYSTEM\Setup" /v UnattendFile /t REG_SZ /d "C:\Windows\System32\Sysprep\unattend.xml" /f | Out-Null
    }
    # Ensure NO autounattend.xml exists at the root of the ISO (avoids 24H2/26H2 WinPE unattended crash)
    if (Test-Path "$stagingDir\autounattend.xml") {
        Remove-Item "$stagingDir\autounattend.xml" -Force -ErrorAction SilentlyContinue
    }

    # 14. Unload Registry
    Write-Host "[*] Unmounting registry hives..." -ForegroundColor DarkGray
    reg unload HKLM\zCOMPONENTS | Out-Null
    reg unload HKLM\zDEFAULT | Out-Null
    reg unload HKLM\zNTUSER | Out-Null
    reg unload HKLM\zSOFTWARE | Out-Null
    reg unload HKLM\zSYSTEM | Out-Null

    # 15. Commit and Clean Image
    Write-Host "`n[*] Starting component cleanup..." -ForegroundColor Cyan
    & dism /English "/image:$mountDir" /Cleanup-Image /StartComponentCleanup | Out-Null

    Write-Host "[*] Unmounting and committing changes to install.wim..." -ForegroundColor Cyan
    & dism /English /unmount-image "/mountdir:$mountDir" /commit

    # Export WIM to clean single-index WIM
    Write-Host "[*] Re-exporting install.wim to optimize size..." -ForegroundColor Cyan
    $tempWim = "$stagingDir\sources\install_clean.wim"
    & dism /Export-Image /SourceImageFile:$wimPath /SourceIndex:$EditionIndex /DestinationImageFile:$tempWim /Compress:max
    Remove-Item $wimPath -Force
    Rename-Item $tempWim "install.wim"

    # 16. Service boot.wim (WinPE & Setup)
    Write-Host "`n[*] Servicing boot.wim (Hardware bypasses in setup)..." -ForegroundColor Cyan
    $bootWim = "$stagingDir\sources\boot.wim"
    Set-ItemProperty -Path $bootWim -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
    & dism /English /mount-image "/imagefile:$bootWim" /index:2 "/mountdir:$mountDir"

    reg load HKLM\zSYSTEM "$mountDir\Windows\System32\config\SYSTEM" | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassStorageCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\LabConfig" /v BypassDiskCheck /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSYSTEM\Setup\MoSetup" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f | Out-Null
    reg unload HKLM\zSYSTEM | Out-Null

    if (Test-Path "$oemFolder\setup.bmp") {
        $setupBmp = "$mountDir\sources\setup.bmp"
        if (Test-Path $setupBmp) { & takeown /f $setupBmp /a 2>&1 | Out-Null; & icacls $setupBmp /grant Administrators:F /c /q 2>&1 | Out-Null }
        Copy-Item "$oemFolder\setup.bmp" $setupBmp -Force -ErrorAction SilentlyContinue
        Copy-Item "$oemFolder\setup.bmp" "$stagingDir\sources\background_cli.bmp" -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "$oemFolder\winpe.jpg") {
        $winpeJpg = "$mountDir\Windows\System32\winpe.jpg"
        if (Test-Path $winpeJpg) { & takeown /f $winpeJpg /a 2>&1 | Out-Null; & icacls $winpeJpg /grant Administrators:F /c /q 2>&1 | Out-Null }
        Copy-Item "$oemFolder\winpe.jpg" $winpeJpg -Force -ErrorAction SilentlyContinue
    }

    & dism /English /unmount-image "/mountdir:$mountDir" /commit

    # 16.1 Retain bootfix.bin so system prompts before CD boot and avoids infinite reboot loops
    Write-Host "[*] Retaining bootfix.bin for proper UEFI/BIOS boot prompt..." -ForegroundColor DarkGray

    # 16.2 Modern Setup Media Cleanup (Retain authentic appraiserres.dll, remove PID/ei conflicts)
    Write-Host "[*] Preserving authentic Microsoft appraiserres.dll & cleaning setup media..." -ForegroundColor Cyan
    if (Test-Path "$stagingDir\sources\PID.txt") {
        Remove-Item "$stagingDir\sources\PID.txt" -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "$stagingDir\sources\ei.cfg") {
        Remove-Item "$stagingDir\sources\ei.cfg" -Force -ErrorAction SilentlyContinue
    }
    $appraiser = "$stagingDir\sources\appraiserres.dll"
    if (Test-Path $appraiser) {
        Set-ItemProperty -Path $appraiser -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        (Get-Item $appraiser).Attributes = 'Normal'
        Write-Host "  [+] Authentic appraiserres.dll preserved ($((Get-Item $appraiser).Length) bytes)" -ForegroundColor Green
    }

    # 17. Compile Final Dual-Boot ISO
    Write-Host "`n[*] Compiling bootable ISO via oscdimg..." -ForegroundColor Cyan
    $localOscdimg = Join-Path $PSScriptRoot "oscdimg.exe"
    $efisys = Join-Path $PSScriptRoot "efisys_direct_raw.bin"

    if (-not (Test-Path $localOscdimg)) {
        throw "oscdimg.exe not found at $localOscdimg"
    }

    $bootdata = if (Test-Path $efisys) {
        "2#p0,e,b$stagingDir\boot\etfsboot.com#pEF,e,b$efisys"
    } else {
        "2#p0,e,b$stagingDir\boot\etfsboot.com#pEF,e,b$stagingDir\efi\microsoft\boot\efisys.bin"
    }

    $oscdimgArgs = "-m -o -u2 -udfver102 `"-bootdata:$bootdata`" `"$stagingDir`" `"$OutISO`""
    $p = Start-Process -FilePath $localOscdimg -ArgumentList $oscdimgArgs -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        throw "oscdimg failed with exit code $($p.ExitCode)"
    }

    Write-Host "`n======================================================================" -ForegroundColor Green
    Write-Host " [SUCCESS] WinAurex Stable Workstation ISO Compiled Successfully!     " -ForegroundColor White
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host " * ISO Location  : $OutISO" -ForegroundColor Yellow
    Write-Host " * Windows Update: Fully Functional" -ForegroundColor Green
    Write-Host " * WinGet & Store: Fully Functional" -ForegroundColor Green
    Write-Host " * Drivers       : 100% Intact & Untouched" -ForegroundColor Green
    Write-Host "======================================================================`n" -ForegroundColor Green

} finally {
    # 18. Safe Cleanup (NEVER touch repo files like oscdimg.exe or autounattend.xml)
    Write-Host "[*] Cleaning temporary build folders..." -ForegroundColor DarkGray
    foreach ($h in @('zCOMPONENTS','zDEFAULT','zNTUSER','zSOFTWARE','zSYSTEM')) {
        cmd.exe /c "reg unload HKLM\$h >nul 2>&1"
    }
    if (Test-Path "$ScratchDisk\scratchdir") {
        try { dism /unmount-image "/mountdir:$ScratchDisk\scratchdir" /discard | Out-Null } catch {}
        Remove-Item "$ScratchDisk\scratchdir" -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "$ScratchDisk\WinAurex_Staging") {
        Remove-Item "$ScratchDisk\WinAurex_Staging" -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($wasMountedByScript -and $mountedDrive) {
        Write-Host "[*] Dismounting source ISO..." -ForegroundColor DarkGray
        try { Dismount-DiskImage -ImagePath (Resolve-Path $ISO).Path -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
}
