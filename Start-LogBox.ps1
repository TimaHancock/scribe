<#
.SYNOPSIS
    A hotkey-summoned box for adding running-log entries to the active project's log.md.

.DESCRIPTION
    Runs in the background with a tray icon. Press the hotkey (default
    Ctrl+Alt+L) and a small box opens on the monitor your mouse is on.
    Type the full tag, then the entry:

        TRY Pointed the reverse proxy at port 8080

    Enter saves and closes. Shift+Enter starts a new line, for pasted output.
    Esc closes without saving. The box shows your last few entries, so you
    can see where you left off.

    The time and the date heading are added for you. Entries go to log.md in
    the active project folder, which Save-Screenshot.ps1 also uses. Set the
    project from the tray menu, with -Project, or with Set-ActiveProject.

    Exit from the tray icon's menu.

.PARAMETER Project
    Project folder to make active before starting.

.PARAMETER Hotkey
    Global hotkey, for example 'Ctrl+Alt+L' or 'Ctrl+Shift+F9'. Default: Ctrl+Alt+L.

.PARAMETER ExtraTags
    Tags to accept in addition to the playbook's core and module tags.

.PARAMETER PreviewLines
    Recent log lines to show in the box. Default: 6.

.EXAMPLE
    powershell.exe -STA -WindowStyle Hidden -File .\Start-LogBox.ps1

.EXAMPLE
    powershell.exe -STA -File .\Start-LogBox.ps1 -Project C:\Labs\2026-10-senior-capstone -Hotkey 'Ctrl+Shift+F9'
#>
[CmdletBinding()]
param(
    [string]$Project,
    [string]$Hotkey = 'Ctrl+Alt+L',
    [string[]]$ExtraTags = @(),
    [ValidateRange(0, 20)]
    [int]$PreviewLines = 6
)

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    throw 'Windows Forms needs a single-threaded apartment. Run: powershell.exe -STA -File .\Start-LogBox.ps1'
}

