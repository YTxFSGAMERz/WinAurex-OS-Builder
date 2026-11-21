@echo off
wpeinit >nul 2>&1
setlocal EnableDelayedExpansion
title WinAurex OS - High-Speed Deployment Engine
color 1F
mode con: cols=96 lines=36

:: 1. Search for Install Image (install.wim or install.esd) across drives with retry loop
set "INSTALL_WIM="
set "INSTALL_DRIVE="
set /a RETRY_COUNT=0

:SCAN_DRIVES
for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if exist "%%d:\sources\install.wim" (
        set "INSTALL_WIM=%%d:\sources\install.wim"
        set "INSTALL_DRIVE=%%d:"
        goto :FOUND_WIM
    )
    if exist "%%d:\sources\install.esd" (
        set "INSTALL_WIM=%%d:\sources\install.esd"
        set "INSTALL_DRIVE=%%d:"
        goto :FOUND_WIM
    )
)

if not defined INSTALL_WIM (
    set /a RETRY_COUNT+=1
    if !RETRY_COUNT! leq 5 (
        echo [*] Waiting for optical/installation drives to initialize (Attempt !RETRY_COUNT!/5)...
        ping -n 3 127.0.0.1 >nul
        goto :SCAN_DRIVES
    )
)

:FOUND_WIM
if not defined INSTALL_WIM (
    color 4F
    echo [-] ERROR: Could not locate \sources\install.wim or \sources\install.esd on any drive!
    echo.
    echo Dropping to Command Prompt for recovery...
    cmd.exe
    exit /b 1
)

:: 2. Initialize Archinstall-style Configuration Defaults
set "CFG_DISK=0"
set "CFG_PARTMODE=AUTO"
set "CFG_TARGET_VOL="
set "CFG_TARGET_VOL_DESC=Disk 0 (Auto-Wipe)"
set "CFG_FORMAT_TARGET=YES"
set "CFG_ESP_VOL=AUTO"
set "CFG_ESP_DESC=Auto-Created (100MB FAT32 ESP)"
set "CFG_COMPACT=YES"
set "CFG_FOOTPRINT=YES"
set "CFG_HOSTNAME=WinAurex-PC"
set "CFG_USERNAME=Admin"
set "CFG_PASSWORD="

:MAIN_MENU
cls
echo ================================================================================================
echo       #   #   #  #####  #   #   ###   #     #  ####   #####  #   #       ###    #### 
echo       #   #   #    #    ##  #  #   #  #     #  #   #  #       # #       #   #  #     
echo       #   #   #    #    # # #  #####  #     #  ####   ####     #        #   #   ###  
echo        # # # #     #    #  ##  #   #  #     #  #  #   #       # #       #   #      # 
echo         #   #    #####  #   #  #   #   #####   #   #  #####  #   #       ###   ####  
echo.
echo                    HIGH-SPEED GUIDED DIRECT-DEPLOYMENT ENGINE
echo                             https://www.winaurex.tech
echo ================================================================================================
echo [+] Installation Media Detected: !INSTALL_WIM!
echo ------------------------------------------------------------------------------------------------

set "DISP_PART_MODE=Automatic (Wipe Disk !CFG_DISK!, Create UEFI/GPT Layout)"
set "DISP_TARGET_OS=[N/A - Whole Disk Auto-Partitioned]"
set "DISP_FORMAT=[YES] (NTFS Format on OS Partition)"
set "DISP_ESP=[Auto-Created] (100MB FAT32 ESP)"

if "!CFG_PARTMODE!"=="MANUAL" (
    set "DISP_PART_MODE=Manual (Select Partition, Preserve other partitions)"
    set "DISP_TARGET_OS=!CFG_TARGET_VOL_DESC!"
    set "DISP_FORMAT=[!CFG_FORMAT_TARGET!] (Quick NTFS Format)"
    set "DISP_ESP=!CFG_ESP_DESC!"
)

set "DISP_COMPACT=[*] ENABLED (Saves ~4.5 GB binary footprint)"
if "!CFG_COMPACT!"=="NO" set "DISP_COMPACT=[ ] DISABLED (Standard uncompressed footprint)"

set "DISP_FOOTPRINT=[*] ENABLED (Hibernate Off, 1-2GB Fixed Pagefile)"
if "!CFG_FOOTPRINT!"=="NO" set "DISP_FOOTPRINT=[ ] DISABLED (Stock Windows settings)"

echo  CONFIGURATION PARAMETERS:
echo   [1] Target Disk             : Disk !CFG_DISK!
echo   [2] Partitioning Mode       : !DISP_PART_MODE!
echo   [3] Target OS Partition     : !DISP_TARGET_OS!
echo   [4] Quick Format Target     : !DISP_FORMAT!
echo   [5] EFI System Partition    : !DISP_ESP!
echo   [6] CompactOS Compression   : !DISP_COMPACT!
echo   [7] Footprint Optimization  : !DISP_FOOTPRINT!
echo   [8] Hostname / ComputerName : !CFG_HOSTNAME!
echo   [9] User Account Setup      : !CFG_USERNAME!
echo ------------------------------------------------------------------------------------------------
echo  ACTIONS:
echo   [I] Install (Write changes to disk and deploy WinAurex)
echo   [P] Guided Partition Manager (Create, Delete, Shrink, Format and Assign)
echo   [R] Refresh Disks and Media
echo   [Q] Exit to Command Prompt
echo ================================================================================================

set "MENU_CHOICE="
set /p MENU_CHOICE="Select an option [1-9, I, P, R, Q] (or press Enter to Install): "

