@echo off
title WinAurex - Install Notepad++
setlocal enabledelayedexpansion

echo ======================================================================
echo                  WinAurex Application Installer
echo                           Notepad++
echo ======================================================================
echo.

where winget >nul 2>&1
if %errorlevel% equ 0 (
    echo [*] Installing Notepad++ via WinGet...
    winget install --id Notepad++.Notepad++ --exact --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [+] Notepad++ installed successfully via WinGet!
        goto done
    )
    echo [!] WinGet returned error code %errorlevel%. Attempting direct download fallback...
)

echo [*] Downloading latest Notepad++ standalone installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $installer = Join-Path $env:TEMP 'npp_setup.exe'; Invoke-WebRequest -Uri 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.7.1/npp.8.7.1.Installer.x64.exe' -OutFile $installer; Start-Process -FilePath $installer -ArgumentList '/S' -Wait; Remove-Item $installer -Force -ErrorAction SilentlyContinue"

:done
echo.
echo [DONE] Notepad++ installation routine finished.
timeout /t 3 >nul
