@echo off
title WinAurex Universal Optimization Suite
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

if exist "C:\WinAurex\apply.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\WinAurex\apply.ps1" -Force
    exit /b
)

if exist "%~dp0..\..\..\WinAurex\apply.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\..\WinAurex\apply.ps1" -Force
    exit /b
)

echo [*] Connecting to https://www.winaurex.tech to run the latest WinAurex optimization suite...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $s = irm https://www.winaurex.tech/apply.ps1; iex $s } -Force"
pause
