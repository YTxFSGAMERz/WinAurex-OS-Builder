@echo off
title WinAurex - Install VLC Media Player
setlocal enabledelayedexpansion

echo ======================================================================
echo                  WinAurex Application Installer
echo                         VLC Media Player
echo ======================================================================
echo.

where winget >nul 2>&1
if %errorlevel% equ 0 (
    echo [*] Installing VLC Media Player via WinGet...
    winget install --id VideoLAN.VLC --exact --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [+] VLC Media Player installed successfully via WinGet!
        goto done
    )
    echo [!] WinGet returned error code %errorlevel%. Attempting direct download fallback...
)

echo [*] Downloading latest VLC Media Player installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $installer = Join-Path $env:TEMP 'vlc_setup.exe'; Invoke-WebRequest -Uri 'https://get.videolan.org/vlc/3.0.21/win64/vlc-3.0.21-win64.exe' -OutFile $installer; Start-Process -FilePath $installer -ArgumentList '/L=1033 /S' -Wait; Remove-Item $installer -Force -ErrorAction SilentlyContinue"

:done
echo.
echo [DONE] VLC Media Player installation routine finished.
timeout /t 3 >nul
