@echo off
title WinAurex - Install Mozilla Firefox
setlocal enabledelayedexpansion

echo ======================================================================
echo                  WinAurex Application Installer
echo                        Mozilla Firefox
echo ======================================================================
echo.

where winget >nul 2>&1
if %errorlevel% equ 0 (
    echo [*] Installing Mozilla Firefox via WinGet...
    winget install --id Mozilla.Firefox --exact --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [+] Mozilla Firefox installed successfully via WinGet!
        goto done
    )
    echo [!] WinGet returned error code %errorlevel%. Attempting direct download fallback...
)

echo [*] Downloading latest Mozilla Firefox standalone setup...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $installer = Join-Path $env:TEMP 'FirefoxSetup.exe'; Invoke-WebRequest -Uri 'https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US' -OutFile $installer; Start-Process -FilePath $installer -ArgumentList '/S' -Wait; Remove-Item $installer -Force -ErrorAction SilentlyContinue"

:done
echo.
echo [DONE] Mozilla Firefox installation routine finished.
timeout /t 3 >nul
