<#
    ProjectLog.psm1 - shared logic for Start-Scribe.ps1, Save-Screenshot.ps1 and
    New-Project.ps1. No UI here; dialogs are in ProjectLogUI.psm1.

    Keeps the active project, the recent-projects list and settings.json under
    %APPDATA%\ProjectLog, names evidence files, and appends entries to the
    project's log.md in one of the playbook's running-log formats.

    obsidian (the default for new logs) renders as a list in Obsidian; extra
    lines go in a code block, and PROOF embeds the file:

        ## 2026-10-26 (times local, UTC-4)
        - 14:32 **TRY** Pointed the reverse proxy at port 8080
        - 14:33 **SAW** 502 Bad Gateway
          ```
          connect() failed (111: Connection refused)
          ```
        - 14:33 **PROOF** ![[2026-10-26_1433_proxy-502.png]]

    plain lines up in columns for a text editor; a second entry in the same
    minute drops its time, and extra lines are indented under the text:

        ## 2026-10-26 (times local, UTC-4)
        14:32 TRY      Pointed the reverse proxy at port 8080.
              SAW      502 Bad Gateway. Proxy log:
                       connect() failed (111: Connection refused)
              PROOF    evidence/terminal/2026-10-26_1432_proxy-error.txt

    A log keeps the format of the entries already in it, so the two never mix.
    A new date heading is written when the day changes.
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
    <#
        Points every tool at a project folder and moves it to the top of the
        recent list. Its log is <folder>\log.md. A running work session moves
        with it: it ends on the old project and starts on this one, so each log
        gets its own share of the time.
    #>
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

    $open = Get-ProjectSession
    if ($open -and $open.Project -ne $root) {
        # The switch has happened either way; a log that can't be written shouldn't undo it.
        try {
            $when = Get-Date
            # A deleted project gets no "Ended" line; logging would recreate its folder.
            if (Test-Path -LiteralPath $open.Project -PathType Container) {
                [void](Stop-ProjectSession -When $when -Reason "switched to $(Split-Path -Leaf $root)")
            }
            else { Remove-Item -LiteralPath (Get-ProjectLogStatePath 'session.json') -Force }
            Start-ProjectSession -Root $root -When $when
        }
        catch { Write-Warning "Couldn't move the work session to $(Split-Path -Leaf $root): $($_.Exception.Message)" }
    }
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

function Get-ProjectFolders {
    <#
        Project folders directly under a projects folder, most recently logged
        first. Only folders with a log.md count, so other notes in a vault are left out.
    #>
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Container)) { return @() }
    $found = foreach ($dir in Get-ChildItem -LiteralPath $Path -Directory) {
        $log = Join-Path $dir.FullName 'log.md'
        if (Test-Path -LiteralPath $log -PathType Leaf) {
            [pscustomobject]@{ Path = $dir.FullName; Logged = (Get-Item -LiteralPath $log).LastWriteTimeUtc }
        }
    }
    return @($found | Sort-Object Logged -Descending | ForEach-Object { $_.Path })
}

function Get-ProjectChoices {
    <# Recent projects first, then the rest of the projects folder, without duplicates. #>
    param([string]$ProjectsFolder)
    $seen = @{}
    $out = foreach ($p in @(Get-RecentProjects) + @(Get-ProjectFolders -Path $ProjectsFolder)) {
        if ($seen.ContainsKey($p)) { continue }
        $seen[$p] = $true
        $p
    }
    return @($out)
}

# --- Obsidian ---------------------------------------------------------------------

function Get-ObsidianVault {
    <# The vault folder (the one holding .obsidian) that contains Path, or $null. #>
    param([Parameter(Mandatory)][string]$Path)
    $dir = $Path
    if (Test-Path -LiteralPath $dir -PathType Leaf) { $dir = Split-Path -Parent $dir }
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir '.obsidian') -PathType Container) { return $dir }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Get-ObsidianUri {
    <# obsidian:// link that opens a file in whichever vault holds it. #>
    param([Parameter(Mandatory)][string]$Path)
    return 'obsidian://open?path=' + [Uri]::EscapeDataString($Path)
}

