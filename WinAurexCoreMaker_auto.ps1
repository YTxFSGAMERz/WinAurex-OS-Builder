<#
.SYNOPSIS
    WinAurex Core Builder Automated (Extreme Tier Wrapper)
.DESCRIPTION
    Maintains backward compatibility for automated legacy WinAurex Core workflows,
    delegating to WinAurexMaker_Extreme.ps1 with -Auto.
#>

[CmdletBinding()]
param (
    [string]$ISO,
    [string]$SCRATCH,
    [int]$EditionIndex = 1,
    [switch]$EnableNetFX3,
    [string]$OutISO
)

$target = Join-Path $PSScriptRoot "WinAurexMaker_Extreme.ps1"
if (Test-Path $target) {
    & $target @PSBoundParameters -Auto
} else {
    Write-Error "Extreme builder engine not found at $target"
}
