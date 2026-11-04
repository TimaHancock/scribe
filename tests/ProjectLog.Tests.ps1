<#
    Pester 5 tests for ProjectLog.psm1. Run from the repo root:

        powershell.exe -NoProfile -Command "Invoke-Pester .\tests"

    Kept ASCII-only (non-ASCII test input is built with [char]) because Windows
    PowerShell 5.1 reads BOM-less files as ANSI.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\ProjectLog.psm1') -Force
    $script:nl = [Environment]::NewLine
    $script:tags = Get-KnownLogTags
    # Keep the real active project, recent list and settings out of reach.
    $script:savedConfig = $env:PROJECTLOG_CONFIG
    $script:stateDir = Join-Path $TestDrive 'state'
    $env:PROJECTLOG_CONFIG = Join-Path $stateDir 'active-project.txt'
}

AfterAll {
    $env:PROJECTLOG_CONFIG = $script:savedConfig
}

Describe 'ConvertTo-Slug' {
    It 'lowercases and joins runs of other characters with one hyphen' {
        ConvertTo-Slug 'Admin Panel -- exposed!! (no auth)' | Should -Be 'admin-panel-exposed-no-auth'
    }
    It 'folds accents to plain letters' {
        ConvertTo-Slug "Caf$([char]0xE9) cr$([char]0xE8)me" | Should -Be 'cafe-creme'
    }
    It 'returns an empty string when nothing usable is left' {
        ConvertTo-Slug '!!! ???' | Should -Be ''
        ConvertTo-Slug '' | Should -Be ''
    }
    It 'cuts at a word boundary when one is close to the limit' {
        ConvertTo-Slug 'aaaa bbbb cccc' -MaxLength 10 | Should -Be 'aaaa-bbbb'
    }
    It 'keeps a whole word that ends exactly at the limit' {
        ConvertTo-Slug 'aaaa bbbbb cc' -MaxLength 10 | Should -Be 'aaaa-bbbbb'
    }
    It 'hard-cuts when no word boundary is close enough' {
        ConvertTo-Slug 'abcdefghijklmno' -MaxLength 10 | Should -Be 'abcdefghij'
        ConvertTo-Slug 'ab cdefghijklmn' -MaxLength 10 | Should -Be 'ab-cdefghi'
    }
}

Describe 'Get-ProjectFolderName' {
    It 'prefixes the year and month' {
        Get-ProjectFolderName -Name 'Proxy Lab' -When ([datetime]'2026-11-02') | Should -Be '2026-11-proxy-lab'
    }
    It "doesn't double a typed date prefix" {
        Get-ProjectFolderName -Name '2026-10 old lab' -When ([datetime]'2026-11-02') | Should -Be '2026-10-old-lab'
    }
    It 'returns an empty string for a name with no letters or digits' {
        Get-ProjectFolderName -Name '?!' | Should -Be ''
    }
}

Describe 'Get-KnownLogTags' {
    It 'includes core and module tags' {
        $tags | Should -Contain 'TRY'
        $tags | Should -Contain 'VERIFIED'
    }
    It 'uppercases extra tags and drops duplicates' {
        $t = Get-KnownLogTags -ExtraTags 'flag', 'try'
        $t | Should -Contain 'FLAG'
        @($t | Where-Object { $_ -eq 'TRY' }).Count | Should -Be 1
    }
    It 'accepts $null extra tags (an empty settings list unrolls to $null)' {
        { Get-KnownLogTags -ExtraTags $null } | Should -Not -Throw
        (Get-KnownLogTags -ExtraTags $null).Count | Should -Be $tags.Count
    }
}

Describe 'Split-LogInput' {
    It 'splits a tag and text, matching the tag case-insensitively' {
        $r = Split-LogInput -InputText '  try Pointed the proxy at 8080  ' -KnownTags $tags
        $r.Error | Should -BeNullOrEmpty
        $r.Tag | Should -Be 'TRY'
        $r.Text | Should -Be 'Pointed the proxy at 8080'
    }
    It 'keeps extra lines of a multi-line entry' {
        $r = Split-LogInput -InputText "SAW 502 Bad Gateway`r`nconnect() failed" -KnownTags $tags
        $r.Text | Should -Be "502 Bad Gateway`nconnect() failed"
    }
    It 'rejects empty input' {
        (Split-LogInput -InputText '   ' -KnownTags $tags).Error | Should -Match 'Type a tag'
    }
    It 'rejects an unknown tag' {
        (Split-LogInput -InputText 'NOPE something' -KnownTags $tags).Error | Should -Match "Unknown tag 'NOPE'"
    }
    It 'rejects a tag with no text' {
        $r = Split-LogInput -InputText 'FIX' -KnownTags $tags
        $r.Tag | Should -Be 'FIX'
        $r.Error | Should -Match 'Add the entry text'
    }
}

