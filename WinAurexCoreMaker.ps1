<#
.SYNOPSIS
    WinAurex Core Builder (Extreme Ultra-Lite Tier Wrapper)
.DESCRIPTION
    Maintains backward compatibility for legacy WinAurex Core workflows,
    delegating directly to WinAurexMaker_Extreme.ps1.
#>

[CmdletBinding()]
param (
    [string]$ISO,
    [string]$SCRATCH,
    [int]$EditionIndex = 1,
    [switch]$Auto,
    [switch]$EnableNetFX3,
    [string]$OutISO
)

$target = Join-Path $PSScriptRoot "WinAurexMaker_Extreme.ps1"
if (Test-Path $target) {
    & $target @PSBoundParameters
} else {
    Write-Error "Extreme builder engine not found at $target"
}
