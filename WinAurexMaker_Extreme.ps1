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

# Auto-resolve Windows 11 Pro if EditionIndex was not explicitly passed
$targetSourceMedia = if (Test-Path "$mountedDrive\sources\install.wim") { "$mountedDrive\sources\install.wim" } else { "$mountedDrive\sources\install.esd" }
if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('EditionIndex')) {
    Write-Host "[*] Using specified Edition Index: $EditionIndex" -ForegroundColor Cyan
} else {
    Write-Host "[*] Auto-detecting 'Windows 11 Pro' index in $targetSourceMedia..." -ForegroundColor Cyan
    $wimInfo = & dism /English /Get-WimInfo "/WimFile:$targetSourceMedia"
    $detectedIndex = 0
    $curIdx = 0
    foreach ($line in ($wimInfo -split "`r?`n")) {
        if ($line -match '^Index\s*:\s*(\d+)') {
            $curIdx = [int]$matches[1]
        }
        if ($line -match '^Name\s*:\s*Windows 11 Pro$') {
            $detectedIndex = $curIdx
            break
        }
    }
    if ($detectedIndex -gt 0) {
        $EditionIndex = $detectedIndex
        Write-Host "  [+] Found 'Windows 11 Pro' at Index: $EditionIndex" -ForegroundColor Green
    } else {
        Write-Host "  [-] 'Windows 11 Pro' not found by name. Defaulting to Index: $EditionIndex" -ForegroundColor Yellow
    }
}

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
    cmd.exe /c "attrib -r `"$stagingDir\*`" /s /d >nul 2>&1"

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

    # 8. Nuclear Debloating (Purge ALL Provisioned AppX)
    Write-Host "`n[*] Performing 100% AppX annihilation..." -ForegroundColor Cyan
    $packagesRaw = & dism /English "/image:$mountDir" /Get-ProvisionedAppxPackages
    $allPackages = @()
    foreach ($line in ($packagesRaw -split "`r?`n")) {
        if ($line -match 'PackageName\s*:\s*(.*)') {
            $allPackages += $matches[1].Trim()
        }
    }

    foreach ($pkg in $allPackages) {
        Write-Host "  [-] Eradicating AppX: $pkg" -ForegroundColor DarkGray
        & dism /English "/image:$mountDir" /Remove-ProvisionedAppxPackage "/PackageName:$pkg" | Out-Null
    }

    # 9. Extended FOD / Capability Removal (Massive Size Reduction)
    Write-Host "[*] Stripping unused Windows Capabilities & FODs (Speech, Handwriting, OCR, Math)..." -ForegroundColor Cyan
    $capsToPurge = @(
        'Language.Handwriting*',
        'Language.Speech*',
        'Language.TextToSpeech*',
        'Language.OCR*',
        'App.StepsRecorder*',
        'MathRecognizer*',
        'Microsoft.Windows.WordPad*',
        'Media.WindowsMediaPlayer*',
        'Hello.Face*',
        'App.Support.QuickAssist*',
        'Microsoft.Windows.PowerShell.ISE*',
        'OpenSSH.Client*',
        'Print.Fax.Scan*',
        'Print.Management.Console*',
        'XPS.Foundation*'
    )
    $installedCaps = Get-WindowsCapability -Path $mountDir -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Installed' }
    foreach ($cap in $installedCaps) {
        $shouldRemove = $false
        foreach ($pattern in $capsToPurge) {
            if ($cap.Name -like $pattern) {
                $shouldRemove = $true
                break
            }
        }
        if ($shouldRemove) {
            Write-Host "  [-] Removing Capability: $($cap.Name)" -ForegroundColor DarkGray
            Remove-WindowsCapability -Path $mountDir -Name $cap.Name -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # Disable Windows 11 Reserved Storage (reclaims 7.0 GB of hidden disk reservation)
    Write-Host "[*] Disabling Reserved Storage state (reclaims 7GB disk footprint)..." -ForegroundColor Cyan
    & dism /English "/image:$mountDir" /Set-ReservedStorageState /State:Disabled | Out-Null

    # 10. Bloat SystemApps Annihilation (AI, Copilot, Widgets, ContentDelivery)
    Write-Host "[*] Annihilating bloat SystemApps (AI, Copilot, Widgets, Ads)..." -ForegroundColor Cyan
    $systemAppsToPurge = @(
        "Microsoft.Windows.ContentDeliveryManager_*",
        "Microsoft.Windows.PeopleExperienceHost_*",
        "Microsoft.XboxGameCallableUI_*",
        "Microsoft.AIFabric.CBS.*",
        "MicrosoftWindows.Client.CoreAI_*",
        "MicrosoftWindows.Client.AIX_*",
        "Microsoft.Copilot_*",
        "MicrosoftWindows.Client.WebExperience_*",
        "Microsoft.Windows.PinningConfirmationDialog_*",
        "Microsoft.Windows.SecureAssessmentBrowser_*",
        "Microsoft.SecHealthUI_*",
        "Microsoft.Windows.SecHealthUI_*"
    )
    foreach ($appPat in $systemAppsToPurge) {
        $foundDirs = Get-ChildItem -Path "$mountDir\Windows\SystemApps" -Filter $appPat -Directory -ErrorAction SilentlyContinue
        foreach ($d in $foundDirs) {
            Write-Host "  [-] Purging SystemApp: $($d.Name)" -ForegroundColor DarkGray
            & takeown /f $d.FullName /r /d y 2>&1 | Out-Null
            & icacls $d.FullName /grant "$($adminGroup.Value):(F)" /t /c /q 2>&1 | Out-Null
            Remove-Item -Path $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        # In Windows 11 24H2, SecHealthUI also resides in Program Files\WindowsApps
        $winAppsDirs = Get-ChildItem -Path "$mountDir\Program Files\WindowsApps" -Filter $appPat -Directory -ErrorAction SilentlyContinue
        foreach ($d in $winAppsDirs) {
            Write-Host "  [-] Purging WindowsApp: $($d.Name)" -ForegroundColor DarkGray
            & takeown /f $d.FullName /r /d y 2>&1 | Out-Null
            & icacls $d.FullName /grant "$($adminGroup.Value):(F)" /t /c /q 2>&1 | Out-Null
            Remove-Item -Path $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Purge Windows Security Health staging directory
    $secHealthDir = "$mountDir\Windows\System32\SecurityHealth"
    if (Test-Path $secHealthDir) {
        Write-Host "  [-] Purging SecurityHealth staging directory..." -ForegroundColor DarkGray
        & takeown /f $secHealthDir /r /d y 2>&1 | Out-Null
        & icacls $secHealthDir /grant "$($adminGroup.Value):(F)" /t /c /q 2>&1 | Out-Null
        Remove-Item -Path $secHealthDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Purge Defender and Security Health binaries
    foreach ($secExe in @('SecurityHealthSystray.exe', 'SecurityHealthHost.exe', 'SecurityHealthService.exe', 'smartscreen.exe')) {
        $secPath = "$mountDir\Windows\System32\$secExe"
        if (Test-Path $secPath) {
            & takeown /f $secPath /a 2>&1 | Out-Null
            & icacls $secPath /grant "$($adminGroup.Value):(F)" /c /q 2>&1 | Out-Null
            Remove-Item -Path $secPath -Force -ErrorAction SilentlyContinue
        }
    }

    # Purge Windows Defender program directories
    foreach ($defDir in @(
        "$mountDir\Program Files\Windows Defender",
        "$mountDir\Program Files (x86)\Windows Defender",
        "$mountDir\ProgramData\Microsoft\Windows Defender",
        "$mountDir\ProgramData\Microsoft\Windows Security Health"
    )) {
        if (Test-Path $defDir) {
            Write-Host "  [-] Purging Defender folder: $defDir" -ForegroundColor DarkGray
            & takeown /f $defDir /r /d y 2>&1 | Out-Null
            & icacls $defDir /grant "$($adminGroup.Value):(F)" /t /c /q 2>&1 | Out-Null
            Remove-Item -Path $defDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # 11. Edge & OneDrive Total Eradication
    Write-Host "[*] Annihilating Microsoft Edge & OneDrive binaries..." -ForegroundColor Cyan
    Remove-Item -Path "$mountDir\Program Files (x86)\Microsoft\Edge" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$mountDir\Program Files (x86)\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$mountDir\Program Files (x86)\Microsoft\EdgeCore" -Recurse -Force -ErrorAction SilentlyContinue

    foreach ($oneDriveExe in @("$mountDir\Windows\System32\OneDriveSetup.exe", "$mountDir\Windows\SysWOW64\OneDriveSetup.exe")) {
        if (Test-Path $oneDriveExe) {
            & takeown /f $oneDriveExe 2>&1 | Out-Null
            & icacls $oneDriveExe /grant "$($adminGroup.Value):(F)" 2>&1 | Out-Null
            Remove-Item $oneDriveExe -Force -ErrorAction SilentlyContinue
        }
    }

    # 12. Physical WinRE Eradication (Direct-Deploy does not need SafeOS!)
    Write-Host "[*] Physically eradicating WinRE recovery image (-700 MB)..." -ForegroundColor Cyan
    if (Test-Path "$mountDir\Windows\System32\Recovery\winre.wim") {
        & takeown /f "$mountDir\Windows\System32\Recovery" /r 2>&1 | Out-Null
        & icacls "$mountDir\Windows\System32\Recovery" /grant "$($adminGroup.Value):(F)" /t /c 2>&1 | Out-Null
        Remove-Item "$mountDir\Windows\System32\Recovery\winre.wim" -Force -ErrorAction SilentlyContinue
        Write-Host "  [-] winre.wim permanently destroyed" -ForegroundColor Green
    }

    # 12.1 DriverStore Archaic Repository Pruning (Pruning ~1.2 GB of ancient printer/modem drivers)
    Write-Host "[*] Pruning archaic inbox DriverStore repository (printers, modems, scanners)..." -ForegroundColor Cyan
    $driverPatterns = @('prn*.inf_*', 'mdm*.inf_*', 'tape*.inf_*', 'scfilter*.inf_*')
    foreach ($pat in $driverPatterns) {
        $found = Get-ChildItem -Path "$mountDir\Windows\System32\DriverStore\FileRepository" -Filter $pat -Directory -ErrorAction SilentlyContinue
        foreach ($d in $found) {
            & takeown /f $d.FullName /r /d y 2>&1 | Out-Null
            & icacls $d.FullName /grant "$($adminGroup.Value):(F)" /t /c /q 2>&1 | Out-Null
            Remove-Item -Path $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # 12.2 Font & Localization Pruning (Saving ~700 MB of non-Latin Asian/archaic fonts)
    Write-Host "[*] Pruning non-Latin localized fonts (saving ~700 MB)..." -ForegroundColor Cyan
    $fontsToPurge = @('msyh*.ttc', 'msjh*.ttc', 'simsun*.ttc', 'mingliu*.ttc', 'msgothic*.ttc', 'malgun*.ttc', 'gulim*.ttc', 'batang*.ttc', 'ebrima*.ttf', 'khmer*.ttf', 'lao*.ttf', 'mymr*.ttf', 'gadugi*.ttf')
    foreach ($f in $fontsToPurge) {
        $foundFonts = Get-ChildItem -Path "$mountDir\Windows\Fonts" -Filter $f -ErrorAction SilentlyContinue
        foreach ($file in $foundFonts) {
            & takeown /f $file.FullName /a 2>&1 | Out-Null
            & icacls $file.FullName /grant "$($adminGroup.Value):(F)" /c /q 2>&1 | Out-Null
            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        }
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
    cmd.exe /c "reg add `"$oemKey`" /v Manufacturer /t REG_SZ /d `"WinAurex`" /f >nul 2>&1"
    cmd.exe /c "reg add `"$oemKey`" /v Model /t REG_SZ /d `"WinAurex Core Ultra-Lite Edition`" /f >nul 2>&1"
    cmd.exe /c "reg add `"$oemKey`" /v SupportURL /t REG_SZ /d `"https://www.winaurex.tech`" /f >nul 2>&1"
    cmd.exe /c "reg add `"$oemKey`" /v SupportPhone /t REG_SZ /d `"Telegram: @FFShaikh69`" /f >nul 2>&1"
    cmd.exe /c "reg add `"$oemKey`" /v SupportHours /t REG_SZ /d `"24/7 Community Support`" /f >nul 2>&1"
    cmd.exe /c "reg add `"$oemKey`" /v Logo /t REG_SZ /d `"C:\Windows\System32\oemlogo.bmp`" /f >nul 2>&1"
    cmd.exe /c "reg add `"$oemKey`" /v Author /t REG_SZ /d `"Farhan Shaikh`" /f >nul 2>&1"
    cmd.exe /c "reg add `"$oemKey`" /v `"Author Info`" /t REG_SZ /d `"https://github.com/YTxFSGAMERz`" /f >nul 2>&1"

    $oemFolder = Join-Path $PSScriptRoot "OEM Info"
    if (Test-Path "$oemFolder\oemlogo.bmp") {
        $logoDest = "$mountDir\Windows\System32\oemlogo.bmp"
        if (Test-Path $logoDest) { & takeown /f $logoDest /a 2>&1 | Out-Null; & icacls $logoDest /grant Administrators:F /c /q 2>&1 | Out-Null }
        Copy-Item "$oemFolder\oemlogo.bmp" $logoDest -Force -ErrorAction SilentlyContinue
    }

    # 13. Hardware Bypasses & Clean Setup
    Write-Host "[*] Injecting hardware bypasses (TPM 2.0, Secure Boot, RAM, CPU, Storage, BitLocker)..." -ForegroundColor Cyan
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassTPMCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassRAMCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassCPUCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassStorageCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\MoSetup`" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\ControlSet001\Control\BitLocker`" /v PreventDeviceEncryption /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE`" /v BypassNRO /t REG_DWORD /d 1 /f >nul 2>&1"

    # =========================================================================
    # SUPER-DEBLOAT: ERADICATE ACCOUNTS, PRIVACY/SECURITY & MICROSOFT 365 SLOP
    # =========================================================================
    Write-Host "[*] Eliminating Accounts, Windows Security, M365 slop & Privacy from Settings..." -ForegroundColor Yellow
    $settingsHide = "hide:home;account;yourinfo;emailandaccounts;signinoptions;otherusers;workplace;backup;windowsdefender;deviceencryption;findmydevice;privacy;privacy-general;privacy-speech;privacy-speechtyping;privacy-feedback;privacy-activityhistory;privacy-location;privacy-webcam;privacy-camera;privacy-microphone;privacy-notifications;privacy-accountinfo;privacy-contacts;privacy-calendar;privacy-phonecalls;privacy-callhistory;privacy-messaging;privacy-email;privacy-tasks;privacy-documents;privacy-downloadsfolder;privacy-pictures;privacy-videos;privacy-broadfilesystemaccess;privacy-automaticfiledownloads;privacy-radios;privacy-customdevices;privacy-motion;privacy-eyetracker;privacy-backgroundspatialperception;privacy-backgroundapps;privacy-appdiagnostics;cortana-windowssearch"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer`" /v SettingsPageVisibility /t REG_SZ /d `"$settingsHide`" /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer`" /v NoOnlineAccount /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer`" /v SettingsPageVisibility /t REG_SZ /d `"$settingsHide`" /f >nul 2>&1"

    # Eradicate Microsoft Account Promo Banner & Microsoft 365 Badges in Settings
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\PolicyManager\default\Settings\AllowYourAccount`" /v Value /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`" /v NoConnectedUser /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\MicrosoftAccount`" /v DisableUserAuth /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableConsumerAccountStateContent /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableCloudOptimizedContent /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableSoftLanding /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f >nul 2>&1"

    # Disable Hibernation & Reserved Storage registry anchors (saves 10+ GB on disk)
    cmd.exe /c "reg add `"HKLM\zSYSTEM\ControlSet001\Control\Power`" /v HibernateEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager`" /v ShippedWithReserves /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager`" /v BaseReservationManager /t REG_DWORD /d 0 /f >nul 2>&1"
    # Fixed Virtual Memory / Pagefile Policy (prevents dynamic 4-8 GB swap ballooning)
    cmd.exe /c "reg add `"HKLM\zSYSTEM\ControlSet001\Control\Session Manager\Memory Management`" /v PagingFiles /t REG_MULTI_SZ /d `"C:\pagefile.sys 1024 2048`" /f >nul 2>&1"

    # Annihilate Windows Defender Security Center UI & Systray
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray`" /v HideSystray /t REG_DWORD /d 1 /f >nul 2>&1"
    foreach ($cat in @('Account protection', 'App and browser protection', 'Device performance and health', 'Device security', 'Family options', 'Firewall and network protection', 'Virus and threat protection')) {
        cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender Security Center\$cat`" /v UILockdown /t REG_DWORD /d 1 /f >nul 2>&1"
    }

    # Disable All Settings & Cloud Sync Engines
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\SettingSync`" /v DisableSettingSync /t REG_DWORD /d 2 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\SettingSync`" /v DisableSettingSyncUserOverride /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\SettingSync`" /v DisableApplicationSettingSync /t REG_DWORD /d 2 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\SettingSync`" /v DisableCredentialsSettingSync /t REG_DWORD /d 2 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\SettingSync`" /v DisableDesktopThemeSettingSync /t REG_DWORD /d 2 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\SettingSync`" /v DisablePersonalizationSettingSync /t REG_DWORD /d 2 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\SettingSync`" /v DisableWebBrowserSettingSync /t REG_DWORD /d 2 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\SettingSync`" /v DisableWindowsSettingSync /t REG_DWORD /d 2 /f >nul 2>&1"

    # Disable Windows Hello / Passport Prompts
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\PassportForWork`" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\PassportForWork`" /v DisablePostLogonProvisioning /t REG_DWORD /d 1 /f >nul 2>&1"

    # Privacy, Advertising, and Consumer Bloat Annihilation
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo`" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableConsumerAccountStateContent /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableSoftLanding /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f >nul 2>&1"

    # Speech & Inking Personalization (Online Speech & Custom Dictionary Harvest)
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\InputPersonalization`" /v AllowInputPersonalization /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\InputPersonalization`" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\InputPersonalization`" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Speech`" /v AllowSpeechModelUpdate /t REG_DWORD /d 0 /f >nul 2>&1"

    # Diagnostics, Telemetry, and Activity Tracking
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection`" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection`" /v MaxTelemetryAllowed /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection`" /v DoNotShowFeedbackNotifications /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection`" /v DisableOneSettingsDownloads /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\System`" /v EnableActivityFeed /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\System`" /v PublishUserActivities /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\System`" /v UploadUserActivities /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\System`" /v AllowClipboardHistory /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\System`" /v AllowCrossDeviceClipboard /t REG_DWORD /d 0 /f >nul 2>&1"

    # Location & Find My Device
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\FindMyDevice`" /v AllowFindMyDevice /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\LocationAndSensors`" /v DisableLocation /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\LocationAndSensors`" /v DisableLocationScripting /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\LocationAndSensors`" /v DisableWindowsLocationProvider /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location`" /v Value /t REG_SZ /d `"Deny`" /f >nul 2>&1"

    # GameDVR & Delivery Optimization
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\GameDVR`" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization`" /v DODownloadMode /t REG_DWORD /d 0 /f >nul 2>&1"

    # User Profile (Default NTUSER) Tweaks: Recommendations & Offers, Tracking, ContentDelivery
    cmd.exe /c "reg add `"HKLM\zNTUSER\Control Panel\International\User Profile`" /v HttpAcceptLanguageOptOut /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`" /v Start_TrackProgs /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`" /v Start_TrackDocs /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SubscribedContent-353698Enabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy`" /v HasAccepted /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\InputPersonalization`" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\InputPersonalization`" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\InputPersonalization\TrainedDataStore`" /v HarvestContacts /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Privacy`" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Search`" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Search`" /v CortanaConsent /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Search`" /v DeviceHistoryEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Search`" /v HistoryViewEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Search`" /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`" /v ShowTaskViewButton /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`" /v TaskbarMn /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`" /v TaskbarDa /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\GameDVR`" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul 2>&1"

    # TIER 3 EXTREME: DISABLE WINDOWS UPDATE FOR MAXIMUM RESOURCE REDUCTION
    Write-Host "[*] Disabling Windows Update services (Extreme Ultra-Lite Baseline)..." -ForegroundColor Yellow
    foreach ($svc in @('wuauserv', 'UsoSvc', 'WaaSMedicSvc')) {
        cmd.exe /c "reg add `"HKLM\zSYSTEM\ControlSet001\Services\$svc`" /v Start /t REG_DWORD /d 4 /f >nul 2>&1"
    }
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`" /v AUOptions /t REG_DWORD /d 2 /f >nul 2>&1"

    # TIER 3 EXTREME: DISABLE WINDOWS DEFENDER & SMARTSCREEN (SUB-800MB RAM TARGET)
    Write-Host "[*] Annihilating Windows Defender & SmartScreen services..." -ForegroundColor Yellow
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender`" /v DisableAntiSpyware /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender`" /v DisableAntiVirus /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection`" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection`" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection`" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection`" /v DisableScanOnRealtimeEnable /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection`" /v DisableIOAVProtection /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\System`" /v EnableSmartScreen /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer`" /v SmartScreenEnabled /t REG_SZ /d `"Off`" /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray`" /v HideSystray /t REG_DWORD /d 1 /f >nul 2>&1"
    foreach ($cat in @("Account protection", "App and browser protection", "Device performance and health", "Device security", "Family options", "Firewall and network protection", "Virus and threat protection")) {
        cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows Defender Security Center\$cat`" /v UILockdown /t REG_DWORD /d 1 /f >nul 2>&1"
    }

    # Delete SecurityHealth taskbar startup entry and neutralize windowsdefender protocol
    cmd.exe /c "reg delete `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Run`" /v SecurityHealth /f >nul 2>&1"
    cmd.exe /c "reg delete `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run`" /v SecurityHealth /f >nul 2>&1"
    cmd.exe /c "reg delete `"HKLM\zSOFTWARE\Classes\windowsdefender`" /f >nul 2>&1"

    # Disable Defender services, security health services, and anti-malware kernel filter drivers
    foreach ($svc in @('WinDefend', 'WdNisSvc', 'Sense', 'SecurityHealthService', 'wscsvc', 'WdBoot', 'WdFilter', 'WdNisDrv')) {
        cmd.exe /c "reg add `"HKLM\zSYSTEM\ControlSet001\Services\$svc`" /v Start /t REG_DWORD /d 4 /f >nul 2>&1"
    }

    # TIER 3 EXTREME: DISABLE WINDOWS SEARCH INDEXER & SYSMAIN (SUPERFETCH)
    Write-Host "[*] Disabling Windows Search Indexer & SuperFetch..." -ForegroundColor Yellow
    cmd.exe /c "reg add `"HKLM\zSYSTEM\ControlSet001\Services\WSearch`" /v Start /t REG_DWORD /d 4 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\ControlSet001\Services\SysMain`" /v Start /t REG_DWORD /d 4 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Search`" /v AllowCortana /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Search`" /v DisableWebSearch /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Search`" /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f >nul 2>&1"

    # TIER 3 EXTREME: DISABLE TELEMETRY, DIAGNOSTICS & TRACKING SERVICES
    Write-Host "[*] Disabling Telemetry, Diagnostics & Error Reporting services..." -ForegroundColor Yellow
    foreach ($svc in @('DiagTrack', 'dmwappushservice', 'diagnosticshub.standardcollector.service', 'WerSvc', 'MapsBroker', 'lfsvc', 'WbioSrvc', 'DoSvc', 'PcaSvc', 'TrkWks', 'PhoneSvc', 'SensorService', 'SensrSvc', 'SensorDataService', 'wisvc', 'RetailDemo')) {
        cmd.exe /c "reg add `"HKLM\zSYSTEM\ControlSet001\Services\$svc`" /v Start /t REG_DWORD /d 4 /f >nul 2>&1"
    }

    # Visual Performance Optimization (Disable unnecessary animation latency)
    cmd.exe /c "reg add `"HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Control Panel\Desktop`" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zNTUSER\Control Panel\Desktop\WindowMetrics`" /v MinAnimate /t REG_SZ /d 0 /f >nul 2>&1"

    # Disable WinRE AutoRecovery Agent
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ReAgent`" /v AutoRecovery /t REG_DWORD /d 0 /f >nul 2>&1"

    # Disable Edge telemetry and background processes
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Edge`" /v HubsSidebarEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Edge`" /v ShowHomeButton /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Edge`" /v HideFirstRunExperience /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Edge`" /v StartupBoostEnabled /t REG_DWORD /d 0 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSOFTWARE\Policies\Microsoft\Edge`" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f >nul 2>&1"

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

    # 14. Pre-Stage Unattended Configuration (Offline Sysprep Injection)
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
        cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup`" /v UnattendFile /t REG_SZ /d `"C:\Windows\System32\Sysprep\unattend.xml`" /f >nul 2>&1"
    }
    # Ensure NO autounattend.xml exists at the root of the ISO (avoids 24H2/26H2 WinPE unattended crash)
    if (Test-Path "$stagingDir\autounattend.xml") {
        Remove-Item "$stagingDir\autounattend.xml" -Force -ErrorAction SilentlyContinue
    }

    # 15. Unload Registry
    Write-Host "[*] Unmounting registry hives..." -ForegroundColor DarkGray
    reg unload HKLM\zCOMPONENTS | Out-Null
    reg unload HKLM\zDEFAULT | Out-Null
    reg unload HKLM\zNTUSER | Out-Null
    reg unload HKLM\zSOFTWARE | Out-Null
    reg unload HKLM\zSYSTEM | Out-Null

    # 15.1 Purge Cache & Update Backups (Extreme size reduction)
    Write-Host "[*] Purging WinSxS backup manifests and Windows cache directories..." -ForegroundColor Cyan
    Remove-Item -Path "$mountDir\Windows\WinSxS\Backup\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$mountDir\Windows\WinSxS\ManifestCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$mountDir\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$mountDir\ProgramData\Microsoft\Windows\WER\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$mountDir\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    # 16. Commit and Clean Image
    Write-Host "`n[*] Starting component cleanup..." -ForegroundColor Cyan
    & dism /English "/image:$mountDir" /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null

    Write-Host "[*] Unmounting and committing changes to install.wim..." -ForegroundColor Cyan
    & dism /English /unmount-image "/mountdir:$mountDir" /commit

    Write-Host "[*] Exporting ultra-compressed install.esd with Solid LZMS recovery compression..." -ForegroundColor Cyan
    $targetEsd = "$stagingDir\sources\install.esd"
    if (Test-Path $targetEsd) { Remove-Item $targetEsd -Force -ErrorAction SilentlyContinue }
    & dism /Export-Image /SourceImageFile:$wimPath /SourceIndex:$EditionIndex /DestinationImageFile:$targetEsd /Compress:recovery /CheckIntegrity
    Remove-Item $wimPath -Force -ErrorAction SilentlyContinue
    if (Test-Path "$stagingDir\sources\install.wim") {
        Remove-Item "$stagingDir\sources\install.wim" -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  [+] install.esd created successfully ($([math]::Round((Get-Item $targetEsd).Length / 1GB, 2)) GB)" -ForegroundColor Green

    # 17. Service boot.wim (WinPE & WinAurex Direct-Deploy Engine)
    Write-Host "`n[*] Servicing boot.wim (WinAurex Direct-Deploy Engine & Hardware bypasses)..." -ForegroundColor Cyan
    $bootWim = "$stagingDir\sources\boot.wim"
    Set-ItemProperty -Path $bootWim -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
    & dism /English /mount-image "/imagefile:$bootWim" /index:2 "/mountdir:$mountDir"

    cmd.exe /c "reg load HKLM\zSYSTEM `"$mountDir\Windows\System32\config\SYSTEM`" >nul 2>&1"
    # SHELL CONFIGURATION: WinPE natively uses winpeshl.exe
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup`" /v CmdLine /t REG_SZ /d `"winpeshl.exe`" /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassTPMCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassRAMCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassCPUCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassStorageCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\LabConfig`" /v BypassDiskCheck /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg add `"HKLM\zSYSTEM\Setup\MoSetup`" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f >nul 2>&1"
    cmd.exe /c "reg unload HKLM\zSYSTEM >nul 2>&1"

    # Inject WinAurex Direct-Deploy Launcher into boot.wim
    $deployCmdSource = Join-Path $PSScriptRoot "WinAurexDeploy.cmd"
    if (Test-Path $deployCmdSource) {
        Write-Host "  [+] Injecting WinAurex Direct-Deploy Engine into boot.wim and staging..." -ForegroundColor Green
        if (-not (Test-Path "$mountDir\sources")) { New-Item -ItemType Directory -Path "$mountDir\sources" -Force | Out-Null }
        Copy-Item $deployCmdSource "$mountDir\sources\WinAurexDeploy.cmd" -Force
        Copy-Item $deployCmdSource "$mountDir\Windows\System32\WinAurexDeploy.cmd" -Force
        Copy-Item $deployCmdSource "$stagingDir\sources\WinAurexDeploy.cmd" -Force

        # Also copy autounattend.xml into sources for unattended deployment
        $xmlSrc = Join-Path $PSScriptRoot "autounattend.xml"
        if (Test-Path $xmlSrc) {
            Copy-Item $xmlSrc "$mountDir\sources\autounattend.xml" -Force -ErrorAction SilentlyContinue
            Copy-Item $xmlSrc "$stagingDir\sources\autounattend.xml" -Force -ErrorAction SilentlyContinue
        }

        # Configure winpeshl.ini to cleanly launch WinAurex Direct-Deploy CLI directly (bypassing Microsoft setup)
        $winpeshlContent = @"
[LaunchApps]
%SYSTEMDRIVE%\Windows\System32\wpeinit.exe
cmd.exe, /k %SYSTEMDRIVE%\sources\WinAurexDeploy.cmd
"@
        Set-Content -Path "$mountDir\Windows\System32\winpeshl.ini" -Value $winpeshlContent -Encoding Ascii

        # Neutralize Microsoft setup.exe in boot.wim
        if (Test-Path "$mountDir\sources\setup.exe") {
            & takeown /f "$mountDir\sources\setup.exe" /a 2>&1 | Out-Null
            & icacls "$mountDir\sources\setup.exe" /grant Administrators:F /c /q 2>&1 | Out-Null
            Remove-Item "$mountDir\sources\setup.exe" -Force -ErrorAction SilentlyContinue
        }

        # Configure startnet.cmd to auto-launch the WinAurex CLI Direct-Deploy Engine
        $startnetContent = @"
@echo off
title WinAurex OS - High-Speed Direct-Deploy Engine
wpeinit

if exist %SYSTEMDRIVE%\sources\WinAurexDeploy.cmd (
    call %SYSTEMDRIVE%\sources\WinAurexDeploy.cmd
    goto :eof
)
if exist %SYSTEMDRIVE%\Windows\System32\WinAurexDeploy.cmd (
    call %SYSTEMDRIVE%\Windows\System32\WinAurexDeploy.cmd
    goto :eof
)
for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if exist %%d:\sources\WinAurexDeploy.cmd (
        call %%d:\sources\WinAurexDeploy.cmd
        goto :eof
    )
)
"@
        Set-Content -Path "$mountDir\Windows\System32\startnet.cmd" -Value $startnetContent -Encoding Ascii
    }

    # Copy native console utilities into WinPE for countdown & options
    foreach ($tool in @('choice.exe', 'timeout.exe', 'findstr.exe')) {
        $hostTool = Join-Path $env:SystemRoot "System32\$tool"
        if (Test-Path $hostTool) {
            Copy-Item $hostTool "$mountDir\Windows\System32\$tool" -Force -ErrorAction SilentlyContinue
        }
    }

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

    # 17.1 Remove bootfix.bin for direct, unattended automated UEFI boot
    if (Test-Path "$stagingDir\boot\bootfix.bin") {
        Remove-Item "$stagingDir\boot\bootfix.bin" -Force -ErrorAction SilentlyContinue
        Write-Host "[*] Removed bootfix.bin for direct automated UEFI boot..." -ForegroundColor Green
    }

    # 17.2 Classic Microsoft Setup Media Complete Annihilation (Reclaims ~270 MB)
    Write-Host "[*] Purging classic Microsoft Setup binaries and legacy databases (~270 MB)..." -ForegroundColor Cyan
    $setupFilesToPurge = @(
        "$stagingDir\setup.exe",
        "$stagingDir\setup_ms.bak",
        "$stagingDir\sources\setup.exe",
        "$stagingDir\sources\setup_ms.bak",
        "$stagingDir\sources\setupplatform.exe",
        "$stagingDir\sources\setupplatform.dll",
        "$stagingDir\sources\setupprep.exe",
        "$stagingDir\sources\winsetup.dll",
        "$stagingDir\sources\compatctrl.dll",
        "$stagingDir\sources\compatresources.dll",
        "$stagingDir\sources\appraiser.dll",
        "$stagingDir\sources\appraiser.sdb",
        "$stagingDir\sources\appraiserdatasha1.cat",
        "$stagingDir\sources\appraisersdblatestoshash.txt",
        "$stagingDir\sources\PID.txt",
        "$stagingDir\sources\ei.cfg",
        "$stagingDir\sources\wpx.dll",
        "$stagingDir\sources\vhdprovider.dll"
    )
    foreach ($f in $setupFilesToPurge) {
        if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
    }

    # Purge legacy upgrade/migration tables and sflist files
    Get-ChildItem -Path "$stagingDir\sources" -Filter "sflist*.dat" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$stagingDir\sources" -Filter "sfpat*.inf" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$stagingDir\sources" -Filter "wds*.dll" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    # Purge legacy setup directories
    $setupDirsToPurge = @(
        "$stagingDir\sources\migration",
        "$stagingDir\sources\replacementmanifests",
        "$stagingDir\sources\dlmanifests",
        "$stagingDir\sources\etwproviders",
        "$stagingDir\sources\uup",
        "$stagingDir\sources\asz",
        "$stagingDir\sources\ca-es",
        "$stagingDir\sources\eu-es",
        "$stagingDir\sources\gl-es",
        "$stagingDir\sources\id-id",
        "$stagingDir\sources\vi-vn"
    )
    foreach ($d in $setupDirsToPurge) {
        if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-Host "  [+] Classic Microsoft Setup media completely eradicated from ISO" -ForegroundColor Green

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

    $oscdimgArgs = "-m -o -u2 -udfver102 `"-bootdata:$bootdata`" `"$stagingDir`" `"$OutISO`""
    $p = Start-Process -FilePath $localOscdimg -ArgumentList $oscdimgArgs -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        throw "oscdimg failed with exit code $($p.ExitCode)"
    }

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
