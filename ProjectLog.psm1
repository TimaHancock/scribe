<#
    ProjectLog.psm1 - shared logic for Start-Scribe.ps1, Save-Screenshot.ps1 and
    New-Project.ps1. No UI here; dialogs are in ProjectLogUI.psm1.

    Keeps the active project, the recent-projects list and settings.json under
    %APPDATA%\ProjectLog, names evidence files, and appends entries to the
    project's log.md in the playbook's running-log format:

        ## 2026-10-26 (times local, UTC-4)
        14:32 TRY      Pointed the reverse proxy at port 8080.
              SAW      502 Bad Gateway. Proxy log:
                       connect() failed (111: Connection refused)
              PROOF    evidence/terminal/2026-10-26_1432_proxy-error.txt

    A new date heading is written when the day changes, a second entry in the
    same minute drops its time, and extra lines are indented under the text.
#>

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing   # Get-ImageHash

$script:CoreTags = @('TRY', 'SAW', 'PROOF', 'DECISION', 'DEAD', 'FIX', 'Q', 'REF', 'NEXT')
$script:ModuleTags = @(
    'RETURN', 'AI',                           # Academic assessment
    'CHANGE', 'COMMS', 'SCOPE', 'APPROVAL',   # IT project
    'SOURCE', 'CLAIM', 'VERIFIED'             # Technology evaluation
)
# When to use each tag, and a sample entry. Shown as the log box's tag tooltips.
$script:TagHelp = @{
    TRY      = @{ When = 'You run or change something';                               Example = 'Pointed the reverse proxy at port 8080' }
    SAW      = @{ When = 'You observe output, an error or a state; paste it exactly'; Example = '502 Bad Gateway. connect() failed (111: Connection refused)' }
    PROOF    = @{ When = 'You save an evidence file';                                 Example = 'evidence/terminal/2026-10-26_1432_proxy-error.txt' }
    DECISION = @{ When = 'You choose between options; link the record';              Example = 'Delete unused app registrations instead of disabling them; see decisions.md#3' }
    DEAD     = @{ When = 'An attempt fails; add the time it cost and the lesson';     Example = 'Copilot Notebook chats cannot reach the web. 40 min. Stay in individual chats.' }
    FIX      = @{ When = 'Something starts working';                                  Example = 'Proxy answers on 8080 after opening the firewall port' }
    Q        = @{ When = 'A question opens';                                          Example = 'Do service principals without sign-ins in 90 days still own resources?' }
    REF      = @{ When = 'A doc, post or tool helped';                                Example = 'Entra workload identities docs https://learn.microsoft.com/en-us/entra/workload-id/' }
    NEXT     = @{ When = 'You stop and note where to pick up';                        Example = 'Export the owner list and compare it with the HR roster' }
    RETURN   = @{ When = 'An assessment comes back with feedback';                    Example = 'Task 2 returned: section C needs a cited source for the risk rating' }
    AI       = @{ When = 'You use an AI tool; say what for and what you kept';        Example = 'Claude drafted the outline for section B; rewrote the conclusions myself' }
    CHANGE   = @{ When = 'A change request is raised or carried out';                 Example = 'CHG0012345 submitted: remove 14 stale app registrations' }
    COMMS    = @{ When = 'You tell or hear from stakeholders';                        Example = 'Emailed app owners the removal list; replies due Friday' }
    SCOPE    = @{ When = 'Scope is added, cut or clarified';                          Example = 'Out of scope: multi-tenant apps from vendors' }
    APPROVAL = @{ When = 'Someone signs off, or declines';                            Example = 'Security lead approved the cleanup procedure v1.2' }
    SOURCE   = @{ When = 'You find material on the technology being evaluated';       Example = 'Vendor whitepaper on conditional access for workload identities' }
    CLAIM    = @{ When = 'A source asserts something you need to test';               Example = 'Vendor says the API returns last sign-in for every service principal' }
    VERIFIED = @{ When = 'You confirm or refute a claim yourself';                   Example = 'Last sign-in is blank for apps created before 2023, so the claim is only partly true' }
}
$script:TagWidth = 8                           # tag column: 'TRY     ' + one space
$script:Indent = ' ' * (6 + $script:TagWidth + 1)   # aligns under the entry text

