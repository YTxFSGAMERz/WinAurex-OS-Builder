@echo off
title WinAurex - Install Voidtools Everything
setlocal enabledelayedexpansion

echo ======================================================================
echo                  WinAurex Application Installer
echo                      Voidtools Everything Search
echo ======================================================================
echo.

where winget >nul 2>&1
if %errorlevel% equ 0 (
    echo [*] Installing Everything via WinGet...
    winget install --id voidtools.Everything --exact --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [+] Voidtools Everything installed successfully via WinGet!
        goto done
    )
    echo [!] WinGet returned error code %errorlevel%. Attempting direct download fallback...
)

echo [*] Downloading latest Everything installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $installer = Join-Path $env:TEMP 'EverythingSetup.exe'; Invoke-WebRequest -Uri 'https://www.voidtools.com/Everything-1.4.1.1026.x64-Setup.exe' -OutFile $installer; Start-Process -FilePath $installer -ArgumentList '/S' -Wait; Remove-Item $installer -Force -ErrorAction SilentlyContinue"

:done
echo.
echo [DONE] Voidtools Everything installation routine finished.
timeout /t 3 >nul