if not defined MENU_CHOICE goto :CONFIRM_INSTALL
if /i "!MENU_CHOICE!"=="I" goto :CONFIRM_INSTALL
if /i "!MENU_CHOICE!"=="P" goto :PARTITION_MANAGER
if /i "!MENU_CHOICE!"=="R" goto :REFRESH_MEDIA
if /i "!MENU_CHOICE!"=="Q" goto :CMD_SHELL

if "!MENU_CHOICE!"=="1" goto :SET_DISK
if "!MENU_CHOICE!"=="2" goto :TOGGLE_PARTMODE
if "!MENU_CHOICE!"=="3" goto :PARTITION_MANAGER
if "!MENU_CHOICE!"=="4" goto :TOGGLE_FORMAT
if "!MENU_CHOICE!"=="5" goto :PARTITION_MANAGER
if "!MENU_CHOICE!"=="6" goto :TOGGLE_COMPACT
if "!MENU_CHOICE!"=="7" goto :TOGGLE_FOOTPRINT
if "!MENU_CHOICE!"=="8" goto :SET_HOSTNAME
if "!MENU_CHOICE!"=="9" goto :SET_USERACCOUNT

goto :MAIN_MENU

:: -------------------------------------------------------------------------------------------------
:: MAIN MENU HANDLERS
:: -------------------------------------------------------------------------------------------------

:SET_DISK
cls
echo ================================================================================================
echo                                 SELECT TARGET STORAGE DISK
echo ================================================================================================
echo.
echo Available storage disks:
set "DP_TMP=%TEMP%\dp_ls_disk.txt"
echo list disk > "%DP_TMP%"
diskpart /s "%DP_TMP%" | find /v /i "Microsoft DiskPart" | find /v /i "Copyright" | find /v /i "On computer"
del "%DP_TMP%" >nul 2>&1
echo.
set /p NEW_DISK="Enter Target Disk Number [default !CFG_DISK!]: "
if defined NEW_DISK set "CFG_DISK=!NEW_DISK!"
if "!CFG_PARTMODE!"=="AUTO" (
    set "CFG_TARGET_VOL_DESC=Disk !CFG_DISK! (Auto-Wipe)"
)
goto :MAIN_MENU

:TOGGLE_PARTMODE
cls
echo ================================================================================================
echo                                  SELECT PARTITIONING MODE
echo ================================================================================================
echo.
echo   [A] Automatic (Wipe Entire Disk !CFG_DISK!, Create Clean UEFI Layout) [RECOMMENDED]
echo   [M] Guided Partition Manager (Create, Shrink, Format or Select Partitions - Dual Boot)
echo ================================================================================================
set "PM_CHOICE="
set /p PM_CHOICE="Choose [A/M, default A]: "
if /i "!PM_CHOICE!"=="M" (
    set "CFG_PARTMODE=MANUAL"
    goto :PARTITION_MANAGER
) else (
    set "CFG_PARTMODE=AUTO"
    set "CFG_TARGET_VOL="
    set "CFG_TARGET_VOL_DESC=Disk !CFG_DISK! (Auto-Wipe)"
    set "CFG_ESP_VOL=AUTO"
    set "CFG_ESP_DESC=Auto-Created (100MB FAT32 ESP)"
    set "CFG_FORMAT_TARGET=YES"
)
goto :MAIN_MENU

:TOGGLE_FORMAT
if "!CFG_FORMAT_TARGET!"=="YES" (
    set "CFG_FORMAT_TARGET=NO"
) else (
    set "CFG_FORMAT_TARGET=YES"
)
goto :MAIN_MENU

:TOGGLE_COMPACT
if "!CFG_COMPACT!"=="YES" (
    set "CFG_COMPACT=NO"
) else (
    set "CFG_COMPACT=YES"
)
goto :MAIN_MENU

:TOGGLE_FOOTPRINT
if "!CFG_FOOTPRINT!"=="YES" (
    set "CFG_FOOTPRINT=NO"
) else (
    set "CFG_FOOTPRINT=YES"
)
goto :MAIN_MENU

:SET_HOSTNAME
cls
echo ================================================================================================
echo                                     SET COMPUTER NAME
echo ================================================================================================
echo.
set /p NEW_HOST="Enter Computer Name / Hostname [default !CFG_HOSTNAME!]: "
if defined NEW_HOST set "CFG_HOSTNAME=!NEW_HOST!"
goto :MAIN_MENU

:SET_USERACCOUNT
cls
echo ================================================================================================
echo                                     USER ACCOUNT SETUP
echo ================================================================================================
echo.
set /p NEW_USER="Enter Username [default !CFG_USERNAME!]: "
if defined NEW_USER set "CFG_USERNAME=!NEW_USER!"
set /p NEW_PASS="Enter Password (leave empty for blank/auto-logon): "
set "CFG_PASSWORD=!NEW_PASS!"
goto :MAIN_MENU

:REFRESH_MEDIA
echo [*] Re-scanning disks and media...
goto :SCAN_DRIVES

:CMD_SHELL
echo Dropping to WinPE Command Prompt...
cmd.exe
goto :MAIN_MENU

:: -------------------------------------------------------------------------------------------------
:: GUIDED PARTITION MANAGER (NO COMMANDS REQUIRED, CLEAN INTERFACE)
:: -------------------------------------------------------------------------------------------------