function Set-FrontmatterValue {
    <#
        Sets "Name: Value" in a note's YAML frontmatter. Only changes a key that
        is already there, so notes that never asked for it are left alone.
        Returns whether it wrote.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $utf8 = New-Object Text.UTF8Encoding $false
    $text = [IO.File]::ReadAllText($Path, $utf8)
    $m = [regex]::Match($text, '\A---\r?\n(.*?)\r?\n---[ \t]*(\r?\n|\z)', 'Singleline')
    if (-not $m.Success) { return $false }
    $body = $m.Groups[1].Value
    $key = New-Object regex ('(?m)^' + [regex]::Escape($Name) + '[ \t]*:.*?(?=\r?$)')
    if (-not $key.IsMatch($body)) { return $false }
    $new = $key.Replace($body, "${Name}: $Value".Replace('$', '$$'), 1)
    if ($new -ceq $body) { return $false }
    $text = $text.Substring(0, $m.Groups[1].Index) + $new + $text.Substring($m.Groups[1].Index + $m.Groups[1].Length)
    [IO.File]::WriteAllText($Path, $text, $utf8)
    return $true
}

# --- Settings -------------------------------------------------------------------

$script:DefaultSettings = [ordered]@{
    logHotkey      = 'Ctrl+Alt+L'
    previewLines   = 6
    extraTags      = @()
    watchClipboard = $true
    maxSlugLength  = 50
    logFormat      = 'obsidian'
    projectsFolder = ''
    pasteHotkey    = 'Ctrl+Alt+V'
    idleReminderMinutes = 15
}
# Written by Initialize-ProjectLogSettings; keep in step with the defaults above.
$script:DefaultSettingsJson = @'
{
  "logHotkey": "Ctrl+Alt+L",
  "pasteHotkey": "Ctrl+Alt+V",
  "previewLines": 6,
  "extraTags": [],
  "watchClipboard": true,
  "maxSlugLength": 50,
  "logFormat": "obsidian",
  "projectsFolder": "",
  "idleReminderMinutes": 15
}
'@
$script:LogFormats = @('obsidian', 'plain')

