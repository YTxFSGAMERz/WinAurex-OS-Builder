@echo off
title WinAurex - Install LibreOffice
setlocal enabledelayedexpansion

echo ======================================================================
echo                  WinAurex Application Installer
echo                           LibreOffice
echo ======================================================================
echo.

where winget >nul 2>&1
if %errorlevel% equ 0 (
    echo [*] Installing LibreOffice via WinGet...
    winget install --id TheDocumentFoundation.LibreOffice --exact --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo [+] LibreOffice installed successfully via WinGet!
        goto done
    )
    echo [!] WinGet returned error code %errorlevel%. Attempting direct download fallback...
)

echo [*] Downloading latest LibreOffice MSI installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $installer = Join-Path $env:TEMP 'LibreOffice.msi'; Invoke-WebRequest -Uri 'https://download.documentfoundation.org/libreoffice/stable/24.8.3/win/x86_64/LibreOffice_24.8.3_Win_x86-64.msi' -OutFile $installer; Start-Process -FilePath 'msiexec.exe' -ArgumentList ('/i `"{0}`" /qn /norestart' -f $installer) -Wait; Remove-Item $installer -Force -ErrorAction SilentlyContinue"

:done
echo.
echo [DONE] LibreOffice installation routine finished.
timeout /t 3 >nul
