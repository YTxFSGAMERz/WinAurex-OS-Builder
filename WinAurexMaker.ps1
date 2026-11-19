<#
.SYNOPSIS
    WinAurex OS Builder - Master Flagship Orchestrator
.DESCRIPTION
    Main entry point for WinAurex Windows 11 Image Engineering.
    Supports 3 specialized build tiers:
      1. Stable   : WinAurex Stable Workstation (WU + WinGet + Drivers 100% Functional)
      2. Moderate : WinAurex Performance & Gaming (WinGet Working, Drivers Intact, WU Disabled)
      3. Extreme  : WinAurex Core Ultra-Lite (Sub-1GB RAM Idle Target for VMs / Low-Spec Rigs)
.PARAMETER Profile
    Target OS build profile: 'Stable' (default), 'Moderate', or 'Extreme'.
.PARAMETER ISO
    Mounted drive letter (e.g. 'E') or path to Windows 11 ISO file.
.PARAMETER SCRATCH
    Drive letter for scratch extraction workspace (defaults to system drive).
.PARAMETER EditionIndex
    Target Windows edition index (e.g. 1 for Home, 6 for Pro).
.PARAMETER Auto
    Run non-interactively without pause prompts.
.PARAMETER EnableNetFX3
    Enable .NET Framework 3.5 offline from installation media.
.PARAMETER OutISO
    Destination path for the compiled bootable ISO file.
.NOTES
    Author: Farhan Shaikh (@FFShaikh69) // WinAurex Framework
#>

[CmdletBinding()]
param (
    [ValidateSet('Stable', 'Moderate', 'Extreme', '1', '2', '3')]
    [string]$Profile = 'Stable',
    [string]$ISO,
    [string]$SCRATCH,
    [int]$EditionIndex = 1,
    [switch]$Auto,
    [switch]$EnableNetFX3,
    [string]$OutISO
)

# Elevate to Administrator if required
$adminSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$adminGroup = $adminSID.Translate([System.Security.Principal.NTAccount])
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $myWindowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[*] Requesting Administrator elevation..." -ForegroundColor Yellow
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell"
    $newProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $newProcess.Verb = "runas"
    [System.Diagnostics.Process]::Start($newProcess) | Out-Null
    Exit
}

# If user ran without parameters and not automated, present profile choice menu
if (-not $PSBoundParameters.ContainsKey('Profile') -and -not $Auto) {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "                WINAUREX OS BUILDER - MASTER ENGINE                  " -ForegroundColor White
    Write-Host "                       https://www.winaurex.tech                      " -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host " Select your desired OS Build Profile:`n" -ForegroundColor White
    Write-Host "  [1] Stable Workstation (Recommended)" -ForegroundColor Green
    Write-Host "      - Windows Update: 100% Fully Functional" -ForegroundColor DarkGray
    Write-Host "      - WinGet Package Manager: 100% Fully Functional" -ForegroundColor DarkGray
    Write-Host "      - Hardware Drivers: 100% Intact & Preserved" -ForegroundColor DarkGray
    Write-Host "      - Removes advertising, promo pins, and consumer bloatware`n" -ForegroundColor DarkGray

    Write-Host "  [2] Performance & Gaming" -ForegroundColor Yellow
    Write-Host "      - Windows Update: Disabled (No unexpected reboots or latency spikes)" -ForegroundColor DarkGray
    Write-Host "      - WinGet Package Manager: 100% Fully Functional" -ForegroundColor DarkGray
    Write-Host "      - Hardware Drivers: 100% Intact (GPU, Wi-Fi, Audio Preserved)" -ForegroundColor DarkGray
    Write-Host "      - Deeper debloat (Xbox background daemons, Copilot, Teams stripped)`n" -ForegroundColor DarkGray

    Write-Host "  [3] Core Ultra-Lite (Extreme)" -ForegroundColor Magenta
    Write-Host "      - WinAurex Core strip-down for low-spec VMs and benchmark rigs" -ForegroundColor DarkGray
    Write-Host "      - Strips all provisioned packages, FODs, Edge, WinRE" -ForegroundColor DarkGray
    Write-Host "      - Sub-1GB RAM idle baseline`n" -ForegroundColor DarkGray
    Write-Host "======================================================================" -ForegroundColor Cyan

    $choice = Read-Host " Enter choice [1-3] (Default: 1 - Stable)"
    switch ($choice.Trim()) {
        '2' { $Profile = 'Moderate' }
        '3' { $Profile = 'Extreme' }
        default { $Profile = 'Stable' }
    }
} else {
    switch ($Profile) {
        '1' { $Profile = 'Stable' }
        '2' { $Profile = 'Moderate' }
        '3' { $Profile = 'Extreme' }
    }
}

# Map profile to dedicated tier script
$scriptMap = @{
    'Stable'   = Join-Path $PSScriptRoot "WinAurexMaker_Stable.ps1"
    'Moderate' = Join-Path $PSScriptRoot "WinAurexMaker_Moderate.ps1"
    'Extreme'  = Join-Path $PSScriptRoot "WinAurexMaker_Extreme.ps1"
}

$targetScript = $scriptMap[$Profile]
if (-not (Test-Path $targetScript)) {
    Write-Error "Target builder script not found at $targetScript"
    Exit 1
}

Write-Host "`n[*] Dispatching to profile: $Profile ($targetScript)..." -ForegroundColor Cyan

# Forward parameters to target script
$forwardParams = @{
    FilePath = $targetScript
    ArgumentList = @()
}

$argList = @()
if ($ISO) { $argList += @('-ISO', "`"$ISO`"") }
if ($SCRATCH) { $argList += @('-SCRATCH', "`"$SCRATCH`"") }
if ($EditionIndex) { $argList += @('-EditionIndex', $EditionIndex) }
if ($Auto) { $argList += '-Auto' }
if ($EnableNetFX3) { $argList += '-EnableNetFX3' }
if ($OutISO) { $argList += @('-OutISO', "`"$OutISO`"") }

& $targetScript @PSBoundParameters