:PARTITION_MANAGER
cls
echo ================================================================================================
echo                            WINAUREX GUIDED PARTITION MANAGER
echo ================================================================================================
echo  Target Disk: Disk !CFG_DISK!  ^|  Target OS: !CFG_TARGET_VOL_DESC!  ^|  ESP: !CFG_ESP_DESC!
echo ------------------------------------------------------------------------------------------------
echo  CURRENT STORAGE OVERVIEW:
set "DP_INFO=%TEMP%\dp_info.txt"
(
echo list disk
echo select disk !CFG_DISK!
echo list partition
echo list volume
) > "%DP_INFO%"
diskpart /s "%DP_INFO%" | find /v /i "Microsoft DiskPart" | find /v /i "Copyright" | find /v /i "On computer" | find /v /i "is now the selected disk"
del "%DP_INFO%" >nul 2>&1
echo ------------------------------------------------------------------------------------------------
echo  GUIDED PARTITIONING ACTIONS:
echo   [1] Select Active Disk (Current: Disk !CFG_DISK!)
echo   [2] Create New Partition (Primary OS Partition or EFI Boot Partition)
echo   [3] Delete a Partition (Safely removes a partition to free space)
echo   [4] Shrink a Partition (Frees space from an existing partition for WinAurex)
echo   [5] Quick Format a Partition (Formats NTFS or FAT32)
echo   [6] Assign Partition as Target OS (Assigns W: for WinAurex installation)
echo   [7] Assign Partition as EFI Bootloader (Assigns S: for UEFI boot files)
echo   [8] Initialize / Clean Disk as GPT (Wipes active disk and initializes GPT)
echo   [B] Back to Main Installer Menu
echo ================================================================================================
set "PM_ACT="
set /p PM_ACT="Select action [1-8, B] (default B): "
if not defined PM_ACT goto :MAIN_MENU
if /i "!PM_ACT!"=="B" goto :MAIN_MENU

if "!PM_ACT!"=="1" goto :PM_SELECT_DISK
if "!PM_ACT!"=="2" goto :PM_CREATE_PART
if "!PM_ACT!"=="3" goto :PM_DELETE_PART
if "!PM_ACT!"=="4" goto :PM_SHRINK_PART
if "!PM_ACT!"=="5" goto :PM_FORMAT_PART
if "!PM_ACT!"=="6" goto :PM_ASSIGN_OS
if "!PM_ACT!"=="7" goto :PM_ASSIGN_ESP
if "!PM_ACT!"=="8" goto :PM_WIPE_DISK

goto :PARTITION_MANAGER

:PM_SELECT_DISK
cls
echo ================================================================================================
echo                                 SELECT ACTIVE DISK (CURRENT: DISK !CFG_DISK!)
echo ================================================================================================
echo.
set "DP_TMP=%TEMP%\dp_sel_d.txt"
echo list disk > "%DP_TMP%"
diskpart /s "%DP_TMP%" | find /v /i "Microsoft DiskPart" | find /v /i "Copyright" | find /v /i "On computer"
del "%DP_TMP%" >nul 2>&1
echo.
set /p NEW_DISK="Enter Disk Number [default !CFG_DISK!]: "
if defined NEW_DISK (
    set "CFG_DISK=!NEW_DISK!"
    echo [+] Target Disk changed to Disk !CFG_DISK!
)
pause
goto :PARTITION_MANAGER

:PM_CREATE_PART
cls
echo ================================================================================================
echo                               CREATE NEW PARTITION ON DISK !CFG_DISK!
echo ================================================================================================
set "DP_TMP=%TEMP%\dp_cr_part.txt"
(
echo select disk !CFG_DISK!
echo list partition
) > "%DP_TMP%"
diskpart /s "%DP_TMP%" | find /v /i "Microsoft DiskPart" | find /v /i "Copyright" | find /v /i "On computer" | find /v /i "is now the selected disk"
del "%DP_TMP%" >nul 2>&1
echo.
echo Select Partition Type:
echo   [1] WinAurex OS Primary Partition (NTFS - for Operating System) [RECOMMENDED]
echo   [2] EFI System Partition (FAT32 - 100MB for UEFI bootloader)
echo   [3] Microsoft Reserved Partition (MSR - 16MB)
echo   [C] Cancel
set "CP_TYPE=1"
set /p CP_TYPE="Choose partition type [1-3, C, default 1]: "
if /i "!CP_TYPE!"=="C" goto :PARTITION_MANAGER

set "DP_ACT=%TEMP%\dp_act.txt"
if "!CP_TYPE!"=="1" (
    echo.
    echo Enter partition size in Megabytes (e.g. 64000 for 64 GB, 120000 for 120 GB)
    echo Press ENTER with no input to use ALL remaining unallocated space:
    set "CP_SIZE="
    set /p CP_SIZE="Size in MB: "
    if defined CP_SIZE (
        (
        echo select disk !CFG_DISK!
        echo create partition primary size=!CP_SIZE!
        echo format quick fs=ntfs label="WinAurex"
        echo assign letter=W
        ) > "%DP_ACT%"
    ) else (
        (
        echo select disk !CFG_DISK!
        echo create partition primary
        echo format quick fs=ntfs label="WinAurex"
        echo assign letter=W
        ) > "%DP_ACT%"
    )
    echo [*] Creating and formatting WinAurex OS Primary partition...
    diskpart /s "%DP_ACT%" >nul 2>&1
    del "%DP_ACT%" >nul 2>&1
    set "CFG_PARTMODE=MANUAL"
    set "CFG_TARGET_VOL=W"
    set "CFG_TARGET_VOL_DESC=Partition W: (WinAurex OS)"
    set "CFG_FORMAT_TARGET=NO"
    echo [+] WinAurex OS partition created, formatted as NTFS, and mapped to W:!
)

