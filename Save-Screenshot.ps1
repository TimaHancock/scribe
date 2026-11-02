<#
.SYNOPSIS
    Watches the clipboard for new screenshots and saves each one as
    YYYY-MM-DD_HHMM_short-description.png after asking for a description.

.DESCRIPTION
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
    Longest description slug kept in the file name. Default: 50.

.EXAMPLE
    powershell.exe -STA -File .\Save-Screenshot.ps1

    Saves into the active project set by Start-LogBox.ps1 or Set-ActiveProject.
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
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
if (-not ('SaveShot.Native' -as [type])) {
    Add-Type -Namespace SaveShot -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
'@
}

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
    [pscustomobject]@{ Dir = $dir; Log = $log }
}

function Get-ShotSlug {
    param([string]$Text)
    $slug = ConvertTo-Slug -Text $Text -MaxLength $MaxSlugLength
    if (-not $slug) { $slug = 'screenshot' }
    return $slug
}

function Get-ImageHash {
    param([System.Drawing.Bitmap]$Image)
    # Lock as 32bpp ARGB so the same pixels hash the same whichever clipboard
    # format (DIB, PNG, ...) the image was read from.
    $rect = New-Object System.Drawing.Rectangle(0, 0, $Image.Width, $Image.Height)
    $data = $Image.LockBits($rect, 'ReadOnly', [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $bytes = New-Object byte[] ($data.Stride * $data.Height)
        [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    }
    finally {
        $Image.UnlockBits($data)
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return '{0}x{1}:{2}' -f $Image.Width, $Image.Height, [BitConverter]::ToString($sha.ComputeHash($bytes))
    }
    finally {
        $sha.Dispose()
    }
}

function Get-UniquePath {
    param([string]$Dir, [string]$Base)
    $path = Join-Path $Dir "$Base.png"
    $n = 2
    while (Test-Path -LiteralPath $path) {
        $path = Join-Path $Dir "$Base-$n.png"
        $n++
    }
    return $path
}

function Show-DescriptionPrompt {
    param([string]$Stamp, [System.Drawing.Image]$Image)

    $form = New-Object System.Windows.Forms.Form -Property @{
        Text            = 'Name this screenshot'
        FormBorderStyle = 'FixedDialog'
        MaximizeBox     = $false
        MinimizeBox     = $false
        StartPosition   = 'CenterScreen'
        TopMost         = $true
        ClientSize      = New-Object System.Drawing.Size(420, 300)
    }
    $preview = New-Object System.Windows.Forms.PictureBox -Property @{
        Image       = $Image
        SizeMode    = 'Zoom'
        BorderStyle = 'FixedSingle'
        Location    = New-Object System.Drawing.Point(10, 10)
        Size        = New-Object System.Drawing.Size(400, 170)
    }
    $label = New-Object System.Windows.Forms.Label -Property @{
        Text     = 'Short description (Enter saves, Esc skips):'
        AutoSize = $true
        Location = New-Object System.Drawing.Point(10, 190)
    }
    $box = New-Object System.Windows.Forms.TextBox -Property @{
        Location = New-Object System.Drawing.Point(10, 210)
        Size     = New-Object System.Drawing.Size(400, 24)
    }
    $nameLabel = New-Object System.Windows.Forms.Label -Property @{
        Text      = "${Stamp}_screenshot.png"
        ForeColor = [System.Drawing.Color]::DimGray
        Location  = New-Object System.Drawing.Point(10, 240)
        Size      = New-Object System.Drawing.Size(400, 18)
    }
    $save = New-Object System.Windows.Forms.Button -Property @{
        Text         = 'Save'
        DialogResult = 'OK'
        Location     = New-Object System.Drawing.Point(254, 266)
        Size         = New-Object System.Drawing.Size(75, 26)
    }
    $skip = New-Object System.Windows.Forms.Button -Property @{
        Text         = 'Skip'
        DialogResult = 'Cancel'
        Location     = New-Object System.Drawing.Point(335, 266)
        Size         = New-Object System.Drawing.Size(75, 26)
    }

    $form.AcceptButton = $save
    $form.CancelButton = $skip
    $box.Add_TextChanged({ $nameLabel.Text = "${Stamp}_$(Get-ShotSlug $box.Text).png" })
    $form.Add_Shown({ $form.Activate(); [void]$box.Focus() })
    $form.Controls.AddRange(@($preview, $label, $box, $nameLabel, $save, $skip))

    $result = $form.ShowDialog()
    $text = $box.Text
    $preview.Image = $null
    $form.Dispose()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $text }
    return $null
}

function Add-ProofLine {
    param([string]$Log, [datetime]$When, [string]$Path)
    $logDir = Split-Path -Parent $Log
    $shown = $Path
    if ($Path.StartsWith($logDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        $shown = $Path.Substring($logDir.Length + 1) -replace '\\', '/'
    }
    [void](Add-LogEntry -LogPath $Log -Tag 'PROOF' -Text $shown -When $When)
}

$start = Get-Targets
Write-Host "Watching the clipboard. Saving to: $($start.Dir)"
if ($start.Log) { Write-Host "Appending PROOF lines to: $($start.Log)" }
Write-Host 'Take a screenshot to start. Ctrl+C stops.'

$last = [SaveShot.Native]::GetClipboardSequenceNumber()
$lastHash = $null

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
        $stamp = $captured.ToString('yyyy-MM-dd_HHmm')
        $description = Show-DescriptionPrompt -Stamp $stamp -Image $image
        if ($null -eq $description) {
            Write-Host "Skipped capture from $stamp"
        }
        else {
            $targets = Get-Targets
            New-Item -ItemType Directory -Path $targets.Dir -Force | Out-Null
            $path = Get-UniquePath -Dir $targets.Dir -Base "${stamp}_$(Get-ShotSlug $description)"
            $image.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Host "Saved $path"
            if ($targets.Log) { Add-ProofLine -Log $targets.Log -When $captured -Path $path }
        }
    }
    finally {
        $image.Dispose()
    }

    $last = [SaveShot.Native]::GetClipboardSequenceNumber()
}