Describe 'Format-LogEntry' {
    BeforeAll { $script:when = [datetime]'2026-10-26 14:32' }

    It 'pads the tag column' {
        Format-LogEntry -Tag 'TRY' -Text 'Pointed the proxy' -When $when |
            Should -Be '14:32 TRY      Pointed the proxy'
    }
    It 'blanks the time for a second entry in the same minute' {
        Format-LogEntry -Tag 'SAW' -Text '502' -When $when -SameMinute |
            Should -Be '      SAW      502'
    }
    It 'indents extra lines under the text and drops trailing blank lines' {
        $lines = Format-LogEntry -Tag 'SAW' -Text "502 Bad Gateway`n`nconnect() failed   `n`n" -When $when
        $lines | Should -Be @(
            '14:32 SAW      502 Bad Gateway'
            ''
            ((' ' * 15) + 'connect() failed')
        )
    }
}

Describe 'Add-LogEntry, plain format' {
    BeforeEach { $script:log = Join-Path $TestDrive "log-$([guid]::NewGuid()).md" }

    It 'creates the log with a date heading' {
        Add-LogEntry -DefaultFormat plain -LogPath $log -Tag 'TRY' -Text 'First' -When ([datetime]'2026-10-26 14:32') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines[0] | Should -Match '^## 2026-10-26 \(times local, UTC[+-]\d+(:\d{2})?\)$'
        $lines[1] | Should -Be '14:32 TRY      First'
    }
    It 'adds no heading for the same day and blanks a repeated minute' {
        Add-LogEntry -DefaultFormat plain -LogPath $log -Tag 'TRY' -Text 'One' -When ([datetime]'2026-10-26 14:32') | Out-Null
        Add-LogEntry -DefaultFormat plain -LogPath $log -Tag 'SAW' -Text 'Two' -When ([datetime]'2026-10-26 14:32') | Out-Null
        Add-LogEntry -DefaultFormat plain -LogPath $log -Tag 'FIX' -Text 'Three' -When ([datetime]'2026-10-26 14:47') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines.Count | Should -Be 4
        $lines[2] | Should -Be '      SAW      Two'
        $lines[3] | Should -Be '14:47 FIX      Three'
    }
    It 'starts a new heading after one blank line when the day changes' {
        Add-LogEntry -DefaultFormat plain -LogPath $log -Tag 'TRY' -Text 'One' -When ([datetime]'2026-10-26 23:59') | Out-Null
        Add-LogEntry -DefaultFormat plain -LogPath $log -Tag 'TRY' -Text 'Two' -When ([datetime]'2026-10-27 00:01') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines[2] | Should -Be ''
        $lines[3] | Should -Match '^## 2026-10-27 '
        $lines[4] | Should -Be '00:01 TRY      Two'
    }
    It "doesn't double the blank line after New-Project's title" {
        [IO.File]::WriteAllText($log, "# Running log: x$nl$nl")
        Add-LogEntry -DefaultFormat plain -LogPath $log -Tag 'TRY' -Text 'One' -When ([datetime]'2026-10-26 14:32') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines[0] | Should -Be '# Running log: x'
        $lines[1] | Should -Be ''
        $lines[2] | Should -Match '^## 2026-10-26 '
    }
    It 'adds a line break when the file does not end with one' {
        [IO.File]::WriteAllText($log, "## 2026-10-26 (times local, UTC-4)${nl}14:00 TRY      One")
        Add-LogEntry -DefaultFormat plain -LogPath $log -Tag 'FIX' -Text 'Two' -When ([datetime]'2026-10-26 14:05') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines.Count | Should -Be 3
        $lines[2] | Should -Be '14:05 FIX      Two'
    }
    It 'writes UTF-8 without a BOM' {
        Add-LogEntry -DefaultFormat plain -LogPath $log -Tag 'TRY' -Text 'One' | Out-Null
        $bytes = [IO.File]::ReadAllBytes($log)
        $bytes[0] | Should -Be ([byte][char]'#')
    }
}

