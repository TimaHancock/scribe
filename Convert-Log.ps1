<#
.SYNOPSIS
    Rewrites a plain-format running log in the Obsidian format.

.DESCRIPTION
    Turns each aligned-column entry into a list item with the tag in bold,
    puts extra lines in a code block under the entry, and changes PROOF paths
    to images in the project into embeds (![[name.png]]). Headings and any
    other text are kept. The original is saved beside it as log.md.bak first.

    New entries keep the format a log already has, so convert a log before
    logging to it in the new format.

.PARAMETER Path
    The log to convert. Default: the active project's log.md.

.EXAMPLE
    powershell.exe -File .\Convert-Log.ps1 -WhatIf

.EXAMPLE
    .\Convert-Log.ps1 -Path D:\Vault\Projects\2026-10-proxy-lab\log.md
#>
[CmdletBinding(SupportsShouldProcess)]
param([string]$Path)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ProjectLog.psm1') -Force

if ($Path) {
    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}
else {
    $root = Get-ActiveProject
    if (-not $root) { throw 'No active project. Pass -Path.' }
    $Path = (Get-ProjectPaths -Root $root).Log
}
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Log not found: $Path" }

$utf8 = New-Object Text.UTF8Encoding $false
$text = [IO.File]::ReadAllText($Path, $utf8)
$format = Find-LogFormat -Text $text
if ($format -ne 'plain') {
    Write-Host "Nothing to convert: $Path $(if ($format) { 'is already in the obsidian format' } else { 'has no entries yet' })."
    return
}

$converted = ConvertTo-ObsidianLog -Text $text -ProjectRoot (Split-Path -Parent $Path)
if ($text.Contains("`r`n")) { $converted = $converted -replace "`n", "`r`n" }

if ($PSCmdlet.ShouldProcess($Path, 'Convert to the obsidian log format')) {
    $backup = Get-UniquePath -Dir (Split-Path -Parent $Path) -Base (Split-Path -Leaf $Path) -Extension 'bak'
    Copy-Item -LiteralPath $Path -Destination $backup
    [IO.File]::WriteAllText($Path, $converted, $utf8)
    Write-Host "Converted $Path" -ForegroundColor Green
    Write-Host "The original is in $backup"
}
else {
    Write-Host $converted
}
