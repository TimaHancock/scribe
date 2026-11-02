<#
    ProjectLog.psm1 - shared helpers for Start-LogBox.ps1 and Save-Screenshot.ps1.

    Keeps one "active project" setting and appends entries to that project's
    log.md in the playbook's running-log format:

        ## 2026-10-26 (times local, UTC-4)
        14:32 TRY      Pointed the reverse proxy at port 8080.
              SAW      502 Bad Gateway. Proxy log:
                       connect() failed (111: Connection refused)
              PROOF    evidence/terminal/2026-10-26_1432_proxy-error.txt

    A new date heading is written when the day changes, a second entry in the
    same minute drops its time, and extra lines are indented under the text.
#>

Set-StrictMode -Version Latest

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

function Get-ActiveProject {
    <# Returns the active project's root folder, or $null if none is set or it no longer exists. #>
    $config = Get-ProjectLogConfigPath
    if (-not (Test-Path -LiteralPath $config)) { return $null }
    $root = (Get-Content -LiteralPath $config -Raw -Encoding UTF8).Trim()
    if ($root -and (Test-Path -LiteralPath $root -PathType Container)) { return $root }
    return $null
}

function Set-ActiveProject {
    <# Points both tools at a project folder. Its log is <folder>\log.md. #>
    param([Parameter(Mandatory)][string]$Path)
    $root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Not a folder: $root" }
    $config = Get-ProjectLogConfigPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $config) -Force | Out-Null
    [IO.File]::WriteAllText($config, $root, (New-Object Text.UTF8Encoding $false))
    return $root
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

function Get-KnownLogTags {
    param([string[]]$ExtraTags = @())
    return @($script:CoreTags + $script:ModuleTags + ($ExtraTags | ForEach-Object { $_.ToUpperInvariant() })) |
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
        if ($existing.Trim()) { [void]$sb.Append([Environment]::NewLine) }
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

Export-ModuleMember -Function Get-ActiveProject, Set-ActiveProject, Get-ProjectPaths, Get-KnownLogTags, Get-LogTagHelp,
    Split-LogInput, Format-LogEntry, Add-LogEntry, Get-LogTail
