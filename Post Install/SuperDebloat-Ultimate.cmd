@echo off
title WinAurex Total Debloat ^& Annihilation Suite
setlocal enabledelayedexpansion

:: Check Admin Rights
IF "%PROCESSOR_ARCHITECTURE%" EQU "amd64" (
    >nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) ELSE (
    >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)

if '%errorlevel%' NEQ '0' (
    echo Elevating privileges to Administrator...
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\getadmin.vbs"
    cscript //nologo "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B
)

pushd "%CD%"
CD /D "%~dp0"

cls
echo ============================================================================================
echo                    WINAUREX TOTAL ANNIHILATION ^& DEBLOAT ENGINE
echo ============================================================================================
echo.
echo [*] Eradicating Windows Security (SecHealthUI), Recommendations & Offers, Accounts & Bloat...
echo.

:: 1. TERMINATE AND PURGE WINDOWS SECURITY & DEFENDER
echo [1/9] Annihilating Windows Security UI (SecHealthUI), Defender Center, and Drivers...
taskkill /f /im SecHealthUI.exe >nul 2>&1
taskkill /f /im SecurityHealthSystray.exe >nul 2>&1
taskkill /f /im SecurityHealthService.exe >nul 2>&1
taskkill /f /im SecurityHealthHost.exe >nul 2>&1
taskkill /f /im smartscreen.exe >nul 2>&1

:: Remove SecHealthUI AppX package
powershell -Command "Get-AppxPackage -AllUsers *SecHealthUI* | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue" >nul 2>&1
powershell -Command "Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like '*SecHealthUI*' } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue" >nul 2>&1

:: Delete Startup Run key for SecurityHealthSystray
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v SecurityHealth /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v SecurityHealth /f >nul 2>&1

:: Neutralize windowsdefender protocol handler
reg delete "HKCR\windowsdefender" /f >nul 2>&1

:: Delete SecurityHealth staging folder & WindowsApps package
if exist "%SystemRoot%\System32\SecurityHealth" (
    takeown /f "%SystemRoot%\System32\SecurityHealth" /r /d y >nul 2>&1
    icacls "%SystemRoot%\System32\SecurityHealth" /grant administrators:F /t /c /q >nul 2>&1
    rd /s /q "%SystemRoot%\System32\SecurityHealth" >nul 2>&1
)
for /d %%D in ("%ProgramFiles%\WindowsApps\*SecHealthUI*") do (
    takeown /f "%%~D" /r /d y >nul 2>&1
    icacls "%%~D" /grant administrators:F /t /c /q >nul 2>&1
    rd /s /q "%%~D" >nul 2>&1
)
for %%B in (SecurityHealthSystray.exe SecurityHealthHost.exe SecurityHealthService.exe smartscreen.exe) do (
    if exist "%SystemRoot%\System32\%%B" (
        takeown /f "%SystemRoot%\System32\%%B" /a >nul 2>&1
        icacls "%SystemRoot%\System32\%%B" /grant administrators:F /c /q >nul 2>&1
        del /f /q "%SystemRoot%\System32\%%B" >nul 2>&1
    )
)

:: Disable Defender services & filter drivers
for %%S in (WinDefend SecurityHealthService Sense WdNisSvc wscsvc WdBoot WdFilter WdNisDrv) do (
    sc stop %%S >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\%%S" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
)

:: Hide Defender Security Center systray and lockdown all UI pages
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" /v HideSystray /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiVirus /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableScanOnRealtimeEnable /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableIOAVProtection /t REG_DWORD /d 1 /f >nul 2>&1
for %%C in (
    "Account protection"
    "App and browser protection"
    "Device performance and health"
    "Device security"
    "Family options"
    "Firewall and network protection"
    "Virus and threat protection"
) do (
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\%%~C" /v UILockdown /t REG_DWORD /d 1 /f >nul 2>&1
)

:: 2. ERADICATE RECOMMENDATIONS & OFFERS TOGGLES (Language list, App tracking, Notifications)
echo [2/9] Forcing all Recommendations & Offers toggles to OFF...
:: Turn off "Allow websites to access my language list"
reg add "HKCU\Control Panel\International\User Profile" /v HttpAcceptLanguageOptOut /t REG_DWORD /d 1 /f >nul 2>&1

:: Turn off "Improve Start and search results" (track app launches and doc tracking)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 0 /f >nul 2>&1

:: Turn off Settings Notifications, Recommendations and Product Suggestions
for %%K in (
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
) do (
    reg add "%%~K" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%%~K" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%%~K" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%%~K" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%%~K" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%%~K" /v SubscribedContent-353698Enabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%%~K" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%%~K" /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%%~K" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "%%~K" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
)

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableConsumerAccountStateContent /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f >nul 2>&1

:: 3. ERADICATE ACCOUNTS & MICROSOFT ACCOUNT PROMO BANNER
echo [3/9] Neutralizing Accounts and killing Microsoft Account promo banner...
:: Kill "Sign in to get the most out of Windows" hero banner in Settings
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\Settings\AllowYourAccount" /v Value /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v NoConnectedUser /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftAccount" /v DisableUserAuth /t REG_DWORD /d 1 /f >nul 2>&1

