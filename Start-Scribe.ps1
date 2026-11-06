<#
.SYNOPSIS
    Scribe: one tray app for the active project's running log and screenshots.

.DESCRIPTION
    Runs in the background with a tray icon and does two jobs.

    Log box. Press the hotkey (default Ctrl+Alt+L) and a small box opens on
    the monitor your mouse is on. Type the full tag, then the entry:

        TRY Pointed the reverse proxy at port 8080

    Enter saves and closes. Shift+Enter starts a new line, for pasted output.
    Esc closes without saving. Ctrl+P picks another project. The box shows
    your last few entries, so you can see where you left off. A DECISION can
    also create its decisions\NNN-slug.md record, and files dropped on the box
    are copied into evidence\exports with a PROOF line.

    Copied text. Press the paste hotkey (default Ctrl+Alt+V) and the
    clipboard's text is logged as a SAW entry, word for word.

    Sessions. Start session and End session in the tray menu log a SESSION
    entry at each end, with a NEXT when you stop, and remind you during a
    session when nothing has been logged for a while.

    Screenshots. Take a screenshot with any tool that copies to the clipboard
    (Win+Shift+S, PrtScn, ShareX). A box asks for a short description, saves
    the image as YYYY-MM-DD_HHMM_<slug>.png in the project's
    evidence\screenshots folder and logs a PROOF line. Untick "Watch for
    screenshots" in the tray menu to pause this.

    The time and the date heading are added for you, in the log's format
    (logFormat in settings.json sets it for a new log). Pick the active
    project from the tray menu's Project list, the log box, New-Project.ps1 or
    Set-ActiveProject. The lists include every project in projectsFolder, and
    "Open log" opens the log in Obsidian when the project is in a vault.

    Settings are in %APPDATA%\ProjectLog\settings.json (tray menu: Edit
    settings) and apply a few seconds after you save. Parameters override them.
    Install-Scribe.ps1 adds Start Menu and Startup shortcuts. Exit from the
    tray menu.

    Hide the console with powershell.exe's own -WindowStyle Hidden, as the
    shortcuts do. A launcher that starts the process hidden (Start-Process
    -WindowStyle Hidden, a scheduled task set to Hidden) also hides every
    dialog Scribe opens.

.PARAMETER Project
    Project folder to make active before starting.

.PARAMETER Hotkey
    Global hotkey for the log box, for example 'Ctrl+Alt+L' or 'Ctrl+Shift+F9'.
    Overrides logHotkey in settings.json.

.PARAMETER ExtraTags
    Tags to accept in addition to the playbook's core and module tags.
    Overrides extraTags in settings.json.

.PARAMETER PreviewLines
    Recent log lines to show in the box. Overrides previewLines in settings.json.

.PARAMETER NoScreenshots
    Start with the screenshot watch paused.

.EXAMPLE
    powershell.exe -STA -WindowStyle Hidden -File .\Start-Scribe.ps1

.EXAMPLE
    powershell.exe -STA -File .\Start-Scribe.ps1 -Project C:\Labs\2026-10-senior-capstone -Hotkey 'Ctrl+Shift+F9'
#>
[CmdletBinding()]
param(
    [string]$Project,
    [string]$Hotkey,
    [string[]]$ExtraTags,
    [ValidateRange(0, 20)]
    [int]$PreviewLines,
    [switch]$NoScreenshots
)

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    throw 'Windows Forms and the clipboard need a single-threaded apartment. Run: powershell.exe -STA -File .\Start-Scribe.ps1'
}

Import-Module (Join-Path $PSScriptRoot 'ProjectLog.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ProjectLogUI.psm1') -Force
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# One Scribe at a time; a second copy would double every prompt.
$instance = New-Object Threading.Mutex($false, 'Local\ProjectLog.Scribe')
$ownsInstance = $false
try { $ownsInstance = $instance.WaitOne(0) }
catch [Threading.AbandonedMutexException] { $ownsInstance = $true }
if (-not $ownsInstance) {
    [void][System.Windows.Forms.MessageBox]::Show('Scribe is already running. Look for its icon in the notification area.', 'Scribe')
    $instance.Dispose()
    return
}