function Test-SettingValue {
    <# Returns $null when a settings.json value is usable, otherwise why not. #>
    param([string]$Name, $Value)
    $isInt = $Value -is [int] -or $Value -is [long]
    switch ($Name) {
        'logHotkey'      { if ($Value -isnot [string] -or -not $Value.Trim()) { return 'should be text such as "Ctrl+Alt+L"' } }
        'pasteHotkey'    { if ($Value -isnot [string]) { return 'should be text such as "Ctrl+Alt+V", or "" for none' } }
        'idleReminderMinutes' { if (-not $isInt -or $Value -lt 0 -or $Value -gt 240) { return 'should be a whole number of minutes from 0 (off) to 240' } }
        'previewLines'   { if (-not $isInt -or $Value -lt 0 -or $Value -gt 20) { return 'should be a whole number from 0 to 20' } }
        'maxSlugLength'  { if (-not $isInt -or $Value -lt 10 -or $Value -gt 120) { return 'should be a whole number from 10 to 120' } }
        'watchClipboard' { if ($Value -isnot [bool]) { return 'should be true or false' } }
        'logFormat'      { if ($script:LogFormats -notcontains $Value) { return 'should be "obsidian" or "plain"' } }
        'projectsFolder' { if ($Value -isnot [string]) { return 'should be a folder path in quotes, with \\ for each backslash, or ""' } }
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
            $settings[$key[0]] = switch ($key[0]) {
                'extraTags' { @($p.Value) }
                'logFormat' { $p.Value.ToLowerInvariant() }
                default     { $p.Value }
            }
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

function Get-ProjectFolderName {
    <# "YYYY-MM-<slug>" for a new project, or '' when the name has no letters or digits. #>
    param([string]$Name, [datetime]$When = (Get-Date))
    $slug = ConvertTo-Slug $Name
    if (-not $slug) { return '' }
    # Don't double the date prefix if one was typed.
    if ($slug -notmatch '^\d{4}-\d{2}-') { $slug = '{0}-{1}' -f $When.ToString('yyyy-MM'), $slug }
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
    <# <Dir>\<Base>.<Extension>, adding -2, -3, ... rather than overwriting. An empty Extension means none. #>
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$Base,
        [AllowEmptyString()][string]$Extension = 'png'
    )
    $suffix = if ($Extension) { ".$Extension" } else { '' }
    $path = Join-Path $Dir "$Base$suffix"
    $n = 2
    while (Test-Path -LiteralPath $path) {
        $path = Join-Path $Dir "$Base-$n$suffix"
        $n++
    }
    return $path
}

function Add-ProofEntry {
    <#
        Logs a PROOF line for an evidence file inside the log's folder: an
        Obsidian embed (![[name.png]]) in an obsidian log, or the relative path
        with forward slashes in a plain one. Evidence names carry the time, so
        the bare file name is enough for Obsidian to find it. A file elsewhere
        is logged with its full path.
    #>
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$Path,
        [datetime]$When = (Get-Date),
        [ValidateSet('obsidian', 'plain')][string]$DefaultFormat
    )
    $format = Resolve-LogFormat -LogPath $LogPath -DefaultFormat $DefaultFormat
    $logDir = Split-Path -Parent $LogPath
    $shown = $Path
    if ($Path.StartsWith($logDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        if ($format -eq 'obsidian') {
            $embed = if ([IO.Path]::GetExtension($Path) -match '^\.(png|jpe?g|gif|bmp|webp|svg)$') { '!' } else { '' }
            $shown = "$embed[[$(Split-Path -Leaf $Path)]]"
        }
        else {
            $shown = $Path.Substring($logDir.Length + 1) -replace '\\', '/'
        }
    }
    return Add-LogEntry -LogPath $LogPath -Tag 'PROOF' -Text $shown -When $When -DefaultFormat $format
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
    <# Builds the lines for one entry. -SameMinute blanks the time column of a plain entry. #>
    param(
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][datetime]$When,
        [switch]$SameMinute,
        [ValidateSet('obsidian', 'plain')][string]$Format = 'plain'
    )
    $lines = @(($Text -replace "`r`n", "`n").Split("`n") | ForEach-Object { $_.TrimEnd() })
    while ($lines.Count -gt 1 -and -not $lines[-1]) { $lines = $lines[0..($lines.Count - 2)] }

    if ($Format -eq 'obsidian') {
        $out = @("- {0} **{1}** {2}" -f $When.ToString('HH:mm'), $Tag, $lines[0])
        $rest = @($lines | Select-Object -Skip 1)
        while ($rest.Count -and -not $rest[0]) { $rest = @($rest | Select-Object -Skip 1) }
        if ($rest.Count) {
            # Extra lines are usually pasted output: keep them verbatim in a code
            # block nested under the item, with a fence longer than any inside.
            $longest = 0
            foreach ($m in [regex]::Matches(($rest -join "`n"), '`+')) { $longest = [Math]::Max($longest, $m.Length) }
            $fence = '`' * [Math]::Max(3, $longest + 1)
            $out += "  $fence"
            foreach ($line in $rest) { $out += if ($line) { "  $line" } else { '' } }
            $out += "  $fence"
        }
        return $out
    }

    $time = if ($SameMinute) { '     ' } else { $When.ToString('HH:mm') }
    $out = @("{0} {1} {2}" -f $time, $Tag.PadRight($script:TagWidth), $lines[0])
    foreach ($line in $lines | Select-Object -Skip 1) {
        $out += if ($line) { $script:Indent + $line } else { '' }
    }
    return $out
}

function Find-LogFormat {
    <# 'obsidian' or 'plain' from the last stamped entry in a log's text, or $null if it has none. #>
    param([string]$Text)
    $lines = ($Text -replace "`r`n", "`n").Split("`n")
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '^- \d{2}:\d{2} ') { return 'obsidian' }
        if ($lines[$i] -match '^\d{2}:\d{2} ') { return 'plain' }
    }
    return $null
}

