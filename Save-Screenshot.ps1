<#
.SYNOPSIS
    Watches the clipboard for new screenshots and saves each one as
    YYYY-MM-DD_HHMM_short-description.png after asking for a description.

.DESCRIPTION
    The console version of Start-Scribe.ps1's screenshot watch, for when you
    want a specific -OutputDir or -LogPath. Only one of the two can watch the
    clipboard at a time.

    Take screenshots with any tool that copies to the clipboard
    (Win+Shift+S, ShareX, Greenshot, PrtScn). Each time a new image lands on
    the clipboard, a small box shows a preview and asks for a short
    description. Enter saves, Esc skips. Press Ctrl+C in the console to stop.

    The timestamp is the moment the image hit the clipboard, not when you
    finished typing. Descriptions are turned into lowercase-hyphen slugs.
    An image identical to the last one handled (saved or skipped) is ignored,
    since some tools re-copy the capture when their window closes.
    Clipboard images carry no EXIF or GPS metadata, so saved PNGs are clean.

.PARAMETER OutputDir
    Folder to save into; created if missing. Default: the active project's
    evidence\screenshots folder, or .\evidence\screenshots if no project is set.

.PARAMETER LogPath
    Running log to append a PROOF line to for each saved file. Default: the
    active project's log.md. With no active project and no -LogPath, nothing
    is logged.

.PARAMETER NoLog
    Don't append PROOF lines, even when a project is active.

.PARAMETER MaxSlugLength
    Longest description slug kept in the file name. Default: maxSlugLength
    in settings.json, which defaults to 50.

.EXAMPLE
    powershell.exe -STA -File .\Save-Screenshot.ps1

    Saves into the active project set by Start-Scribe.ps1 or Set-ActiveProject.
    Changing the active project takes effect on the next capture.

.EXAMPLE
    powershell.exe -STA -File .\Save-Screenshot.ps1 `
        -OutputDir C:\Labs\2026-10-proxy\evidence\screenshots `
        -LogPath   C:\Labs\2026-10-proxy\log.md
#>
[CmdletBinding()]
param(
    [string]$OutputDir = 'evidence\screenshots',
    [string]$LogPath,
    [ValidateRange(10, 120)]
    [int]$MaxSlugLength = 50,
    [switch]$NoLog
)

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    throw 'Clipboard access needs a single-threaded apartment. Run: powershell.exe -STA -File .\Save-Screenshot.ps1'
}

Import-Module (Join-Path $PSScriptRoot 'ProjectLog.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ProjectLogUI.psm1') -Force
if (-not ('SaveShot.Native' -as [type])) {
    Add-Type -Namespace SaveShot -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
'@
}

# Scribe watches the clipboard too; two watchers would mean two prompts per screenshot.
$watchLock = Enter-ClipboardWatch
if (-not $watchLock) {
    throw 'Scribe is already watching the clipboard for screenshots. Use it, or untick "Watch for screenshots" in its tray menu and run this again.'
}

if (-not $PSBoundParameters.ContainsKey('MaxSlugLength')) { $MaxSlugLength = (Get-ProjectLogSettings).maxSlugLength }
$resolve = { param($p) $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) }
$explicitOutput = $PSBoundParameters.ContainsKey('OutputDir')
$explicitLog = $PSBoundParameters.ContainsKey('LogPath')
if ($explicitOutput) { $OutputDir = & $resolve $OutputDir }
if ($explicitLog) { $LogPath = & $resolve $LogPath }

function Get-Targets {
    # Re-read the active project on every capture, so switching projects needs no restart.
    $project = Get-ActiveProject
    $paths = if ($project) { Get-ProjectPaths -Root $project } else { $null }
    $dir = if ($explicitOutput) { $OutputDir } elseif ($paths) { $paths.Screenshots } else { & $resolve 'evidence\screenshots' }
    $log = if ($NoLog) { $null } elseif ($explicitLog) { $LogPath } elseif ($paths) { $paths.Log } else { $null }
    $name = if ($project -and -not $explicitOutput) { Split-Path -Leaf $project } else { $null }
    [pscustomobject]@{ Dir = $dir; Log = $log; Project = $name }
}

$start = Get-Targets
Write-Host "Watching the clipboard. Saving to: $($start.Dir)"
if ($start.Log) { Write-Host "Appending PROOF lines to: $($start.Log)" }
Write-Host 'Take a screenshot to start. Ctrl+C stops.'

$last = [SaveShot.Native]::GetClipboardSequenceNumber()
$lastHash = $null

try {
    while ($true) {
        Start-Sleep -Milliseconds 400
        $seq = [SaveShot.Native]::GetClipboardSequenceNumber()
        if ($seq -eq $last) { continue }

        # Some tools write several clipboard formats per capture; let them finish.
        Start-Sleep -Milliseconds 150
        $last = [SaveShot.Native]::GetClipboardSequenceNumber()

        $image = $null
        try {
            if (-not [System.Windows.Forms.Clipboard]::ContainsImage()) { continue }
            $image = [System.Windows.Forms.Clipboard]::GetImage()
        }
        catch {
            continue   # clipboard briefly locked by another app; next change will retry
        }
        if ($null -eq $image) { continue }

        try {
            # The Snipping Tool puts the same capture on the clipboard again when its
            # window closes, which bumps the sequence number. Only prompt for new pixels.
            $hash = Get-ImageHash $image
            if ($hash -eq $lastHash) { continue }
            $lastHash = $hash

            $captured = Get-Date
            $answer = Show-DescriptionPrompt -Image $image -When $captured -MaxSlugLength $MaxSlugLength -ProjectName (Get-Targets).Project
            if ($null -eq $answer) {
                Write-Host "Skipped capture from $($captured.ToString('HH:mm'))"
            }
            else {
                $targets = Get-Targets
                New-Item -ItemType Directory -Path $targets.Dir -Force | Out-Null
                $path = Get-UniquePath -Dir $targets.Dir -Base (Get-EvidenceName -When $captured -Description $answer.Description -MaxSlugLength $MaxSlugLength)
                $image.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
                Write-Host "Saved $path"
                if ($targets.Log) {
                    if ($answer.Tag) { [void](Add-LogEntry -LogPath $targets.Log -Tag $answer.Tag -Text $answer.Note -When $captured) }
                    [void](Add-ProofEntry -LogPath $targets.Log -Path $path -When $captured)
                }
            }
        }
        finally {
            $image.Dispose()
        }

        $last = [SaveShot.Native]::GetClipboardSequenceNumber()
    }
}
finally {
    # Runs on Ctrl+C too, so Scribe can take over the clipboard right away.
    Exit-ClipboardWatch -Lock $watchLock
}
