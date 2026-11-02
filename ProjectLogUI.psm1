<#
    ProjectLogUI.psm1 - WinForms dialogs shared by Start-Scribe.ps1 and
    Save-Screenshot.ps1. Needs an STA thread and ProjectLog.psm1 loaded first.
#>

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Windows only lets the app you're working in hand over the foreground, and a
# clipboard change gives the watcher no such right, so Activate() alone leaves
# the keyboard in the other app. Joining the foreground thread's input queue for
# a moment lets SetForegroundWindow through.
if (-not ('ProjectLogUI.Foreground' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace ProjectLogUI {
    public static class Foreground {
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr processId);
        [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
        [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
        [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr hWnd);
        [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);

        // Returns whether hWnd ended up in the foreground.
        public static bool Take(IntPtr hWnd) {
            IntPtr current = GetForegroundWindow();
            if (current == hWnd) return true;
            uint mine = GetCurrentThreadId();
            uint theirs = current == IntPtr.Zero ? 0 : GetWindowThreadProcessId(current, IntPtr.Zero);
            bool attached = theirs != 0 && theirs != mine && AttachThreadInput(mine, theirs, true);
            try {
                BringWindowToTop(hWnd);
                SetForegroundWindow(hWnd);
            }
            finally {
                if (attached) AttachThreadInput(mine, theirs, false);
            }
            return GetForegroundWindow() == hWnd;
        }
    }
}
'@
}

function Show-DescriptionPrompt {
    <#
        Shows a captured image and asks for a short description.
        Returns the typed text, or $null if the capture was skipped.
    #>
    param(
        [Parameter(Mandatory)][System.Drawing.Image]$Image,
        [Parameter(Mandatory)][datetime]$When,
        [int]$MaxSlugLength = 50,
        [string]$ProjectName
    )

    $title = 'Name this screenshot'
    if ($ProjectName) { $title += " - $ProjectName" }
    $form = New-Object System.Windows.Forms.Form -Property @{
        Text            = $title
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
        Text      = "$(Get-EvidenceName -When $When -MaxSlugLength $MaxSlugLength).png"
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
    $box.Add_TextChanged({ $nameLabel.Text = "$(Get-EvidenceName -When $When -Description $box.Text -MaxSlugLength $MaxSlugLength).png" })
    $form.Add_Shown({
        $form.Activate()
        [void][ProjectLogUI.Foreground]::Take($form.Handle)
        [void]$box.Focus()
    })
    $form.Controls.AddRange(@($preview, $label, $box, $nameLabel, $save, $skip))

    $result = $form.ShowDialog()
    $text = $box.Text
    $preview.Image = $null
    $form.Dispose()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $text }
    return $null
}

Export-ModuleMember -Function Show-DescriptionPrompt
