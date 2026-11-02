<#
.SYNOPSIS
    Creates a new project workspace in the documentation playbook's layout.
    Authors: Claude and Tima

.DESCRIPTION
    Asks for a project slug and a type module, then builds the folder tree for
    that module with a kickoff-card README.md and an empty log.md. The folder
    is named YYYY-MM-<slug> and goes in projectsFolder from settings.json, or
    wherever you pick when that isn't set.

    The kickoff card, the academic kickoff additions and the runbook procedure
    come from documentation-playbook\, so a template is edited in one place.
    The README gets frontmatter (type, status, module, started, updated) for
    Obsidian. When the parent folder is inside an Obsidian vault and has no
    .base file yet, Projects.base is copied there as a dashboard of projects.

    Module trees match the Project directory section of each type module:
      Core       the core layout, for anything without a module
      ITProject  change records, comms, before/after evidence, handover pack
      Runbook    authoring workspace for writing and testing one procedure
      TechEval   options, proof of concept, private folder, MADR decision
      Academic   one graded task: task snapshot, matrix, submitted, feedback
      Capstone   one root, shared evidence, one folder per task

    Afterward it can make the new folder the active project, so
    Start-Scribe.ps1 and Save-Screenshot.ps1 write into it.

.PARAMETER Slug
    Short project name, e.g. "proxy lab" or "net101 task 1". Turned into
    lowercase-hyphen form. Prompted for if omitted.

.PARAMETER Path
    Parent folder to create the project in. Defaults to projectsFolder in
    settings.json; a folder picker opens if that isn't set either.

.PARAMETER Module
    Which layout to build. Prompted for if omitted.

.PARAMETER Tasks
    Number of task folders for a Capstone project. Prompted for if omitted.

.PARAMETER SetActive
    Make the new folder the active project without asking.

.EXAMPLE
    powershell.exe -STA -File .\New-Project.ps1

.EXAMPLE
    .\New-Project.ps1 -Slug "senior capstone" -Module Capstone -Tasks 3 -Path D:\Projects -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Slug,
    [string]$Path,
    [ValidateSet('Core', 'ITProject', 'Runbook', 'TechEval', 'Academic', 'Capstone')]
    [string]$Module,
    [ValidateRange(1, 12)]
    [int]$Tasks,
    [switch]$SetActive
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ProjectLog.psm1') -Force

$utf8 = New-Object Text.UTF8Encoding $false
$today = Get-Date

function Select-ParentFolder {
    $last = Get-ProjectLogStatePath 'last-parent.txt'
    $start = if (Test-Path -LiteralPath $last) { (Get-Content -LiteralPath $last -Raw).Trim() } else { $null }

    $canPick = $IsWindows -ne $false -and [Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA'
    if (-not $canPick) {
        return Read-Host 'Parent folder for the project (run with -STA on Windows for a folder picker)'
    }
    Add-Type -AssemblyName System.Windows.Forms
    # A hidden topmost owner keeps the picker from opening behind the console.
    $owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; ShowInTaskbar = $false; Opacity = 0 }
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Where should the new project folder go?'
    $dialog.ShowNewFolderButton = $true
    if ($start -and (Test-Path -LiteralPath $start)) { $dialog.SelectedPath = $start }
    try {
        $owner.Show(); $owner.Activate()
        if ($dialog.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath }
        return $null
    }
    finally { $dialog.Dispose(); $owner.Dispose() }
}

function Select-Module {
    $choices = [ordered]@{
        '1' = @('Core', 'no type module')
        '2' = @('ITProject', 'migration, deployment, rollout, decommission')
        '3' = @('Runbook', 'writing or overhauling one procedure')
        '4' = @('TechEval', 'choosing a product, tool or approach')
        '5' = @('Academic', 'one graded task')
        '6' = @('Capstone', 'multi-task capstone')
    }
    Write-Host 'Type module:'
    foreach ($k in $choices.Keys) { Write-Host ("  {0}. {1,-10} {2}" -f $k, $choices[$k][0], $choices[$k][1]) }
    $pick = Read-Host 'Choose 1-6 (Enter for Core)'
    if (-not $pick) { return 'Core' }
    if (-not $choices.Contains($pick)) { throw "No module numbered '$pick'." }
    return $choices[$pick][0]
}

# --- File templates -----------------------------------------------------------