function Get-ProjectLogConfigPath {
    if ($env:PROJECTLOG_CONFIG) { return $env:PROJECTLOG_CONFIG }
    $base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
    return Join-Path $base 'ProjectLog\active-project.txt'
}

function Get-ProjectLogStatePath {
    <# A file in the folder that holds active-project.txt, settings.json and the other state files. #>
    param([Parameter(Mandatory)][string]$Name)
    return Join-Path (Split-Path -Parent (Get-ProjectLogConfigPath)) $Name
}

function Get-ActiveProject {
    <# Returns the active project's root folder, or $null if none is set or it no longer exists. #>
    $config = Get-ProjectLogConfigPath
    if (-not (Test-Path -LiteralPath $config)) { return $null }
    $root = (Get-Content -LiteralPath $config -Raw -Encoding UTF8).Trim()
    if ($root -and (Test-Path -LiteralPath $root -PathType Container)) { return $root }
    return $null
}

function Set-ActiveProject {
    <# Points every tool at a project folder and moves it to the top of the recent list. Its log is <folder>\log.md. #>
    param([Parameter(Mandatory)][string]$Path)
    $root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Not a folder: $root" }
    $utf8 = New-Object Text.UTF8Encoding $false
    $config = Get-ProjectLogConfigPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $config) -Force | Out-Null
    # Read the recent list before switching, so the previous project stays in it.
    $recent = @($root) + @(Get-RecentProjects -Count 9 | Where-Object { $_ -ne $root })
    [IO.File]::WriteAllText($config, $root, $utf8)
    [IO.File]::WriteAllText((Get-ProjectLogStatePath 'recent-projects.txt'), (($recent -join "`r`n") + "`r`n"), $utf8)
    return $root
}

function Get-RecentProjects {
    <# Recently active project folders, newest first, skipping any that no longer exist. #>
    param([int]$Count = 10)
    $list = @()
    $active = Get-ActiveProject
    if ($active) { $list += $active }
    $file = Get-ProjectLogStatePath 'recent-projects.txt'
    if (Test-Path -LiteralPath $file) { $list += @(Get-Content -LiteralPath $file -Encoding UTF8) }
    $seen = @{}   # case-insensitive keys, like Windows paths
    $out = foreach ($p in $list) {
        $p = $p.Trim()
        if (-not $p -or $seen.ContainsKey($p)) { continue }
        $seen[$p] = $true
        if (Test-Path -LiteralPath $p -PathType Container) { $p }
    }
    return @($out | Select-Object -First $Count)
}

# --- Settings -------------------------------------------------------------------

$script:DefaultSettings = [ordered]@{
    logHotkey      = 'Ctrl+Alt+L'
    previewLines   = 6
    extraTags      = @()
    watchClipboard = $true
    maxSlugLength  = 50
}
# Written by Initialize-ProjectLogSettings; keep in step with the defaults above.
$script:DefaultSettingsJson = @'
{
  "logHotkey": "Ctrl+Alt+L",
  "previewLines": 6,
  "extraTags": [],
  "watchClipboard": true,
  "maxSlugLength": 50
}
'@

function Test-SettingValue {
    <# Returns $null when a settings.json value is usable, otherwise why not. #>
    param([string]$Name, $Value)
    $isInt = $Value -is [int] -or $Value -is [long]
    switch ($Name) {
        'logHotkey'      { if ($Value -isnot [string] -or -not $Value.Trim()) { return 'should be text such as "Ctrl+Alt+L"' } }
        'previewLines'   { if (-not $isInt -or $Value -lt 0 -or $Value -gt 20) { return 'should be a whole number from 0 to 20' } }
        'maxSlugLength'  { if (-not $isInt -or $Value -lt 10 -or $Value -gt 120) { return 'should be a whole number from 10 to 120' } }
        'watchClipboard' { if ($Value -isnot [bool]) { return 'should be true or false' } }
        'extraTags' {
            foreach ($t in @($Value)) {
                if ($t -isnot [string] -or $t -notmatch '^\S+$') { return 'should be a list of single words, such as ["FLAG", "LOOT"]' }
            }
        }
    }
    return $null
}

