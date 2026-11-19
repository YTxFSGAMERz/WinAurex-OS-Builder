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
echo                       https://www.winaurex.tech
echo ======================================================================
echo.
echo Select Target OS Build Profile:
echo  [1] Stable Workstation (Recommended) - WU + WinGet + Drivers 100%% Working
echo  [2] Performance ^& Gaming             - WinGet Working, Drivers Intact, WU Disabled
echo  [3] Core Ultra-Lite                  - Extreme Debloat for Low-Spec VMs ^& Rigs
echo.
set /p PROFILE_CHOICE="Enter profile choice [1-3] (Default: 1): "
if "%PROFILE_CHOICE%"=="" set PROFILE_CHOICE=1
if "%PROFILE_CHOICE%"=="1" set PROFILE_NAME=Stable
if "%PROFILE_CHOICE%"=="2" set PROFILE_NAME=Moderate
if "%PROFILE_CHOICE%"=="3" set PROFILE_NAME=Extreme

echo.
echo [*] Selected Profile: !PROFILE_NAME!
echo.

set "SOURCE_ISO=%~1"

if defined SOURCE_ISO (
    if exist "!SOURCE_ISO!" goto :iso_ready
)

:: Search current folder for .iso
for %%f in ("%~dp0*.iso") do (
    set "SOURCE_ISO=%%f"
    goto :iso_ready
)

:: Search Downloads folder for .iso
for %%f in ("%USERPROFILE%\Downloads\*.iso") do (
    set "SOURCE_ISO=%%f"
    goto :iso_ready
)

:iso_ready
if not defined SOURCE_ISO (
    echo [*] No .iso file automatically found in script directory or Downloads.
    echo [*] WinAurex will scan for already mounted Windows installation drives...
) else (
    echo [+] Target base ISO found: [!SOURCE_ISO!]
)

echo.
echo Press any key to start building WinAurex !PROFILE_NAME! ISO...
pause >nul

echo.
echo [*] Launching WinAurex build engine...
if defined SOURCE_ISO (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinAurexMaker.ps1" -Profile !PROFILE_NAME! -ISO "!SOURCE_ISO!" -Auto
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinAurexMaker.ps1" -Profile !PROFILE_NAME! -Auto
)

echo.
echo ======================================================================
echo [SUCCESS] WinAurex ISO Compilation Process Complete!
echo Look for WinAurex_!PROFILE_NAME!.iso in %~dp0
echo ======================================================================
pause
