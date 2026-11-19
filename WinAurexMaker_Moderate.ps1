<#
.SYNOPSIS
    WinAurex OS Builder - Tier 2: Performance & Gaming Edition
.DESCRIPTION
    Builds a high-performance, gaming-optimized, debloated Windows 11 ISO:
    - Model: WinAurex Performance & Gaming Edition
    - Windows Updates: DISABLED (Prevents background download lag, stutters, and forced reboots)
    - WinGet & Microsoft Store: 100% PRESERVED & FUNCTIONAL (Install packages via winget)
    - Drivers & Hardware: 100% INTACT (Zero driver removal; GPU, Wi-Fi, Audio, Chipset 100% preserved)
    - Bloatware: Strips consumer ads, Xbox background bloat, Copilot, Teams, and OneDrive
    - Pre-stages "Post Install" application suite to the Public Desktop and ISO root
    - Dual-boot UEFI & BIOS ISO compilation via oscdimg.exe
.NOTES
    Author: Farhan Shaikh (@FFShaikh69) // WinAurex Framework
#>

[CmdletBinding()]
param (
    [string]$ISO,
    [string]$SCRATCH,
    [int]$EditionIndex = 1,
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
Write-Host "         WINAUREX OS BUILDER - TIER 2: PERFORMANCE & GAMING           " -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  * Edition Name   : WinAurex Performance & Gaming Edition" -ForegroundColor Green
Write-Host "  * Windows Update : DISABLED (No Background Downloads or Forced Reboots)" -ForegroundColor Yellow
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
    $OutISO = Join-Path $PSScriptRoot "WinAurex_Moderate.iso"
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

    if ((Test-Path "$stagingDir\sources\install.esd") -and -not (Test-Path "$stagingDir\sources\install.wim")) {
        Write-Host "[*] Exporting install.esd to install.wim in staging..." -ForegroundColor Cyan
        & dism /Export-Image /SourceImageFile:"$stagingDir\sources\install.esd" /SourceIndex:$EditionIndex /DestinationImageFile:"$stagingDir\sources\install.wim" /Compress:max /CheckIntegrity
        Remove-Item "$stagingDir\sources\install.esd" -Force -ErrorAction SilentlyContinue
    }

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

    # 8. Deep Debloating for Performance & Gaming (PRESERVE WINGET, STORE & DRIVERS)
    Write-Host "`n[*] Debloating bloatware & background daemons (preserving WinGet, Store, Drivers)..." -ForegroundColor Cyan
    $packagesRaw = & dism /English "/image:$mountDir" /Get-ProvisionedAppxPackages
    $allPackages = @()
    foreach ($line in ($packagesRaw -split "`r?`n")) {
        if ($line -match 'PackageName\s*:\s*(.*)') {
            $allPackages += $matches[1].Trim()
        }
    }

    # Moderate list removes Consumer Ads + Xbox / Gaming background bloat + Copilot / Teams
    $moderateBloatPrefixes = @(
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
        'Microsoft.Windows.Teams_',
        'Microsoft.Copilot_',
        'Microsoft.Windows.Copilot',
        'Microsoft.549981C3F5F10_',
        'Microsoft.ZuneMusic_',
        'Microsoft.ZuneVideo_',
        'Microsoft.GamingApp_',
        'Microsoft.Xbox.TCUI_',
        'Microsoft.XboxGamingOverlay_',
        'Microsoft.XboxGameOverlay_',
        'Microsoft.XboxSpeechToTextOverlay_',
        'Microsoft.XboxApp_',
        'Microsoft.XboxIdentityProvider_'
    )

    foreach ($pkg in $allPackages) {
        # STRICT PROTECTION: Never remove WinGet, Store, Terminal, or Core Frameworks
        if ($pkg -match 'DesktopAppInstaller|WindowsStore|WindowsTerminal|VCLibs|UI\.Xaml|SecHealthUI') {
            continue
        }

        foreach ($prefix in $moderateBloatPrefixes) {
            if ($pkg -like "$prefix*") {
                Write-Host "  [-] Removing: $pkg" -ForegroundColor DarkGray
                & dism /English "/image:$mountDir" /Remove-ProvisionedAppxPackage "/PackageName:$pkg" | Out-Null
                break
            }
        }
    }

    # Remove OneDrive setup from System32
    if (Test-Path "$mountDir\Windows\System32\OneDriveSetup.exe") {
        Write-Host "  [-] Removing OneDriveSetup.exe..." -ForegroundColor DarkGray
        & takeown /f "$mountDir\Windows\System32\OneDriveSetup.exe" | Out-Null
        & icacls "$mountDir\Windows\System32\OneDriveSetup.exe" /grant "$($adminGroup.Value):(F)" | Out-Null
        Remove-Item "$mountDir\Windows\System32\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
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

    # 11. Injects WinAurex Performance & Gaming OEM Branding
    Write-Host "[*] Injecting 'WinAurex Performance & Gaming Edition' OEM Branding..." -ForegroundColor Cyan
    $oemKey = "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
    & reg add $oemKey /v Manufacturer /t REG_SZ /d "WinAurex" /f | Out-Null
    & reg add $oemKey /v Model /t REG_SZ /d "WinAurex Performance & Gaming Edition" /f | Out-Null
    & reg add $oemKey /v SupportURL /t REG_SZ /d "https://www.winaurex.tech" /f | Out-Null
    & reg add $oemKey /v SupportPhone /t REG_SZ /d "Telegram: @FFShaikh69" /f | Out-Null
    & reg add $oemKey /v SupportHours /t REG_SZ /d "24/7 Community Support" /f | Out-Null
    & reg add $oemKey /v Logo /t REG_SZ /d "C:\Windows\System32\oemlogo.bmp" /f | Out-Null
    & reg add $oemKey /v Author /t REG_SZ /d "Farhan Shaikh" /f | Out-Null
    & reg add $oemKey /v "Author Info" /t REG_SZ /d "https://github.com/YTxFSGAMERz" /f | Out-Null

    # Copy OEM logo & custom wallpapers
    $oemFolder = Join-Path $PSScriptRoot "OEM Info"
    if (Test-Path "$oemFolder\oemlogo.bmp") {
        Copy-Item "$oemFolder\oemlogo.bmp" "$mountDir\Windows\System32\oemlogo.bmp" -Force
    }
    if (Test-Path "$oemFolder\img0.jpg") {
        $wallDir = "$mountDir\Windows\Web\Wallpaper\Windows"
        if (-not (Test-Path $wallDir)) { New-Item -ItemType Directory -Path $wallDir -Force | Out-Null }
        Copy-Item "$oemFolder\img0.jpg" "$wallDir\img0.jpg" -Force
        Copy-Item "$oemFolder\img0.jpg" "$wallDir\img0_3840x2160.jpg" -Force
    }
    if (Test-Path "$oemFolder\img19.jpg") {
        $wallDir = "$mountDir\Windows\Web\Wallpaper\Windows"
        Copy-Item "$oemFolder\img19.jpg" "$wallDir\img19.jpg" -Force
        Copy-Item "$oemFolder\img19.jpg" "$wallDir\img19_3840x2160.jpg" -Force
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

    # TIER 2 MODERATE: WINDOWS UPDATE DISABLED (PREVENTS REBOOTS & LATENCY) WHILE WINGET IS PRESERVED
    Write-Host "[*] Disabling Windows Update automatic downloads (Gaming & Low-Latency Profile)..." -ForegroundColor Yellow
    & reg add "HKLM\zSYSTEM\ControlSet001\Services\wuauserv" /v Start /t REG_DWORD /d 4 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f | Out-Null
    # Preserve WaaSMedicSVC and UsoSvc in registry so CBS store does not corrupt, allowing WinGet to install cleanly

    # Disable OneDrive sync policy
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f | Out-Null

    # 13. Pre-Stage "Post Install" Application Suite & autounattend.xml
    Write-Host "[*] Pre-staging 'Post Install' folder to Public Desktop..." -ForegroundColor Cyan
    $postInstallSource = Join-Path $PSScriptRoot "Post Install"
    if (Test-Path $postInstallSource) {
        $desktopPostInstall = "$mountDir\Users\Public\Desktop\Post Install"
        if (-not (Test-Path $desktopPostInstall)) { New-Item -ItemType Directory -Path $desktopPostInstall -Force | Out-Null }
        robocopy $postInstallSource $desktopPostInstall /E /NJH /NJS /NDL /NC /NS | Out-Null

        $isoPostInstall = "$stagingDir\Post Install"
        robocopy $postInstallSource $isoPostInstall /E /NJH /NJS /NDL /NC /NS | Out-Null
    }

    $xmlSource = Join-Path $PSScriptRoot "autounattend.xml"
    if (Test-Path $xmlSource) {
        Copy-Item $xmlSource "$mountDir\Windows\System32\Sysprep\autounattend.xml" -Force | Out-Null
        Copy-Item $xmlSource "$stagingDir\autounattend.xml" -Force | Out-Null
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
    & reg add "HKLM\zSYSTEM\Setup\MoSetup" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f | Out-Null
    reg unload HKLM\zSYSTEM | Out-Null

    if (Test-Path "$oemFolder\setup.bmp") {
        Copy-Item "$oemFolder\setup.bmp" "$mountDir\sources\setup.bmp" -Force -ErrorAction SilentlyContinue
        Copy-Item "$oemFolder\setup.bmp" "$stagingDir\sources\background_cli.bmp" -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "$oemFolder\winpe.jpg") {
        Copy-Item "$oemFolder\winpe.jpg" "$mountDir\Windows\System32\winpe.jpg" -Force -ErrorAction SilentlyContinue
    }

    & dism /English /unmount-image "/mountdir:$mountDir" /commit

    if (Test-Path "$stagingDir\boot\bootfix.bin") {
        Remove-Item "$stagingDir\boot\bootfix.bin" -Force -ErrorAction SilentlyContinue
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

    & $localOscdimg -m -o -u2 -udfver102 "-bootdata:$bootdata" "$stagingDir" "$OutISO"

    Write-Host "`n======================================================================" -ForegroundColor Green
    Write-Host " [SUCCESS] WinAurex Performance & Gaming ISO Compiled Successfully!   " -ForegroundColor White
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host " * ISO Location  : $OutISO" -ForegroundColor Yellow
    Write-Host " * Windows Update: Disabled (Zero Latency & No Forced Reboots)" -ForegroundColor Yellow
    Write-Host " * WinGet & Store: Fully Functional" -ForegroundColor Green
    Write-Host " * Drivers       : 100% Intact & Untouched" -ForegroundColor Green
    Write-Host "======================================================================`n" -ForegroundColor Green

} finally {
    # 18. Safe Cleanup (NEVER touch repo files like oscdimg.exe or autounattend.xml)
    Write-Host "[*] Cleaning temporary build folders..." -ForegroundColor DarkGray
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