function Get-ProjectLogSettings {
    <#
        settings.json merged over the defaults. A bad or unknown value is listed
        in Warnings and the default is used, so a typo never stops the tray app.
    #>
    $path = Get-ProjectLogStatePath 'settings.json'
    $settings = [ordered]@{}
    foreach ($k in $script:DefaultSettings.Keys) { $settings[$k] = $script:DefaultSettings[$k] }
    $warnings = @()

    $file = $null
    if (Test-Path -LiteralPath $path) {
        $text = [IO.File]::ReadAllText($path)
        if ($text.Trim()) {
            try { $file = $text | ConvertFrom-Json -ErrorAction Stop }
            catch { $warnings += "settings.json isn't valid JSON, so the defaults are in use. $($_.Exception.Message)" }
        }
    }
    if ($null -ne $file -and $file -isnot [pscustomobject]) {
        $warnings += 'settings.json should hold one { ... } object, so the defaults are in use.'
        $file = $null
    }
    if ($file) {
        foreach ($p in $file.PSObject.Properties) {
            $key = @($script:DefaultSettings.Keys | Where-Object { $_ -eq $p.Name })
            if (-not $key) { $warnings += "settings.json: unknown setting '$($p.Name)' was ignored."; continue }
            $problem = Test-SettingValue -Name $key[0] -Value $p.Value
            if ($problem) { $warnings += "settings.json: $($key[0]) $problem; using $(ConvertTo-Json -Compress -InputObject $settings[$key[0]])."; continue }
            $settings[$key[0]] = if ($key[0] -eq 'extraTags') { @($p.Value) } else { $p.Value }
        }
    }
    $settings['Path'] = $path
    $settings['Warnings'] = $warnings
    return [pscustomobject]$settings
}

function Initialize-ProjectLogSettings {
    <# Creates settings.json with the defaults if it doesn't exist yet. Returns its path. #>
    $path = Get-ProjectLogStatePath 'settings.json'
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        [IO.File]::WriteAllText($path, ($script:DefaultSettingsJson -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding $false))
    }
    return $path
}

# --- Clipboard watch lock -------------------------------------------------------

function Enter-ClipboardWatch {
    <#
        Claims the clipboard watch so Scribe and Save-Screenshot.ps1 never both
        prompt for the same screenshot. Returns the lock, or $null if another
        process holds it. Pass the lock to Exit-ClipboardWatch on the same thread.
    #>
    $mutex = New-Object Threading.Mutex($false, 'Local\ProjectLog.ClipboardWatch')
    try {
        if ($mutex.WaitOne(0)) { return $mutex }
    }
    catch [Threading.AbandonedMutexException] {
        return $mutex   # the last holder exited without releasing; the lock is ours now
    }
    $mutex.Dispose()
    return $null
}

function Exit-ClipboardWatch {
    param([Parameter(Mandatory)][Threading.Mutex]$Lock)
    $Lock.ReleaseMutex()
    $Lock.Dispose()
}

function Get-ProjectPaths {
    <# Log and screenshot locations for a project root. #>
    param([Parameter(Mandatory)][string]$Root)
    [pscustomobject]@{
        Root        = $Root
        Log         = Join-Path $Root 'log.md'
        Screenshots = Join-Path (Join-Path $Root 'evidence') 'screenshots'
    }
}