function Resolve-LogFormat {
    <# The format to write a log in: its own if it has entries, else DefaultFormat, else the logFormat setting. #>
    param([Parameter(Mandatory)][string]$LogPath, [string]$DefaultFormat)
    if (Test-Path -LiteralPath $LogPath) {
        $found = Find-LogFormat -Text ([IO.File]::ReadAllText($LogPath, (New-Object Text.UTF8Encoding $false)))
        if ($found) { return $found }
    }
    if ($DefaultFormat) { return $DefaultFormat }
    return (Get-ProjectLogSettings).logFormat
}

function Add-LogEntry {
    <#
        Appends one entry to a log file, adding a date heading when the day changes.
        The entry follows the log's existing format; DefaultFormat (or the
        logFormat setting) is only used for a log with no entries yet.
        On a new day it also sets "updated:" in the README beside the log, if
        its frontmatter has one. Returns the text that was written.
    #>
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$Text,
        [datetime]$When = (Get-Date),
        [ValidateSet('obsidian', 'plain')][string]$DefaultFormat
    )
    $utf8 = New-Object Text.UTF8Encoding $false
    $existing = if (Test-Path -LiteralPath $LogPath) { [IO.File]::ReadAllText($LogPath, $utf8) } else { '' }
    $format = Find-LogFormat -Text $existing
    if (-not $format) { $format = if ($DefaultFormat) { $DefaultFormat } else { (Get-ProjectLogSettings).logFormat } }

    # Find the last date heading, and the last stamped time under it.
    $lastDate = $null
    $lastStamp = $null
    foreach ($line in ($existing -replace "`r`n", "`n").Split("`n")) {
        $h = [regex]::Match($line, '^## (\d{4}-\d{2}-\d{2})')
        if ($h.Success) { $lastDate = $h.Groups[1].Value; $lastStamp = $null; continue }
        $t = [regex]::Match($line, '^(?:- )?(\d{2}:\d{2}) ')
        if ($t.Success) { $lastStamp = $t.Groups[1].Value }
    }

    $today = $When.ToString('yyyy-MM-dd')
    $sb = New-Object Text.StringBuilder
    if ($existing -and -not $existing.EndsWith("`n")) { [void]$sb.Append([Environment]::NewLine) }

    $sameMinute = $false
    $newDay = $lastDate -ne $today
    if ($newDay) {
        # One blank line before the heading; New-Project's log.md already ends with one.
        $endsBlank = ($existing -replace "`r`n", "`n").EndsWith("`n`n")
        if ($existing.Trim() -and -not $endsBlank) { [void]$sb.Append([Environment]::NewLine) }
        [void]$sb.Append("## $today (times local, $(Get-UtcOffsetLabel $When))").Append([Environment]::NewLine)
    }
    elseif ($lastStamp -eq $When.ToString('HH:mm')) {
        $sameMinute = $true
    }

    foreach ($line in (Format-LogEntry -Tag $Tag -Text $Text -When $When -SameMinute:$sameMinute -Format $format)) {
        [void]$sb.Append($line).Append([Environment]::NewLine)
    }

    $dir = Split-Path -Parent $LogPath
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::AppendAllText($LogPath, $sb.ToString(), $utf8)

    if ($newDay -and $dir) {
        # Feeds the dashboard's last-activity column. The entry is already safe,
        # so a README that's locked or odd never fails the log.
        try { [void](Set-FrontmatterValue -Path (Join-Path $dir 'README.md') -Name 'updated' -Value $today) } catch { }
    }
    return $sb.ToString()
}

