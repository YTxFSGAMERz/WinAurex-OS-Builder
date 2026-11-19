@echo off
title WinAurex - Install ONLYOFFICE Desktop Editors
setlocal enabledelayedexpansion

echo ======================================================================
echo                  WinAurex Application Installer
echo                    ONLYOFFICE Desktop Editors
echo ======================================================================
echo.

where winget >nul 2>&1
if %errorlevel% equ 0 (
    echo [*] Installing ONLYOFFICE via WinGet...
    winget install --id ONLYOFFICE.DesktopEditors --exact --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [+] ONLYOFFICE installed successfully via WinGet!
        goto done
    )
    echo [!] WinGet returned error code %errorlevel%. Attempting direct download fallback...
)

echo [*] Downloading latest ONLYOFFICE Desktop Editors installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $installer = Join-Path $env:TEMP 'DesktopEditors_x64.exe'; Invoke-WebRequest -Uri 'https://download.onlyoffice.com/install/desktop/editors/windows/ONLYOFFICE-DesktopEditors-x64.exe' -OutFile $installer; Start-Process -FilePath $installer -ArgumentList '/VERYSILENT /NORESTART' -Wait; Remove-Item $installer -Force -ErrorAction SilentlyContinue"

:done
echo.
echo [DONE] ONLYOFFICE installation routine finished.
timeout /t 3 >nul