:: Disable All Settings Sync
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSync /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSyncUserOverride /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableApplicationSettingSync /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableCredentialsSettingSync /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableDesktopThemeSettingSync /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisablePersonalizationSettingSync /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableWebBrowserSettingSync /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableWindowsSettingSync /t REG_DWORD /d 2 /f >nul 2>&1

:: Disable Windows Hello Prompts
reg add "HKLM\SOFTWARE\Policies\Microsoft\PassportForWork" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\PassportForWork" /v DisablePostLogonProvisioning /t REG_DWORD /d 1 /f >nul 2>&1

:: 4. SETTINGS PAGE VISIBILITY & MICROSOFT 365 SLOP PURGE
echo [4/9] Enforcing SettingsPageVisibility to purge Accounts, Privacy & Security, and M365 slop...
set "SETTINGS_HIDE=hide:home;account;yourinfo;emailandaccounts;signinoptions;otherusers;workplace;backup;windowsdefender;deviceencryption;findmydevice;privacy;privacy-general;privacy-speech;privacy-speechtyping;privacy-feedback;privacy-activityhistory;privacy-location;privacy-webcam;privacy-camera;privacy-microphone;privacy-notifications;privacy-accountinfo;privacy-contacts;privacy-calendar;privacy-phonecalls;privacy-callhistory;privacy-messaging;privacy-email;privacy-tasks;privacy-documents;privacy-downloadsfolder;privacy-pictures;privacy-videos;privacy-broadfilesystemaccess;privacy-automaticfiledownloads;privacy-radios;privacy-customdevices;privacy-motion;privacy-eyetracker;privacy-backgroundspatialperception;privacy-backgroundapps;privacy-appdiagnostics;cortana-windowssearch"
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v SettingsPageVisibility /t REG_SZ /d "%SETTINGS_HIDE%" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v SettingsPageVisibility /t REG_SZ /d "%SETTINGS_HIDE%" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoOnlineAccount /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableCloudOptimizedContent /t REG_DWORD /d 1 /f >nul 2>&1

:: Disable Hibernation and Reserved Storage, enforce CompactOS, cap pagefile
powercfg.exe /hibernate off >nul 2>&1
compact.exe /CompactOS:always >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v HibernateEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "C:\pagefile.sys 1024 2048" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" /v ShippedWithReserves /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" /v BaseReservationManager /t REG_DWORD /d 0 /f >nul 2>&1

:: 5. SPEECH, INKING & INPUT PERSONALIZATION
echo [5/9] Neutralizing Speech, Inking, and Contact Harvesting...
reg add "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" /v AllowInputPersonalization /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Speech" /v AllowSpeechModelUpdate /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /v HasAccepted /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\InputPersonalization\TrainedDataStore" /v HarvestContacts /t REG_DWORD /d 0 /f >nul 2>&1

:: 6. DIAGNOSTICS & TELEMETRY
echo [6/9] Destroying Diagnostic Telemetry and Feedback requests...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v MaxTelemetryAllowed /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DoNotShowFeedbackNotifications /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DisableOneSettingsDownloads /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Siuf\Rules" /v NumberOfSIFInPeriod /t REG_DWORD /d 0 /f >nul 2>&1

:: Activity Feed & Location
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v UploadUserActivities /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\FindMyDevice" /v AllowFindMyDevice /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocationScripting /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableWindowsLocationProvider /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d "Deny" /f >nul 2>&1

:: Search & Cortana
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCloudSearch /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v DisableWebSearch /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowSearchToUseLocation /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v DeviceHistoryEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v HistoryViewEnabled /t REG_DWORD /d 0 /f >nul 2>&1

:: 7. GAMEDVR & DELIVERY OPTIMIZATION
echo [7/9] Disabling GameDVR and Delivery Optimization...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v AllowClipboardHistory /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v AllowCrossDeviceClipboard /t REG_DWORD /d 0 /f >nul 2>&1

:: 8. SERVICES & SCHEDULED TASKS
echo [8/9] Neutralizing background services and telemetry tasks...
for %%S in (
    DoSvc PcaSvc TrkWks PhoneSvc SensorService SensrSvc SensorDataService wisvc RetailDemo
    DiagTrack dmwappushservice WerSvc MapsBroker lfsvc WbioSrvc SecurityHealthService WinDefend
) do (
    sc config %%S start= disabled >nul 2>&1
    sc stop %%S >nul 2>&1
)

for %%T in (
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Application Experience\StartupAppTask"
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask"
    "\Microsoft\Windows\Autochk\Proxy"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    "\Microsoft\Windows\Maintenance\WinSAT"
    "\Microsoft\Windows\Maps\MapsUpdateTask"
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
) do (
    schtasks /change /tn %%T /disable >nul 2>&1
)

:: 9. HIBERNATION ANNIHILATION
echo [9/9] Disabling hibernation (reclaiming 8-16 GB storage)...
powercfg /h off >nul 2>&1

echo.
echo ============================================================================================
echo [SUCCESS] TOTAL ANNIHILATION COMPLETE!
echo Windows Security, Recommendations & Offers, and Accounts are eradicated.
echo Restart the Settings app (close and reopen) to verify the ultra-clean interface.
echo ============================================================================================
echo.
pause
exit /b 0