if "!CP_TYPE!"=="2" (
    set "EFI_SIZE=100"
    set /p EFI_SIZE="Enter EFI Partition Size in MB [default 100]: "
    (
    echo select disk !CFG_DISK!
    echo create partition efi size=!EFI_SIZE!
    echo format quick fs=fat32 label="System"
    echo assign letter=S
    ) > "%DP_ACT%"
    echo [*] Creating and formatting EFI System Partition...
    diskpart /s "%DP_ACT%" >nul 2>&1
    del "%DP_ACT%" >nul 2>&1
    set "CFG_ESP_VOL=S"
    set "CFG_ESP_DESC=Partition S: (ESP)"
    echo [+] EFI System Partition created, formatted as FAT32, and mapped to S:!
)

if "!CP_TYPE!"=="3" (
    (
    echo select disk !CFG_DISK!
    echo create partition msr size=16
    ) > "%DP_ACT%"
    diskpart /s "%DP_ACT%" >nul 2>&1
    del "%DP_ACT%" >nul 2>&1
    echo [+] 16MB MSR Partition created.
)
pause
goto :PARTITION_MANAGER

:PM_DELETE_PART
cls
echo ================================================================================================
echo                                DELETE A PARTITION ON DISK !CFG_DISK!
echo ================================================================================================
set "DP_TMP=%TEMP%\dp_del_ls.txt"
(
echo select disk !CFG_DISK!
echo list partition
) > "%DP_TMP%"
diskpart /s "%DP_TMP%" | find /v /i "Microsoft DiskPart" | find /v /i "Copyright" | find /v /i "On computer" | find /v /i "is now the selected disk"
del "%DP_TMP%" >nul 2>&1
echo.
set "DEL_PART="
set /p DEL_PART="Enter Partition Number to DELETE (or C to Cancel): "
if not defined DEL_PART goto :PARTITION_MANAGER
if /i "!DEL_PART!"=="C" goto :PARTITION_MANAGER

echo.
color 4F
echo WARNING: This will PERMANENTLY ERASE Partition !DEL_PART! and all data on it!
set "CONFIRM_DEL="
set /p CONFIRM_DEL="Type 'YES' to permanently delete Partition !DEL_PART!: "
color 1F
if /i "!CONFIRM_DEL!"=="YES" (
    set "DP_ACT=%TEMP%\dp_act.txt"
    (
    echo select disk !CFG_DISK!
    echo select partition !DEL_PART!
    echo delete partition override
    ) > "%DP_ACT%"
    diskpart /s "%DP_ACT%" >nul 2>&1
    del "%DP_ACT%" >nul 2>&1
    echo [+] Partition !DEL_PART! deleted successfully!
) else (
    echo [-] Deletion cancelled.
)
pause
goto :PARTITION_MANAGER

:PM_SHRINK_PART
cls
echo ================================================================================================
echo                    SHRINK A PARTITION ON DISK !CFG_DISK! (Free space for Dual-Boot)
echo ================================================================================================
set "DP_TMP=%TEMP%\dp_sh_ls.txt"
(
echo select disk !CFG_DISK!
echo list partition
) > "%DP_TMP%"
diskpart /s "%DP_TMP%" | find /v /i "Microsoft DiskPart" | find /v /i "Copyright" | find /v /i "On computer" | find /v /i "is now the selected disk"
del "%DP_TMP%" >nul 2>&1
echo.
set "SHRINK_PART="
set /p SHRINK_PART="Enter Partition Number to SHRINK (or C to Cancel): "
if not defined SHRINK_PART goto :PARTITION_MANAGER
if /i "!SHRINK_PART!"=="C" goto :PARTITION_MANAGER

echo.
echo Enter the amount of space to shrink in Megabytes.
echo (Examples: 30000 = 30 GB, 50000 = 50 GB, 100000 = 100 GB)
set "SHRINK_MB="
set /p SHRINK_MB="Amount to shrink (MB): "
if defined SHRINK_MB (
    set "DP_ACT=%TEMP%\dp_act.txt"
    (
    echo select disk !CFG_DISK!
    echo select partition !SHRINK_PART!
    echo shrink desired=!SHRINK_MB!
    ) > "%DP_ACT%"
    echo [*] Shrinking partition !SHRINK_PART!...
    diskpart /s "%DP_ACT%" >nul 2>&1
    del "%DP_ACT%" >nul 2>&1
    echo [+] Partition !SHRINK_PART! shrunk. Unallocated space is now available!
)
pause
goto :PARTITION_MANAGER

:PM_FORMAT_PART
cls
echo ================================================================================================
echo                                    QUICK FORMAT A PARTITION
echo ================================================================================================
set "DP_TMP=%TEMP%\dp_fmt_ls.txt"
echo list volume > "%DP_TMP%"
diskpart /s "%DP_TMP%" | find /v /i "Microsoft DiskPart" | find /v /i "Copyright" | find /v /i "On computer"
del "%DP_TMP%" >nul 2>&1
echo.
set "FMT_VOL="
set /p FMT_VOL="Enter Volume Number or Drive Letter to format (or C to cancel): "
if not defined FMT_VOL goto :PARTITION_MANAGER
if /i "!FMT_VOL!"=="C" goto :PARTITION_MANAGER

echo.
echo Select Filesystem:
echo   [1] NTFS  (Standard for Windows OS / Data partitions)
echo   [2] FAT32 (Standard for EFI System Partition)
set "FS_CHOICE=1"
set /p FS_CHOICE="Choose [1-2, default 1]: "
set "FS_NAME=ntfs"
if "!FS_CHOICE!"=="2" set "FS_NAME=fat32"

set "FMT_LABEL=WinAurex"
set /p FMT_LABEL="Enter Volume Label [default WinAurex]: "