function ConvertTo-Slug {
    <#
        Lowercase-hyphen form for file and folder names, at most MaxLength characters.
        Returns '' when nothing usable is left; callers pick their own fallback.
    #>
    param([string]$Text, [int]$MaxLength = 50)
    # Fold accents to plain letters (e-acute -> e) before stripping everything else.
    $plain = -join ("$Text".Normalize([Text.NormalizationForm]::FormD).ToCharArray() |
        Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    $slug = ($plain.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if ($slug.Length -gt $MaxLength) {
        $cut = $slug.Substring(0, $MaxLength)
        # Prefer ending on a whole word when one ends reasonably close to the limit.
        $lastHyphen = $cut.LastIndexOf('-')
        if ($slug[$MaxLength] -ne '-' -and $lastHyphen -ge [int]($MaxLength * 0.6)) {
            $cut = $cut.Substring(0, $lastHyphen)
        }
        $slug = $cut.TrimEnd('-')
    }
    return $slug
}

# --- Evidence files ---------------------------------------------------------------

function Get-EvidenceName {
    <# "yyyy-MM-dd_HHmm_<slug>" for an evidence file, without the extension. #>
    param(
        [Parameter(Mandatory)][datetime]$When,
        [string]$Description,
        [int]$MaxSlugLength = 50,
        [string]$DefaultSlug = 'screenshot'
    )
    $slug = ConvertTo-Slug -Text $Description -MaxLength $MaxSlugLength
    if (-not $slug) { $slug = $DefaultSlug }
    return '{0}_{1}' -f $When.ToString('yyyy-MM-dd_HHmm'), $slug
}

function Get-UniquePath {
    <# <Dir>\<Base>.<Extension>, adding -2, -3, ... rather than overwriting. #>
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$Base,
        [string]$Extension = 'png'
    )
    $path = Join-Path $Dir "$Base.$Extension"
    $n = 2
    while (Test-Path -LiteralPath $path) {
        $path = Join-Path $Dir "$Base-$n.$Extension"
        $n++
    }
    return $path
}

function Add-ProofEntry {
    <#
        Logs a PROOF line for an evidence file. Files inside the log's folder are
        written relative to it with forward slashes, so they work as Markdown links.
    #>
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$Path,
        [datetime]$When = (Get-Date)
    )
    $logDir = Split-Path -Parent $LogPath
    $shown = $Path
    if ($Path.StartsWith($logDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        $shown = $Path.Substring($logDir.Length + 1) -replace '\\', '/'
    }
    return Add-LogEntry -LogPath $LogPath -Tag 'PROOF' -Text $shown -When $When
}

function Get-ImageHash {
    <# Identifies an image by size and pixels, so a re-copy of the same capture can be ignored. #>
    param([Parameter(Mandatory)][System.Drawing.Bitmap]$Image)
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

function Get-KnownLogTags {
    param([string[]]$ExtraTags = @())
    return @($script:CoreTags + $script:ModuleTags + @($ExtraTags | Where-Object { $_ } | ForEach-Object { $_.ToUpperInvariant() })) |
        Select-Object -Unique
}

function Get-LogTagHelp {
    <# Tooltip text for one tag: when to use it and an example entry. #>
    param([Parameter(Mandatory)][string]$Tag)
    $help = $script:TagHelp[$Tag.ToUpperInvariant()]
    if (-not $help) { return "Custom tag (added with -ExtraTags)." }
    return "Log it when: $($help.When)`n`nExample:`n$($Tag.ToUpperInvariant()) $($help.Example)"
}

function Split-LogInput {
    <#
        Splits "TAG text..." typed into the box. Returns Tag, Text and Error.
        The tag is the first word, matched case-insensitively against the known list.
    #>
    param([string]$InputText, [string[]]$KnownTags)
    $clean = ($InputText -replace "`r`n", "`n").Trim()
    if (-not $clean) { return [pscustomobject]@{ Tag = $null; Text = $null; Error = 'Type a tag, then the entry.' } }

    $m = [regex]::Match($clean, '^(\S+)[ \t]*(.*)$', 'Singleline')
    $tag = $m.Groups[1].Value.ToUpperInvariant()
    $text = $m.Groups[2].Value.Trim()

    if ($KnownTags -notcontains $tag) {
        return [pscustomobject]@{ Tag = $null; Text = $null; Error = "Unknown tag '$($m.Groups[1].Value)'. Known: $($KnownTags -join ' ')" }
    }
    if (-not $text) { return [pscustomobject]@{ Tag = $tag; Text = $null; Error = "Add the entry text after $tag." } }
    return [pscustomobject]@{ Tag = $tag; Text = $text; Error = $null }
}

function Get-UtcOffsetLabel {
    param([datetime]$When)
    $offset = [TimeZoneInfo]::Local.GetUtcOffset($When)
    $sign = if ($offset -lt [TimeSpan]::Zero) { '-' } else { '+' }
    $abs = $offset.Duration()
    $label = "UTC$sign$($abs.Hours)"
    if ($abs.Minutes) { $label += ':{0:D2}' -f $abs.Minutes }
    return $label
}

function Format-LogEntry {
    <# Builds the lines for one entry. -SameMinute blanks the time column. #>
    param(
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][datetime]$When,
        [switch]$SameMinute
    )
    $lines = @(($Text -replace "`r`n", "`n").Split("`n") | ForEach-Object { $_.TrimEnd() })
    while ($lines.Count -gt 1 -and -not $lines[-1]) { $lines = $lines[0..($lines.Count - 2)] }

    $time = if ($SameMinute) { '     ' } else { $When.ToString('HH:mm') }
    $out = @("{0} {1} {2}" -f $time, $Tag.PadRight($script:TagWidth), $lines[0])
    foreach ($line in $lines | Select-Object -Skip 1) {
        $out += if ($line) { $script:Indent + $line } else { '' }
    }
    return $out
}

function Add-LogEntry {
    <#
        Appends one entry to a log file, adding a date heading when the day changes.
        Returns the text that was written.
    #>
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$Text,
        [datetime]$When = (Get-Date)
    )
    $utf8 = New-Object Text.UTF8Encoding $false
    $existing = if (Test-Path -LiteralPath $LogPath) { [IO.File]::ReadAllText($LogPath, $utf8) } else { '' }

    # Find the last date heading, and the last stamped time under it.
    $lastDate = $null
    $lastStamp = $null
    foreach ($line in ($existing -replace "`r`n", "`n").Split("`n")) {
        $h = [regex]::Match($line, '^## (\d{4}-\d{2}-\d{2})')
        if ($h.Success) { $lastDate = $h.Groups[1].Value; $lastStamp = $null; continue }
        $t = [regex]::Match($line, '^(\d{2}:\d{2}) ')
        if ($t.Success) { $lastStamp = $t.Groups[1].Value }
    }

    $today = $When.ToString('yyyy-MM-dd')
    $sb = New-Object Text.StringBuilder
    if ($existing -and -not $existing.EndsWith("`n")) { [void]$sb.Append([Environment]::NewLine) }

    $sameMinute = $false
    if ($lastDate -ne $today) {
        # One blank line before the heading; New-Project's log.md already ends with one.
        $endsBlank = ($existing -replace "`r`n", "`n").EndsWith("`n`n")
        if ($existing.Trim() -and -not $endsBlank) { [void]$sb.Append([Environment]::NewLine) }
        [void]$sb.Append("## $today (times local, $(Get-UtcOffsetLabel $When))").Append([Environment]::NewLine)
    }
    elseif ($lastStamp -eq $When.ToString('HH:mm')) {
        $sameMinute = $true
    }

    foreach ($line in (Format-LogEntry -Tag $Tag -Text $Text -When $When -SameMinute:$sameMinute)) {
        [void]$sb.Append($line).Append([Environment]::NewLine)
    }

    $dir = Split-Path -Parent $LogPath
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::AppendAllText($LogPath, $sb.ToString(), $utf8)
    return $sb.ToString()
}

function Get-LogTail {
    <# The last few non-empty lines of a log, for the box's preview. #>
    param([Parameter(Mandatory)][string]$LogPath, [int]$Count = 6)
    if (-not (Test-Path -LiteralPath $LogPath)) { return @() }
    return @(Get-Content -LiteralPath $LogPath -Encoding UTF8 | Where-Object { $_.Trim() } | Select-Object -Last $Count)
}

Export-ModuleMember -Function Get-ProjectLogStatePath, Get-ActiveProject, Set-ActiveProject, Get-RecentProjects, Get-ProjectPaths,
    Get-ProjectLogSettings, Initialize-ProjectLogSettings, Enter-ClipboardWatch, Exit-ClipboardWatch,
    ConvertTo-Slug, Get-EvidenceName, Get-UniquePath, Add-ProofEntry, Get-ImageHash,
    Get-KnownLogTags, Get-LogTagHelp, Split-LogInput, Format-LogEntry, Add-LogEntry, Get-LogTail