Describe 'Active and recent projects' {
    BeforeEach {
        Remove-Item -LiteralPath $stateDir -Recurse -Force -ErrorAction SilentlyContinue
        $script:p = 1..12 | ForEach-Object { (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive "proj-$_")).FullName }
    }

    It 'has no active or recent project at first' {
        Get-ActiveProject | Should -BeNullOrEmpty
        @(Get-RecentProjects).Count | Should -Be 0
    }
    It 'puts the newest project first without duplicates' {
        Set-ActiveProject $p[0] | Should -Be $p[0]
        [void](Set-ActiveProject $p[1])
        [void](Set-ActiveProject $p[0])
        Get-ActiveProject | Should -Be $p[0]
        Get-RecentProjects | Should -Be @($p[0], $p[1])
    }
    It 'matches folders case-insensitively' {
        [void](Set-ActiveProject $p[0])
        [void](Set-ActiveProject $p[1])
        [void](Set-ActiveProject $p[0].ToUpperInvariant())
        @(Get-RecentProjects).Count | Should -Be 2
    }
    It 'keeps the ten newest' {
        foreach ($folder in $p) { [void](Set-ActiveProject $folder) }
        $recent = Get-RecentProjects
        $recent.Count | Should -Be 10
        $recent[0] | Should -Be $p[11]
        $recent | Should -Not -Contain $p[0]
    }
    It 'skips folders that no longer exist' {
        [void](Set-ActiveProject $p[0])
        [void](Set-ActiveProject $p[1])
        Remove-Item -LiteralPath $p[0]
        Get-RecentProjects | Should -Be @($p[1])
    }
    It 'includes an active project that predates the recent list' {
        New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
        [IO.File]::WriteAllText($env:PROJECTLOG_CONFIG, $p[2])
        Get-RecentProjects | Should -Be @($p[2])
    }
}

Describe 'Get-ProjectLogSettings' {
    BeforeEach {
        Remove-Item -LiteralPath $stateDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
        $script:settingsPath = Join-Path $stateDir 'settings.json'
    }

    It 'uses the defaults when there is no file' {
        $s = Get-ProjectLogSettings
        $s.logHotkey | Should -Be 'Ctrl+Alt+L'
        $s.previewLines | Should -Be 6
        $s.watchClipboard | Should -BeTrue
        $s.logFormat | Should -Be 'obsidian'
        $s.projectsFolder | Should -Be ''
        $s.pasteHotkey | Should -Be 'Ctrl+Alt+V'
        $s.idleReminderMinutes | Should -Be 15
        @($s.Warnings).Count | Should -Be 0
    }
    It 'rejects an unknown log format' {
        Set-Content -LiteralPath $settingsPath -Value '{ "logFormat": "html" }'
        $s = Get-ProjectLogSettings
        $s.logFormat | Should -Be 'obsidian'
        $s.Warnings | Should -Match 'logFormat should be "obsidian" or "plain"'
    }
    It 'writes a default file that reads back with no warnings' {
        Initialize-ProjectLogSettings | Should -Be $settingsPath
        $s = Get-ProjectLogSettings
        @($s.Warnings).Count | Should -Be 0
        $s.maxSlugLength | Should -Be 50
    }
    It "doesn't overwrite an existing file" {
        Set-Content -LiteralPath $settingsPath -Value '{ "previewLines": 3 }'
        [void](Initialize-ProjectLogSettings)
        (Get-ProjectLogSettings).previewLines | Should -Be 3
    }
    It 'reads values, with keys in any case' {
        Set-Content -LiteralPath $settingsPath -Value '{ "LogHotkey": "Ctrl+Shift+F9", "previewLines": 0, "extraTags": ["FLAG", "LOOT"], "watchClipboard": false }'
        $s = Get-ProjectLogSettings
        $s.logHotkey | Should -Be 'Ctrl+Shift+F9'
        $s.previewLines | Should -Be 0
        $s.extraTags | Should -Be @('FLAG', 'LOOT')
        $s.watchClipboard | Should -BeFalse
        @($s.Warnings).Count | Should -Be 0
    }
    It 'warns about a bad value and keeps the default' {
        Set-Content -LiteralPath $settingsPath -Value '{ "previewLines": 99, "watchClipboard": "yes", "extraTags": ["two words"] }'
        $s = Get-ProjectLogSettings
        $s.previewLines | Should -Be 6
        $s.watchClipboard | Should -BeTrue
        @($s.extraTags).Count | Should -Be 0
        @($s.Warnings).Count | Should -Be 3
        $s.Warnings[0] | Should -Match 'previewLines should be a whole number from 0 to 20'
    }
    It 'warns about an unknown setting' {
        Set-Content -LiteralPath $settingsPath -Value '{ "logHotKeys": "Ctrl+Alt+K" }'
        $s = Get-ProjectLogSettings
        $s.logHotkey | Should -Be 'Ctrl+Alt+L'
        $s.Warnings | Should -Match "unknown setting 'logHotKeys'"
    }
    It 'warns about broken JSON and uses the defaults' {
        Set-Content -LiteralPath $settingsPath -Value '{ "previewLines": 3, }}'
        $s = Get-ProjectLogSettings
        $s.previewLines | Should -Be 6
        $s.Warnings | Should -Match "isn't valid JSON"
    }
    It 'treats an empty file as no settings' {
        Set-Content -LiteralPath $settingsPath -Value ''
        @((Get-ProjectLogSettings).Warnings).Count | Should -Be 0
    }
}