function ConvertTo-ObsidianLog {
    <#
        Rewrites a plain-format log's text in the obsidian format. Headings and
        any other lines are kept; PROOF paths to images become embeds when
        -ProjectRoot is given and the file is there.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text, [string]$ProjectRoot)
    $lines = ($Text -replace "`r`n", "`n").Split("`n")
    $out = New-Object Collections.Generic.List[string]
    $entry = $null
    $time = '00:00'
    $flush = {
        if ($entry) {
            # Blank lines after an entry separate it from what follows; keep them outside the entry.
            $trailing = 0
            while ($entry.Lines.Count -gt 1 -and -not $entry.Lines[-1]) {
                $entry.Lines = @($entry.Lines | Select-Object -First ($entry.Lines.Count - 1))
                $trailing++
            }
            $when = [datetime]::ParseExact($entry.Time, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
            $text = $entry.Lines -join "`n"
            if ($entry.Tag -eq 'PROOF' -and $ProjectRoot -and $entry.Lines.Count -eq 1) {
                $file = Join-Path $ProjectRoot ($text -replace '/', '\')
                if ($text -notmatch '^[A-Za-z]:|^\\\\' -and (Test-Path -LiteralPath $file -PathType Leaf)) {
                    $embed = if ($text -match '\.(png|jpe?g|gif|bmp|webp|svg)$') { '!' } else { '' }
                    $text = "$embed[[$(Split-Path -Leaf $file)]]"
                }
            }
            foreach ($l in (Format-LogEntry -Tag $entry.Tag -Text $text -When $when -Format obsidian)) { $out.Add($l) }
            for ($i = 0; $i -lt $trailing; $i++) { $out.Add('') }
        }
    }
    foreach ($line in $lines) {
        $m = [regex]::Match($line, '^(\d{2}:\d{2}| {5}) (\S+) +(.*)$')
        if ($m.Success -and $m.Groups[2].Value -cmatch '^[A-Z]+$') {
            . $flush
            if ($m.Groups[1].Value.Trim()) { $time = $m.Groups[1].Value }
            $entry = @{ Time = $time; Tag = $m.Groups[2].Value; Lines = @($m.Groups[3].Value) }
            continue
        }
        if ($entry -and ($line.StartsWith($script:Indent) -or -not $line.Trim())) {
            $entry.Lines += if ($line.Trim()) { $line.Substring($script:Indent.Length) } else { '' }
            continue
        }
        . $flush
        $entry = $null
        if ($line -match '^## \d{4}-\d{2}-\d{2}') { $time = '00:00' }
        $out.Add($line)
    }
    . $flush
    return ($out -join "`n")
}

# --- Playbook templates -------------------------------------------------------------

$script:PlaybookRoot = Join-Path $PSScriptRoot 'documentation-playbook'

function Get-PlaybookTemplate {
    <#
        The first ```markdown block in a playbook file (relative to
        documentation-playbook\), after the line Heading when one is given.
        Read as UTF-8, so the playbook's own characters survive Windows
        PowerShell's ANSI default.
    #>
    param([Parameter(Mandatory)][string]$File, [string]$Heading)
    $path = Join-Path $script:PlaybookRoot $File
    if (-not (Test-Path -LiteralPath $path)) { throw "Playbook template not found: $path" }
    $lines = [IO.File]::ReadAllLines($path, (New-Object Text.UTF8Encoding $false))
    $i = 0
    if ($Heading) {
        while ($i -lt $lines.Count -and $lines[$i].Trim() -ne $Heading) { $i++ }
    }
    while ($i -lt $lines.Count -and $lines[$i] -notmatch '^(`{3,})markdown\s*$') { $i++ }
    if ($i -ge $lines.Count) { throw "No markdown block$(if ($Heading) { " after '$Heading'" }) in $path" }
    $fence = $Matches[1]
    $block = for ($j = $i + 1; $j -lt $lines.Count -and $lines[$j] -ne $fence; $j++) { $lines[$j] }
    return (@($block) -join "`n") + "`n"
}

# --- Pasted text, dropped files and decision records --------------------------------