# A hidden message-only window on the UI thread. Hotkeys and clipboard changes
# only bump counters in WndProc; a UI timer reads them, so PowerShell code never
# runs inside a window procedure.
if (-not ('Scribe.MessageWindow' -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Scribe {
    public class MessageWindow : NativeWindow, IDisposable {
        [DllImport("user32.dll", SetLastError = true)] private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
        [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
        [DllImport("user32.dll", SetLastError = true)] private static extern bool AddClipboardFormatListener(IntPtr hWnd);
        [DllImport("user32.dll")] private static extern bool RemoveClipboardFormatListener(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);

        private const int WM_HOTKEY = 0x0312, WM_CLIPBOARDUPDATE = 0x031D;
        private const uint MOD_NOREPEAT = 0x4000;
        private readonly Dictionary<int, int> presses = new Dictionary<int, int>();
        private int clipboardChanges;
        private bool listening;

        public MessageWindow() {
            var cp = new CreateParams();
            cp.Parent = new IntPtr(-3);   // HWND_MESSAGE
            CreateHandle(cp);
        }

        // Returns 0, or the Win32 error (1409 means another app owns the hotkey).
        public int SetHotkey(int id, uint modifiers, uint vk) {
            ClearHotkey(id);
            if (!RegisterHotKey(Handle, id, modifiers | MOD_NOREPEAT, vk)) return Marshal.GetLastWin32Error();
            presses[id] = 0;
            return 0;
        }

        public void ClearHotkey(int id) {
            if (presses.Remove(id)) UnregisterHotKey(Handle, id);
        }

        public bool TakePress(int id) {
            int n;
            if (!presses.TryGetValue(id, out n) || n == 0) return false;
            presses[id] = 0;
            return true;
        }

        public bool StartClipboard() {
            if (!listening) listening = AddClipboardFormatListener(Handle);
            clipboardChanges = 0;
            return listening;
        }

        public void StopClipboard() {
            if (listening) RemoveClipboardFormatListener(Handle);
            listening = false;
            clipboardChanges = 0;
        }

        public bool TakeClipboardChange() {
            bool changed = clipboardChanges > 0;
            clipboardChanges = 0;
            return changed;
        }

        protected override void WndProc(ref Message m) {
            if (m.Msg == WM_HOTKEY) {
                int id = m.WParam.ToInt32();
                if (presses.ContainsKey(id)) presses[id]++;
            }
            else if (m.Msg == WM_CLIPBOARDUPDATE) {
                clipboardChanges++;
            }
            base.WndProc(ref m);
        }

        public void Dispose() {
            StopClipboard();
            foreach (int id in new List<int>(presses.Keys)) ClearHotkey(id);
            DestroyHandle();
        }
    }
}
'@
}

function ConvertFrom-HotkeyString {
    param([string]$Text)
    $mods = 0
    $key = $null
    foreach ($part in ($Text -split '\+' | ForEach-Object { $_.Trim() })) {
        switch -Regex ($part) {
            '^(ctrl|control)$' { $mods = $mods -bor 0x2; continue }
            '^alt$'            { $mods = $mods -bor 0x1; continue }
            '^shift$'          { $mods = $mods -bor 0x4; continue }
            '^win$'            { $mods = $mods -bor 0x8; continue }
            default {
                # Enum.Parse works on Windows PowerShell 5.1 and PowerShell 7 alike.
                $name = if ($part -match '^\d$') { "D$part" } else { $part }   # "9" means the 9 key, not key code 9
                if ($name -match '^\d+$') { throw "Unknown key '$part' in hotkey '$Text'." }
                try { $key = [Enum]::Parse([System.Windows.Forms.Keys], $name, $true) }
                catch { throw "Unknown key '$part' in hotkey '$Text'." }
            }
        }
    }
    if ($null -eq $key) { throw "Hotkey '$Text' has no key, only modifiers." }
    if ($mods -eq 0) { throw "Hotkey '$Text' needs at least one modifier (Ctrl, Alt, Shift or Win)." }
    [pscustomobject]@{ Modifiers = [uint32]$mods; Key = [uint32][int]$key }
}

$LogHotkeyId = 1
$PasteHotkeyId = 2
$script:hotkeys = @{}   # hotkey id -> the text registered for it ('' when turned off)
$explicit = @($PSBoundParameters.Keys)
$mono = New-Object System.Drawing.Font('Consolas', 10)
$dropBlue = [System.Drawing.Color]::FromArgb(40, 71, 196)    # the tray icon's blue
$dropTint = [System.Drawing.Color]::FromArgb(225, 233, 252)  # the log box while files are dragged over it

$script:busy = $false          # a dialog is open; hotkey presses are dropped, clipboard changes wait
$script:watching = $false
$script:watchLock = $null
$script:watchSetting = $null   # watchClipboard as last read from settings.json
$script:lastHash = $null
$script:clipDue = $null
$script:tick = 0
$script:hotkeyText = $null
$script:settingsStamp = $null
$script:clearNotificationsAt = $null   # when to clear shown notifications from the notification center
$script:idleMinutes = 0
$script:remindedAt = $null             # the last-activity time the idle reminder already fired for

function Show-TrayMessage {
    param([string]$Text, [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info')
    $shown = if ($Text.Length -gt 250) { $Text.Substring(0, 247) + '...' } else { $Text }
    $tray.ShowBalloonTip(8000, 'Scribe', $shown, $Level)
    # Windows ignores the timeout and keeps the notification in the notification
    # center; the UI timer clears it once it has been on screen.
    $script:clearNotificationsAt = (Get-Date).AddSeconds(10)
    # Balloons can be hidden by Focus Assist, so keep problems in a file too.
    if ($Level -ne 'Info') {
        try { Add-Content -LiteralPath (Get-ProjectLogStatePath 'scribe.log') -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Level $Text" -Encoding UTF8 }
        catch { }
    }
}

function Clear-TrayMessages {
    <# Removing the tray icon takes its notifications out of the notification center; then it comes straight back. #>
    $script:clearNotificationsAt = $null
    $tray.Visible = $false
    $tray.Visible = $true
}

function Get-SettingsStamp {
    $path = Get-ProjectLogStatePath 'settings.json'
    if (Test-Path -LiteralPath $path) { return (Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks }
    return 0
}

function Update-Settings {
    <# Applies settings.json (parameters win) and returns any problems to report. #>
    $s = Get-ProjectLogSettings
    $script:settingsStamp = Get-SettingsStamp
    $problems = @($s.Warnings)

    $script:previewLines = if ($explicit -contains 'PreviewLines') { $PreviewLines } else { $s.previewLines }
    $script:maxSlug = $s.maxSlugLength
    $tags = if ($explicit -contains 'ExtraTags') { $ExtraTags } else { $s.extraTags }
    $script:knownTags = Get-KnownLogTags -ExtraTags $tags
    $script:watchSetting = $s.watchClipboard
    $script:logFormat = $s.logFormat
    $script:projectsFolder = $s.projectsFolder
    if ($s.projectsFolder -and -not (Test-Path -LiteralPath $s.projectsFolder -PathType Container)) {
        $problems += "projectsFolder doesn't exist: $($s.projectsFolder)"
    }

    $script:idleMinutes = $s.idleReminderMinutes
    $wanted = if ($explicit -contains 'Hotkey') { $Hotkey } else { $s.logHotkey }
    $problems += @(Set-ScribeHotkey -Id $LogHotkeyId -Wanted $wanted -Setting 'logHotkey' -Fallback 'Double-click the tray icon instead, or choose another logHotkey.')
    $problems += @(Set-ScribeHotkey -Id $PasteHotkeyId -Wanted $s.pasteHotkey -Setting 'pasteHotkey' -Fallback 'Choose another pasteHotkey, or "" to turn it off.')
    $script:hotkeyText = $script:hotkeys[$LogHotkeyId]
    return $problems
}

function Set-ScribeHotkey {
    <# Registers one hotkey when its setting changed ('' turns it off). Returns a problem to report, or nothing. #>
    param([int]$Id, [string]$Wanted, [string]$Setting, [string]$Fallback)
    if ($script:hotkeys.ContainsKey($Id) -and $Wanted -eq $script:hotkeys[$Id]) { return }
    $script:hotkeys[$Id] = $null
    $window.ClearHotkey($Id)
    if (-not $Wanted.Trim()) { $script:hotkeys[$Id] = $Wanted; return }
    try {
        $combo = ConvertFrom-HotkeyString -Text $Wanted
        $err = $window.SetHotkey($Id, $combo.Modifiers, $combo.Key)
        if ($err) { return "Couldn't register $Wanted for $Setting (error $err; 1409 means another app already uses it). $Fallback" }
        $script:hotkeys[$Id] = $Wanted
    }
    catch { return "${Setting}: $($_.Exception.Message)" }
}

function Update-TrayText {
    $root = Get-ActiveProject
    $text = if ($root) { "Scribe: $(Split-Path -Leaf $root)" } else { 'Scribe: no project' }
    $session = Get-ProjectSession
    if ($session) { $text += " - session $(Format-SessionLength ((Get-Date) - $session.Started))" }
    if (-not $script:watching) { $text += ' (screenshots paused)' }
    if ($text.Length -gt 63) { $text = $text.Substring(0, 60) + '...' }   # NotifyIcon.Text throws past 63
    $tray.Text = $text
}

function Set-Watching {
    param([bool]$On)
    if ($On -and -not $script:watchLock) {
        $script:watchLock = Enter-ClipboardWatch
        if (-not $script:watchLock) {
            Show-TrayMessage 'Save-Screenshot.ps1 is already watching the clipboard, so the screenshot watch is off. Stop that script, then tick "Watch for screenshots".' Warning
            $On = $false
        }
        elseif (-not $window.StartClipboard()) {
            Show-TrayMessage "Couldn't listen for clipboard changes (error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." Error
            $On = $false
        }
    }
    if (-not $On) {
        $window.StopClipboard()
        if ($script:watchLock) { Exit-ClipboardWatch -Lock $script:watchLock; $script:watchLock = $null }
        $script:clipDue = $null
    }
    $script:watching = $On
    $watchItem.Checked = $On
    $tray.Icon = if ($On) { $iconOn } else { $iconOff }
    Update-TrayText
}

function Select-ProjectFolder {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose the active project folder (its log is log.md)'
    $current = Get-ActiveProject
    if ($current) { $dialog.SelectedPath = $current }
    elseif ($script:projectsFolder) { $dialog.SelectedPath = $script:projectsFolder }
    try {
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return Switch-ActiveProject -Path $dialog.SelectedPath
        }
    }
    finally { $dialog.Dispose() }
    return $null
}

function Switch-ActiveProject {
    <# Set-ActiveProject, plus a notification when a running session moved with it. Returns the new root. #>
    param([Parameter(Mandatory)][string]$Path)
    $before = Get-ProjectSession
    $root = Set-ActiveProject -Path $Path
    Update-TrayText
    $message = Get-SessionMoveMessage -Before $before
    if ($message) { Show-TrayMessage $message }
    return $root
}

function Get-SessionMoveMessage {
    <# "Session moved to B (1h 10m logged on A)." when the session now runs on another project, else nothing. #>
    param($Before)
    $after = Get-ProjectSession
    if (-not $Before -or -not $after -or $after.Project -eq $Before.Project) { return }
    $length = Format-SessionLength ($after.Started - $Before.Started)
    return "Session moved to $(Split-Path -Leaf $after.Project) ($length logged on $(Split-Path -Leaf $Before.Project))."
}

function Show-LogBox {
    if ($script:busy) { return }
    $script:busy = $true
    try {
        $root = Get-ActiveProject
        if (-not $root) { $root = Select-ProjectFolder }
        if (-not $root) { return }
        # Handlers change state through this table, which sidesteps PowerShell scope rules.
        $state = @{ Paths = Get-ProjectPaths -Root $root; Recent = @(); Record = $null }

        $form = New-Object System.Windows.Forms.Form -Property @{
            Text            = "Log - $(Split-Path -Leaf $root)"
            FormBorderStyle = 'FixedToolWindow'
            StartPosition   = 'Manual'
            TopMost         = $true
            ShowInTaskbar   = $false
            KeyPreview      = $true
            ClientSize      = New-Object System.Drawing.Size(640, 402)
        }
        $screen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position).WorkingArea
        $form.Location = New-Object System.Drawing.Point(
            ($screen.X + [int](($screen.Width - $form.Width) / 2)),
            ($screen.Y + [int](($screen.Height - $form.Height) / 3)))

        $projectLabel = New-Object System.Windows.Forms.Label -Property @{
            Text     = 'Project'
            AutoSize = $true
            Location = New-Object System.Drawing.Point(10, 13)
        }
        $projectPick = New-Object System.Windows.Forms.ComboBox -Property @{
            DropDownStyle = 'DropDownList'
            TabStop       = $false
            Location      = New-Object System.Drawing.Point(62, 10)
            Size          = New-Object System.Drawing.Size(320, 24)
        }
        $preview = New-Object System.Windows.Forms.TextBox -Property @{
            Multiline   = $true
            ReadOnly    = $true
            TabStop     = $false
            WordWrap    = $false
            ScrollBars  = 'Horizontal'
            Font        = $mono
            ForeColor   = [System.Drawing.Color]::DimGray
            BackColor   = [System.Drawing.SystemColors]::Control
            BorderStyle = 'None'
            Location    = New-Object System.Drawing.Point(10, 42)
            Size        = New-Object System.Drawing.Size(620, 110)
        }
        $entry = New-Object System.Windows.Forms.TextBox -Property @{
            Multiline     = $true
            AcceptsReturn = $true
            WordWrap      = $true
            ScrollBars    = 'Vertical'
            Font          = $mono
            Location      = New-Object System.Drawing.Point(10, 160)
            Size          = New-Object System.Drawing.Size(620, 90)
        }
        # One link per tag: hover shows when to use it, click puts it in the entry box.
        $tags = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{
            Location     = New-Object System.Drawing.Point(10, 256)
            Size         = New-Object System.Drawing.Size(620, 38)
            WrapContents = $true
        }
        $tagTips = New-Object System.Windows.Forms.ToolTip -Property @{
            AutoPopDelay = 20000
            InitialDelay = 300
        }
        foreach ($t in $script:knownTags) {
            $link = New-Object System.Windows.Forms.LinkLabel -Property @{
                Text     = $t
                Tag      = $t
                AutoSize = $true
                TabStop  = $false
                Margin   = New-Object System.Windows.Forms.Padding(0, 0, 6, 2)
            }
            $tagTips.SetToolTip($link, (Get-LogTagHelp -Tag $t))
            $link.Add_LinkClicked({
                param($s, $e)
                $tag = $s.Tag
                # Swap out a tag that's already typed rather than stacking a second one.
                $m = [regex]::Match($entry.Text, '^(\S+)[ \t]*(.*)$', 'Singleline')
                $rest = $entry.Text
                if ($m.Success -and $script:knownTags -contains $m.Groups[1].Value.ToUpperInvariant()) { $rest = $m.Groups[2].Value }
                $entry.Text = "$tag $($rest.TrimStart())"
                [void]$entry.Focus()
                $entry.SelectionStart = $entry.TextLength
            })
            $tags.Controls.Add($link)
        }
        # A dashed drop target that lights up, with the whole box, while files are dragged over.
        $dropZone = New-Object System.Windows.Forms.Panel -Property @{
            BackColor = [System.Drawing.SystemColors]::Window
            Location  = New-Object System.Drawing.Point(10, 298)
            Size      = New-Object System.Drawing.Size(620, 38)
        }
        $dropIdle = 'Drop files here to save them as evidence  (copied to evidence\exports, with a PROOF line)'
        $state.DropText = $dropIdle
        $state.Dragging = $false
        $dashPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::DarkGray), 1
        $dashPen.DashStyle = 'Dash'
        $activePen = New-Object System.Drawing.Pen ($dropBlue), 2
        $boldFont = New-Object System.Drawing.Font($dropZone.Font, [System.Drawing.FontStyle]::Bold)
        $dropZone.Add_Paint({
            param($s, $e)
            $rect = New-Object System.Drawing.Rectangle(1, 1, ($s.Width - 3), ($s.Height - 3))
            if ($state.Dragging) { $e.Graphics.DrawRectangle($activePen, $rect) } else { $e.Graphics.DrawRectangle($dashPen, $rect) }
            $font = if ($state.Dragging) { $boldFont } else { $s.Font }
            $color = if ($state.Dragging) { $dropBlue } else { [System.Drawing.Color]::DimGray }
            [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $state.DropText, $font, $s.ClientRectangle, $color,
                [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, EndEllipsis')
        })
        $hint = New-Object System.Windows.Forms.Label -Property @{
            Text      = 'TAG then text  -  Enter saves  -  Shift+Enter new line  -  Ctrl+P project  -  Esc closes'
            ForeColor = [System.Drawing.Color]::DimGray
            AutoSize  = $true
            Location  = New-Object System.Drawing.Point(10, 344)
        }
        # Shown in the hint's place while the entry is a DECISION.
        $recordBox = New-Object System.Windows.Forms.CheckBox -Property @{
            Text     = 'Also create a decision record (NNN-slug.md in decisions) and open it'
            Checked  = $true
            TabStop  = $false
            Visible  = $false
            AutoSize = $true
            Location = New-Object System.Drawing.Point(10, 341)
        }
        $status = New-Object System.Windows.Forms.Label -Property @{
            ForeColor = [System.Drawing.Color]::Firebrick
            Location  = New-Object System.Drawing.Point(10, 362)
            Size      = New-Object System.Drawing.Size(620, 36)
        }

        $showTail = {
            # Drop the Obsidian bold markers; the preview is plain text.
            $preview.Text = ((Get-LogTail -LogPath $state.Paths.Log -Count $script:previewLines) -join [Environment]::NewLine) -replace '\*\*([A-Z]+)\*\*', '$1'
            if (-not $preview.Text) { $preview.Text = '(log.md is empty or new)' }
            $preview.SelectionStart = $preview.TextLength
            $preview.ScrollToCaret()
        }
        # Recent projects, newest first, the rest of the projects folder, then a way to pick any folder.
        $fillProjects = {
            $state.Recent = @(Get-ProjectChoices -ProjectsFolder $script:projectsFolder)
            $projectPick.Items.Clear()
            foreach ($p in $state.Recent) { [void]$projectPick.Items.Add((Split-Path -Leaf $p)) }
            [void]$projectPick.Items.Add('Choose folder...')
            $projectPick.SelectedIndex = [Math]::Max(0, [Array]::IndexOf([string[]]$state.Recent, $state.Paths.Root))
        }
        $switchTo = {
            param($newRoot)
            $state.Paths = Get-ProjectPaths -Root $newRoot
            $form.Text = "Log - $(Split-Path -Leaf $newRoot)"
            $status.Text = ''
            & $showTail
            & $fillProjects
            Update-TrayText
        }
        $save = {
            $parsed = Split-LogInput -InputText $entry.Text -KnownTags $script:knownTags
            if ($parsed.Error) { $status.Text = $parsed.Error; return }
            try {
                $text = $parsed.Text
                if ($parsed.Tag -eq 'DECISION' -and $recordBox.Checked) {
                    $state.Record = New-DecisionRecord -Root $state.Paths.Root -Decision $text
                    $text = "$text; see $(Get-NoteLink -LogPath $state.Paths.Log -Path $state.Record -DefaultFormat $script:logFormat)"
                }
                [void](Add-LogEntry -LogPath $state.Paths.Log -Tag $parsed.Tag -Text $text -DefaultFormat $script:logFormat)
                $form.Close()
            }
            catch { $status.Text = "Couldn't write to log.md: $($_.Exception.Message)" }
        }
        $setDragging = {
            param([bool]$On, [string]$Text)
            $state.Dragging = $On
            $state.DropText = if ($On) { $Text } else { $dropIdle }
            $form.BackColor = if ($On) { $dropTint } else { [System.Drawing.SystemColors]::Control }
            $dropZone.BackColor = if ($On) { [System.Drawing.Color]::White } else { [System.Drawing.SystemColors]::Window }
            $dropZone.Invalidate()
        }
        # Each dropped file is copied into evidence\exports and gets a PROOF line.
        $dropFiles = {
            param($s, $e)
            & $setDragging $false
            $saved = 0
            $skipped = @()
            foreach ($f in @($e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop))) {
                try {
                    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { $skipped += Split-Path -Leaf $f; continue }
                    $copy = Copy-EvidenceFile -Root $state.Paths.Root -Path $f -MaxSlugLength $script:maxSlug
                    [void](Add-ProofEntry -LogPath $state.Paths.Log -Path $copy -DefaultFormat $script:logFormat)
                    $saved++
                }
                catch { $skipped += "$(Split-Path -Leaf $f) ($($_.Exception.Message))" }
            }
            & $showTail
            $status.ForeColor = if ($skipped) { [System.Drawing.Color]::Firebrick } else { [System.Drawing.Color]::DarkGreen }
            $status.Text = "Saved $saved file$(if ($saved -ne 1) { 's' }) to evidence\exports with a PROOF line."
            if ($skipped) { $status.Text += " Skipped (folders aren't copied): $($skipped -join ', ')" }
            [void]$entry.Focus()
        }
        $dragOver = {
            param($s, $e)
            if (-not $e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { return }
            $e.Effect = 'Copy'
            $items = @($e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop))
            $files = @($items | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count
            $text = if (-not $files) { "Folders aren't copied; drop the files inside them" }
                    elseif ($files -eq 1) { 'Release to save 1 file to evidence\exports' }
                    else { "Release to save $files files to evidence\exports" }
            & $setDragging $true $text
        }
        $dragLeave = {
            # Moving between controls inside the box also fires this; only a real exit counts.
            if (-not $form.RectangleToScreen($form.ClientRectangle).Contains([System.Windows.Forms.Cursor]::Position)) { & $setDragging $false }
        }

        $projectPick.Add_SelectionChangeCommitted({
            $i = $projectPick.SelectedIndex
            if ($i -ge 0 -and $i -lt $state.Recent.Count) {
                try { & $switchTo (Switch-ActiveProject -Path $state.Recent[$i]) }
                catch { $status.Text = "Couldn't switch project: $($_.Exception.Message)"; & $fillProjects }
            }
            else {
                $new = Select-ProjectFolder
                if ($new) { & $switchTo $new } else { & $fillProjects }
            }
            [void]$entry.Focus()
        })
        $entry.Add_KeyDown({
            param($s, $e)
            if ($e.KeyCode -eq 'Enter' -and -not $e.Shift) {
                $e.SuppressKeyPress = $true
                & $save
            }
        })
        $form.Add_KeyDown({
            param($s, $e)
            if ($e.KeyCode -eq 'Escape') {
                $e.SuppressKeyPress = $true
                # Esc in an open project list just closes the list.
                if ($projectPick.DroppedDown) { $projectPick.DroppedDown = $false; [void]$entry.Focus() } else { $form.Close() }
            }
            elseif ($e.KeyCode -eq 'P' -and $e.Control) {
                $e.SuppressKeyPress = $true
                [void]$projectPick.Focus()
                $projectPick.DroppedDown = $true
            }
        })
        $form.Add_Shown({
            & $showTail
            $form.Activate()
            [void][Scribe.MessageWindow]::SetForegroundWindow($form.Handle)
            [void]$entry.Focus()
        })
        $entry.Add_TextChanged({
            $isDecision = $entry.Text -match '^\s*decision\b'
            $recordBox.Visible = $isDecision
            $hint.Visible = -not $isDecision
            if ($status.ForeColor -ne [System.Drawing.Color]::Firebrick) { $status.Text = ''; $status.ForeColor = [System.Drawing.Color]::Firebrick }
        })

        & $fillProjects
        $form.Controls.AddRange(@($projectLabel, $projectPick, $preview, $entry, $tags, $dropZone, $hint, $recordBox, $status))
        # A drop lands on whichever control is under the mouse, so every one of them takes it.
        foreach ($c in @($form) + @($form.Controls) + @($tags.Controls)) {
            $c.AllowDrop = $true
            $c.Add_DragEnter($dragOver)
            $c.Add_DragLeave($dragLeave)
            $c.Add_DragDrop($dropFiles)
        }
        [void]$form.ShowDialog()
        $tagTips.Dispose()
        $form.Dispose()
        $dashPen.Dispose(); $activePen.Dispose(); $boldFont.Dispose()
        if ($state.Record) { Open-Note -Path $state.Record }
    }
    finally { $script:busy = $false }
}

function Invoke-ScreenshotCapture {
    $image = $null
    try {
        if (-not [System.Windows.Forms.Clipboard]::ContainsImage()) { return }
        $image = [System.Windows.Forms.Clipboard]::GetImage()
    }
    catch {
        return   # clipboard briefly locked by another app; the next change retries
    }
    if ($null -eq $image) { return }

    $script:busy = $true
    try {
        # The Snipping Tool puts the same capture on the clipboard again when its
        # window closes. Only prompt for new pixels.
        $hash = Get-ImageHash $image
        if ($hash -eq $script:lastHash) { return }
        $script:lastHash = $hash

        $captured = Get-Date
        $root = Get-ActiveProject
        if (-not $root) { $root = Select-ProjectFolder }
        if (-not $root) { return }

        $answer = Show-DescriptionPrompt -Image $image -When $captured -MaxSlugLength $script:maxSlug -ProjectName (Split-Path -Leaf $root)
        if ($null -eq $answer) { return }

        # Save where the dialog said, even if the project changed while it was open.
        $paths = Get-ProjectPaths -Root $root
        New-Item -ItemType Directory -Path $paths.Screenshots -Force | Out-Null
        $path = Get-UniquePath -Dir $paths.Screenshots -Base (Get-EvidenceName -When $captured -Description $answer.Description -MaxSlugLength $script:maxSlug)
        $image.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        if ($answer.Tag) { [void](Add-LogEntry -LogPath $paths.Log -Tag $answer.Tag -Text $answer.Note -When $captured -DefaultFormat $script:logFormat) }
        [void](Add-ProofEntry -LogPath $paths.Log -Path $path -When $captured -DefaultFormat $script:logFormat)
    }
    catch { Show-TrayMessage "Couldn't save the screenshot: $($_.Exception.Message)" Error }
    finally {
        $image.Dispose()
        $script:busy = $false
    }
}

function Invoke-PasteCapture {
    <# The paste hotkey: logs the clipboard's text as a SAW entry in the active project. #>
    $text = $null
    try {
        if ([System.Windows.Forms.Clipboard]::ContainsText()) { $text = [System.Windows.Forms.Clipboard]::GetText() }
    }
    catch { Show-TrayMessage "Couldn't read the clipboard. Try again." Warning; return }
    if (-not $text -or -not $text.Trim()) { Show-TrayMessage "The clipboard has no text to log. Copy the output first, then press $($script:hotkeys[$PasteHotkeyId])."; return }
    $root = Get-ActiveProject
    if (-not $root) { Show-TrayMessage 'No active project yet. Pick one from the Project menu.'; return }
    try {
        $saved = Add-PastedEntry -LogPath (Get-ProjectPaths -Root $root).Log -Text $text -DefaultFormat $script:logFormat
        $lines = @($text.Trim() -split "`r?`n")
        $shown = $lines[0].Trim()
        if ($shown.Length -gt 60) { $shown = $shown.Substring(0, 57) + '...' }
        $more = if ($saved) { " ($($lines.Count) lines, saved as $(Split-Path -Leaf $saved))" } elseif ($lines.Count -gt 1) { " (+$($lines.Count - 1) more lines)" } else { '' }
        Show-TrayMessage "SAW logged to $(Split-Path -Leaf $root): $shown$more"
    }
    catch { Show-TrayMessage "Couldn't log the clipboard text: $($_.Exception.Message)" Error }
}

function Switch-Session {
    <# Starts a session on the active project, or ends the running one after asking for a NEXT. #>
    if ($script:busy) { return }
    $open = Get-ProjectSession
    if (-not $open) {
        $root = Get-ActiveProject
        if (-not $root) { Show-TrayMessage 'No active project yet. Pick one from the Project menu.'; return }
        try {
            Start-ProjectSession -Root $root -DefaultFormat $script:logFormat
            $script:remindedAt = $null
            Update-TrayText
            Show-TrayMessage "Session started on $(Split-Path -Leaf $root)."
        }
        catch { Show-TrayMessage "Couldn't start a session: $($_.Exception.Message)" Error }
        return
    }
    $script:busy = $true
    try {
        $next = Show-SessionEndDialog -ProjectName (Split-Path -Leaf $open.Project) -Length ((Get-Date) - $open.Started)
        if ($null -eq $next) { return }
        $length = Stop-ProjectSession -Next $next -DefaultFormat $script:logFormat
        Update-TrayText
        Show-TrayMessage "Session on $(Split-Path -Leaf $open.Project) ended after $(Format-SessionLength $length)."
    }
    catch { Show-TrayMessage "Couldn't end the session: $($_.Exception.Message)" Error }
    finally { $script:busy = $false }
}

function Test-IdleReminder {
    <# During a session, a reminder once nothing has been logged for idleReminderMinutes. #>
    if (-not $script:idleMinutes) { return }
    $open = Get-ProjectSession
    if (-not $open) { return }
    $log = (Get-ProjectPaths -Root $open.Project).Log
    $last = $open.Started
    if (Test-Path -LiteralPath $log) {
        $written = (Get-Item -LiteralPath $log).LastWriteTime
        if ($written -gt $last) { $last = $written }
    }
    # Once per quiet spell: a new entry moves $last on and re-arms it.
    if ($script:remindedAt -eq $last) { return }
    if (((Get-Date) - $last).TotalMinutes -ge $script:idleMinutes) {
        $script:remindedAt = $last
        $span = if ($script:idleMinutes -eq 1) { '1 minute' } else { "$($script:idleMinutes) minutes" }
        Show-TrayMessage "Nothing logged on $(Split-Path -Leaf $open.Project) for $span. What are you trying now? ($($script:hotkeyText) to log it)"
    }
}

function New-TrayIcon {
    <# A round badge with an S, drawn at runtime so there's no icon file to ship. #>
    param([System.Drawing.Color]$Color)
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $brush = New-Object System.Drawing.SolidBrush $Color
    $font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $format = New-Object System.Drawing.StringFormat -Property @{ Alignment = 'Center'; LineAlignment = 'Center' }
    try {
        $g.SmoothingMode = 'AntiAlias'
        $g.TextRenderingHint = 'AntiAliasGridFit'
        $g.FillEllipse($brush, 1, 1, 30, 30)
        $g.DrawString('S', $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 1, 32, 32)), $format)
        return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    }
    finally {
        $format.Dispose(); $font.Dispose(); $brush.Dispose(); $g.Dispose(); $bmp.Dispose()
    }
}

function Update-ProjectMenu {
    $projectMenu.DropDownItems.Clear()
    $active = Get-ActiveProject
    foreach ($p in @(Get-ProjectChoices -ProjectsFolder $script:projectsFolder)) {
        $item = New-Object System.Windows.Forms.ToolStripMenuItem (Split-Path -Leaf $p)
        $item.Tag = $p
        $item.ToolTipText = $p
        $item.Checked = ($p -eq $active)
        $item.Add_Click({
            param($s, $e)
            try { [void](Switch-ActiveProject -Path $s.Tag) }
            catch { Show-TrayMessage "Couldn't switch project: $($_.Exception.Message)" Error }
        })
        [void]$projectMenu.DropDownItems.Add($item)
    }
    if ($projectMenu.DropDownItems.Count) { [void]$projectMenu.DropDownItems.Add('-') }
    [void]$projectMenu.DropDownItems.Add('Choose folder...', $null, { if (-not $script:busy) { [void](Select-ProjectFolder) } })
}

function Open-ActiveProjectItem {
    param([ValidateSet('Log', 'Folder')][string]$What)
    $root = Get-ActiveProject
    if (-not $root) { Show-TrayMessage 'No active project yet. Pick one from the Project menu.'; return }
    if ($What -eq 'Folder') { Invoke-Item -LiteralPath $root; return }
    $log = (Get-ProjectPaths -Root $root).Log
    if (-not (Test-Path -LiteralPath $log)) { New-Item -ItemType File -Path $log | Out-Null }
    Open-Note -Path $log
}

function Open-Note {
    <# Opens a Markdown file in Obsidian when it's in a vault, otherwise in its default app. #>
    param([Parameter(Mandatory)][string]$Path)
    if (Test-OpensInObsidian -Path $Path) {
        try { Start-Process -FilePath (Get-ObsidianUri -Path $Path) -ErrorAction Stop; return }
        catch { }   # fall through to the default app
    }
    try { Start-Process -FilePath $Path -ErrorAction Stop }
    catch { Start-Process -FilePath notepad.exe -ArgumentList "`"$Path`"" }
}

function Invoke-ProjectScript {
    <#
        Runs one of this folder's scripts in its own powershell.exe, so its
        Import-Module and prompts can't disturb Scribe. Returns ExitCode and
        Message (the last error line, or the output).
    #>
    param([Parameter(Mandatory)][string]$Name, [string[]]$Arguments = @())
    $ErrorActionPreference = 'Continue'   # the child's stderr is data here, not a failure of Scribe
    $exe = Join-Path $PSHOME 'powershell.exe'
    $output = @(& $exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $Name) @Arguments 2>&1)
    $code = $LASTEXITCODE
    # A thrown error arrives on stderr wrapped at the console width, as
    # "<script> : <message>" followed by "+ CategoryInfo" detail. Rejoin the
    # message lines and drop the rest.
    $errLines = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
    $message = ''
    foreach ($line in $errLines) {
        if ($line -match '^\s*(\+|At line:|At [A-Za-z]:\\)') { break }
        $message += $line.Trim()
    }
    $message = $message -replace '^.*?\.ps1 : ', ''
    if (-not $message) { $message = (@($output | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) | Select-Object -Last 1) }
    return [pscustomobject]@{ ExitCode = $code; Message = "$message" }
}

function ConvertTo-ArgumentPath {
    <# A folder path that survives being quoted on a command line: no trailing backslash to escape the quote. #>
    param([Parameter(Mandatory)][string]$Path)
    $p = $Path.TrimEnd('\')
    if ($p -match '^[A-Za-z]:$') { $p += '\.' }
    return $p
}

function New-ProjectFromTray {
    if ($script:busy) { return }
    $script:busy = $true
    try {
        $parent = $script:projectsFolder
        $last = Get-ProjectLogStatePath 'last-parent.txt'
        if (-not $parent -and (Test-Path -LiteralPath $last)) { $parent = (Get-Content -LiteralPath $last -Raw -Encoding UTF8).Trim() }
        $choice = Show-NewProjectDialog -Parent $parent
        if (-not $choice) { return }

        $arguments = @('-Slug', $choice.Name, '-Module', $choice.Module, '-Path', (ConvertTo-ArgumentPath $choice.Path), '-SetActive')
        if ($choice.Module -eq 'Capstone') { $arguments += @('-Tasks', $choice.Tasks) }
        # New-Project.ps1 switches the active project, which moves a running session too.
        $before = Get-ProjectSession
        $result = Invoke-ProjectScript -Name 'New-Project.ps1' -Arguments $arguments
        $root = Join-Path $choice.Path $choice.Name
        if ($result.ExitCode -or -not (Test-Path -LiteralPath $root)) {
            Show-TrayMessage "Couldn't create the project. $($result.Message)" Error
            return
        }
        Update-TrayText
        Show-TrayMessage (("Created $($choice.Name). It's the active project now. " + (Get-SessionMoveMessage -Before $before)).Trim())
        if ($choice.OpenReadme) { Open-Note -Path (Join-Path $root 'README.md') }
    }
    catch { Show-TrayMessage "Couldn't create the project: $($_.Exception.Message)" Error }
    finally { $script:busy = $false }
}

function Update-ConvertMenu {
    <# Lists the projects whose logs are still in the plain format. #>
    $convertMenu.DropDownItems.Clear()
    foreach ($p in @(Get-ProjectChoices -ProjectsFolder $script:projectsFolder)) {
        $log = (Get-ProjectPaths -Root $p).Log
        if (-not (Test-Path -LiteralPath $log)) { continue }
        if ((Resolve-LogFormat -LogPath $log -DefaultFormat obsidian) -ne 'plain') { continue }
        $item = New-Object System.Windows.Forms.ToolStripMenuItem (Split-Path -Leaf $p)
        $item.Tag = $log
        $item.ToolTipText = $log
        $item.Add_Click({ param($s, $e) Convert-ProjectLog -LogPath $s.Tag })
        [void]$convertMenu.DropDownItems.Add($item)
    }
    if (-not $convertMenu.DropDownItems.Count) {
        $none = $convertMenu.DropDownItems.Add('No plain-format logs to convert')
        $none.Enabled = $false
    }
}

function Convert-ProjectLog {
    param([Parameter(Mandatory)][string]$LogPath)
    if ($script:busy) { return }
    $script:busy = $true
    try {
        $name = Split-Path -Leaf (Split-Path -Parent $LogPath)
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Rewrite the log of $name in the Obsidian format?`n`nThe original is kept beside it as log.md.bak.",
            'Scribe - convert log', 'YesNo', 'Question', 'Button1')
        if ($answer -ne 'Yes') { return }
        $result = Invoke-ProjectScript -Name 'Convert-Log.ps1' -Arguments @('-Path', $LogPath)
        if ($result.ExitCode -or (Resolve-LogFormat -LogPath $LogPath -DefaultFormat plain) -ne 'obsidian') {
            Show-TrayMessage "Couldn't convert the log of $name. $($result.Message)" Error
            return
        }
        Show-TrayMessage "Converted the log of $name. The original is in log.md.bak."
    }
    catch { Show-TrayMessage "Couldn't convert the log: $($_.Exception.Message)" Error }
    finally { $script:busy = $false }
}

function Test-OpensInObsidian {
    <# True when the file is in a vault and Obsidian handles obsidian:// links. #>
    param([Parameter(Mandatory)][string]$Path)
    return [bool](Get-ObsidianVault -Path $Path) -and (Test-Path -LiteralPath 'Registry::HKEY_CLASSES_ROOT\obsidian\shell\open\command')
}

# --- Tray -----------------------------------------------------------------------

$iconOn = New-TrayIcon ([System.Drawing.Color]::FromArgb(40, 71, 196))
$iconOff = New-TrayIcon ([System.Drawing.Color]::FromArgb(128, 128, 128))
$window = New-Object Scribe.MessageWindow

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = $iconOff
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$newEntry = $menu.Items.Add('New log entry', $null, { Show-LogBox })
$newEntry.Font = New-Object System.Drawing.Font($newEntry.Font, [System.Drawing.FontStyle]::Bold)
$projectMenu = New-Object System.Windows.Forms.ToolStripMenuItem 'Project'
$projectMenu.Add_DropDownOpening({ Update-ProjectMenu })
[void]$menu.Items.Add($projectMenu)
[void]$menu.Items.Add('New project...', $null, { New-ProjectFromTray })
$sessionItem = $menu.Items.Add('Start session', $null, { Switch-Session })
$watchItem = New-Object System.Windows.Forms.ToolStripMenuItem 'Watch for screenshots'
$watchItem.Add_Click({ Set-Watching (-not $script:watching) })
[void]$menu.Items.Add($watchItem)
[void]$menu.Items.Add('-')
$openLogItem = $menu.Items.Add('Open log', $null, { Open-ActiveProjectItem -What Log })
$menu.Add_Opening({
    $root = Get-ActiveProject
    $openLogItem.Text = if ($root -and (Test-OpensInObsidian -Path $root)) { 'Open log in Obsidian' } else { 'Open log' }
    $session = Get-ProjectSession
    $sessionItem.Text = if ($session) { "End session ($(Format-SessionLength ((Get-Date) - $session.Started)))..." } else { 'Start session' }
})
[void]$menu.Items.Add('Open project folder', $null, { Open-ActiveProjectItem -What Folder })
$convertMenu = New-Object System.Windows.Forms.ToolStripMenuItem 'Convert log to Obsidian'
$convertMenu.Add_DropDownOpening({ Update-ConvertMenu })
[void]$convertMenu.DropDownItems.Add('...')   # placeholder so the arrow shows; filled on opening
[void]$menu.Items.Add($convertMenu)
[void]$menu.Items.Add('Edit settings', $null, {
    $path = Initialize-ProjectLogSettings
    # Fall back to Notepad when .json has no default app.
    try { Start-Process -FilePath $path -ErrorAction Stop }
    catch { Start-Process -FilePath notepad.exe -ArgumentList "`"$path`"" }
})
[void]$menu.Items.Add('-')
[void]$menu.Items.Add('Exit', $null, { [System.Windows.Forms.Application]::ExitThread() })
$tray.ContextMenuStrip = $menu
# Double-click is the backup trigger when a remote session swallows the hotkey.
$tray.Add_DoubleClick({ Show-LogBox })
$tray.Visible = $true

# --- Start --------------------------------------------------------------------

if ($Project) {
    try { [void](Switch-ActiveProject -Path $Project) }
    catch { Show-TrayMessage "Couldn't use -Project: $($_.Exception.Message)" Warning }
}
$problems = @(Update-Settings)
Set-Watching ($script:watchSetting -and -not $NoScreenshots)
Update-ProjectMenu
if ($problems) { Show-TrayMessage ($problems -join "`n") Warning }
Write-Host "Scribe is running. Log box: $(if ($script:hotkeyText) { $script:hotkeyText } else { 'double-click the tray icon' }). Exit from the tray icon."

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100
$timer.Add_Tick({
    try {
        # Not while the tray menu is open: hiding the icon would close it.
        if ($script:clearNotificationsAt -and (Get-Date) -ge $script:clearNotificationsAt -and -not $menu.Visible) {
            Clear-TrayMessages
        }
        if ($script:busy) {
            # A dialog is open: drop hotkey presses, leave clipboard changes for later.
            [void]$window.TakePress($LogHotkeyId)
            [void]$window.TakePress($PasteHotkeyId)
            return
        }
        if ($window.TakePress($LogHotkeyId)) { Show-LogBox; return }
        if ($window.TakePress($PasteHotkeyId)) { Invoke-PasteCapture; return }

        # Some tools write several clipboard formats per capture; wait until they settle.
        if ($window.TakeClipboardChange()) { $script:clipDue = (Get-Date).AddMilliseconds(200) }
        if ($script:clipDue -and (Get-Date) -ge $script:clipDue) {
            $script:clipDue = $null
            if ($script:watching) { Invoke-ScreenshotCapture }
        }

        # Every 5 seconds: pick up a project switched elsewhere, and settings.json edits.
        $script:tick++
        if ($script:tick % 50 -eq 0) {
            Update-TrayText
            Test-IdleReminder
            if ((Get-SettingsStamp) -ne $script:settingsStamp) {
                $wasWatchSetting = $script:watchSetting
                $problems = @(Update-Settings)
                if ($script:watchSetting -ne $wasWatchSetting) { Set-Watching $script:watchSetting }
                if ($problems) { Show-TrayMessage ((@('Settings reloaded with problems:') + $problems) -join "`n") Warning }
                else { Show-TrayMessage 'Settings reloaded.' }
            }
        }
    }
    catch { Show-TrayMessage $_.Exception.Message Error }
})
$timer.Start()

try { [System.Windows.Forms.Application]::Run() }
finally {
    $timer.Stop()
    $window.StopClipboard()
    if ($script:watchLock) { Exit-ClipboardWatch -Lock $script:watchLock }
    $window.Dispose()
    $tray.Visible = $false
    $tray.Dispose()
    $instance.ReleaseMutex()
    $instance.Dispose()
}