Import-Module (Join-Path $PSScriptRoot 'ProjectLog.psm1') -Force
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Global hotkey on its own thread with a plain Win32 message loop. The UI polls
# a counter, so no PowerShell code ever runs off the UI thread.
if (-not ('LogBox.Hotkey' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Threading;

namespace LogBox {
    public static class Hotkey {
        [StructLayout(LayoutKind.Sequential)]
        private struct MSG {
            public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam;
            public uint time; public int ptX; public int ptY; public uint lPrivate;
        }
        [DllImport("user32.dll", SetLastError = true)] private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
        [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
        [DllImport("user32.dll")] private static extern int GetMessage(out MSG msg, IntPtr hWnd, uint min, uint max);
        [DllImport("user32.dll")] private static extern bool PostThreadMessage(uint threadId, uint msg, IntPtr wParam, IntPtr lParam);
        [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);

        private const uint WM_HOTKEY = 0x0312, WM_QUIT = 0x0012, MOD_NOREPEAT = 0x4000;
        private static int pressed, status, lastError;
        private static uint threadId;

        public static bool Start(uint modifiers, uint vk, out int win32Error) {
            status = 0; lastError = 0;
            var t = new Thread(() => {
                threadId = GetCurrentThreadId();
                if (!RegisterHotKey(IntPtr.Zero, 1, modifiers | MOD_NOREPEAT, vk)) {
                    lastError = Marshal.GetLastWin32Error();
                    Volatile.Write(ref status, -1);
                    return;
                }
                Volatile.Write(ref status, 1);
                MSG msg;
                while (GetMessage(out msg, IntPtr.Zero, 0, 0) > 0) {
                    if (msg.message == WM_HOTKEY) Interlocked.Increment(ref pressed);
                }
                UnregisterHotKey(IntPtr.Zero, 1);
            });
            t.IsBackground = true;
            t.Start();
            while (Volatile.Read(ref status) == 0) Thread.Sleep(10);
            win32Error = lastError;
            return status == 1;
        }

        public static bool TakePress() { return Interlocked.Exchange(ref pressed, 0) > 0; }

        public static void Stop() {
            if (Volatile.Read(ref status) == 1) PostThreadMessage(threadId, WM_QUIT, IntPtr.Zero, IntPtr.Zero);
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

$knownTags = Get-KnownLogTags -ExtraTags $ExtraTags
$script:boxOpen = $false
$mono = New-Object System.Drawing.Font('Consolas', 10)

function Select-ProjectFolder {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose the active project folder (its log is log.md)'
    $current = Get-ActiveProject
    if ($current) { $dialog.SelectedPath = $current }
    try {
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return Set-ActiveProject -Path $dialog.SelectedPath
        }
    }
    finally { $dialog.Dispose() }
    return $null
}

function Show-LogBox {
    if ($script:boxOpen) { return }
    $script:boxOpen = $true
    try {
        $root = Get-ActiveProject
        if (-not $root) { $root = Select-ProjectFolder }
        if (-not $root) { return }
        # Handlers change state through this table, which sidesteps PowerShell scope rules.
        $state = @{ Paths = Get-ProjectPaths -Root $root }

        $form = New-Object System.Windows.Forms.Form -Property @{
            Text            = "Log - $(Split-Path -Leaf $root)"
            FormBorderStyle = 'FixedToolWindow'
            StartPosition   = 'Manual'
            TopMost         = $true
            ShowInTaskbar   = $false
            KeyPreview      = $true
            ClientSize      = New-Object System.Drawing.Size(640, 340)
        }
        $screen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position).WorkingArea
        $form.Location = New-Object System.Drawing.Point(
            ($screen.X + [int](($screen.Width - $form.Width) / 2)),
            ($screen.Y + [int](($screen.Height - $form.Height) / 3)))

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
            Location    = New-Object System.Drawing.Point(10, 10)
            Size        = New-Object System.Drawing.Size(620, 120)
            Text        = ((Get-LogTail -LogPath $state.Paths.Log -Count $PreviewLines) -join [Environment]::NewLine)
        }
        if (-not $preview.Text) { $preview.Text = '(log.md is empty or new)' }

        $entry = New-Object System.Windows.Forms.TextBox -Property @{
            Multiline     = $true
            AcceptsReturn = $true
            WordWrap      = $true
            ScrollBars    = 'Vertical'
            Font          = $mono
            Location      = New-Object System.Drawing.Point(10, 140)
            Size          = New-Object System.Drawing.Size(620, 90)
        }
        # One link per tag: hover shows when to use it, click puts it in the entry box.
        $tags = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{
            Location     = New-Object System.Drawing.Point(10, 236)
            Size         = New-Object System.Drawing.Size(620, 38)
            WrapContents = $true
        }
        $tagTips = New-Object System.Windows.Forms.ToolTip -Property @{
            AutoPopDelay = 20000
            InitialDelay = 300
        }
        foreach ($t in $knownTags) {
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
                if ($m.Success -and $knownTags -contains $m.Groups[1].Value.ToUpperInvariant()) { $rest = $m.Groups[2].Value }
                $entry.Text = "$tag $($rest.TrimStart())"
                [void]$entry.Focus()
                $entry.SelectionStart = $entry.TextLength
            })
            $tags.Controls.Add($link)
        }
        $hint = New-Object System.Windows.Forms.Label -Property @{
            Text      = 'TAG then text  -  Enter saves  -  Shift+Enter new line  -  Esc closes'
            ForeColor = [System.Drawing.Color]::DimGray
            AutoSize  = $true
            Location  = New-Object System.Drawing.Point(10, 278)
        }
        $status = New-Object System.Windows.Forms.Label -Property @{
            ForeColor = [System.Drawing.Color]::Firebrick
            Location  = New-Object System.Drawing.Point(10, 298)
            Size      = New-Object System.Drawing.Size(520, 36)
        }
        $change = New-Object System.Windows.Forms.LinkLabel -Property @{
            Text     = 'Change project'
            AutoSize = $true
            Location = New-Object System.Drawing.Point(540, 278)
        }

        $save = {
            $parsed = Split-LogInput -InputText $entry.Text -KnownTags $knownTags
            if ($parsed.Error) { $status.Text = $parsed.Error; return }
            try {
                [void](Add-LogEntry -LogPath $state.Paths.Log -Tag $parsed.Tag -Text $parsed.Text)
                $form.Close()
            }
            catch { $status.Text = "Couldn't write to log.md: $($_.Exception.Message)" }
        }

        $entry.Add_KeyDown({
            param($s, $e)
            if ($e.KeyCode -eq 'Enter' -and -not $e.Shift) {
                $e.SuppressKeyPress = $true
                & $save
            }
        })
        $form.Add_KeyDown({
            param($s, $e)
            if ($e.KeyCode -eq 'Escape') { $e.SuppressKeyPress = $true; $form.Close() }
        })
        $change.Add_LinkClicked({
            $new = Select-ProjectFolder
            if ($new) {
                $state.Paths = Get-ProjectPaths -Root $new
                $form.Text = "Log - $(Split-Path -Leaf $new)"
                $preview.Text = ((Get-LogTail -LogPath $state.Paths.Log -Count $PreviewLines) -join [Environment]::NewLine)
                if (-not $preview.Text) { $preview.Text = '(log.md is empty or new)' }
            }
            [void]$entry.Focus()
        })
        $form.Add_Shown({
            $preview.SelectionStart = $preview.TextLength
            $preview.ScrollToCaret()
            $form.Activate()
            [void][LogBox.Hotkey]::SetForegroundWindow($form.Handle)
            [void]$entry.Focus()
        })

        $form.Controls.AddRange(@($preview, $entry, $tags, $hint, $status, $change))
        [void]$form.ShowDialog()
        $tagTips.Dispose()
        $form.Dispose()
    }
    finally { $script:boxOpen = $false }
}

# Tray icon: the backup trigger when a remote session swallows the hotkey.
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Application
$tray.Text = "Log box ($Hotkey)"
$menu = New-Object System.Windows.Forms.ContextMenuStrip
[void]$menu.Items.Add('New entry', $null, { Show-LogBox })
[void]$menu.Items.Add('Set active project...', $null, { [void](Select-ProjectFolder) })
[void]$menu.Items.Add('Open log', $null, {
    $root = Get-ActiveProject
    if ($root) {
        $log = (Get-ProjectPaths -Root $root).Log
        if (-not (Test-Path -LiteralPath $log)) { New-Item -ItemType File -Path $log | Out-Null }
        Start-Process -FilePath $log
    }
})
[void]$menu.Items.Add('-')
[void]$menu.Items.Add('Exit', $null, {
    $timer.Stop()
    [LogBox.Hotkey]::Stop()
    $tray.Visible = $false
    [System.Windows.Forms.Application]::ExitThread()
})
$tray.ContextMenuStrip = $menu
$tray.Add_DoubleClick({ Show-LogBox })
$tray.Visible = $true

if ($Project) {
    $root = Set-ActiveProject -Path $Project
    Write-Host "Active project: $root"
}

$combo = ConvertFrom-HotkeyString -Text $Hotkey
$win32Error = 0
if ([LogBox.Hotkey]::Start($combo.Modifiers, $combo.Key, [ref]$win32Error)) {
    Write-Host "Log box ready. Press $Hotkey to add an entry; exit from the tray icon."
}
else {
    $message = "Couldn't register $Hotkey (error $win32Error; 1409 means another app already uses it). Double-click the tray icon instead, or restart with -Hotkey."
    Write-Warning $message
    $tray.ShowBalloonTip(8000, 'Log box', $message, [System.Windows.Forms.ToolTipIcon]::Warning)
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100
$timer.Add_Tick({ if ([LogBox.Hotkey]::TakePress()) { Show-LogBox } })
$timer.Start()

try { [System.Windows.Forms.Application]::Run() }
finally {
    [LogBox.Hotkey]::Stop()
    $tray.Visible = $false
    $tray.Dispose()
}
