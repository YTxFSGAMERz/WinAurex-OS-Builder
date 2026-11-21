<#
.SYNOPSIS
    WinAurex VMware Automation Runner
.DESCRIPTION
    Automates VM power operations, captures live screen snapshots, and monitors
    WinAurex installation progress until reaching the desktop.
#>

[CmdletBinding()]
param (
    [string]$VmxPath = "C:\Users\Admin\Documents\Virtual Machines\Windows 11 x64 (4)\Windows 11 x64 (4).vmx",
    [string]$IsoPath = "C:\Users\Admin\Documents\GitHub\WinAurex-OS-Builder\WinAurex_Extreme.iso",
    [string]$SnapshotDir = "C:\Users\Admin\.gemini\antigravity\brain\b34f42b0-60a1-4ea2-93f3-ede7545c8d9c\vm_snapshots",
    [int]$TimeoutMinutes = 10
)

$vmrun = "C:\Program Files\VMware\VMware Workstation\vmrun.exe"
if (-not (Test-Path $vmrun)) {
    throw "vmrun.exe not found at $vmrun"
}
if (-not (Test-Path $VmxPath)) {
    throw "VMX file not found at $VmxPath"
}
if (-not (Test-Path $IsoPath)) {
    throw "ISO file not found at $IsoPath"
}
if (-not (Test-Path $SnapshotDir)) {
    New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "           WINAUREX VMWARE AUTOMATION RUNNER                          " -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " * VM Config   : $VmxPath" -ForegroundColor Yellow
Write-Host " * ISO Image   : $IsoPath" -ForegroundColor Yellow
Write-Host " * Snapshots   : $SnapshotDir" -ForegroundColor DarkGray
Write-Host "======================================================================`n" -ForegroundColor Cyan

# 1. Update VMX file to attach WinAurex_Extreme.iso
Write-Host "[*] Verifying ISO attachment in VMX configuration..." -ForegroundColor Cyan
$vmxContent = Get-Content $VmxPath -Raw
$vmxUpdated = $false

if ($vmxContent -match 'sata0:1\.fileName\s*=\s*".*?"') {
    $vmxContent = $vmxContent -replace 'sata0:1\.fileName\s*=\s*".*?"', "sata0:1.fileName = `"$IsoPath`""
    $vmxUpdated = $true
}
if ($vmxContent -match 'sata0:1\.present\s*=\s*".*?"') {
    $vmxContent = $vmxContent -replace 'sata0:1\.present\s*=\s*".*?"', 'sata0:1.present = "TRUE"'
}
if ($vmxContent -match 'sata0:1\.deviceType\s*=\s*".*?"') {
    $vmxContent = $vmxContent -replace 'sata0:1\.deviceType\s*=\s*".*?"', 'sata0:1.deviceType = "cdrom-image"'
}
if ($vmxUpdated) {
    Set-Content -Path $VmxPath -Value $vmxContent -Encoding UTF8
    Write-Host "  [+] VMX configuration updated." -ForegroundColor Green
}

# 2. Stop VM if already running
$runningVMs = & $vmrun list
if ($runningVMs -match [regex]::Escape($VmxPath)) {
    Write-Host "[*] Stopping running VM instance..." -ForegroundColor Yellow
    & $vmrun -T ws stop $VmxPath hard | Out-Null
    Start-Sleep -Seconds 3
}

# 3. Clean old snapshots
Get-ChildItem -Path $SnapshotDir -Filter "*.png" -ErrorAction SilentlyContinue | Remove-Item -Force

# 4. Power on the VM
Write-Host "[*] Powering on VM with VMware Workstation GUI..." -ForegroundColor Green
& $vmrun -T ws start $VmxPath gui
Start-Sleep -Seconds 6

# 5. Monitoring loop
Write-Host "[*] Starting live installation monitor (taking snapshots every 15s)..." -ForegroundColor Cyan
$startTime = Get-Date
$iteration = 0

while ((Get-Date) -lt $startTime.AddMinutes($TimeoutMinutes)) {
    $iteration++
    Start-Sleep -Seconds 15

    $shotPath = Join-Path $SnapshotDir "vm_shot_$iteration.png"
    & $vmrun -T ws captureScreen $VmxPath $shotPath 2>&1 | Out-Null

    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    if (Test-Path $shotPath) {
        Write-Host "  [t+${elapsed}m] Captured snapshot #$iteration" -ForegroundColor DarkGray
    }

    # Check running status
    $checkRunning = & $vmrun list
    if ($checkRunning -notmatch [regex]::Escape($VmxPath)) {
        Write-Host "  [!] VM not in running list (may be rebooting)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}

Write-Host "`n[*] Monitoring window completed." -ForegroundColor Cyan
