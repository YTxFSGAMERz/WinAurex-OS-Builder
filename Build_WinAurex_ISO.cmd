@echo off
title WinAurex One-Click ISO Compiler
setlocal enabledelayedexpansion

:: Check Admin Rights
IF "%PROCESSOR_ARCHITECTURE%" EQU "amd64" (
    >nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) ELSE (
    >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)

if '%errorlevel%' NEQ '0' (
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\getadmin.vbs"
    cscript //nologo "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B
)

pushd "%CD%"
CD /D "%~dp0"

cls
echo ======================================================================
echo                  WinAurex One-Click ISO Compiler
echo ======================================================================
echo.

set "DEFAULT_ISO=C:\Users\Admin\Downloads\Windows11_Client_x64_en-us_26300_9457.iso"
set "SOURCE_ISO="

if exist "!DEFAULT_ISO!" (
    echo Found base Windows 11 ISO:
    echo [!DEFAULT_ISO!]
    echo.
    set "SOURCE_ISO=!DEFAULT_ISO!"
) else (
    echo [!] Default ISO not found. Searching Downloads for .iso files...
    for %%f in ("%USERPROFILE%\Downloads\*.iso") do (
        set "SOURCE_ISO=%%f"
        goto :iso_found
    )
)

:iso_found
if not defined SOURCE_ISO (
    echo [ERROR] No Windows 11 ISO file found in Downloads!
    echo Please place your Windows 11 ISO in Downloads and try again.
    pause
    exit /b
)

echo [*] Target ISO: !SOURCE_ISO!
echo.
echo Press any key to mount image and begin compiling WinAurex.iso...
pause >nul

echo.
echo [*] Mounting base ISO image...
for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "(Mount-DiskImage -ImagePath '!SOURCE_ISO!' -PassThru | Get-Volume).DriveLetter"`) do (
    set "DRIVE=%%i"
)

if not defined DRIVE (
    echo [ERROR] Failed to mount ISO image.
    pause
    exit /b
)

echo [+] Mounted successfully to drive [!DRIVE!:]
echo.
echo [*] Starting WinAurexMaker build engine...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinAurexMaker.ps1" -ISO !DRIVE! -SCRATCH C

echo.
echo [*] Dismounting source ISO...
powershell.exe -NoProfile -Command "Dismount-DiskImage -ImagePath '!SOURCE_ISO!'" >nul 2>&1

echo.
echo ======================================================================
echo [SUCCESS] Build process complete!
echo Look for WinAurex.iso on drive C:\ or in %~dp0
echo ======================================================================
pause
