@echo off
title WinAurex - Install 7-Zip
setlocal enabledelayedexpansion

echo ======================================================================
echo                  WinAurex Application Installer
echo                         7-Zip Compression
echo ======================================================================
echo.

if exist "%~dp07z2501-x64.exe" (
    echo [*] Found offline 7-Zip installer in local folder. Installing...
    start /wait "" "%~dp07z2501-x64.exe" /S
    if %errorlevel% equ 0 (
        echo [+] 7-Zip installed successfully from offline package!
        goto done
    )
)

where winget >nul 2>&1
if %errorlevel% equ 0 (
    echo [*] Installing 7-Zip via WinGet...
    winget install --id 7zip.7zip --exact --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [+] 7-Zip installed successfully via WinGet!
        goto done
    )
)

echo [*] Downloading 7-Zip standalone installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $installer = Join-Path $env:TEMP '7z_setup.exe'; Invoke-WebRequest -Uri 'https://www.7-zip.org/a/7z2408-x64.exe' -OutFile $installer; Start-Process -FilePath $installer -ArgumentList '/S' -Wait; Remove-Item $installer -Force -ErrorAction SilentlyContinue"

:done
echo.
echo [DONE] 7-Zip installation routine finished.
timeout /t 3 >nul