Describe 'Evidence files' {
    BeforeAll { $script:when = [datetime]'2026-10-26 14:32' }

    It 'names a file from the time and description' {
        Get-EvidenceName -When $when -Description 'Proxy 502 error' | Should -Be '2026-10-26_1432_proxy-502-error'
    }
    It 'uses the default slug for an empty description' {
        Get-EvidenceName -When $when -Description '  ' | Should -Be '2026-10-26_1432_screenshot'
        Get-EvidenceName -When $when -DefaultSlug 'output' | Should -Be '2026-10-26_1432_output'
    }
    It 'adds -2, -3 rather than overwriting' {
        $dir = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive 'shots')).FullName
        $first = Get-UniquePath -Dir $dir -Base 'x'
        $first | Should -Be (Join-Path $dir 'x.png')
        New-Item -ItemType File -Path $first | Out-Null
        $second = Get-UniquePath -Dir $dir -Base 'x'
        $second | Should -Be (Join-Path $dir 'x-2.png')
        New-Item -ItemType File -Path $second | Out-Null
        Get-UniquePath -Dir $dir -Base 'x' | Should -Be (Join-Path $dir 'x-3.png')
        Get-UniquePath -Dir $dir -Base 'x' -Extension 'txt' | Should -Be (Join-Path $dir 'x.txt')
    }
    It 'logs a file inside the project relative to the log (plain)' {
        $root = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive 'proof-in')).FullName
        $log = Join-Path $root 'log.md'
        [void](Add-ProofEntry -DefaultFormat plain -LogPath $log -Path (Join-Path $root 'evidence\screenshots\a.png') -When $when)
        (Get-Content -LiteralPath $log)[1] | Should -Be '14:32 PROOF    evidence/screenshots/a.png'
    }
    It 'logs a file outside the project with its full path' {
        $root = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive 'proof-out')).FullName
        $log = Join-Path $root 'log.md'
        [void](Add-ProofEntry -DefaultFormat plain -LogPath $log -Path 'D:\elsewhere\a.png' -When $when)
        (Get-Content -LiteralPath $log)[1] | Should -Be '14:32 PROOF    D:\elsewhere\a.png'
    }
    It 'embeds an image and links other files by name in an obsidian log' {
        $root = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive 'proof-obs')).FullName
        $log = Join-Path $root 'log.md'
        [void](Add-ProofEntry -DefaultFormat obsidian -LogPath $log -Path (Join-Path $root 'evidence\screenshots\a.png') -When $when)
        [void](Add-ProofEntry -LogPath $log -Path (Join-Path $root 'evidence\terminal\b.txt') -When $when)
        [void](Add-ProofEntry -LogPath $log -Path 'D:\elsewhere\c.png' -When $when)
        $lines = Get-Content -LiteralPath $log
        $lines[1] | Should -Be '- 14:32 **PROOF** ![[a.png]]'
        $lines[2] | Should -Be '- 14:32 **PROOF** [[b.txt]]'
        $lines[3] | Should -Be '- 14:32 **PROOF** D:\elsewhere\c.png'
    }
}

Describe 'Format-LogEntry, obsidian format' {
    BeforeAll { $script:when = [datetime]'2026-10-26 14:32' }

    It 'writes a list item with the tag in bold' {
        Format-LogEntry -Tag 'TRY' -Text 'Pointed the proxy' -When $when -Format obsidian |
            Should -Be '- 14:32 **TRY** Pointed the proxy'
    }
    It 'stamps every entry, even in the same minute' {
        Format-LogEntry -Tag 'SAW' -Text '502' -When $when -SameMinute -Format obsidian |
            Should -Be '- 14:32 **SAW** 502'
    }
    It 'puts extra lines in a nested code block, trimming blank lines around them' {
        $lines = Format-LogEntry -Tag 'SAW' -Text "502 Bad Gateway`n`nconnect() failed   `n`n    indented`n`n" -When $when -Format obsidian
        $lines | Should -Be @(
            '- 14:32 **SAW** 502 Bad Gateway'
            '  ```'
            '  connect() failed'
            ''
            '      indented'
            '  ```'
        )
    }
    It 'uses a longer fence when the text holds one' {
        $lines = Format-LogEntry -Tag 'SAW' -Text "Readme says`n``````powershell`nGet-Thing`n``````" -When $when -Format obsidian
        $lines[1] | Should -Be '  ````'
        $lines[-1] | Should -Be '  ````'
    }
}