function Add-PastedEntry {
    <#
        Logs copied text or command output as one entry, verbatim. Without a
        Note, a single line goes inline (as code in an obsidian log) and
        several lines go in a code block under "Pasted N lines:". With a Note,
        the note is the entry's text and all of the output goes in the block.
        More than MaxLines is saved to evidence\terminal as a .txt file
        instead, with a short entry and a PROOF line, so a huge paste can't
        swamp the log. Returns the path of a saved file, or $null.
    #>
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$Text,
        [string]$Tag = 'SAW',
        [string]$Note,
        [datetime]$When = (Get-Date),
        [ValidateSet('obsidian', 'plain')][string]$DefaultFormat,
        [int]$MaxLines = 50
    )
    $Note = "$Note".Trim()
    $lines = @(($Text -replace "`r`n", "`n").Split("`n") | ForEach-Object { $_.TrimEnd() })
    while ($lines.Count -and -not $lines[0]) { $lines = @($lines | Select-Object -Skip 1) }
    while ($lines.Count -and -not $lines[-1]) { $lines = @($lines | Select-Object -First ($lines.Count - 1)) }
    if (-not $lines.Count) { throw 'The clipboard text is empty.' }
    $format = Resolve-LogFormat -LogPath $LogPath -DefaultFormat $DefaultFormat

    if ($lines.Count -gt $MaxLines) {
        $dir = Join-Path (Join-Path (Split-Path -Parent $LogPath) 'evidence') 'terminal'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $file = Get-UniquePath -Dir $dir -Base (Get-EvidenceName -When $When -DefaultSlug 'pasted') -Extension 'txt'
        [IO.File]::WriteAllText($file, (($lines -join "`r`n") + "`r`n"), (New-Object Text.UTF8Encoding $false))
        $summary = if ($Note) { "$Note ($($lines.Count) lines, saved as evidence)" } else { "Pasted $($lines.Count) lines, saved as evidence:" }
        [void](Add-LogEntry -LogPath $LogPath -Tag $Tag -Text $summary -When $When -DefaultFormat $format)
        [void](Add-ProofEntry -LogPath $LogPath -Path $file -When $When -DefaultFormat $format)
        return $file
    }
    if ($Note) {
        $entry = (@($Note) + $lines) -join "`n"
    }
    elseif ($lines.Count -eq 1) {
        $entry = $lines[0].Trim()
        if ($format -eq 'obsidian') {
            # Inline code needs a backtick run longer than any inside, and a space when the text starts or ends with one.
            $longest = 0
            foreach ($m in [regex]::Matches($entry, '`+')) { $longest = [Math]::Max($longest, $m.Length) }
            $tick = '`' * ($longest + 1)
            $pad = if ($entry -match '^`|`$') { ' ' } else { '' }
            $entry = "$tick$pad$entry$pad$tick"
        }
    }
    else {
        $entry = (@("Pasted $($lines.Count) lines:") + $lines) -join "`n"
    }
    [void](Add-LogEntry -LogPath $LogPath -Tag $Tag -Text $entry -When $When -DefaultFormat $format)
    return $null
}

