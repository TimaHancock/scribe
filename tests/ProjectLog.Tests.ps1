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

Describe 'Add-LogEntry' {
    BeforeEach { $script:log = Join-Path $TestDrive "log-$([guid]::NewGuid()).md" }

    It 'creates the log with a date heading' {
        Add-LogEntry -LogPath $log -Tag 'TRY' -Text 'First' -When ([datetime]'2026-10-26 14:32') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines[0] | Should -Match '^## 2026-10-26 \(times local, UTC[+-]\d+(:\d{2})?\)$'
        $lines[1] | Should -Be '14:32 TRY      First'
    }
    It 'adds no heading for the same day and blanks a repeated minute' {
        Add-LogEntry -LogPath $log -Tag 'TRY' -Text 'One' -When ([datetime]'2026-10-26 14:32') | Out-Null
        Add-LogEntry -LogPath $log -Tag 'SAW' -Text 'Two' -When ([datetime]'2026-10-26 14:32') | Out-Null
        Add-LogEntry -LogPath $log -Tag 'FIX' -Text 'Three' -When ([datetime]'2026-10-26 14:47') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines.Count | Should -Be 4
        $lines[2] | Should -Be '      SAW      Two'
        $lines[3] | Should -Be '14:47 FIX      Three'
    }
    It 'starts a new heading after one blank line when the day changes' {
        Add-LogEntry -LogPath $log -Tag 'TRY' -Text 'One' -When ([datetime]'2026-10-26 23:59') | Out-Null
        Add-LogEntry -LogPath $log -Tag 'TRY' -Text 'Two' -When ([datetime]'2026-10-27 00:01') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines[2] | Should -Be ''
        $lines[3] | Should -Match '^## 2026-10-27 '
        $lines[4] | Should -Be '00:01 TRY      Two'
    }
    It "doesn't double the blank line after New-Project's title" {
        [IO.File]::WriteAllText($log, "# Running log: x$nl$nl")
        Add-LogEntry -LogPath $log -Tag 'TRY' -Text 'One' -When ([datetime]'2026-10-26 14:32') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines[0] | Should -Be '# Running log: x'
        $lines[1] | Should -Be ''
        $lines[2] | Should -Match '^## 2026-10-26 '
    }
    It 'adds a line break when the file does not end with one' {
        [IO.File]::WriteAllText($log, "## 2026-10-26 (times local, UTC-4)${nl}14:00 TRY      One")
        Add-LogEntry -LogPath $log -Tag 'FIX' -Text 'Two' -When ([datetime]'2026-10-26 14:05') | Out-Null
        $lines = Get-Content -LiteralPath $log
        $lines.Count | Should -Be 3
        $lines[2] | Should -Be '14:05 FIX      Two'
    }
    It 'writes UTF-8 without a BOM' {
        Add-LogEntry -LogPath $log -Tag 'TRY' -Text 'One' | Out-Null
        $bytes = [IO.File]::ReadAllBytes($log)
        $bytes[0] | Should -Be ([byte][char]'#')
    }
}