echo.
color 4F
echo WARNING: All data on Volume !FMT_VOL! will be completely erased!
set "CONFIRM_FMT="
set /p CONFIRM_FMT="Confirm quick format? [Y/N, default N]: "
color 1F
if /i "!CONFIRM_FMT!"=="Y" (
    set "DP_ACT=%TEMP%\dp_act.txt"
    (
    echo select volume !FMT_VOL!
    echo format quick fs=!FS_NAME! label="!FMT_LABEL!"
    ) > "%DP_ACT%"
    diskpart /s "%DP_ACT%" >nul 2>&1
    del "%DP_ACT%" >nul 2>&1
    echo [+] Volume !FMT_VOL! formatted as !FS_NAME! successfully!
) else (
    echo [-] Formatting cancelled.
)
pause
goto :PARTITION_MANAGER

:PM_ASSIGN_OS
cls
echo ================================================================================================
echo                               ASSIGN TARGET OS PARTITION (W:)
echo ================================================================================================
set "DP_TMP=%TEMP%\dp_os_ls.txt"
echo list volume > "%DP_TMP%"
diskpart /s "%DP_TMP%" | find /v /i "Microsoft DiskPart" | find /v /i "Copyright" | find /v /i "On computer"
del "%DP_TMP%" >nul 2>&1
echo.
set "SEL_OS_VOL="
set /p SEL_OS_VOL="Enter Volume Number or Letter for WinAurex OS (or C to cancel): "
if not defined SEL_OS_VOL goto :PARTITION_MANAGER
if /i "!SEL_OS_VOL!"=="C" goto :PARTITION_MANAGER

set "DP_ACT=%TEMP%\dp_act.txt"
(
echo select volume !SEL_OS_VOL!
echo assign letter=W
) > "%DP_ACT%"
diskpart /s "%DP_ACT%" >nul 2>&1
del "%DP_ACT%" >nul 2>&1

set "CFG_PARTMODE=MANUAL"
set "CFG_TARGET_VOL=!SEL_OS_VOL!"
set "CFG_TARGET_VOL_DESC=Volume !SEL_OS_VOL! (W:)"

echo.
set "FMT_Q=Y"
set /p FMT_Q="Quick format this partition as NTFS during deployment? [Y/N, default Y]: "
if /i "!FMT_Q!"=="N" (
    set "CFG_FORMAT_TARGET=NO"
) else (
    set "CFG_FORMAT_TARGET=YES"
)
echo [+] Target OS set to Volume !SEL_OS_VOL! (mapped to W:)
pause
goto :PARTITION_MANAGER

:PM_ASSIGN_ESP
cls
echo ================================================================================================
echo                          ASSIGN EFI SYSTEM BOOTLOADER PARTITION (S:)
echo ================================================================================================
set "DP_TMP=%TEMP%\dp_esp_ls.txt"
echo list volume > "%DP_TMP%"
diskpart /s "%DP_TMP%" | find /v /i "Microsoft DiskPart" | find /v /i "Copyright" | find /v /i "On computer"
del "%DP_TMP%" >nul 2>&1
echo.
set "SEL_ESP_VOL="
set /p SEL_ESP_VOL="Enter Volume Number or Letter for EFI Bootloader (or C to cancel): "
if not defined SEL_ESP_VOL goto :PARTITION_MANAGER
if /i "!SEL_ESP_VOL!"=="C" goto :PARTITION_MANAGER

set "DP_ACT=%TEMP%\dp_act.txt"
(
echo select volume !SEL_ESP_VOL!
echo assign letter=S
) > "%DP_ACT%"
diskpart /s "%DP_ACT%" >nul 2>&1
del "%DP_ACT%" >nul 2>&1

set "CFG_ESP_VOL=!SEL_ESP_VOL!"
set "CFG_ESP_DESC=Volume !SEL_ESP_VOL! (S:)"
echo [+] EFI Bootloader partition set to Volume !SEL_ESP_VOL! (mapped to S:)
pause
goto :PARTITION_MANAGER

:PM_WIPE_DISK
cls
echo ================================================================================================
echo                           INITIALIZE / WIPE DISK !CFG_DISK! TO GPT
echo ================================================================================================
color 4F
echo WARNING: This will completely WIPE ALL PARTITIONS AND DATA on Disk !CFG_DISK!
echo The disk will be cleaned and converted to GPT partition table.
echo.
set "CONFIRM_WIPE="
set /p CONFIRM_WIPE="Type 'YES' to proceed with wiping Disk !CFG_DISK!: "
color 1F
if /i "!CONFIRM_WIPE!"=="YES" (
    set "DP_ACT=%TEMP%\dp_act.txt"
    (
    echo select disk !CFG_DISK!
    echo clean
    echo convert gpt
    ) > "%DP_ACT%"
    echo [*] Cleaning and converting Disk !CFG_DISK!...
    diskpart /s "%DP_ACT%" >nul 2>&1
    del "%DP_ACT%" >nul 2>&1
    echo [+] Disk !CFG_DISK! wiped clean and initialized as GPT!
) else (
    echo [-] Disk wipe cancelled.
)
pause
goto :PARTITION_MANAGER

:: -------------------------------------------------------------------------------------------------
:: INSTALLATION CONFIRMATION & EXECUTION
:: -------------------------------------------------------------------------------------------------

:CONFIRM_INSTALL
cls
echo ================================================================================================
echo                                  INSTALLATION CONFIRMATION
echo ================================================================================================
echo.
echo Review your configuration before proceeding:
echo.