function Copy-EvidenceFile {
    <#
        Copies a file into the project's evidence\<Folder> under the naming rule,
        keeping its extension. The copy is byte for byte, so the file keeps any
        metadata it already had. Returns the new path.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path,
        [datetime]$When = (Get-Date),
        [string]$Folder = 'exports',
        [int]$MaxSlugLength = 50
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Not a file: $Path" }
    $dir = Join-Path (Join-Path $Root 'evidence') $Folder
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $base = Get-EvidenceName -When $When -Description ([IO.Path]::GetFileNameWithoutExtension($Path)) -MaxSlugLength $MaxSlugLength -DefaultSlug 'file'
    $target = Get-UniquePath -Dir $dir -Base $base -Extension ([IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant())
    Copy-Item -LiteralPath $Path -Destination $target
    return $target
}

function New-DecisionRecord {
    <#
        Creates decisions\NNN-<slug>.md from the playbook's decision-record
        template, numbered after the highest record already there, with the
        title, date and decision filled in. Returns the new path.
        A coding project keeps its records with the code, in
        repo\docs\decisions, whenever that folder exists.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Decision,
        [datetime]$When = (Get-Date)
    )
    $dir = Join-Path $Root 'decisions'
    $inRepo = Join-Path (Join-Path (Join-Path $Root 'repo') 'docs') 'decisions'
    if (Test-Path -LiteralPath $inRepo -PathType Container) { $dir = $inRepo }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $last = 0
    foreach ($f in Get-ChildItem -LiteralPath $dir -File) {
        if ($f.Name -match '^(\d{3})-') { $last = [Math]::Max($last, [int]$Matches[1]) }
    }
    $number = '{0:D3}' -f ($last + 1)

    # The heading is a short noun phrase: the decision up to its first reason.
    $title = ($Decision -split '[;\r\n]')[0].Trim().TrimEnd('.')
    if ($title.Length -gt 80) { $title = $title.Substring(0, 77).TrimEnd() + '...' }
    $slug = ConvertTo-Slug -Text $title -MaxLength 50
    if (-not $slug) { $slug = 'decision' }
    $path = Get-UniquePath -Dir $dir -Base "$number-$slug" -Extension 'md'

    $text = Get-PlaybookTemplate 'templates\03-decision-record.md'
    $text = $text -replace '(?m)^# NNN\. <[^>\r\n]*>', "# $number. $($title.Replace('$', '$$'))"
    $text = $text.Replace('YYYY-MM-DD', $When.ToString('yyyy-MM-dd'))
    $text = $text -replace 'proposed \| accepted \| superseded by NNN', 'accepted'
    $text = $text -replace '(?m)^We will \.\.\..*$', $Decision.Trim().Replace('$', '$$')
    [IO.File]::WriteAllText($path, ($text -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding $false))
    return $path
}

function Get-NoteLink {
    <# How a log points at a note in the project: [[name]] in an obsidian log, the relative path in a plain one. #>
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('obsidian', 'plain')][string]$DefaultFormat
    )
    if ((Resolve-LogFormat -LogPath $LogPath -DefaultFormat $DefaultFormat) -eq 'obsidian') {
        return "[[$([IO.Path]::GetFileNameWithoutExtension($Path))]]"
    }
    $logDir = Split-Path -Parent $LogPath
    if ($Path.StartsWith($logDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($logDir.Length + 1) -replace '\\', '/'
    }
    return $Path
}

# --- Work sessions ------------------------------------------------------------------
#
# A session is logged as two SESSION entries, "Started" and "Ended after 1h 25m",
# so time spent can be read back from the log. session.json in the state folder
# holds the one open session, so it survives a Scribe restart.

function Format-SessionLength {
    param([Parameter(Mandatory)][TimeSpan]$Length)
    $minutes = [int][Math]::Max(0, [Math]::Round($Length.TotalMinutes))
    return '{0}h {1:D2}m' -f [Math]::Floor($minutes / 60), ($minutes % 60)
}

function Get-ProjectSession {
    <# The open session (Project, Started), or $null. #>
    $file = Get-ProjectLogStatePath 'session.json'
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    try {
        $s = [IO.File]::ReadAllText($file) | ConvertFrom-Json -ErrorAction Stop
        # PowerShell 7 turns the ISO date into a DateTime already; 5.1 leaves it a string.
        $started = $s.started
        if ($started -isnot [datetime]) { $started = [datetime]::ParseExact($started, 's', [Globalization.CultureInfo]::InvariantCulture) }
        return [pscustomobject]@{ Project = [string]$s.project; Started = $started }
    }
    catch { return $null }
}

function Start-ProjectSession {
    <# Opens a session on a project and logs SESSION Started. Throws if one is already open. #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [datetime]$When = (Get-Date),
        [ValidateSet('obsidian', 'plain')][string]$DefaultFormat
    )
    $open = Get-ProjectSession
    if ($open) { throw "A session on $(Split-Path -Leaf $open.Project) is already running." }
    $file = Get-ProjectLogStatePath 'session.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force | Out-Null
    $json = ConvertTo-Json -InputObject ([ordered]@{ project = $Root; started = $When.ToString('s') })
    [IO.File]::WriteAllText($file, $json, (New-Object Text.UTF8Encoding $false))
    $log = (Get-ProjectPaths -Root $Root).Log
    [void](Add-LogEntry -LogPath $log -Tag 'SESSION' -Text 'Started' -When $When -DefaultFormat (Resolve-LogFormat -LogPath $log -DefaultFormat $DefaultFormat))
}