Describe 'Add-LogEntry, obsidian format' {
    BeforeEach { $script:log = Join-Path $TestDrive "log-$([guid]::NewGuid()).md" }

    It 'writes a new log in the default format and stamps a repeated minute' {
        Add-LogEntry -DefaultFormat obsidian -LogPath $log -Tag 'TRY' -Text 'One' -When ([datetime]'2026-10-26 14:32') | Out-Null
        Add-LogEntry -LogPath $log -Tag 'SAW' -Text 'Two' -When ([datetime]'2026-10-26 14:32') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines[0] | Should -Match '^## 2026-10-26 '
        $lines[1] | Should -Be '- 14:32 **TRY** One'
        $lines[2] | Should -Be '- 14:32 **SAW** Two'
    }
    It 'keeps a plain log plain whatever the default' {
        Add-LogEntry -DefaultFormat plain -LogPath $log -Tag 'TRY' -Text 'One' -When ([datetime]'2026-10-26 14:32') | Out-Null
        Add-LogEntry -DefaultFormat obsidian -LogPath $log -Tag 'FIX' -Text 'Two' -When ([datetime]'2026-10-26 14:40') | Out-Null
        (Get-Content -LiteralPath $log)[2] | Should -Be '14:40 FIX      Two'
    }
    It 'uses the logFormat setting when no default is given' {
        New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
        Set-Content -LiteralPath (Join-Path $stateDir 'settings.json') -Value '{ "logFormat": "Plain" }'
        try {
            Add-LogEntry -LogPath $log -Tag 'TRY' -Text 'One' -When ([datetime]'2026-10-26 14:32') | Out-Null
            (Get-Content -LiteralPath $log)[1] | Should -Be '14:32 TRY      One'
        }
        finally { Remove-Item -LiteralPath (Join-Path $stateDir 'settings.json') }
    }
    It 'detects the format from the last entry' {
        Find-LogFormat -Text "# Running log`n`n" | Should -BeNullOrEmpty
        Find-LogFormat -Text "## 2026-10-26`n14:32 TRY      One`n               more" | Should -Be 'plain'
        Find-LogFormat -Text "## 2026-10-26`n- 14:32 **TRY** One`n  ``````" | Should -Be 'obsidian'
    }
}

Describe 'Project activity in README frontmatter' {
    BeforeEach {
        $script:root = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive "act-$([guid]::NewGuid())")).FullName
        $script:readme = Join-Path $root 'README.md'
    }

    It 'sets updated when the log starts a new day' {
        [IO.File]::WriteAllText($readme, "---`r`ntype: project`r`nupdated: 2026-01-01`r`n---`r`n# Title`r`n")
        Add-LogEntry -DefaultFormat obsidian -LogPath (Join-Path $root 'log.md') -Tag 'TRY' -Text 'One' -When ([datetime]'2026-10-26 14:32') | Out-Null
        [IO.File]::ReadAllText($readme) | Should -Be "---`r`ntype: project`r`nupdated: 2026-10-26`r`n---`r`n# Title`r`n"
    }
    It 'leaves a README without the key alone' {
        $text = "---`ntype: project`n---`n# Title`n"
        [IO.File]::WriteAllText($readme, $text)
        Set-FrontmatterValue -Path $readme -Name 'updated' -Value '2026-10-26' | Should -BeFalse
        [IO.File]::ReadAllText($readme) | Should -Be $text
    }
    It 'leaves a README without frontmatter alone' {
        [IO.File]::WriteAllText($readme, "# Title`nupdated: 2020-01-01`n")
        Set-FrontmatterValue -Path $readme -Name 'updated' -Value '2026-10-26' | Should -BeFalse
    }
    It 'only changes the frontmatter' {
        [IO.File]::WriteAllText($readme, "---`nupdated:`n---`nupdated: body`n")
        Set-FrontmatterValue -Path $readme -Name 'updated' -Value '2026-10-26' | Should -BeTrue
        [IO.File]::ReadAllText($readme) | Should -Be "---`nupdated: 2026-10-26`n---`nupdated: body`n"
    }
}

