@echo off
title WinAurex - Install Microsoft 365 / Office
setlocal enabledelayedexpansion

echo ======================================================================
echo                  WinAurex Application Installer
echo                    Microsoft 365 / Office Setup
echo ======================================================================
echo.

where winget >nul 2>&1
if %errorlevel% equ 0 (
    echo [*] Installing Microsoft 365 Apps via WinGet...
    winget install --id Microsoft.Office --exact --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [+] Microsoft 365 installation started successfully via WinGet!
        goto done
    )
    echo [!] WinGet returned error code %errorlevel%. Attempting direct bootstrap...
)

echo [*] Launching Microsoft 365 official setup bootstrapper...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $installer = Join-Path $env:TEMP 'OfficeSetup.exe'; Invoke-WebRequest -Uri 'https://c2rsetup.office.com/mac/download.aspx?id=1' -OutFile $installer -ErrorAction SilentlyContinue; if (-not (Test-Path $installer)) { Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2171997' -OutFile $installer }; Start-Process -FilePath $installer -Wait; Remove-Item $installer -Force -ErrorAction SilentlyContinue"

:done
echo.
echo [DONE] Microsoft 365 setup process completed.
timeout /t 3 >nul