set "CONFIRM_PART_MODE=AUTOMATIC (WIPE ENTIRE DISK !CFG_DISK!)"
set "CONFIRM_WARN=WARNING: ALL EXISTING DATA ON DISK !CFG_DISK! WILL BE PERMANENTLY ERASED!"
set "CONFIRM_TARGET=W:\ (100%% of remaining disk space)"
set "CONFIRM_ESP=S:\ (100MB FAT32 ESP)"
set "CONFIRM_FORMAT=YES (Full Disk Initialized as GPT)"

if "!CFG_PARTMODE!"=="MANUAL" (
    set "CONFIRM_PART_MODE=MANUAL (EXISTING PARTITIONS PRESERVED - DUAL BOOT)"
    set "CONFIRM_WARN=Only target partition will be modified; all other partitions preserved."
    set "CONFIRM_TARGET=W:\ (!CFG_TARGET_VOL_DESC!)"
    set "CONFIRM_ESP=S:\ (!CFG_ESP_DESC!)"
    set "CONFIRM_FORMAT=[!CFG_FORMAT_TARGET!] (Quick NTFS Format)"
)

echo   * Partitioning Mode   : !CONFIRM_PART_MODE!
echo   * Partition Safety    : !CONFIRM_WARN!
echo   * Target Drive (OS)   : !CONFIRM_TARGET!
echo   * Format OS Target    : !CONFIRM_FORMAT!
echo   * EFI Bootloader      : !CONFIRM_ESP!
echo   * CompactOS Enabled   : !CFG_COMPACT!
echo   * Footprint Opt       : !CFG_FOOTPRINT!
echo   * Computer Name       : !CFG_HOSTNAME!
echo   * Primary User        : !CFG_USERNAME!
echo.
echo ================================================================================================
echo Type 'YES' to write changes and install WinAurex, or press Enter to return to menu:
set "CONFIRM="
set /p CONFIRM="Confirm installation: "
if /i not "!CONFIRM!"=="YES" goto :MAIN_MENU

:: -------------------------------------------------------------------------------------------------
:: DEPLOYMENT EXECUTION PIPELINE
:: -------------------------------------------------------------------------------------------------

cls
echo ================================================================================================
echo                         WINAUREX DEPLOYMENT IN PROGRESS
echo ================================================================================================
echo.
echo [*] Source Image: !INSTALL_WIM!
echo.

if "!CFG_PARTMODE!"=="AUTO" (
    echo [1/5] Partitioning and formatting Disk !CFG_DISK! (UEFI / GPT layout)...
    set "DP_SCRIPT=%TEMP%\diskpart_winaurex.txt"
    (
    echo select disk !CFG_DISK!
    echo clean
    echo convert gpt
    echo create partition efi size=100
    echo format quick fs=fat32 label="System"
    echo assign letter=S
    echo create partition msr size=16
    echo create partition primary
    echo format quick fs=ntfs label="WinAurex"
    echo assign letter=W
    ) > "%DP_SCRIPT%"
    diskpart /s "%DP_SCRIPT%" >nul 2>&1
    del "%DP_SCRIPT%" >nul 2>&1

    if not exist W:\ (
        echo [*] Retrying volume letter assignment...
        (
        echo select disk !CFG_DISK!
        echo select partition 3
        echo assign letter=W
        echo select partition 1
        echo assign letter=S
        ) > "%DP_SCRIPT%"
        diskpart /s "%DP_SCRIPT%" >nul 2>&1
        del "%DP_SCRIPT%" >nul 2>&1
    )
) else (
    echo [1/5] Configuring Target Partition for Manual Deployment...
    :: If target volume assignment wasn't locked to W:, re-assign now
    if not exist W:\ (
        if defined CFG_TARGET_VOL (
            (
            echo select volume !CFG_TARGET_VOL!
            echo assign letter=W
            ) | diskpart >nul 2>&1
        )
    )
    if "!CFG_FORMAT_TARGET!"=="YES" (
        echo [*] Formatting target partition W: as NTFS...
        (
        echo select volume W
        echo format quick fs=ntfs label="WinAurex"
        ) | diskpart >nul 2>&1
    )
    :: Ensure S: is mounted for EFI System Partition
    if not exist S:\ (
        if not "!CFG_ESP_VOL!"=="AUTO" (
            (
            echo select volume !CFG_ESP_VOL!
            echo assign letter=S
            ) | diskpart >nul 2>&1
        )
    )
)

if not exist W:\ (
    color 4F
    echo [-] ERROR: Target partition W: is not accessible!
    cmd.exe
    exit /b 1
)

echo [+] Target disk ready: S: (EFI System), W: (WinAurex OS)
echo.

:: Apply Image via DISM with or without CompactOS
if "!CFG_COMPACT!"=="YES" (
    echo [2/5] Applying WinAurex OS Image via DISM with CompactOS (~2 minutes)...
    echo.
    dism /Apply-Image /ImageFile:"!INSTALL_WIM!" /Index:1 /ApplyDir:W:\ /Compact
    compact.exe /CompactOS:always >nul 2>&1
) else (
    echo [2/5] Applying WinAurex OS Image via DISM (~2 minutes)...
    echo.
    dism /Apply-Image /ImageFile:"!INSTALL_WIM!" /Index:1 /ApplyDir:W:\
)

if %ERRORLEVEL% neq 0 (
    color 4F
    echo.
    echo [-] ERROR: DISM Apply-Image failed with exit code %ERRORLEVEL%!
    echo Dropping to Command Prompt for diagnostics...
    cmd.exe
    exit /b 1
)

echo.
echo [+] OS image applied successfully!
echo.