Describe 'ConvertTo-ObsidianLog' {
    It 'converts entries and keeps headings, blank lines and other text' {
        $root = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive 'conv')).FullName
        New-Item -ItemType Directory -Force -Path (Join-Path $root 'evidence\screenshots') | Out-Null
        New-Item -ItemType File -Force -Path (Join-Path $root 'evidence\screenshots\x.png') | Out-Null
        $plain = @(
            '# Running log: conv'
            ''
            '## 2026-10-26 (times local, UTC-4)'
            '14:32 TRY      Pointed the proxy at 8080'
            '      SAW      502 Bad Gateway'
            '               connect() failed'
            '      PROOF    evidence/screenshots/x.png'
            '      PROOF    evidence/terminal/missing.txt'
            ''
            '## 2026-10-27 (times local, UTC-4)'
            '09:00 FIX      Works'
            ''
        ) -join "`n"
        $out = (ConvertTo-ObsidianLog -Text $plain -ProjectRoot $root).Split("`n")
        $out | Should -Be @(
            '# Running log: conv'
            ''
            '## 2026-10-26 (times local, UTC-4)'
            '- 14:32 **TRY** Pointed the proxy at 8080'
            '- 14:32 **SAW** 502 Bad Gateway'
            '  ```'
            '  connect() failed'
            '  ```'
            '- 14:32 **PROOF** ![[x.png]]'
            '- 14:32 **PROOF** evidence/terminal/missing.txt'
            ''
            '## 2026-10-27 (times local, UTC-4)'
            '- 09:00 **FIX** Works'
            ''
        )
    }
}

Describe 'Projects folder and Obsidian' {
    BeforeAll {
        $script:vault = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive 'vault')).FullName
        New-Item -ItemType Directory -Force -Path (Join-Path $vault '.obsidian') | Out-Null
        foreach ($n in 'old', 'new', 'notes') { New-Item -ItemType Directory -Force -Path (Join-Path $vault $n) | Out-Null }
        Set-Content -LiteralPath (Join-Path $vault 'old\log.md') -Value 'x'
        Set-Content -LiteralPath (Join-Path $vault 'new\log.md') -Value 'x'
        (Get-Item -LiteralPath (Join-Path $vault 'old\log.md')).LastWriteTimeUtc = [datetime]'2026-01-01'
    }

    It 'lists folders with a log.md, most recently logged first' {
        Get-ProjectFolders -Path $vault | Should -Be @((Join-Path $vault 'new'), (Join-Path $vault 'old'))
        @(Get-ProjectFolders -Path '').Count | Should -Be 0
        @(Get-ProjectFolders -Path (Join-Path $vault 'nope')).Count | Should -Be 0
    }
    It 'puts recent projects first without duplicates' {
        Remove-Item -LiteralPath $stateDir -Recurse -Force -ErrorAction SilentlyContinue
        [void](Set-ActiveProject (Join-Path $vault 'old'))
        Get-ProjectChoices -ProjectsFolder $vault | Should -Be @((Join-Path $vault 'old'), (Join-Path $vault 'new'))
    }
    It 'finds the vault that holds a file' {
        Get-ObsidianVault -Path (Join-Path $vault 'old\log.md') | Should -Be $vault
        Get-ObsidianVault -Path $TestDrive | Should -BeNullOrEmpty
    }
    It 'builds an obsidian:// link from the full path' {
        Get-ObsidianUri -Path 'C:\my vault\p\log.md' | Should -Be 'obsidian://open?path=C%3A%5Cmy%20vault%5Cp%5Clog.md'
    }
}

Describe 'Get-ImageHash' {
    BeforeAll {
        function New-TestBitmap([System.Drawing.Imaging.PixelFormat]$Format = 'Format32bppArgb') {
            $bmp = New-Object System.Drawing.Bitmap 40, 30, $Format
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.Clear([System.Drawing.Color]::White)
            $g.Dispose()
            return $bmp
        }
    }

    It 'matches the same pixels stored in different formats' {
        Get-ImageHash (New-TestBitmap) | Should -Be (Get-ImageHash (New-TestBitmap 'Format24bppRgb'))
    }
    It 'differs when one pixel differs' {
        $b = New-TestBitmap
        $b.SetPixel(5, 5, [System.Drawing.Color]::Red)
        Get-ImageHash (New-TestBitmap) | Should -Not -Be (Get-ImageHash $b)
    }
}

Describe 'Clipboard watch lock' {
    BeforeAll { $script:module = (Resolve-Path (Join-Path $PSScriptRoot '..\ProjectLog.psm1')).ProviderPath }

    It 'lets only one process watch at a time' {
        $lock = Enter-ClipboardWatch
        if (-not $lock) {
            Set-ItResult -Skipped -Because 'another process holds the lock, probably a running Scribe; exit it to run this test'
            return
        }
        try {
            # Jobs run in a separate process, like a second watcher would.
            $blocked = Start-Job { Import-Module $using:module; $null -eq (Enter-ClipboardWatch) } | Wait-Job | Receive-Job
            $blocked | Should -BeTrue
        }
        finally { Exit-ClipboardWatch -Lock $lock }

        $free = Start-Job { Import-Module $using:module; $l = Enter-ClipboardWatch; $null -ne $l; if ($l) { Exit-ClipboardWatch -Lock $l } } | Wait-Job | Receive-Job
        $free | Should -BeTrue
    }
}

