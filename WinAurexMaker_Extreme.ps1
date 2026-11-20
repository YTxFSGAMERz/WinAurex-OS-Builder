<#
.SYNOPSIS
    WinAurex OS Builder - Tier 3: Core Ultra-Lite Edition
.DESCRIPTION
    Builds an ultra-lightweight, maximum-stripped Windows 11 ISO (similar to WinAurex Core / tiny11):
    - Model: WinAurex Core Ultra-Lite Edition
    - Memory Target: Sub-1GB idle RAM in virtualized or low-spec environments
    - Aggressive Debloat: Purges all consumer AppX, Edge, WinRE, and optional capabilities
    - Windows Update: Disabled
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
Write-Host "           WINAUREX OS BUILDER - TIER 3: CORE ULTRA-LITE             " -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  * Edition Name   : WinAurex Core Ultra-Lite Edition" -ForegroundColor Green
Write-Host "  * Target Platform: Low-Spec Hardware, Benchmark Rigs & Ultra-Lite VMs" -ForegroundColor Yellow
Write-Host "  * Memory Target  : Sub-1GB RAM Idle Baseline" -ForegroundColor Yellow
Write-Host "  * Debloat Level  : Extreme (AppX, FODs, Edge, WinRE Stripped)" -ForegroundColor Yellow
Write-Host "  * Post Install   : Pre-staged to Desktop with Offline Utilities" -ForegroundColor Green
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
    $OutISO = Join-Path $PSScriptRoot "WinAurex_Extreme.iso"
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

    # 8. Extreme Debloating (All Provisioned AppX)
    Write-Host "`n[*] Performing extreme AppX removal..." -ForegroundColor Cyan
    $packagesRaw = & dism /English "/image:$mountDir" /Get-ProvisionedAppxPackages
    $allPackages = @()
    foreach ($line in ($packagesRaw -split "`r?`n")) {
        if ($line -match 'PackageName\s*:\s*(.*)') {
            $allPackages += $matches[1].Trim()
        }
    }

    $extremePrefixes = @(
        'Clipchamp.', 'Microsoft.Bing', 'Microsoft.Gaming', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
        'Microsoft.MicrosoftOffice', 'Microsoft.MicrosoftSolitaire', 'Microsoft.People', 'Microsoft.PowerAutomate',
        'Microsoft.Todos', 'Microsoft.WindowsAlarms', 'microsoft.windowscommunicationsapps', 'Microsoft.WindowsFeedback',
        'Microsoft.WindowsMaps', 'Microsoft.WindowsSoundRecorder', 'Microsoft.Xbox', 'Microsoft.YourPhone',
        'Microsoft.Zune', 'MicrosoftCorporationII.MicrosoftFamily', 'MicrosoftCorporationII.QuickAssist',
        'MicrosoftTeams', 'MSTeams', 'Microsoft.OutlookForWindows', 'Microsoft.Windows.Teams', 'Microsoft.Copilot',
        'Microsoft.549981C3F5F10', 'Microsoft.WindowsCalculator', 'Microsoft.WindowsCamera', 'Microsoft.Paint',
        'Microsoft.ScreenSketch', 'Microsoft.Windows.Photos', 'Microsoft.WindowsStore', 'Microsoft.DesktopAppInstaller',
        'Microsoft.SecHealthUI', 'Microsoft.WindowsTerminal', 'Microsoft.Windows.Backup'
    )

    foreach ($pkg in $allPackages) {
        foreach ($prefix in $extremePrefixes) {
            if ($pkg -like "$prefix*") {
                Write-Host "  [-] Eradicating: $pkg" -ForegroundColor DarkGray
                & dism /English "/image:$mountDir" /Remove-ProvisionedAppxPackage "/PackageName:$pkg" | Out-Null
                break
            }
        }
    }

    # 9. Optional FOD Package Removal
    Write-Host "[*] Stripping legacy FOD optional packages..." -ForegroundColor Cyan
    $fods = & dism "/image:$mountDir" /Get-Packages /Format:Table
    $fodList = $fods -split "`n" | Select-Object -Skip 1
    $fodPatterns = @(
        "Microsoft-Windows-InternetExplorer-Optional-Package",
        "Microsoft-Windows-MediaPlayer-Package",
        "Microsoft-Windows-WordPad-FoD-Package",
        "Microsoft-Windows-TabletPCMath-Package",
        "Microsoft-Windows-StepsRecorder-Package",
        "Microsoft-Windows-Hello-Face-Package"
    )
    foreach ($pat in $fodPatterns) {
        $targets = $fodList | Where-Object { $_ -like "*$pat*" }
        foreach ($t in $targets) {
            $id = ($t -split "\s+")[0]
            if ($id) {
                Write-Host "  [-] Removing capability: $id" -ForegroundColor DarkGray
                & dism "/image:$mountDir" /Remove-Package "/PackageName:$id" | Out-Null
            }
        }
    }

    # 10. Strip Edge Browser, WinRE & OneDrive Setup
    Write-Host "[*] Stripping Microsoft Edge browser application and WinRE..." -ForegroundColor Cyan
    # Strip Edge browser application but preserve EdgeCore / WebView2 runtime for system stability
    Remove-Item -Path "$mountDir\Program Files (x86)\Microsoft\Edge\Application" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$mountDir\Program Files (x86)\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-Path "$mountDir\Windows\System32\Recovery\winre.wim") {
        & takeown /f "$mountDir\Windows\System32\Recovery" /r | Out-Null
        & icacls "$mountDir\Windows\System32\Recovery" /grant "$($adminGroup.Value):(F)" /t /c | Out-Null
        Remove-Item "$mountDir\Windows\System32\Recovery\winre.wim" -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path "$mountDir\Windows\System32\OneDriveSetup.exe") {
        & takeown /f "$mountDir\Windows\System32\OneDriveSetup.exe" | Out-Null
        & icacls "$mountDir\Windows\System32\OneDriveSetup.exe" /grant "$($adminGroup.Value):(F)" | Out-Null
        Remove-Item "$mountDir\Windows\System32\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
    }

    # 11. Load Offline Registry Hives
    Write-Host "`n[*] Loading offline registry hives..." -ForegroundColor Cyan
    reg load HKLM\zCOMPONENTS "$mountDir\Windows\System32\config\COMPONENTS" | Out-Null
    reg load HKLM\zDEFAULT "$mountDir\Windows\System32\config\default" | Out-Null
    reg load HKLM\zNTUSER "$mountDir\Users\Default\ntuser.dat" | Out-Null
    reg load HKLM\zSOFTWARE "$mountDir\Windows\System32\config\SOFTWARE" | Out-Null
    reg load HKLM\zSYSTEM "$mountDir\Windows\System32\config\SYSTEM" | Out-Null

    # 12. Injects WinAurex Core Ultra-Lite OEM Branding
    Write-Host "[*] Injecting 'WinAurex Core Ultra-Lite Edition' OEM Branding..." -ForegroundColor Cyan
    $oemKey = "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
    & reg add $oemKey /v Manufacturer /t REG_SZ /d "WinAurex" /f | Out-Null
    & reg add $oemKey /v Model /t REG_SZ /d "WinAurex Core Ultra-Lite Edition" /f | Out-Null
    & reg add $oemKey /v SupportURL /t REG_SZ /d "https://www.winaurex.tech" /f | Out-Null
    & reg add $oemKey /v SupportPhone /t REG_SZ /d "Telegram: @FFShaikh69" /f | Out-Null
    & reg add $oemKey /v SupportHours /t REG_SZ /d "24/7 Community Support" /f | Out-Null
    & reg add $oemKey /v Logo /t REG_SZ /d "C:\Windows\System32\oemlogo.bmp" /f | Out-Null
    & reg add $oemKey /v Author /t REG_SZ /d "Farhan Shaikh" /f | Out-Null
    & reg add $oemKey /v "Author Info" /t REG_SZ /d "https://github.com/YTxFSGAMERz" /f | Out-Null

    $oemFolder = Join-Path $PSScriptRoot "OEM Info"
    if (Test-Path "$oemFolder\oemlogo.bmp") {
        $logoDest = "$mountDir\Windows\System32\oemlogo.bmp"
        if (Test-Path $logoDest) { & takeown /f $logoDest /a 2>&1 | Out-Null; & icacls $logoDest /grant Administrators:F /c /q 2>&1 | Out-Null }
        Copy-Item "$oemFolder\oemlogo.bmp" $logoDest -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "$oemFolder\img0.jpg") {
        $wallDir = "$mountDir\Windows\Web\Wallpaper\Windows"
        if (-not (Test-Path $wallDir)) { New-Item -ItemType Directory -Path $wallDir -Force | Out-Null }
        foreach ($wName in @('img0.jpg', 'img0_3840x2160.jpg')) {
            $wDest = "$wallDir\$wName"
            if (Test-Path $wDest) { & takeown /f $wDest /a 2>&1 | Out-Null; & icacls $wDest /grant Administrators:F /c /q 2>&1 | Out-Null }
            Copy-Item "$oemFolder\img0.jpg" $wDest -Force -ErrorAction SilentlyContinue
        }
    }
    if (Test-Path "$oemFolder\img19.jpg") {
        $wallDir = "$mountDir\Windows\Web\Wallpaper\Windows"
        foreach ($wName in @('img19.jpg', 'img19_3840x2160.jpg')) {
            $wDest = "$wallDir\$wName"
            if (Test-Path $wDest) { & takeown /f $wDest /a 2>&1 | Out-Null; & icacls $wDest /grant Administrators:F /c /q 2>&1 | Out-Null }
            Copy-Item "$oemFolder\img19.jpg" $wDest -Force -ErrorAction SilentlyContinue
        }
    }

    # 13. Hardware Bypasses & Clean Setup
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

    # TIER 3 EXTREME: DISABLE WINDOWS UPDATE FOR MAXIMUM RESOURCE REDUCTION
    Write-Host "[*] Disabling Windows Update services (Extreme Ultra-Lite Baseline)..." -ForegroundColor Yellow
    & reg add "HKLM\zSYSTEM\ControlSet001\Services\wuauserv" /v Start /t REG_DWORD /d 4 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f | Out-Null

    # Disable WinRE AutoRecovery Agent
    & reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ReAgent" /v AutoRecovery /t REG_DWORD /d 0 /f | Out-Null

    # Disable Edge telemetry and background processes
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Edge" /v HubsSidebarEnabled /t REG_DWORD /d 0 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Edge" /v ShowHomeButton /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Edge" /v StartupBoostEnabled /t REG_DWORD /d 0 /f | Out-Null
    & reg add "HKLM\zSOFTWARE\Policies\Microsoft\Edge" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f | Out-Null

    # 14. Pre-Stage "Post Install" Application Suite & autounattend.xml
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

    # 15. Unload Registry
    Write-Host "[*] Unmounting registry hives..." -ForegroundColor DarkGray
    reg unload HKLM\zCOMPONENTS | Out-Null
    reg unload HKLM\zDEFAULT | Out-Null
    reg unload HKLM\zNTUSER | Out-Null
    reg unload HKLM\zSOFTWARE | Out-Null
    reg unload HKLM\zSYSTEM | Out-Null

    # 16. Commit and Clean Image
    Write-Host "`n[*] Starting component cleanup..." -ForegroundColor Cyan
    & dism /English "/image:$mountDir" /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null

    Write-Host "[*] Unmounting and committing changes to install.wim..." -ForegroundColor Cyan
    & dism /English /unmount-image "/mountdir:$mountDir" /commit

    Write-Host "[*] Re-exporting install.wim with maximum compression..." -ForegroundColor Cyan
    $tempWim = "$stagingDir\sources\install_clean.wim"
    & dism /Export-Image /SourceImageFile:$wimPath /SourceIndex:$EditionIndex /DestinationImageFile:$tempWim /Compress:max
    Remove-Item $wimPath -Force
    Rename-Item $tempWim "install.wim"

    # 17. Service boot.wim (WinPE & Setup)
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

    if (Test-Path "$stagingDir\boot\bootfix.bin") {
        Remove-Item "$stagingDir\boot\bootfix.bin" -Force -ErrorAction SilentlyContinue
    }

    # 17.1 Ensure clean installation channel without prompt
    $eiCfg = "[Channel]`r`n_Default`r`n[VL]`r`n0"
    Set-Content -Path "$stagingDir\sources\ei.cfg" -Value $eiCfg -Encoding Ascii -Force

    # 18. Compile Final Dual-Boot ISO
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
    Write-Host " [SUCCESS] WinAurex Core Ultra-Lite ISO Compiled Successfully!        " -ForegroundColor White
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host " * ISO Location  : $OutISO" -ForegroundColor Yellow
    Write-Host " * RAM Target    : Sub-1GB Idle Baseline" -ForegroundColor Green
    Write-Host "======================================================================`n" -ForegroundColor Green

} finally {
    # 19. Safe Cleanup (NEVER touch repo files like oscdimg.exe or autounattend.xml)
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
