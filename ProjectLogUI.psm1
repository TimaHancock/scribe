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

function Show-NewProjectDialog {
    <#
        Asks for what New-Project.ps1 needs. Returns Name (the folder name),
        Module, Tasks, Path and OpenReadme, or $null if cancelled. Checks that
        the folder can be created before it closes.
    #>
    param([string]$Parent)

    # Same choices and order as New-Project.ps1's console menu.
    $modules = [ordered]@{
        Core      = 'Core - no type module'
        ITProject = 'IT project - migration, deployment, rollout'
        Runbook   = 'Runbook - writing one procedure'
        TechEval  = 'Tech evaluation - choosing a product or tool'
        Academic  = 'Academic - one graded task'
        Capstone  = 'Capstone - multi-task capstone'
    }
    $font = New-Object System.Drawing.Font('Segoe UI', 9)
    $form = New-Object System.Windows.Forms.Form -Property @{
        Text            = 'New project'
        FormBorderStyle = 'FixedDialog'
        MaximizeBox     = $false
        MinimizeBox     = $false
        StartPosition   = 'CenterScreen'
        TopMost         = $true
        Font            = $font
        ClientSize      = New-Object System.Drawing.Size(470, 238)
    }
    $nameLabel = New-Object System.Windows.Forms.Label -Property @{ Text = 'Name'; AutoSize = $true; Location = New-Object System.Drawing.Point(10, 15) }
    $nameBox = New-Object System.Windows.Forms.TextBox -Property @{
        Location = New-Object System.Drawing.Point(90, 12)
        Size     = New-Object System.Drawing.Size(370, 24)
    }
    $folderLabel = New-Object System.Windows.Forms.Label -Property @{
        Text      = 'Type a short name, such as "proxy lab"'
        ForeColor = [System.Drawing.Color]::DimGray
        Location  = New-Object System.Drawing.Point(90, 38)
        Size      = New-Object System.Drawing.Size(370, 18)
    }
    $typeLabel = New-Object System.Windows.Forms.Label -Property @{ Text = 'Type'; AutoSize = $true; Location = New-Object System.Drawing.Point(10, 67) }
    $typePick = New-Object System.Windows.Forms.ComboBox -Property @{
        DropDownStyle = 'DropDownList'
        Location      = New-Object System.Drawing.Point(90, 64)
        Size          = New-Object System.Drawing.Size(290, 24)
    }
    foreach ($v in $modules.Values) { [void]$typePick.Items.Add($v) }
    $typePick.SelectedIndex = 0
    $tasksLabel = New-Object System.Windows.Forms.Label -Property @{ Text = 'Tasks'; AutoSize = $true; Location = New-Object System.Drawing.Point(388, 67) }
    $tasks = New-Object System.Windows.Forms.NumericUpDown -Property @{
        Minimum  = 1
        Maximum  = 12
        Value    = 3
        Enabled  = $false
        Location = New-Object System.Drawing.Point(425, 64)
        Size     = New-Object System.Drawing.Size(35, 24)
    }
    $pathLabel = New-Object System.Windows.Forms.Label -Property @{ Text = 'Create in'; AutoSize = $true; Location = New-Object System.Drawing.Point(10, 101) }
    $pathBox = New-Object System.Windows.Forms.TextBox -Property @{
        Text     = $Parent
        Location = New-Object System.Drawing.Point(90, 98)
        Size     = New-Object System.Drawing.Size(285, 24)
    }
    $browse = New-Object System.Windows.Forms.Button -Property @{
        Text     = 'Browse...'
        Location = New-Object System.Drawing.Point(385, 97)
        Size     = New-Object System.Drawing.Size(75, 26)
    }
    $openReadme = New-Object System.Windows.Forms.CheckBox -Property @{
        Text     = 'Open the kickoff card (README.md) when it''s created'
        Checked  = $true
        AutoSize = $true
        Location = New-Object System.Drawing.Point(90, 132)
    }
    $status = New-Object System.Windows.Forms.Label -Property @{
        ForeColor = [System.Drawing.Color]::Firebrick
        Location  = New-Object System.Drawing.Point(10, 160)
        Size      = New-Object System.Drawing.Size(450, 36)
    }
    $create = New-Object System.Windows.Forms.Button -Property @{
        Text     = 'Create'
        Location = New-Object System.Drawing.Point(304, 202)
        Size     = New-Object System.Drawing.Size(75, 26)
    }
    $cancel = New-Object System.Windows.Forms.Button -Property @{
        Text         = 'Cancel'
        DialogResult = 'Cancel'
        Location     = New-Object System.Drawing.Point(385, 202)
        Size         = New-Object System.Drawing.Size(75, 26)
    }

    $nameBox.Add_TextChanged({
        $folder = Get-ProjectFolderName -Name $nameBox.Text
        $folderLabel.Text = if ($folder) { "Folder: $folder" } else { 'Type a short name, such as "proxy lab"' }
    })
    $typePick.Add_SelectedIndexChanged({ $tasks.Enabled = ($typePick.SelectedIndex -eq 5) })
    $browse.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
            Description         = 'Where should the new project folder go?'
            ShowNewFolderButton = $true
        }
        if ($pathBox.Text -and (Test-Path -LiteralPath $pathBox.Text)) { $dialog.SelectedPath = $pathBox.Text }
        try { if ($dialog.ShowDialog($form) -eq 'OK') { $pathBox.Text = $dialog.SelectedPath } }
        finally { $dialog.Dispose() }
    })
    # Validate here, so a mistake is fixed in the dialog instead of failing afterwards.
    $create.Add_Click({
        $folder = Get-ProjectFolderName -Name $nameBox.Text
        $parentPath = $pathBox.Text.Trim()
        if (-not $folder) { $status.Text = 'The name needs at least one letter or number.'; return }
        if (-not $parentPath -or -not (Test-Path -LiteralPath $parentPath -PathType Container)) { $status.Text = 'Choose a folder that exists to create the project in.'; return }
        if (Test-Path -LiteralPath (Join-Path $parentPath $folder)) { $status.Text = "$folder already exists there. Choose another name."; return }
        $form.DialogResult = 'OK'
    })
    $form.AcceptButton = $create
    $form.CancelButton = $cancel
    $form.Add_Shown({
        $form.Activate()
        [void][ProjectLogUI.Foreground]::Take($form.Handle)
        [void]$nameBox.Focus()
    })
    $form.Controls.AddRange(@($nameLabel, $nameBox, $folderLabel, $typeLabel, $typePick, $tasksLabel, $tasks,
            $pathLabel, $pathBox, $browse, $openReadme, $status, $create, $cancel))

    try {
        if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
        return [pscustomobject]@{
            Name       = Get-ProjectFolderName -Name $nameBox.Text
            Module     = @($modules.Keys)[$typePick.SelectedIndex]
            Tasks      = [int]$tasks.Value
            Path       = $pathBox.Text.Trim()
            OpenReadme = $openReadme.Checked
        }
    }
    finally {
        $form.Dispose()
        $font.Dispose()
    }
}

Export-ModuleMember -Function Show-DescriptionPrompt, Show-NewProjectDialog