Describe 'Add-PastedEntry' {
    BeforeEach {
        $script:root = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive "paste-$([guid]::NewGuid())")).FullName
        $script:log = Join-Path $root 'log.md'
        $script:when = [datetime]'2026-11-04 09:15'
    }

    It 'logs one line inline as code in an obsidian log' {
        [void](Add-PastedEntry -LogPath $log -Text "  connect() failed (111)`r`n`r`n" -When $when -DefaultFormat obsidian)
        (Get-Content -LiteralPath $log)[1] | Should -Be '- 09:15 **SAW** `connect() failed (111)`'
    }
    It 'escapes backticks in inline code' {
        [void](Add-PastedEntry -LogPath $log -Text 'run `ls` now' -When $when -DefaultFormat obsidian)
        (Get-Content -LiteralPath $log)[1] | Should -Be '- 09:15 **SAW** ``run `ls` now``'
    }
    It 'puts several lines in a code block under a count' {
        [void](Add-PastedEntry -LogPath $log -Text "line one`nline two" -When $when -DefaultFormat obsidian)
        $lines = Get-Content -LiteralPath $log
        $lines[1] | Should -Be '- 09:15 **SAW** Pasted 2 lines:'
        $lines[2..5] | Should -Be @('  ```', '  line one', '  line two', '  ```')
    }
    It 'logs plain text as is in a plain log' {
        [void](Add-PastedEntry -LogPath $log -Text 'connect() failed' -When $when -DefaultFormat plain)
        (Get-Content -LiteralPath $log)[1] | Should -Be '09:15 SAW      connect() failed'
    }
    It 'saves a long paste as a file and links it' {
        $file = Add-PastedEntry -LogPath $log -Text ((1..5 | ForEach-Object { "row $_" }) -join "`n") -When $when -DefaultFormat obsidian -MaxLines 3
        $file | Should -Be (Join-Path $root 'evidence\terminal\2026-11-04_0915_pasted.txt')
        @(Get-Content -LiteralPath $file).Count | Should -Be 5
        $lines = Get-Content -LiteralPath $log
        $lines[1] | Should -Be '- 09:15 **SAW** Pasted 5 lines, saved as evidence:'
        $lines[2] | Should -Be '- 09:15 **PROOF** [[2026-11-04_0915_pasted.txt]]'
    }
    It 'refuses empty text' {
        { Add-PastedEntry -LogPath $log -Text " `n " } | Should -Throw '*empty*'
    }
}

Describe 'Copy-EvidenceFile' {
    It 'copies a file into evidence\exports under the naming rule' {
        $root = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive 'drop')).FullName
        $src = Join-Path $TestDrive 'Router Config (old).CONF'
        Set-Content -LiteralPath $src -Value 'hostname r1'
        $when = [datetime]'2026-11-04 09:20'
        $a = Copy-EvidenceFile -Root $root -Path $src -When $when
        $a | Should -Be (Join-Path $root 'evidence\exports\2026-11-04_0920_router-config-old.conf')
        Get-Content -LiteralPath $a | Should -Be 'hostname r1'
        Copy-EvidenceFile -Root $root -Path $src -When $when | Should -Be (Join-Path $root 'evidence\exports\2026-11-04_0920_router-config-old-2.conf')
    }
    It 'keeps a file without an extension extensionless' {
        $root = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive 'drop2')).FullName
        $src = Join-Path $TestDrive 'Dockerfile'
        Set-Content -LiteralPath $src -Value 'FROM x'
        Copy-EvidenceFile -Root $root -Path $src -When ([datetime]'2026-11-04 09:20') | Should -Be (Join-Path $root 'evidence\exports\2026-11-04_0920_dockerfile')
    }
    It 'refuses a folder' {
        { Copy-EvidenceFile -Root $TestDrive -Path $TestDrive } | Should -Throw '*Not a file*'
    }
}

Describe 'New-DecisionRecord' {
    It 'numbers records after the highest one and fills in the template' {
        $root = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive 'dec')).FullName
        New-Item -ItemType Directory -Force -Path (Join-Path $root 'decisions') | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'decisions\007-old.md') -Value 'x'
        $path = New-DecisionRecord -Root $root -Decision 'Delete stale app registrations; disabling leaves owners confused' -When ([datetime]'2026-11-04')
        $path | Should -Be (Join-Path $root 'decisions\008-delete-stale-app-registrations.md')
        $text = [IO.File]::ReadAllText($path)
        $text | Should -Match '(?m)^# 008\. Delete stale app registrations\r?$'
        $text | Should -Match 'Date: 2026-11-04 \S+ Status: accepted'
        $text | Should -Match '(?m)^Delete stale app registrations; disabling leaves owners confused\r?$'
        $text | Should -Not -Match 'NNN|YYYY'
    }
    It 'links a record by name in an obsidian log and by path in a plain one' {
        $root = Join-Path $TestDrive 'dec'
        $rec = Join-Path $root 'decisions\008-x.md'
        Get-NoteLink -LogPath (Join-Path $root 'new.md') -Path $rec -DefaultFormat obsidian | Should -Be '[[008-x]]'
        Get-NoteLink -LogPath (Join-Path $root 'new.md') -Path $rec -DefaultFormat plain | Should -Be 'decisions/008-x.md'
    }
}

