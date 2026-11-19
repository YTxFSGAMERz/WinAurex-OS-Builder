@echo off
title WinAurex - 1-Click Essential Apps Installer
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
echo             WinAurex 1-Click Essential Application Installer
echo ======================================================================
echo.
echo This script will automatically install recommended daily-driver software:
echo  [+] Browser  : Brave Browser (Fast, Ad-Free, Chromium Engine)
echo  [+] Office   : LibreOffice Productivity Suite
echo  [+] Tools    : 7-Zip, Notepad++, VLC Media Player
echo.
echo ======================================================================
set /p confirm="Begin installation now? (Y/N, default Y): "
if /i "%confirm%"=="N" (
    echo Aborted by user.
    pause
    exit /b
)

echo.
echo ======================================================================
echo [1/5] Installing 7-Zip Compression Utility...
echo ======================================================================
call "%~dp03-Tools\Install_7Zip.cmd"

echo.
echo ======================================================================
echo [2/5] Installing Notepad++ Advanced Editor...
echo ======================================================================
call "%~dp03-Tools\Install_Notepad++.cmd"

echo.
echo ======================================================================
echo [3/5] Installing VLC Media Player...
echo ======================================================================
call "%~dp03-Tools\Install_VLC.cmd"

echo.
echo ======================================================================
echo [4/5] Installing Brave Browser...
echo ======================================================================
call "%~dp01-Browsers\Install_Brave.cmd"

echo.
echo ======================================================================
echo [5/5] Installing LibreOffice Suite...
echo ======================================================================
call "%~dp02-Office\Install_LibreOffice.cmd"

echo.
echo ======================================================================
echo [SUCCESS] All essential applications have been installed!
echo ======================================================================
echo.
pause