$moduleNames = @{
    Core = 'none'; ITProject = 'IT project'; Runbook = 'Runbook or SOP'
    TechEval = 'Technology evaluation'; Academic = 'Academic assessment'; Capstone = 'Academic assessment (capstone)'
}
$playbook = Join-Path $PSScriptRoot 'documentation-playbook'

function Get-PlaybookTemplate {
    <#
        The first ```markdown block in a playbook file, after the line Heading
        when one is given. Read as UTF-8, so the playbook's own characters
        survive Windows PowerShell's ANSI default.
    #>
    param([Parameter(Mandatory)][string]$File, [string]$Heading)
    $path = Join-Path $playbook $File
    if (-not (Test-Path -LiteralPath $path)) { throw "Playbook template not found: $path" }
    $lines = [IO.File]::ReadAllLines($path, $utf8)
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

function Get-KickoffCard([string]$ModuleName) {
    $card = Get-PlaybookTemplate 'templates\01-kickoff-card.md'
    $date = $today.ToString('yyyy-MM-dd')
    $card = $card -replace '(?m)^(started|updated): YYYY-MM-DD', "`$1: $date"
    return $card -replace '(?m)^module: <[^>\r\n]*>', "module: $ModuleName"
}

$matrix = @"
# Rubric traceability matrix

| Rubric row | Verb and threshold | Heading in submission | Evidence and location | Status |
| --- | --- | --- | --- | --- |
| A1 | | | | Not started |
"@

$citations = @"
# Citations log

| Source | Author or organization | Date | URL | Accessed | Used for |
| --- | --- | --- | --- | --- | --- |
"@

# --- Layouts: folders, then files (relative path => content) ------------------

function Get-Layout([string]$Name, [int]$TaskCount) {
    $evidence = @('evidence/screenshots', 'evidence/terminal', 'evidence/exports')
    switch ($Name) {
        'Core' {
            @{ Folders = @('decisions') + $evidence + @('scripts', 'diagrams', 'drafts', 'publish')
               Files   = @{} }
        }
        'ITProject' {
            @{ Folders = @('decisions', 'changes', 'comms', 'evidence/before', 'evidence/after/wave-1') + $evidence +
                         @('scripts', 'diagrams', 'handover/runbooks', 'drafts', 'publish')
               Files   = @{ 'handover/as-built.md' = "# As-built`n`nHow the system works now: diagram, configuration summary, where things live, owners, monitoring and alerts, linked runbooks, known issues, vault references.`n" } }
        }
        'Runbook' {
            @{ Folders = @('evidence/runs', 'evidence/screenshots', 'evidence/terminal', 'scripts', 'publish')
               Files   = @{ 'procedure.md' = (Get-PlaybookTemplate 'type-modules\runbook-or-sop.md' -Heading '## Template changes') } }
        }
        'TechEval' {
            @{ Folders = @('options/option-a/docs', 'options/option-b/docs', 'options/do-nothing', 'poc') + $evidence +
                         @('private', 'decisions', 'drafts', 'publish')
               Files   = @{
                   'criteria.csv'               = "Criterion,Weight,Must-have,Option A,Option B,Do nothing,Evidence`n"
                   'cost.csv'                   = "Cost item,Option A,Option B,Do nothing,Notes`n"
                   'options/option-a/notes.md'  = "# Option A`n`nCapabilities, limits, demo and reference-call notes. Tag vendor statements CLAIM until verified.`n"
                   'options/option-b/notes.md'  = "# Option B`n`nCapabilities, limits, demo and reference-call notes. Tag vendor statements CLAIM until verified.`n"
                   'options/do-nothing/notes.md'= "# Do nothing`n`nWhat staying put costs and risks.`n"
                   'poc/plan.md'                = "# Proof-of-concept plan`n`n| Test case | Criterion | Environment | Pass threshold |`n| --- | --- | --- | --- |`n"
                   'poc/results.md'             = "# Proof-of-concept results`n`n| Test case | Result | Evidence |`n| --- | --- | --- |`n"
                   'private/README.md'          = "Quotes, pricing and NDA material. Never copy anything from here to publish/.`n"
               } }
        }
        'Academic' {
            @{ Folders = @('task', 'sources', 'decisions') + $evidence + @('scripts', 'diagrams', 'drafts', 'submitted', 'feedback', 'publish')
               Files   = @{ 'matrix.md' = $matrix; 'sources/citations.md' = $citations } }
        }
        'Capstone' {
            $folders = @('sources', 'decisions') + $evidence + @('publish')
            $files = @{ 'sources/citations.md' = $citations }
            foreach ($n in 1..$TaskCount) {
                $t = "task-$n"
                $folders += @("$t/task", "$t/drafts", "$t/submitted", "$t/feedback")
                $files["$t/matrix.md"] = $matrix
            }
            @{ Folders = $folders; Files = $files }
        }
    }
}

