<#
    ProjectLogTerminal.psm1 - the active project's running log from any
    PowerShell prompt, in Windows PowerShell 5.1 or PowerShell 7. Install-Scribe.ps1
    -Terminal imports it from your profile.

        log TRY Pointed the reverse proxy at port 8080
        docker logs web --tail 20 | log SAW 'Proxy log after the change'
        log DECISION Delete stale app registrations -Record
        Get-NetTCPConnection -LocalPort 8080 | Save-Proof 'listening on 8080'
        Start-ProjectTranscript

    Entries go to the active project's log.md in its own format, like Scribe's.
#>

Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'ProjectLog.psm1')

function Get-TerminalTarget {
    <# The active project's paths, or a clear error. #>
    $root = Get-ActiveProject
    if (-not $root) { throw 'No active project. Pick one in Scribe, or run New-Project.ps1.' }
    return Get-ProjectPaths -Root $root
}

function Add-ProjectLog {
    <#
    .SYNOPSIS
        Adds an entry to the active project's log: log TAG text...
    .DESCRIPTION
        The first word is the tag (TRY, SAW, FIX, ...), the rest is the entry.
        Piped output goes in a code block under the entry, or is saved to
        evidence\terminal and linked when it runs past 50 lines. -Record on a
        DECISION also creates decisions\NNN-slug.md and links it.
    .EXAMPLE
        log FIX App listens on 3000, not 8080
    .EXAMPLE
        ipconfig /all | log SAW 'Adapter state before the change'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({
                param($command, $parameter, $word)
                Get-KnownLogTags | Where-Object { $_ -like "$word*" }
            })]
        [string]$Tag,
        [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$Text,
        [Parameter(ValueFromPipeline)]$InputObject,
        [switch]$Record
    )
    begin { $piped = New-Object Collections.Generic.List[object] }
    process { if ($null -ne $InputObject) { $piped.Add($InputObject) } }
    end {
        $paths = Get-TerminalTarget
        $known = Get-KnownLogTags -ExtraTags (Get-ProjectLogSettings).extraTags
        $tagName = $Tag.ToUpperInvariant()
        if ($known -notcontains $tagName) { throw "Unknown tag '$Tag'. Known: $($known -join ' ')" }
        $note = (@($Text) -join ' ').Trim()
        # Wide, so tables keep their columns instead of wrapping at the console width.
        $output = if ($piped.Count) { ($piped | Out-String -Width 4096).TrimEnd() } else { '' }
        if (-not $note -and -not $output.Trim()) { throw "Add the entry text after $tagName, or pipe output into it." }

        if ($tagName -eq 'DECISION' -and $Record) {
            if (-not $note) { throw 'A decision record needs the decision as text.' }
            $recordPath = New-DecisionRecord -Root $paths.Root -Decision $note
            $note = "$note; see $(Get-NoteLink -LogPath $paths.Log -Path $recordPath)"
            Write-Host "Decision record: $recordPath" -ForegroundColor DarkGray
        }
        if ($output.Trim()) {
            $saved = Add-PastedEntry -LogPath $paths.Log -Text $output -Tag $tagName -Note $note
            if ($saved) { Write-Host "Output saved as $saved" -ForegroundColor DarkGray }
        }
        else {
            [void](Add-LogEntry -LogPath $paths.Log -Tag $tagName -Text $note)
        }
        Write-Host "Logged $tagName to $(Split-Path -Leaf $paths.Root)" -ForegroundColor DarkGray
    }
}

