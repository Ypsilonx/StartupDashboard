Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Kompatibilní vstupní skript pro startup dashboard.

.DESCRIPTION
Soubor zachovává původní cestu pro spuštění,
ale reálná implementace je rozdělená modulově v podsložce dashboard.
#>

$dashboardScript = Join-Path -Path $PSScriptRoot -ChildPath 'dashboard\StartupDashboard.ps1'

if (-not (Test-Path -LiteralPath $dashboardScript)) {
    throw "Dashboard skript nebyl nalezen: $dashboardScript"
}

& $dashboardScript