:: Configure UEFI Bootloader
echo [3/5] Configuring UEFI Bootloader...
if not exist S:\ (
    echo [*] Searching for EFI System Partition...
    set "DP_FIND_ESP=%TEMP%\dp_esp.txt"
    (
    echo select disk !CFG_DISK!
    echo select partition 1
    echo assign letter=S
    ) > "%DP_FIND_ESP%"
    diskpart /s "%DP_FIND_ESP%" >nul 2>&1
    del "%DP_FIND_ESP%" >nul 2>&1
)

if exist W:\Windows\System32\bcdboot.exe (
    W:\Windows\System32\bcdboot.exe W:\Windows /s S: /f UEFI
) else (
    bcdboot W:\Windows /s S: /f UEFI
)
echo [+] UEFI Bootloader configured on EFI System Partition (S:)
echo.

:: Inject Sysprep, Unattended Setup and Post Install
echo [4/5] Injecting Configuration, Bypasses and Post-Install Suite...
if not exist W:\Windows\Panther mkdir W:\Windows\Panther
if not exist W:\Windows\System32\Sysprep mkdir W:\Windows\System32\Sysprep

if exist "!INSTALL_DRIVE!\sources\autounattend.xml" (
    copy /y "!INSTALL_DRIVE!\sources\autounattend.xml" W:\Windows\Panther\unattend.xml >nul
    copy /y "!INSTALL_DRIVE!\sources\autounattend.xml" W:\Windows\System32\Sysprep\unattend.xml >nul
    echo [+] Unattended answer file staged
) else if exist "!INSTALL_DRIVE!\autounattend.xml" (
    copy /y "!INSTALL_DRIVE!\autounattend.xml" W:\Windows\Panther\unattend.xml >nul
    copy /y "!INSTALL_DRIVE!\autounattend.xml" W:\Windows\System32\Sysprep\unattend.xml >nul
    echo [+] Unattended answer file staged
)

:: Pre-stage Post Install folder to Public Desktop
if exist "!INSTALL_DRIVE!\Post Install" (
    if not exist "W:\Users\Public\Desktop\Post Install" mkdir "W:\Users\Public\Desktop\Post Install"
    robocopy "!INSTALL_DRIVE!\Post Install" "W:\Users\Public\Desktop\Post Install" /E /NJH /NJS /NDL /NC /NS >nul
    echo [+] 'Post Install' application suite staged to Desktop
)

:: Purge SecHealthUI and Windows Defender from applied target
for /d %%D in ("W:\Program Files\WindowsApps\*SecHealthUI*") do (
    takeown /f "%%~D" /r /d y >nul 2>&1
    icacls "%%~D" /grant administrators:F /t /c /q >nul 2>&1
    rd /s /q "%%~D" >nul 2>&1
)
for /d %%D in ("W:\Windows\SystemApps\*SecHealthUI*") do (
    takeown /f "%%~D" /r /d y >nul 2>&1
    icacls "%%~D" /grant administrators:F /t /c /q >nul 2>&1
    rd /s /q "%%~D" >nul 2>&1
)
if exist "W:\Windows\System32\SecurityHealth" (
    takeown /f "W:\Windows\System32\SecurityHealth" /r /d y >nul 2>&1
    icacls "W:\Windows\System32\SecurityHealth" /grant administrators:F /t /c /q >nul 2>&1
    rd /s /q "W:\Windows\System32\SecurityHealth" >nul 2>&1
)
for %%B in (SecurityHealthSystray.exe SecurityHealthHost.exe SecurityHealthService.exe smartscreen.exe) do (
    if exist "W:\Windows\System32\%%B" (
        takeown /f "W:\Windows\System32\%%B" /a >nul 2>&1
        icacls "W:\Windows\System32\%%B" /grant administrators:F /c /q >nul 2>&1
        del /f /q "W:\Windows\System32\%%B" >nul 2>&1
    )
)
for %%P in (
    "W:\Program Files\Windows Defender"
    "W:\Program Files (x86)\Windows Defender"
    "W:\ProgramData\Microsoft\Windows Defender"
    "W:\ProgramData\Microsoft\Windows Security Health"
) do (
    if exist "%%~P" (
        takeown /f "%%~P" /r /d y >nul 2>&1
        icacls "%%~P" /grant administrators:F /t /c /q >nul 2>&1
        rd /s /q "%%~P" >nul 2>&1
    )
)

:: Inject target registry customizations
reg load HKLM\wSYSTEM W:\Windows\System32\config\SYSTEM >nul 2>&1
reg add "HKLM\wSYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSYSTEM\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSYSTEM\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSYSTEM\Setup\LabConfig" /v BypassStorageCheck /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSYSTEM\Setup\LabConfig" /v BypassDiskCheck /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSYSTEM\Setup\MoSetup" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSYSTEM\ControlSet001\Control\BitLocker" /v PreventDeviceEncryption /t REG_DWORD /d 1 /f >nul 2>&1

:: Set Computer Name / Hostname
reg add "HKLM\wSYSTEM\ControlSet001\Control\ComputerName\ComputerName" /v ComputerName /t REG_SZ /d "!CFG_HOSTNAME!" /f >nul 2>&1
reg add "HKLM\wSYSTEM\ControlSet001\Control\ComputerName\ActiveComputerName" /v ComputerName /t REG_SZ /d "!CFG_HOSTNAME!" /f >nul 2>&1
reg add "HKLM\wSYSTEM\ControlSet001\Services\Tcpip\Parameters" /v "NV Hostname" /t REG_SZ /d "!CFG_HOSTNAME!" /f >nul 2>&1
reg add "HKLM\wSYSTEM\ControlSet001\Services\Tcpip\Parameters" /v Hostname /t REG_SZ /d "!CFG_HOSTNAME!" /f >nul 2>&1

