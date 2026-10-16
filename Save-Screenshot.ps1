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
    Clipboard images carry no EXIF or GPS metadata, so saved PNGs are clean.

.PARAMETER OutputDir
    Folder to save into; created if missing. Default: .\evidence\screenshots

.PARAMETER LogPath
    Optional running log (for example the project's log.md). When set, a
    PROOF line pointing at each saved file is appended to it.

.PARAMETER MaxSlugLength
    Longest description slug kept in the file name. Default: 50.

.EXAMPLE
    powershell.exe -STA -File .\Save-Screenshot.ps1

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
    [int]$MaxSlugLength = 50
)

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    throw 'Clipboard access needs a single-threaded apartment. Run: powershell.exe -STA -File .\Save-Screenshot.ps1'
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
if (-not ('SaveShot.Native' -as [type])) {
    Add-Type -Namespace SaveShot -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
'@
}

$resolve = { param($p) $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) }
$OutputDir = & $resolve $OutputDir
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
if ($LogPath) { $LogPath = & $resolve $LogPath }

function ConvertTo-Slug {
    param([string]$Text)
    # Fold accents to plain letters (é -> e) before stripping everything else.
    $plain = -join ($Text.Normalize([Text.NormalizationForm]::FormD).ToCharArray() |
        Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    $slug = ($plain.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if ($slug.Length -gt $MaxSlugLength) {
        $cut = $slug.Substring(0, $MaxSlugLength)
        # Prefer ending on a whole word when one ends reasonably close to the limit.
        $lastHyphen = $cut.LastIndexOf('-')
        if ($slug[$MaxSlugLength] -ne '-' -and $lastHyphen -ge [int]($MaxSlugLength * 0.6)) {
            $cut = $cut.Substring(0, $lastHyphen)
        }
        $slug = $cut.TrimEnd('-')
    }
    if (-not $slug) { $slug = 'screenshot' }
    return $slug
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
    $box.Add_TextChanged({ $nameLabel.Text = "${Stamp}_$(ConvertTo-Slug $box.Text).png" })
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
    param([datetime]$When, [string]$Path)
    $logDir = Split-Path -Parent $LogPath
    $shown = $Path
    if ($Path.StartsWith($logDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        $shown = $Path.Substring($logDir.Length + 1) -replace '\\', '/'
    }
    $line = '{0} PROOF     {1}' -f $When.ToString('HH:mm'), $shown
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

Write-Host "Watching the clipboard. Saving to: $OutputDir"
if ($LogPath) { Write-Host "Appending PROOF lines to: $LogPath" }
Write-Host 'Take a screenshot to start. Ctrl+C stops.'

$last = [SaveShot.Native]::GetClipboardSequenceNumber()

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

    $captured = Get-Date
    $stamp = $captured.ToString('yyyy-MM-dd_HHmm')
    try {
        $description = Show-DescriptionPrompt -Stamp $stamp -Image $image
        if ($null -eq $description) {
            Write-Host "Skipped capture from $stamp"
        }
        else {
            $path = Get-UniquePath -Dir $OutputDir -Base "${stamp}_$(ConvertTo-Slug $description)"
            $image.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Host "Saved $path"
            if ($LogPath) { Add-ProofLine -When $captured -Path $path }
        }
    }
    finally {
        $image.Dispose()
    }

    $last = [SaveShot.Native]::GetClipboardSequenceNumber()
}
