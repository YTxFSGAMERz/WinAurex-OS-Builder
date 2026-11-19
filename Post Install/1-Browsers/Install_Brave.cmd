@echo off
title WinAurex - Install Brave Browser
setlocal enabledelayedexpansion

echo ======================================================================
echo                  WinAurex Application Installer
echo                         Brave Browser
echo ======================================================================
echo.

where winget >nul 2>&1
if %errorlevel% equ 0 (
    echo [*] Installing Brave Browser via WinGet...
    winget install --id Brave.Brave --exact --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [+] Brave Browser installed successfully via WinGet!
        goto done
    )
    echo [!] WinGet returned error code %errorlevel%. Attempting direct download fallback...
)

echo [*] Downloading latest Brave Browser standalone setup...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $installer = Join-Path $env:TEMP 'BraveInstaller.exe'; Invoke-WebRequest -Uri 'https://laptop-updates.brave.com/latest/winx64' -OutFile $installer; Start-Process -FilePath $installer -ArgumentList '/silent /install' -Wait; Remove-Item $installer -Force -ErrorAction SilentlyContinue"

:done
echo.
echo [DONE] Brave Browser installation routine finished.
timeout /t 3 >nul