# --- Gather input -------------------------------------------------------------

if (-not $Slug) { $Slug = Read-Host 'Project slug (e.g. "proxy lab" or "net101 task 1")' }
$clean = Get-ProjectFolderName -Name $Slug -When $today
if (-not $clean) { throw 'The slug needs at least one letter or number.' }

if (-not $Module) { $Module = Select-Module }
if ($Module -eq 'Capstone' -and -not $Tasks) {
    $answer = Read-Host 'How many capstone tasks? (Enter for 3)'
    $Tasks = if ($answer) { [int]$answer } else { 3 }
}

if (-not $Path) {
    $projectsFolder = (Get-ProjectLogSettings).projectsFolder
    if ($projectsFolder -and (Test-Path -LiteralPath $projectsFolder -PathType Container)) { $Path = $projectsFolder }
    else { $Path = Select-ParentFolder }
}
if (-not $Path) { Write-Host 'Cancelled.'; return }
if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "Parent folder not found: $Path" }

$root = Join-Path (Resolve-Path -LiteralPath $Path).ProviderPath $clean
if (Test-Path -LiteralPath $root) { throw "Already exists, nothing changed: $root" }

# --- Build --------------------------------------------------------------------

$layout = Get-Layout -Name $Module -TaskCount $Tasks
$readme = Get-KickoffCard $moduleNames[$Module]
if ($Module -in 'Academic', 'Capstone') {
    $readme += "`n" + (Get-PlaybookTemplate 'type-modules\academic-assessment.md' -Heading '### Kickoff card additions')
}

# A projects dashboard for the vault, unless this folder already has a .base file.
$parent = Split-Path -Parent $root
$dashboard = $null
if ((Get-ObsidianVault -Path $parent) -and -not (Get-ChildItem -LiteralPath $parent -Filter '*.base' -File)) {
    $dashboard = Join-Path $parent 'Projects.base'
}

$files = @{
    'README.md' = $readme
    'log.md'    = "# Running log: $clean`n`n"
}
foreach ($k in $layout.Files.Keys) { $files[$k] = $layout.Files[$k] }

if ($PSCmdlet.ShouldProcess($root, "Create $Module project")) {
    New-Item -ItemType Directory -Path $root | Out-Null
    foreach ($folder in $layout.Folders) {
        New-Item -ItemType Directory -Path (Join-Path $root $folder) -Force | Out-Null
    }
    foreach ($rel in $files.Keys) {
        $target = Join-Path $root $rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        $content = $files[$rel]
        if (-not $content.EndsWith("`n")) { $content += "`n" }
        [IO.File]::WriteAllText($target, ($content -replace "`r?`n", [Environment]::NewLine), $utf8)
    }

    $lastParent = Get-ProjectLogStatePath 'last-parent.txt'
    New-Item -ItemType Directory -Path (Split-Path -Parent $lastParent) -Force | Out-Null
    [IO.File]::WriteAllText($lastParent, (Split-Path -Parent $root), $utf8)

    Write-Host "Created $Module project: $root" -ForegroundColor Green
    if ($dashboard) {
        Copy-Item -LiteralPath (Join-Path $playbook 'templates\projects.base') -Destination $dashboard
        Write-Host "Added a projects dashboard for Obsidian: $dashboard"
    }

    $makeActive = $SetActive
    if (-not $makeActive) {
        $answer = Read-Host 'Make it the active project for the log box and screenshots? [Y/n]'
        $makeActive = -not $answer -or $answer -match '^(y|yes)$'
    }
    if ($makeActive) { [void](Set-ActiveProject -Path $root); Write-Host 'Active project set.' }
}
else {
    # -WhatIf: show what would be built.
    Write-Host "Would create: $root"
    ($layout.Folders + $files.Keys) | Sort-Object | ForEach-Object { Write-Host "  $_" }
    if ($dashboard) { Write-Host "Would add the projects dashboard: $dashboard" }
}
