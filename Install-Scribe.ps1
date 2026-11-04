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

    With -Terminal it sets up the terminal commands instead: a block in your
    PowerShell profiles (Windows PowerShell 5.1 and PowerShell 7) that imports
    ProjectLogTerminal.psm1, for log, Save-Proof and Start-ProjectTranscript.
    -Transcript adds a transcript of every session to the active project.
    -Terminal -Uninstall removes the block.

.PARAMETER NoAutostart
    Only add the Start Menu shortcut.

.PARAMETER Uninstall
    Remove both shortcuts, or with -Terminal the profile block. Doesn't stop a
    running Scribe; exit it from the tray.

.PARAMETER Start
    Start Scribe now as well.

.PARAMETER Terminal
    Add the terminal commands to your PowerShell profiles instead of making shortcuts.

.PARAMETER Transcript
    With -Terminal: also record each PowerShell session to the active
    project's evidence\terminal.

.PARAMETER ProfilePath
    With -Terminal: the profile files to change. Default: the all-hosts
    profiles of Windows PowerShell and PowerShell 7 in your Documents folder.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Install-Scribe.ps1 -Start

.EXAMPLE
    .\Install-Scribe.ps1 -Terminal -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$NoAutostart,
    [switch]$Uninstall,
    [switch]$Start,
    [switch]$Terminal,
    [switch]$Transcript,
    [string[]]$ProfilePath
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'Start-Scribe.ps1'
if (-not (Test-Path -LiteralPath $script)) { throw "Start-Scribe.ps1 not found next to this installer: $script" }

if ($Terminal) {
    $begin = '# >>> ProjectLog terminal (added by Install-Scribe.ps1 -Terminal) >>>'
    $end = '# <<< ProjectLog terminal <<<'
    $block = @($begin, "Import-Module '$(Join-Path $PSScriptRoot 'ProjectLogTerminal.psm1')'")
    if ($Transcript) { $block += 'Start-ProjectTranscript -Quiet' }
    $block += $end
    # The all-hosts profile of each edition, so VS Code's terminal gets it too.
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $profiles = if ($ProfilePath) { $ProfilePath | ForEach-Object { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_) } }
                else { @((Join-Path $documents 'WindowsPowerShell\profile.ps1'), (Join-Path $documents 'PowerShell\profile.ps1')) }
    foreach ($file in $profiles) {
        $text = ''
        $bom = $false
        if (Test-Path -LiteralPath $file) {
            $bytes = [IO.File]::ReadAllBytes($file)
            $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $text = [IO.File]::ReadAllText($file)
        }
        # Keep a BOM the profile already has: Windows PowerShell reads a file without one as ANSI.
        $utf8 = New-Object Text.UTF8Encoding $bom
        # Drop an earlier block first, so installing again replaces it.
        $pattern = '(?s)\r?\n?' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end) + '\r?\n?'
        $without = [regex]::Replace($text, $pattern, "`r`n").Trim()
        if ($Uninstall) {
            if ($without -ne $text.Trim() -and $PSCmdlet.ShouldProcess($file, 'Remove the ProjectLog terminal block')) {
                [IO.File]::WriteAllText($file, $(if ($without) { "$without`r`n" } else { '' }), $utf8)
                Write-Host "Removed the terminal commands from $file"
            }
            continue
        }
        if ($PSCmdlet.ShouldProcess($file, 'Add the ProjectLog terminal block')) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force | Out-Null
            $new = $(if ($without) { "$without`r`n`r`n" } else { '' }) + ($block -join "`r`n") + "`r`n"
            [IO.File]::WriteAllText($file, $new, $utf8)
            Write-Host "Added the terminal commands to $file"
        }
    }
    if (-not $Uninstall) {
        $policy = Get-ExecutionPolicy
        if ($policy -in 'Restricted', 'AllSigned') {
            Write-Warning "The execution policy is $policy, so PowerShell won't run your profile. To allow it: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
        }
        Write-Host 'Open a new PowerShell window, then try: log TRY testing the terminal commands'
    }
    return
}

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
