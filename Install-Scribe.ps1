<#
.SYNOPSIS
    Adds Scribe to the Start Menu and starts it when you sign in.

.DESCRIPTION
    Creates two shortcuts to Start-Scribe.ps1 in this folder:

      Start Menu   so you can start Scribe by typing its name
      Startup      so it starts each time you sign in (skip with -NoAutostart)

    The shortcuts run Windows PowerShell 5.1 hidden, in STA mode, with
    -ExecutionPolicy Bypass for this one script. If you move this folder, run
    the installer again. -Uninstall removes both shortcuts.

.PARAMETER NoAutostart
    Only add the Start Menu shortcut.

.PARAMETER Uninstall
    Remove both shortcuts. Doesn't stop a running Scribe; exit it from the tray.

.PARAMETER Start
    Start Scribe now as well.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Install-Scribe.ps1 -Start
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$NoAutostart,
    [switch]$Uninstall,
    [switch]$Start
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'Start-Scribe.ps1'
if (-not (Test-Path -LiteralPath $script)) { throw "Start-Scribe.ps1 not found next to this installer: $script" }

$links = [ordered]@{
    'Start Menu' = Join-Path ([Environment]::GetFolderPath('Programs')) 'Scribe.lnk'
    'Startup'    = Join-Path ([Environment]::GetFolderPath('Startup')) 'Scribe.lnk'
}

if ($Uninstall) {
    foreach ($name in $links.Keys) {
        $link = $links[$name]
        if ((Test-Path -LiteralPath $link) -and $PSCmdlet.ShouldProcess($link, 'Remove shortcut')) {
            Remove-Item -LiteralPath $link
            Write-Host "Removed the $name shortcut."
        }
    }
    return
}

# Always Windows PowerShell 5.1, even when this installer runs under PowerShell 7.
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""

$shell = New-Object -ComObject WScript.Shell
try {
    foreach ($name in $links.Keys) {
        $link = $links[$name]
        if ($name -eq 'Startup' -and $NoAutostart) {
            if ((Test-Path -LiteralPath $link) -and $PSCmdlet.ShouldProcess($link, 'Remove shortcut')) {
                Remove-Item -LiteralPath $link
                Write-Host 'Removed the Startup shortcut; Scribe no longer starts at sign-in.'
            }
            continue
        }
        if ($PSCmdlet.ShouldProcess($link, 'Create shortcut')) {
            $shortcut = $shell.CreateShortcut($link)
            $shortcut.TargetPath = $powershell
            $shortcut.Arguments = $arguments
            $shortcut.WorkingDirectory = $PSScriptRoot
            $shortcut.WindowStyle = 7   # minimized, so the console barely flashes before it hides
            $shortcut.Description = 'Scribe: running log and screenshots for the active project'
            $shortcut.Save()
            Write-Host "Added the $name shortcut: $link"
        }
    }
}
finally {
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
}

if ($Start -and $PSCmdlet.ShouldProcess($script, 'Start Scribe')) {
    Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden
    Write-Host 'Scribe started. Look for the S in the notification area.'
}