function Save-Proof {
    <#
    .SYNOPSIS
        Saves piped output to the active project's evidence\terminal and logs a PROOF line.
    .DESCRIPTION
        The file is named YYYY-MM-DD_HHMM_<name>.txt and starts with the command
        line that produced it. The output still shows on screen, as with
        Tee-Object; add -Quiet to hide it.
    .EXAMPLE
        Get-Service sshd | Save-Proof 'sshd running'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Name,
        [Parameter(ValueFromPipeline)]$InputObject,
        [switch]$Quiet
    )
    begin {
        $paths = Get-TerminalTarget
        $when = Get-Date
        $piped = New-Object Collections.Generic.List[object]
    }
    process {
        if ($null -ne $InputObject) {
            $piped.Add($InputObject)
            if (-not $Quiet) { $InputObject }
        }
    }
    end {
        if (-not $piped.Count) { Write-Warning 'Nothing was piped to Save-Proof, so nothing was saved.'; return }
        $dir = Join-Path (Join-Path $paths.Root 'evidence') 'terminal'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $file = Get-UniquePath -Dir $dir -Base (Get-EvidenceName -When $when -Description $Name -MaxSlugLength (Get-ProjectLogSettings).maxSlugLength -DefaultSlug 'output') -Extension 'txt'
        # The exact command, so the evidence says how it was produced.
        $text = "PS> $($MyInvocation.Line.Trim())`r`n`r`n" + ($piped | Out-String -Width 4096).TrimStart("`r", "`n").TrimEnd() + "`r`n"
        [IO.File]::WriteAllText($file, $text, (New-Object Text.UTF8Encoding $false))
        [void](Add-ProofEntry -LogPath $paths.Log -Path $file -When $when)
        Write-Host "Saved $file" -ForegroundColor DarkGray
    }
}

function Remove-TranscriptHeader {
    <#
        Blanks the user, machine and process lines from the header of a closed
        transcript. Windows PowerShell 5.1 always writes them; PowerShell 7
        skips them with -UseMinimalHeader.
    #>
    param([Parameter(Mandatory)][string]$Path)
    $utf8 = New-Object Text.UTF8Encoding $false
    try { $text = [IO.File]::ReadAllText($Path) } catch { return }   # still open in another window
    # Only inside the header, between the first two rows of asterisks.
    $header = [regex]::Match($text, '\A(\*{10,}\r?\n)(.*?\r?\n)(\*{10,})', 'Singleline')
    if (-not $header.Success) { return }
    $keep = '(?m)^(?!(Username|RunAs User|Configuration Name|Machine|Host Application|Process ID|PSVersion|PSEdition|PSCompatibleVersions|BuildVersion|CLRVersion|WSManStackVersion|PSRemotingProtocolVersion|SerializationVersion|GitCommitId|OS|Platform): ).*\r?\n'
    $lines = [regex]::Matches($header.Groups[2].Value, $keep) | ForEach-Object { $_.Value }
    $clean = $header.Groups[1].Value + (-join $lines) + $text.Substring($header.Groups[3].Index)
    if ($clean -cne $text) {
        try { [IO.File]::WriteAllText($Path, $clean, $utf8) } catch { }
    }
}

function Start-ProjectTranscript {
    <#
    .SYNOPSIS
        Records this PowerShell session to the active project's evidence\terminal.
    .DESCRIPTION
        Starts a transcript named YYYY-MM-DD_HHMM_transcript.txt. It records
        everything typed and printed, including anything secret, and stays in
        evidence\, which never leaves your machine. Does nothing when no
        project is active. Older transcripts there lose their user and machine
        header lines.
    #>
    [CmdletBinding()]
    param([switch]$Quiet)
    $root = Get-ActiveProject
    if (-not $root) {
        if (-not $Quiet) { Write-Warning 'No active project, so no transcript was started.' }
        return
    }
    $dir = Join-Path (Join-Path $root 'evidence') 'terminal'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    foreach ($old in Get-ChildItem -LiteralPath $dir -Filter '*_transcript*.txt' -File) { Remove-TranscriptHeader -Path $old.FullName }

    $file = Get-UniquePath -Dir $dir -Base (Get-EvidenceName -When (Get-Date) -DefaultSlug 'transcript') -Extension 'txt'
    $options = @{ LiteralPath = $file }
    if ((Get-Command Start-Transcript).Parameters.ContainsKey('UseMinimalHeader')) { $options.UseMinimalHeader = $true }
    [void](Start-Transcript @options)
    if (-not $Quiet) { Write-Host "Transcript: $file" -ForegroundColor DarkGray }
}

Set-Alias -Name log -Value Add-ProjectLog
Export-ModuleMember -Function Add-ProjectLog, Save-Proof, Start-ProjectTranscript -Alias log
