@echo off
title Launch WinAurex GUI Dashboard
setlocal enabledelayedexpansion

IF "%PROCESSOR_ARCHITECTURE%" EQU "amd64" (
    >nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) ELSE (
    >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)
if '%errorlevel%' NEQ '0' (
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\getadmin.vbs"
    cscript //nologo "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B
)

if exist "C:\WinAurex\Launch_Dashboard.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\WinAurex\Launch_Dashboard.ps1"
    exit /b
)

if exist "%~dp0..\..\..\WinAurex\Launch_Dashboard.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\..\WinAurex\Launch_Dashboard.ps1"
    exit /b
)

echo [!] WinAurex suite not found locally at C:\WinAurex.
echo [*] Downloading and launching latest WinAurex Dashboard from https://www.winaurex.tech...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $s = irm https://www.winaurex.tech/apply.ps1; iex $s } -LaunchDashboard"
pause