Describe 'Work sessions' {
    BeforeEach {
        Remove-Item -LiteralPath $stateDir -Recurse -Force -ErrorAction SilentlyContinue
        $script:root = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive "sess-$([guid]::NewGuid())")).FullName
        $script:log = Join-Path $root 'log.md'
    }

    It 'logs the start and end, with NEXT, and remembers the open session' {
        Start-ProjectSession -Root $root -When ([datetime]'2026-11-04 09:00') -DefaultFormat obsidian
        (Get-ProjectSession).Project | Should -Be $root
        (Get-ProjectSession).Started | Should -Be ([datetime]'2026-11-04 09:00')
        { Start-ProjectSession -Root $root } | Should -Throw '*already running*'
        $length = Stop-ProjectSession -Next 'Compare owners with HR' -When ([datetime]'2026-11-04 10:25')
        $length | Should -Be (New-TimeSpan -Hours 1 -Minutes 25)
        Get-ProjectSession | Should -BeNullOrEmpty
        $lines = Get-Content -LiteralPath $log
        $lines[1] | Should -Be '- 09:00 **SESSION** Started'
        $lines[2] | Should -Be '- 10:25 **NEXT** Compare owners with HR'
        $lines[3] | Should -Be '- 10:25 **SESSION** Ended after 1h 25m'
    }
    It 'adds up ended sessions in either format' {
        $text = @(
            '## 2026-11-03 (times local, UTC-5)'
            '09:00 SESSION  Started'
            '10:25 SESSION  Ended after 1h 25m'
            '      SESSION  Ended after 0h 05m'
            '- 14:00 **SESSION** Ended after 2h 40m'
            '- 15:00 **SESSION** Ended after 0h 20m, switched to other-project'
        ) -join "`r`n"
        [IO.File]::WriteAllText($log, $text)
        Get-SessionTime -LogPath $log | Should -Be (New-TimeSpan -Hours 4 -Minutes 30)
    }
    It 'moves a running session when the active project changes' {
        $other = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive "sess-b-$([guid]::NewGuid())")).FullName
        [void](Set-ActiveProject $root)
        Start-ProjectSession -Root $root -When (Get-Date).AddMinutes(-70) -DefaultFormat obsidian
        [void](Set-ActiveProject $other)
        (Get-ProjectSession).Project | Should -Be $other
        ((Get-Date) - (Get-ProjectSession).Started).TotalMinutes | Should -BeLessThan 1
        (Get-Content -LiteralPath $log)[-1] | Should -Match "^- \d{2}:\d{2} \*\*SESSION\*\* Ended after 1h 10m, switched to $([regex]::Escape((Split-Path -Leaf $other)))$"
        (Get-Content -LiteralPath (Join-Path $other 'log.md'))[-1] | Should -Match '\*\*SESSION\*\* Started$|SESSION +Started$'
        Get-SessionTime -LogPath $log | Should -Be (New-TimeSpan -Hours 1 -Minutes 10)
    }
    It 'leaves the session alone when the same project is chosen again' {
        [void](Set-ActiveProject $root)
        Start-ProjectSession -Root $root -DefaultFormat obsidian
        [void](Set-ActiveProject $root.ToUpperInvariant())
        @(Get-Content -LiteralPath $log | Where-Object { $_ -match 'SESSION' }).Count | Should -Be 1
    }
    It "doesn't recreate a deleted project to end its session" {
        $gone = (New-Item -ItemType Directory -Force -Path (Join-Path $TestDrive "sess-gone-$([guid]::NewGuid())")).FullName
        Start-ProjectSession -Root $gone -DefaultFormat obsidian
        Remove-Item -LiteralPath $gone -Recurse -Force
        [void](Set-ActiveProject $root)
        Test-Path -LiteralPath $gone | Should -BeFalse
        (Get-ProjectSession).Project | Should -Be $root
    }
    It 'formats a length in hours and minutes' {
        Format-SessionLength (New-TimeSpan -Minutes 3) | Should -Be '0h 03m'
        Format-SessionLength (New-TimeSpan -Hours 26 -Minutes 59 -Seconds 40) | Should -Be '27h 00m'
    }
    It 'refuses to stop when no session is running' {
        { Stop-ProjectSession } | Should -Throw '*No session*'
    }
}