function Stop-ProjectSession {
    <#
        Closes the open session: logs NEXT (when given), then SESSION Ended after
        <length> (and the Reason, when given), in the project the session
        started in. Returns the length.
    #>
    param(
        [string]$Next,
        [datetime]$When = (Get-Date),
        [ValidateSet('obsidian', 'plain')][string]$DefaultFormat,
        [string]$Reason
    )
    $open = Get-ProjectSession
    if (-not $open) { throw 'No session is running.' }
    $log = (Get-ProjectPaths -Root $open.Project).Log
    $format = Resolve-LogFormat -LogPath $log -DefaultFormat $DefaultFormat
    $length = $When - $open.Started
    if ($Next -and $Next.Trim()) {
        [void](Add-LogEntry -LogPath $log -Tag 'NEXT' -Text $Next.Trim() -When $When -DefaultFormat $format)
    }
    $text = "Ended after $(Format-SessionLength $length)"
    if ($Reason) { $text += ", $Reason" }
    [void](Add-LogEntry -LogPath $log -Tag 'SESSION' -Text $text -When $When -DefaultFormat $format)
    Remove-Item -LiteralPath (Get-ProjectLogStatePath 'session.json') -Force
    return $length
}

function Get-SessionTime {
    <# Total time of the ended sessions in a log, for the writeup's "Time spent". #>
    param([Parameter(Mandatory)][string]$LogPath)
    $total = [TimeSpan]::Zero
    if (-not (Test-Path -LiteralPath $LogPath)) { return $total }
    foreach ($line in [IO.File]::ReadAllLines($LogPath, (New-Object Text.UTF8Encoding $false))) {
        $m = [regex]::Match($line, '^(?:- )?(?:\d{2}:\d{2}| {5}) (?:\*\*SESSION\*\*|SESSION +) ?Ended after (\d+)h (\d+)m')
        if ($m.Success) { $total += New-Object TimeSpan ([int]$m.Groups[1].Value), ([int]$m.Groups[2].Value), 0 }
    }
    return $total
}

function Get-LogTail {
    <# The last few non-empty lines of a log, for the box's preview. #>
    param([Parameter(Mandatory)][string]$LogPath, [int]$Count = 6)
    if (-not (Test-Path -LiteralPath $LogPath)) { return @() }
    return @(Get-Content -LiteralPath $LogPath -Encoding UTF8 | Where-Object { $_.Trim() } | Select-Object -Last $Count)
}

Export-ModuleMember -Function Get-ProjectLogStatePath, Get-ActiveProject, Set-ActiveProject, Get-RecentProjects, Get-ProjectPaths,
    Get-ProjectFolders, Get-ProjectChoices, Get-ObsidianVault, Get-ObsidianUri, Set-FrontmatterValue,
    Get-ProjectLogSettings, Initialize-ProjectLogSettings, Enter-ClipboardWatch, Exit-ClipboardWatch,
    ConvertTo-Slug, Get-ProjectFolderName, Get-EvidenceName, Get-UniquePath, Add-ProofEntry, Get-ImageHash,
    Get-KnownLogTags, Get-LogTagHelp, Split-LogInput, Format-LogEntry, Find-LogFormat, Resolve-LogFormat,
    Add-LogEntry, ConvertTo-ObsidianLog, Get-LogTail,
    Get-PlaybookTemplate, Add-PastedEntry, Copy-EvidenceFile, New-DecisionRecord, Get-NoteLink,
    Format-SessionLength, Get-ProjectSession, Start-ProjectSession, Stop-ProjectSession, Get-SessionTime
