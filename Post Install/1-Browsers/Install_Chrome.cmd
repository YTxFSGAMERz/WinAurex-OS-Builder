@echo off
title WinAurex - Install Google Chrome
setlocal enabledelayedexpansion

echo ======================================================================
echo                  WinAurex Application Installer
echo                         Google Chrome
echo ======================================================================
echo.

where winget >nul 2>&1
if %errorlevel% equ 0 (
    echo [*] Installing Google Chrome via WinGet...
    winget install --id Google.Chrome --exact --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [+] Google Chrome installed successfully via WinGet!
        goto done
    )
    echo [!] WinGet returned error code %errorlevel%. Attempting direct download fallback...
)

echo [*] Downloading latest Google Chrome standalone setup...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $installer = Join-Path $env:TEMP 'ChromeSetup.exe'; Invoke-WebRequest -Uri 'https://dl.google.com/chrome/install/latest/chrome_installer.exe' -OutFile $installer; Start-Process -FilePath $installer -ArgumentList '/silent /install' -Wait; Remove-Item $installer -Force -ErrorAction SilentlyContinue"

:done
echo.
echo [DONE] Google Chrome installation routine finished.
timeout /t 3 >nul