:: Disable non-essential, telemetry, Defender & security services and filter drivers
for %%S in (
    DoSvc PcaSvc TrkWks PhoneSvc SensorService SensrSvc SensorDataService wisvc RetailDemo
    DiagTrack dmwappushservice diagnosticshub.standardcollector.service WerSvc MapsBroker lfsvc WbioSrvc
    wuauserv UsoSvc WaaSMedicSvc WinDefend WdNisSvc Sense SecurityHealthService wscsvc WdBoot WdFilter WdNisDrv WSearch SysMain
) do (
    reg add "HKLM\wSYSTEM\ControlSet001\Services\%%S" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
)

if "!CFG_FOOTPRINT!"=="YES" (
    reg add "HKLM\wSYSTEM\ControlSet001\Control\Power" /v HibernateEnabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\wSYSTEM\ControlSet001\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "C:\pagefile.sys 1024 2048" /f >nul 2>&1
)
reg unload HKLM\wSYSTEM >nul 2>&1

reg load HKLM\wSOFTWARE W:\Windows\System32\config\SOFTWARE >nul 2>&1
reg add "HKLM\wSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f >nul 2>&1

:: Eradicate Startup Run key for SecurityHealthSystray & Neutralize windowsdefender protocol
reg delete "HKLM\wSOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v SecurityHealth /f >nul 2>&1
reg delete "HKLM\wSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v SecurityHealth /f >nul 2>&1
reg delete "HKLM\wSOFTWARE\Classes\windowsdefender" /f >nul 2>&1

:: Settings Page Visibility: Completely Hide Home, Accounts & Privacy from Sidebar
set "SETTINGS_HIDE=hide:home;account;yourinfo;emailandaccounts;signinoptions;otherusers;workplace;backup;windowsdefender;deviceencryption;findmydevice;privacy;privacy-general;privacy-speech;privacy-speechtyping;privacy-feedback;privacy-activityhistory;privacy-location;privacy-webcam;privacy-camera;privacy-microphone;privacy-notifications;privacy-accountinfo;privacy-contacts;privacy-calendar;privacy-phonecalls;privacy-callhistory;privacy-messaging;privacy-email;privacy-tasks;privacy-documents;privacy-downloadsfolder;privacy-pictures;privacy-videos;privacy-broadfilesystemaccess;privacy-automaticfiledownloads;privacy-radios;privacy-customdevices;privacy-motion;privacy-eyetracker;privacy-backgroundspatialperception;privacy-backgroundapps;privacy-appdiagnostics;cortana-windowssearch"
reg add "HKLM\wSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v SettingsPageVisibility /t REG_SZ /d "%SETTINGS_HIDE%" /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoOnlineAccount /t REG_DWORD /d 1 /f >nul 2>&1

:: Eradicate Microsoft Account Promo Banner & Microsoft 365 Badges in Settings
reg add "HKLM\wSOFTWARE\Microsoft\PolicyManager\default\Settings\AllowYourAccount" /v Value /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v NoConnectedUser /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\MicrosoftAccount" /v DisableUserAuth /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableConsumerAccountStateContent /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableCloudOptimizedContent /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f >nul 2>&1

if "!CFG_FOOTPRINT!"=="YES" (
    reg add "HKLM\wSOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" /v ShippedWithReserves /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\wSOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" /v BaseReservationManager /t REG_DWORD /d 0 /f >nul 2>&1
)

:: Annihilate Windows Defender Security Center UI
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" /v HideSystray /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiVirus /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableScanOnRealtimeEnable /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableIOAVProtection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\System" /v EnableSmartScreen /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v SmartScreenEnabled /t REG_SZ /d "Off" /f >nul 2>&1
for %%C in (
    "Account protection" "App and browser protection" "Device performance and health"
    "Device security" "Family options" "Firewall and network protection" "Virus and threat protection"
) do (
    reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows Defender Security Center\%%~C" /v UILockdown /t REG_DWORD /d 1 /f >nul 2>&1
)
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSync /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSyncUserOverride /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\PassportForWork" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\PassportForWork" /v DisablePostLogonProvisioning /t REG_DWORD /d 1 /f >nul 2>&1

:: Privacy, Advertising & Recommendations Annihilation
reg add "HKLM\wSOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableConsumerAccountStateContent /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\DataCollection" /v MaxTelemetryAllowed /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DoNotShowFeedbackNotifications /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCloudSearch /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\Windows Search" /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wSOFTWARE\Policies\Microsoft\Windows\Windows Search" /v DisableWebSearch /t REG_DWORD /d 1 /f >nul 2>&1
reg unload HKLM\wSOFTWARE >nul 2>&1

reg load HKLM\wNTUSER W:\Users\Default\ntuser.dat >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v SettingsPageVisibility /t REG_SZ /d "%SETTINGS_HIDE%" /f >nul 2>&1
reg add "HKLM\wNTUSER\Control Panel\International\User Profile" /v HttpAcceptLanguageOptOut /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353698Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\wNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 0 /f >nul 2>&1
reg unload HKLM\wNTUSER >nul 2>&1

echo [+] Configuration, bypasses and debloat policies injected successfully!
echo.
echo ================================================================================================
echo [5/5] INSTALLATION COMPLETE! Press any key to reboot immediately...
echo ================================================================================================
echo.
choice /C R /T 10 /D R /N /M "Rebooting into WinAurex in 10 seconds (press R to reboot immediately)..."
wpeutil reboot
exit /b 0
