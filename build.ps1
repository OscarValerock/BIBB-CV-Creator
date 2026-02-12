# Oscar Martinez CV - Build Script
# PowerShell script to compile the LaTeX CV from YAML data

param(
    [string]$Action = "build",
    [string]$LetterName = "",
    [string]$Lang = "en"
)

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptDir) { $ScriptDir = Get-Location }

$DataFile = Join-Path $ScriptDir "Data\PersonalResumeData_$Lang.md"
if (-not (Test-Path $DataFile)) {
    Write-Host "[ERROR] Data file not found for language '$Lang': $DataFile" -ForegroundColor Red
    exit 1
}
$LettersDir = Join-Path $ScriptDir "Data\MotivationLetters"
$TemplatesDir = Join-Path $ScriptDir "templates"
$SectionsDir = Join-Path $ScriptDir "sections"
$ConfigDir = Join-Path $ScriptDir "config"
$MainFile = Join-Path $ScriptDir "cv.tex"

#######################################
# YAML PARSING FUNCTIONS
#######################################

function Parse-YamlFrontmatter {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw -Encoding UTF8

    # Extract YAML frontmatter between --- markers
    if ($content -match '(?s)^---\r?\n(.+?)\r?\n---') {
        $yaml = $matches[1]
        return Parse-YamlContent $yaml
    }

    throw "No YAML frontmatter found in $FilePath"
}

function Parse-YamlContent {
    param([string]$yaml)

    $result = @{}
    $lines = $yaml -split "`r?`n"
    $currentKey = $null
    $currentIndent = 0
    $arrayStack = @()
    $objectStack = @()
    $multilineKey = $null
    $multilineValue = ""

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Skip empty lines and comments
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }

        # Handle multiline strings (>)
        if ($multilineKey) {
            if ($line -match '^(\s+)(.+)$') {
                $multilineValue += " " + $matches[2].Trim()
                continue
            } else {
                $result[$multilineKey] = $multilineValue.Trim()
                $multilineKey = $null
                $multilineValue = ""
            }
        }

        # Get indentation level
        $indent = 0
        if ($line -match '^(\s*)') {
            $indent = $matches[1].Length
        }

        # Key-value pair
        if ($line -match '^\s*([^:\-]+):\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Multiline indicator
            if ($value -eq '>') {
                $multilineKey = $key
                $multilineValue = ""
                continue
            }

            # Remove quotes from value
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }

            if ($value -eq '') {
                # This is a parent key (object or array follows)
                $result[$key] = @{}
            } else {
                $result[$key] = $value
            }
            $currentKey = $key
            $currentIndent = $indent
        }
        # Array item
        elseif ($line -match '^\s*-\s*(.+)$') {
            $value = $matches[1].Trim()

            # Remove quotes
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }

            if ($currentKey -and $result[$currentKey] -is [hashtable] -and $result[$currentKey].Count -eq 0) {
                $result[$currentKey] = @()
            }

            if ($currentKey -and $result[$currentKey] -is [array]) {
                $result[$currentKey] += $value
            }
        }
    }

    # Handle final multiline value
    if ($multilineKey) {
        $result[$multilineKey] = $multilineValue.Trim()
    }

    return $result
}

function Parse-FullYaml {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw -Encoding UTF8

    # Extract YAML frontmatter
    if ($content -match '(?s)^---\r?\n(.+?)\r?\n---') {
        $yaml = $matches[1]
    } else {
        throw "No YAML frontmatter found"
    }

    # Initialize data structure
    $data = @{
        sections = @{}
        contact = @{}
        personal_details = @{}
        core_competencies = @{}
        experience = @()
        education = @()
        certifications = @()
        languages = @()
        interests_volunteering = @()
        community_open_source_projects = @()
        testimonials = @()
    }

    $lines = $yaml -split "`r?`n"
    $currentSection = $null
    $currentSubSection = $null
    $currentItem = $null
    $multilineKey = $null
    $multilineValue = ""
    $multilineIndent = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Skip comments
        if ($line -match '^\s*#') { continue }

        # Get indentation
        $indent = 0
        if ($line -match '^(\s*)') {
            $indent = $matches[1].Length
        }

        # Skip empty lines but don't break multiline
        if ($line -match '^\s*$') { continue }

        # Handle multiline strings - collect continuation lines
        if ($multilineKey) {
            # If we're at a deeper indent, it's continuation
            if ($indent -gt $multilineIndent) {
                $multilineValue += " " + $line.Trim()
                continue
            } else {
                # End of multiline - store value
                if ($currentItem) {
                    $currentItem[$multilineKey] = $multilineValue.Trim()
                } else {
                    $data[$multilineKey] = $multilineValue.Trim()
                }
                $multilineKey = $null
                $multilineValue = ""
            }
        }

        # Top-level keys (no indentation)
        if ($indent -eq 0 -and $line -match '^([^:\-]+):\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Handle multiline indicator
            if ($value -eq '>') {
                $multilineKey = $key
                $multilineValue = ""
                $multilineIndent = $indent
                $currentSection = $null
                $currentItem = $null
                continue
            }

            # Remove quotes
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }

            if ($value -eq '') {
                # Section header
                $currentSection = $key
                $currentSubSection = $null
                $currentItem = $null
            } else {
                $data[$key] = $value
                $currentSection = $null
            }
            continue
        }

        # Inside a section
        if ($currentSection) {
            # Key:value at indent 2 (like contact.phone or sections.header)
            if ($indent -eq 2 -and $line -match '^\s{2}([^:\-]+):\s*(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()

                # Handle multiline indicator
                if ($value -eq '>') {
                    $multilineKey = $key
                    $multilineValue = ""
                    $multilineIndent = $indent
                    continue
                }

                # Remove quotes
                if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                    $value = $matches[1]
                }

                if ($value -eq '') {
                    # Subsection (like core_competencies.data_platforms_engineering)
                    $currentSubSection = $key
                    if ($data[$currentSection] -is [hashtable]) {
                        $data[$currentSection][$key] = @()
                    }
                } elseif ($value -eq 'true' -or $value -eq 'false') {
                    if ($data[$currentSection] -is [hashtable]) {
                        $data[$currentSection][$key] = ($value -eq 'true')
                    }
                } else {
                    if ($data[$currentSection] -is [hashtable]) {
                        $data[$currentSection][$key] = $value
                    }
                }
                continue
            }

            # Array item at indent 2
            if ($indent -eq 2 -and $line -match '^\s{2}-\s*(.*)$') {
                $value = $matches[1].Trim()

                # Remove quotes
                if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                    $value = $matches[1]
                }

                # Check if key:value on same line (like "- title: xxx")
                if ($value -match '^([^:]+):\s*(.+)$') {
                    $itemKey = $matches[1].Trim()
                    $itemValue = $matches[2].Trim()

                    # Handle multiline on same line as dash
                    if ($itemValue -eq '>') {
                        $currentItem = @{}
                        if ($data[$currentSection] -isnot [array]) {
                            $data[$currentSection] = @()
                        }
                        $data[$currentSection] += $currentItem
                        $multilineKey = $itemKey
                        $multilineValue = ""
                        $multilineIndent = $indent
                        continue
                    }

                    if ($itemValue -match '^"(.+)"$' -or $itemValue -match "^'(.+)'$") {
                        $itemValue = $matches[1]
                    }
                    $currentItem = @{ $itemKey = $itemValue }
                    if ($data[$currentSection] -isnot [array]) {
                        $data[$currentSection] = @()
                    }
                    $data[$currentSection] += $currentItem
                } elseif ($value -ne '') {
                    # Simple string array item
                    if ($data[$currentSection] -isnot [array]) {
                        $data[$currentSection] = @()
                    }
                    $data[$currentSection] += $value
                    $currentItem = $null
                } else {
                    # Complex object starting on next line
                    $currentItem = @{}
                    if ($data[$currentSection] -isnot [array]) {
                        $data[$currentSection] = @()
                    }
                    $data[$currentSection] += $currentItem
                }
                continue
            }

            # Properties within array item (indent 4)
            if ($indent -eq 4 -and $currentItem -and $line -match '^\s{4}([^:\-]+):\s*(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()

                # Handle multiline indicator
                if ($value -eq '>') {
                    $multilineKey = $key
                    $multilineValue = ""
                    $multilineIndent = $indent
                    continue
                }

                # Remove quotes
                if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                    $value = $matches[1]
                }

                if ($value -eq '') {
                    $currentItem[$key] = @()
                    $currentSubSection = $key
                } else {
                    $currentItem[$key] = $value
                }
                continue
            }

            # Nested array within item (indent 6, like achievements or technologies)
            if ($indent -eq 6 -and $currentItem -and $line -match '^\s{6}-\s*(.+)$') {
                $value = $matches[1].Trim()
                if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                    $value = $matches[1]
                }
                if ($currentSubSection -and $currentItem[$currentSubSection] -is [array]) {
                    $currentItem[$currentSubSection] += $value
                }
                continue
            }

            # Subsection array items (indent 4, like competency skills)
            if ($indent -eq 4 -and $currentSubSection -and -not $currentItem -and $line -match '^\s{4}-\s*(.+)$') {
                $value = $matches[1].Trim()
                if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                    $value = $matches[1]
                }
                if ($data[$currentSection] -is [hashtable] -and $data[$currentSection][$currentSubSection] -is [array]) {
                    $data[$currentSection][$currentSubSection] += $value
                }
                continue
            }
        }
    }

    # Handle final multiline value
    if ($multilineKey) {
        if ($currentItem) {
            $currentItem[$multilineKey] = $multilineValue.Trim()
        } else {
            $data[$multilineKey] = $multilineValue.Trim()
        }
    }

    # Post-process: Parse interests_volunteering directly (simple string array)
    if ($yaml -match '(?s)interests_volunteering:\s*\n(.+?)(?=\n[a-z_]+:|$)') {
        $interestsBlock = $matches[1]
        $data.interests_volunteering = @()
        $interestsBlock -split "`r?`n" | ForEach-Object {
            if ($_ -match '^\s{2}-\s*"(.+)"') {
                $data.interests_volunteering += $matches[1]
            }
        }
    }

    # Post-process: Parse testimonials directly (array of objects with multiline quotes)
    if ($yaml -match '(?s)testimonials:\s*\n(.+?)(?=\n[a-z_]+:|$)') {
        $testimonialsBlock = $matches[1]
        $data.testimonials = @()

        # Split by "  - quote:" pattern
        $entries = $testimonialsBlock -split '(?=\s{2}-\s*quote:)'
        foreach ($entry in $entries) {
            if ($entry -match '(?s)^\s{2}-\s*quote:\s*>\s*\n(.+?)\n\s{4}source:\s*"([^"]+)"') {
                $quote = ($matches[1] -replace '\s+', ' ').Trim()
                $source = $matches[2]
                $data.testimonials += @{
                    quote = $quote
                    source = $source
                }
            }
        }
    }

    return $data
}

#######################################
# LANGUAGE LABELS
#######################################

function Load-Labels {
    param([string]$LangCode)

    $labelsFile = Join-Path $ConfigDir "labels_$LangCode.yaml"
    if (-not (Test-Path $labelsFile)) {
        # Fall back to base language (e.g. de_ch -> de)
        $baseLang = ($LangCode -split '_')[0]
        $labelsFile = Join-Path $ConfigDir "labels_$baseLang.yaml"
        if (-not (Test-Path $labelsFile)) {
            Write-Host "[ERROR] Labels file not found for '$LangCode' or '$baseLang'" -ForegroundColor Red
            exit 1
        }
        Write-Host "  Using base language labels: labels_$baseLang.yaml" -ForegroundColor Yellow
    }

    $content = Get-Content $labelsFile -Raw -Encoding UTF8
    $labels = @{}
    foreach ($line in ($content -split "`r?`n")) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
        if ($line -match '^([^:]+):\s*"(.+)"$') {
            $labels[$matches[1].Trim()] = $matches[2]
        } elseif ($line -match "^([^:]+):\s*'(.+)'$") {
            $labels[$matches[1].Trim()] = $matches[2]
        } elseif ($line -match '^([^:]+):\s*(.+)$') {
            $labels[$matches[1].Trim()] = $matches[2].Trim()
        }
    }

    return $labels
}

#######################################
# LATEX ESCAPING
#######################################

function Escape-LaTeX {
    param([string]$text)

    if ([string]::IsNullOrEmpty($text)) { return "" }

    # Escape special LaTeX characters
    $text = $text -replace '\\', '\textbackslash{}'
    $text = $text -replace '&', '\&'
    $text = $text -replace '%', '\%'
    $text = $text -replace '\$', '\$'
    $text = $text -replace '#', '\#'
    $text = $text -replace '_', '\_'
    $text = $text -replace '\{', '\{'
    $text = $text -replace '\}', '\}'
    $text = $text -replace '~', '\textasciitilde{}'
    $text = $text -replace '\^', '\textasciicircum{}'

    # Handle special patterns
    $text = $text -replace '>', '\textgreater{}'
    $text = $text -replace '<', '\textless{}'

    return $text
}

function Escape-LaTeXKeepFormatting {
    param([string]$text)

    if ([string]::IsNullOrEmpty($text)) { return "" }

    # Only escape the most problematic characters, keep & for tabular
    $text = $text -replace '%', '\%'
    $text = $text -replace '\$', '\$'
    $text = $text -replace '#', '\#'
    $text = $text -replace '_', '\_'
    $text = $text -replace '~', '\textasciitilde{}'

    return $text
}

#######################################
# SECTION GENERATORS
#######################################

function Generate-Header {
    param($data, $labels)

    $template = Get-Content "$TemplatesDir\header.tex.template" -Raw

    $name = $data.name -replace '"', ''
    $headline = $data.headline -replace '"', ''
    $location = $data.location -replace '"', ''
    $email = $data.contact.email
    $phone = $data.contact.phone
    $phoneTel = $phone -replace '[^\d+]', ''
    $linkedinUrl = $data.contact.linkedin
    $linkedinDisplay = $linkedinUrl -replace 'https://', ''
    $githubUrl = $data.contact.github
    $githubDisplay = $githubUrl -replace 'https://', ''

    $template = $template -replace '\{\{NAME\}\}', $name
    $template = $template -replace '\{\{HEADLINE\}\}', $headline
    $template = $template -replace '\{\{LOCATION\}\}', $location
    $template = $template -replace '\{\{EMAIL\}\}', $email
    $template = $template -replace '\{\{PHONE\}\}', $phone
    $template = $template -replace '\{\{PHONE_TEL\}\}', $phoneTel
    $template = $template -replace '\{\{LINKEDIN_URL\}\}', $linkedinUrl
    $template = $template -replace '\{\{LINKEDIN_DISPLAY\}\}', $linkedinDisplay
    $template = $template -replace '\{\{GITHUB_URL\}\}', $githubUrl
    $template = $template -replace '\{\{GITHUB_DISPLAY\}\}', $githubDisplay

    # Personal details (optional — used in Swiss/DACH CVs)
    # Controlled by sections.personal_details (default: true if block exists)
    $personalDetailsBlock = ""
    $showPersonalDetails = if ($data.sections.ContainsKey('personal_details')) { $data.sections.personal_details } else { $true }
    if ($showPersonalDetails -and $data.personal_details) {
        $pd = $data.personal_details
        $fields = @()
        if ($pd.date_of_birth) {
            $lbl = if ($labels -and $labels.personal_date_of_birth) { $labels.personal_date_of_birth } else { "Date of Birth" }
            $fields += "\mbox{$lbl`: $(Escape-LaTeX $pd.date_of_birth)}"
        }
        if ($pd.nationality) {
            $lbl = if ($labels -and $labels.personal_nationality) { $labels.personal_nationality } else { "Nationality" }
            $fields += "\mbox{$lbl`: $(Escape-LaTeX $pd.nationality)}"
        }
        if ($pd.residence) {
            $lbl = if ($labels -and $labels.personal_residence) { $labels.personal_residence } else { "Residence" }
            $fields += "\mbox{$lbl`: $(Escape-LaTeX $pd.residence)}"
        }
        if ($pd.marital_status) {
            $lbl = if ($labels -and $labels.personal_marital_status) { $labels.personal_marital_status } else { "Marital Status" }
            $fields += "\mbox{$lbl`: $(Escape-LaTeX $pd.marital_status)}"
        }
        if ($fields.Count -gt 0) {
            $separator = "%`n    \kern 5.0 pt%`n    \AND%`n    \kern 5.0 pt%`n    "
            $joined = $fields -join $separator
            $personalDetailsBlock = "`n`n    \vspace{3 pt}`n`n    $joined"
        }
    }
    $template = $template -replace '\{\{PERSONAL_DETAILS\}\}', $personalDetailsBlock

    return $template
}

function Generate-Summary {
    param($data, $labels)

    $template = Get-Content "$TemplatesDir\summary.tex.template" -Raw

    $summary = $data.professional_summary
    # Add bold formatting for key phrases
    $summary = $summary -replace '(\d+\+?\s*years)', '\textbf{$1}'
    $summary = $summary -replace "(PwC Switzerland's enterprise data services platform)", '\textbf{$1}'

    $template = $template -replace '\{\{SECTION_TITLE\}\}', $labels.section_professional_summary
    $template = $template -replace '\{\{PROFESSIONAL_SUMMARY\}\}', $summary

    return $template
}

function Generate-Skills {
    param($data, $labels)

    $template = Get-Content "$TemplatesDir\skills.tex.template" -Raw

    $content = @()

    # Build competency category list dynamically from data
    $allCategories = @('data_platforms_engineering', 'business_intelligence', 'automation_development', 'full_stack_web', 'leadership_strategy', 'finance_expertise', 'enterprise_systems')

    $first = $true
    foreach ($category in $allCategories) {
        if ($data.core_competencies[$category] -and $data.core_competencies[$category].Count -gt 0) {
            if (-not $first) {
                $content += "\vspace{0.2 cm}"
                $content += ""
            }
            $first = $false

            $label = $labels["comp_$category"]
            $skills = ($data.core_competencies[$category] | ForEach-Object { $_ -replace '"', '' }) -join ', '
            $skills = $skills -replace '&', '\&'

            $content += "\begin{onecolentry}"
            $content += "    \textbf{${label}:} $skills."
            $content += "\end{onecolentry}"
        }
    }

    $template = $template -replace '\{\{SECTION_TITLE\}\}', $labels.section_core_competencies
    $template = $template -replace '\{\{COMPETENCIES_CONTENT\}\}', ($content -join "`n")

    return $template
}

function Format-DateRange {
    param([string]$startDate, [string]$endDate, $labels)

    $sep = if ($labels -and $labels.date_separator) { $labels.date_separator } else { "/" }
    $presentLabel = if ($labels -and $labels.present) { $labels.present } else { "Present" }

    # Convert YYYY-MM to MM{sep}YYYY
    $start = ""
    $end = ""

    if ($startDate -match '^(\d{4})-(\d{2})$') {
        $start = "$($matches[2])$sep$($matches[1])"
    } else {
        $start = $startDate
    }

    if ($endDate -eq 'Present') {
        $end = $presentLabel
    } elseif ($endDate -match '^(\d{4})-(\d{2})$') {
        $end = "$($matches[2])$sep$($matches[1])"
    } else {
        $end = $endDate
    }

    return "$start - $end"
}

function Generate-Experience {
    param($data, $labels)

    $template = Get-Content "$TemplatesDir\experience.tex.template" -Raw

    $content = @()
    $first = $true

    foreach ($job in $data.experience) {
        if (-not $first) {
            $content += "\vspace{0.3 cm}"
            $content += ""
        }
        $first = $false

        $dateRange = Format-DateRange $job.start_date $job.end_date $labels
        $title = $job.title -replace '&', '\&'
        $company = $job.company -replace '&', '\&'
        $location = $job.location

        $content += "\begin{twocolentry}{"
        $content += "    $dateRange"
        $content += "}"
        $content += "    \textbf{$title}, $company -- $location"
        $content += "\end{twocolentry}"
        $content += ""
        $content += "\vspace{\separatorspacetop}"
        $content += "\textcolor{lightgrey}{\rule{\linewidth}{0.4pt}}"
        $content += "\vspace{\separatorspacebottom}"
        $content += ""
        $content += "\vspace{0.10 cm}"
        $content += "\begin{onecolentry}"

        # Add description/responsibilities if present
        if ($job.responsibilities) {
            $resp = $job.responsibilities -replace '&', '\&'
            $content += "    $resp"
        } elseif ($job.description) {
            $desc = $job.description -replace '&', '\&'
            $content += "    $desc"
        }

        # Add achievements if present
        if ($job.achievements -and $job.achievements.Count -gt 0) {
            if ($job.responsibilities -or $job.description) {
                $content += ""
                $content += "    \vspace{0.05 cm}"
            }
            $content += "    \begin{highlights}"
            foreach ($achievement in $job.achievements) {
                $ach = $achievement -replace '&', '\&'
                $ach = $ach -replace '#', '\#'
                $ach = $ach -replace '~', '\textasciitilde{}'
                # Bold numbers and key metrics
                $ach = $ach -replace '(\d+K?\+?)', '\textbf{$1}'
                $ach = $ach -replace '(USD \d+[KM]?)', '\textbf{$1}'
                $ach = $ach -replace '(MXN)', '\textbf{$1}'
                $content += "           \item $ach"
            }
            $content += "    \end{highlights}"
        }

        $content += "\end{onecolentry}"
    }

    $template = $template -replace '\{\{SECTION_TITLE\}\}', $labels.section_experience
    $template = $template -replace '\{\{EXPERIENCE_CONTENT\}\}', ($content -join "`n")

    return $template
}

function Generate-Education {
    param($data, $labels)

    $template = Get-Content "$TemplatesDir\education.tex.template" -Raw

    $content = @()
    $first = $true

    foreach ($edu in $data.education) {
        if (-not $first) {
            $content += "\vspace{0.2 cm}"
            $content += ""
        }
        $first = $false

        $years = if ($edu.start_year -eq $edu.end_year) { $edu.start_year } else { "$($edu.start_year) - $($edu.end_year)" }
        $degree = $edu.degree -replace '&', '\&'
        $institution = $edu.institution
        $location = $edu.location

        $content += "\begin{twocolentry}{"
        $content += "    $years"
        $content += "}"
        $content += "    \textbf{$degree}, $institution -- $location"
        $content += "\end{twocolentry}"
    }

    $template = $template -replace '\{\{SECTION_TITLE\}\}', $labels.section_education
    $template = $template -replace '\{\{EDUCATION_CONTENT\}\}', ($content -join "`n")

    return $template
}

function Generate-Certifications {
    param($data, $labels)

    $template = Get-Content "$TemplatesDir\certifications.tex.template" -Raw

    $content = @()
    $first = $true

    foreach ($cert in $data.certifications) {
        if (-not $first) {
            $content += "\vspace{0.2 cm}"
            $content += ""
        }
        $first = $false

        $certName = $cert -replace '"', ''

        $content += "\begin{onecolentry}"
        $content += "    \textbf{$certName}"
        $content += "\end{onecolentry}"
    }

    $template = $template -replace '\{\{SECTION_TITLE\}\}', $labels.section_certifications
    $template = $template -replace '\{\{CERTIFICATIONS_CONTENT\}\}', ($content -join "`n")

    return $template
}

function Generate-Languages {
    param($data, $labels)

    $template = Get-Content "$TemplatesDir\languages.tex.template" -Raw

    $langs = @()
    foreach ($lang in $data.languages) {
        $langs += "$($lang.language) ($($lang.level))"
    }

    $content = $langs -join ', '

    $template = $template -replace '\{\{SECTION_TITLE\}\}', $labels.section_languages
    $template = $template -replace '\{\{LANGUAGES_CONTENT\}\}', $content

    return $template
}

function Generate-Interests {
    param($data, $labels)

    $template = Get-Content "$TemplatesDir\interests.tex.template" -Raw

    $content = @()
    $first = $true

    foreach ($interest in $data.interests_volunteering) {
        # Skip if not a string
        if ($interest -isnot [string]) { continue }

        if (-not $first) {
            $content += "\vspace{0.2 cm}"
            $content += ""
        }
        $first = $false

        $text = $interest -replace '"', ''

        # Split into label and description
        if ($text -match '^([^:]+):\s*(.+)$') {
            $label = $matches[1]
            $desc = $matches[2]
            # Handle links
            if ($desc -match 'Powercoders') {
                $desc = $desc -replace 'Powercoders', '\href{https://powercoders.org/}{Powercoders}'
            }
            # Bold numbers
            $desc = $desc -replace '(\d+\+?)', '\textbf{$1}'

            $content += "\begin{onecolentry}"
            $content += "    \textbf{${label}:} $desc"
            $content += "\end{onecolentry}"
        } else {
            $content += "\begin{onecolentry}"
            $content += "    $text"
            $content += "\end{onecolentry}"
        }
    }

    $template = $template -replace '\{\{SECTION_TITLE\}\}', $labels.section_interests
    $template = $template -replace '\{\{INTERESTS_CONTENT\}\}', ($content -join "`n")

    return $template
}

function Generate-Projects {
    param($data, $labels)

    $template = Get-Content "$TemplatesDir\projects.tex.template" -Raw

    $content = @()
    $first = $true

    foreach ($project in $data.community_open_source_projects) {
        if (-not $first) {
            $content += "\vspace{0.2 cm}"
            $content += ""
        }
        $first = $false

        $title = $project.title -replace '&', '\&'
        $url = $project.url
        $desc = $project.description -replace '&', '\&'

        $content += "\begin{onecolentry}"
        $content += "    \textbf{\href{$url}{$title}}, $desc"
        $content += "\end{onecolentry}"
    }

    $template = $template -replace '\{\{SECTION_TITLE\}\}', $labels.section_projects
    $template = $template -replace '\{\{PROJECTS_CONTENT\}\}', ($content -join "`n")

    return $template
}

function Generate-Testimonials {
    param($data, $labels)

    $template = Get-Content "$TemplatesDir\testimonials.tex.template" -Raw

    $content = @()
    $first = $true

    foreach ($testimonial in $data.testimonials) {
        # Skip if not a hashtable with quote and source
        if ($testimonial -isnot [hashtable]) { continue }
        if (-not $testimonial.quote -or -not $testimonial.source) { continue }

        if (-not $first) {
            $content += "\vspace{0.2 cm}"
            $content += ""
        }
        $first = $false

        $quote = $testimonial.quote -replace '"', ''
        $quote = $quote -replace "`r?`n\s*", ' '
        $quote = $quote.Trim()
        $quote = $quote -replace '&', '\&'
        $source = $testimonial.source -replace '&', '\&'

        $content += "\begin{onecolentry}"
        $content += "    \textit{'$quote'}"
        $content += ""
        $content += "    \vspace{0.05 cm}"
        $content += "    --- $source"
        $content += "\end{onecolentry}"
    }

    $template = $template -replace '\{\{SECTION_TITLE\}\}', $labels.section_testimonials
    $template = $template -replace '\{\{TESTIMONIALS_CONTENT\}\}', ($content -join "`n")

    return $template
}

#######################################
# MOTIVATION LETTER FUNCTIONS
#######################################

function Build-Letter {
    param([string]$letterName)

    Write-Host "Building motivation letter..." -ForegroundColor Green
    Write-Host ""

    # Find the letter file
    $letterFile = $null
    if ($letterName) {
        # Try with and without .md extension
        $possiblePaths = @(
            (Join-Path $LettersDir "$letterName.md"),
            (Join-Path $LettersDir $letterName)
        )
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $letterFile = $path
                break
            }
        }
    }

    if (-not $letterFile) {
        Write-Host "  [ERROR] Letter file not found: $letterName" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available letters:" -ForegroundColor Yellow
        Get-ChildItem -Path $LettersDir -Filter "*.md" | Where-Object { $_.Name -ne "_TEMPLATE.md" } | ForEach-Object {
            Write-Host "    - $($_.BaseName)" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "Usage: .\build.ps1 letter <LetterName>" -ForegroundColor Yellow
        Write-Host "Example: .\build.ps1 letter Google_DataEngineer" -ForegroundColor Gray
        exit 1
    }

    Write-Host "Letter file: $letterFile" -ForegroundColor Cyan

    # Parse personal data (for name, contact info)
    Write-Host "Reading personal info from $DataFile..." -ForegroundColor Cyan
    try {
        $personalData = Parse-FullYaml $DataFile
    } catch {
        Write-Host "  [ERROR] Failed to parse personal data: $_" -ForegroundColor Red
        exit 1
    }

    # Parse letter data
    Write-Host "Reading letter content from $letterFile..." -ForegroundColor Cyan
    try {
        $letterData = Parse-LetterYaml $letterFile
    } catch {
        Write-Host "  [ERROR] Failed to parse letter data: $_" -ForegroundColor Red
        exit 1
    }

    Write-Host "  [OK] Data loaded successfully" -ForegroundColor Green
    Write-Host ""

    # Load language labels
    Write-Host "Loading language labels ($Lang)..." -ForegroundColor Cyan
    $labels = Load-Labels $Lang
    Write-Host "  [OK] Labels loaded" -ForegroundColor Green

    # Generate letter .tex file
    Write-Host "Generating letter.tex..." -ForegroundColor Cyan
    $letterTex = Generate-LetterTex $personalData $letterData $labels
    $letterTexFile = Join-Path $ScriptDir "letter.tex"
    # Write UTF-8 without BOM for LaTeX compatibility
    [System.IO.File]::WriteAllText($letterTexFile, $letterTex, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  [OK] letter.tex generated" -ForegroundColor Green

    Write-Host ""

    # Compile LaTeX
    Write-Host "Compiling LaTeX..." -ForegroundColor Cyan
    Push-Location $ScriptDir
    try {
        pdflatex -interaction=nonstopmode letter.tex | Out-Null
        pdflatex -interaction=nonstopmode letter.tex | Out-Null
    } finally {
        Pop-Location
    }

    $letterPdf = Join-Path $ScriptDir "letter.pdf"
    if (Test-Path $letterPdf) {
        # Ensure output directory exists
        $letterOutputDir = Join-Path $ScriptDir "output\letters"
        if (-not (Test-Path $letterOutputDir)) {
            New-Item -ItemType Directory -Path $letterOutputDir -Force | Out-Null
        }

        # Rename to "<LetterFileName> (yyyy.MM.dd).pdf"
        $date = Get-Date -Format "yyyy.MM.dd"
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($letterFile)
        $outputName = Join-Path $letterOutputDir "$baseName ($date).pdf"

        # Remove existing file and move new one
        if (Test-Path $outputName) {
            Remove-Item $outputName -Force
        }
        Move-Item -Path $letterPdf -Destination $outputName -Force
        Write-Host ""
        Write-Host "[OK] Letter compiled successfully! Output: output\letters\$(Split-Path $outputName -Leaf)" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[ERROR] Build failed! Check letter.log for errors." -ForegroundColor Red
        exit 1
    }
}

function Parse-LetterYaml {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw -Encoding UTF8

    # Extract YAML frontmatter
    if ($content -match '(?s)^---\r?\n(.+?)\r?\n---') {
        $yaml = $matches[1]
    } else {
        throw "No YAML frontmatter found"
    }

    $data = @{
        recipient = @{
            name = ""
            title = ""
            company = ""
            address = ""
        }
        position = ""
        date = ""
        subject = ""
        salutation = ""
        body = ""
        closing = ""
    }

    $lines = $yaml -split "`r?`n"
    $currentSection = $null
    $multilineKey = $null
    $multilineValue = ""
    $multilineIndent = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Skip comments
        if ($line -match '^\s*#') { continue }

        # Get indentation
        $indent = 0
        if ($line -match '^(\s*)') {
            $indent = $matches[1].Length
        }

        # Skip empty lines
        if ($line -match '^\s*$') { continue }

        # Handle multiline strings (|)
        if ($multilineKey) {
            if ($indent -gt $multilineIndent) {
                if ($multilineValue -ne "") {
                    $multilineValue += "`n`n"
                }
                $multilineValue += $line.Trim()
                continue
            } else {
                # End of multiline
                $data[$multilineKey] = $multilineValue.Trim()
                $multilineKey = $null
                $multilineValue = ""
            }
        }

        # Top-level keys
        if ($indent -eq 0 -and $line -match '^([^:\-]+):\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Handle multiline indicator
            if ($value -eq '|') {
                $multilineKey = $key
                $multilineValue = ""
                $multilineIndent = $indent
                $currentSection = $null
                continue
            }

            # Remove quotes
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }

            if ($value -eq '') {
                $currentSection = $key
            } else {
                $data[$key] = $value
                $currentSection = $null
            }
            continue
        }

        # Inside recipient section
        if ($currentSection -eq 'recipient' -and $indent -eq 2 -and $line -match '^\s{2}([^:]+):\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }
            $data.recipient[$key] = $value
            continue
        }
    }

    # Handle final multiline value
    if ($multilineKey) {
        $data[$multilineKey] = $multilineValue.Trim()
    }

    return $data
}

function Generate-LetterTex {
    param($personalData, $letterData, $labels)

    $template = Get-Content "$TemplatesDir\letter.tex.template" -Raw -Encoding UTF8

    # Personal info from CV data
    $name = $personalData.name -replace '"', ''
    $location = $personalData.location -replace '"', ''
    $email = $personalData.contact.email
    $phone = $personalData.contact.phone

    # Letter-specific info
    $recipientName = $letterData.recipient.name
    $recipientTitle = $letterData.recipient.title
    $companyName = $letterData.recipient.company
    $companyAddress = $letterData.recipient.address

    $subject = $letterData.subject
    # Escape LaTeX special characters in subject
    $subject = $subject -replace '%', '\%'
    $subject = $subject -replace '&', '\&'
    $subject = $subject -replace '_', '\_'
    $salutation = $letterData.salutation
    $closing = $letterData.closing

    # Date - use today if not specified
    $date = $letterData.date
    if ([string]::IsNullOrEmpty($date)) {
        $dateFormat = if ($labels -and $labels.letter_date_format) { $labels.letter_date_format } else { "MMMM d, yyyy" }
        $cultureName = if ($labels -and $labels.letter_date_culture) { $labels.letter_date_culture } else { "en-US" }
        $culture = [System.Globalization.CultureInfo]::new($cultureName)
        $date = (Get-Date).ToString($dateFormat, $culture)
    }

    # Subject prefix from labels
    $subjectPrefix = if ($labels -and $labels.letter_subject_prefix) { $labels.letter_subject_prefix } else { "Re:" }

    # Body - convert paragraphs to LaTeX
    $body = $letterData.body
    # Escape LaTeX special characters (but preserve paragraph breaks)
    $body = $body -replace '&', '\&'
    $body = $body -replace '%', '\%'
    $body = $body -replace '\$', '\$'
    $body = $body -replace '#', '\#'
    $body = $body -replace '_', '\_'

    # Replace template placeholders
    $template = $template -replace '\{\{NAME\}\}', $name
    $template = $template -replace '\{\{LOCATION\}\}', $location
    $template = $template -replace '\{\{EMAIL\}\}', $email
    $template = $template -replace '\{\{PHONE\}\}', $phone
    $template = $template -replace '\{\{DATE\}\}', $date
    $template = $template -replace '\{\{RECIPIENT_NAME\}\}', $recipientName
    $template = $template -replace '\{\{RECIPIENT_TITLE\}\}', $recipientTitle
    $template = $template -replace '\{\{COMPANY_NAME\}\}', $companyName
    $template = $template -replace '\{\{COMPANY_ADDRESS\}\}', $companyAddress
    $template = $template -replace '\{\{SUBJECT_PREFIX\}\}', $subjectPrefix
    $template = $template -replace '\{\{SUBJECT\}\}', $subject
    $template = $template -replace '\{\{SALUTATION\}\}', $salutation
    $template = $template -replace '\{\{BODY\}\}', $body
    $template = $template -replace '\{\{CLOSING\}\}', $closing

    return $template
}

#######################################
# MAIN BUILD FUNCTIONS
#######################################

function Generate-Sections {
    param($data, $labels)

    Write-Host "Generating sections from YAML data..." -ForegroundColor Cyan

    # Ensure sections directory exists
    if (-not (Test-Path $SectionsDir)) {
        New-Item -ItemType Directory -Path $SectionsDir -Force | Out-Null
    }

    $sections = $data.sections
    $generatedSections = @()

    # Header (always generated if enabled)
    if ($sections.header -eq $true) {
        $content = Generate-Header $data $labels
        Set-Content -Path "$SectionsDir\header.tex" -Value $content -Encoding UTF8
        $generatedSections += 'header'
        Write-Host "  [OK] header.tex" -ForegroundColor Green
    }

    # Professional Summary
    if ($sections.professional_summary -eq $true -and $data.professional_summary) {
        $content = Generate-Summary $data $labels
        Set-Content -Path "$SectionsDir\summary.tex" -Value $content -Encoding UTF8
        $generatedSections += 'summary'
        Write-Host "  [OK] summary.tex" -ForegroundColor Green
    }

    # Core Competencies
    if ($sections.core_competencies -eq $true -and $data.core_competencies.Count -gt 0) {
        $content = Generate-Skills $data $labels
        Set-Content -Path "$SectionsDir\skills.tex" -Value $content -Encoding UTF8
        $generatedSections += 'skills'
        Write-Host "  [OK] skills.tex" -ForegroundColor Green
    }

    # Experience
    if ($sections.experience -eq $true -and $data.experience.Count -gt 0) {
        $content = Generate-Experience $data $labels
        Set-Content -Path "$SectionsDir\experience.tex" -Value $content -Encoding UTF8
        $generatedSections += 'experience'
        Write-Host "  [OK] experience.tex" -ForegroundColor Green
    }

    # Education
    if ($sections.education -eq $true -and $data.education.Count -gt 0) {
        $content = Generate-Education $data $labels
        Set-Content -Path "$SectionsDir\education.tex" -Value $content -Encoding UTF8
        $generatedSections += 'education'
        Write-Host "  [OK] education.tex" -ForegroundColor Green
    }

    # Certifications
    if ($sections.certifications -eq $true -and $data.certifications.Count -gt 0) {
        $content = Generate-Certifications $data $labels
        Set-Content -Path "$SectionsDir\certifications.tex" -Value $content -Encoding UTF8
        $generatedSections += 'certifications'
        Write-Host "  [OK] certifications.tex" -ForegroundColor Green
    }

    # Languages
    if ($sections.languages -eq $true -and $data.languages.Count -gt 0) {
        $content = Generate-Languages $data $labels
        Set-Content -Path "$SectionsDir\languages.tex" -Value $content -Encoding UTF8
        $generatedSections += 'languages'
        Write-Host "  [OK] languages.tex" -ForegroundColor Green
    }

    # Interests & Volunteering
    if ($sections.interests_volunteering -eq $true -and $data.interests_volunteering.Count -gt 0) {
        $content = Generate-Interests $data $labels
        Set-Content -Path "$SectionsDir\interests.tex" -Value $content -Encoding UTF8
        $generatedSections += 'interests'
        Write-Host "  [OK] interests.tex" -ForegroundColor Green
    }

    # Community & Open-Source Projects
    if ($sections.community_open_source_projects -eq $true -and $data.community_open_source_projects.Count -gt 0) {
        $content = Generate-Projects $data $labels
        Set-Content -Path "$SectionsDir\projects.tex" -Value $content -Encoding UTF8
        $generatedSections += 'projects'
        Write-Host "  [OK] projects.tex" -ForegroundColor Green
    }

    # Testimonials
    if ($sections.testimonials -eq $true -and $data.testimonials.Count -gt 0) {
        $content = Generate-Testimonials $data $labels
        Set-Content -Path "$SectionsDir\testimonials.tex" -Value $content -Encoding UTF8
        $generatedSections += 'testimonials'
        Write-Host "  [OK] testimonials.tex" -ForegroundColor Green
    }

    return $generatedSections
}

function Generate-MainTex {
    param([array]$enabledSections)

    Write-Host "Generating cv.tex with enabled sections..." -ForegroundColor Cyan

    $content = @"
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Oscar Martinez - Curriculum Vitae
% LaTeX Template - Auto-generated from YAML data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\documentclass[10pt, letterpaper]{article}

% Custom configurations
\input{config/packages}
\input{config/settings}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DOCUMENT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\begin{document}
"@

    # Add sections in order
    $sectionOrder = @(
        @{ key = 'header'; comment = 'Header' },
        @{ key = 'summary'; comment = 'Professional Summary - First impression' },
        @{ key = 'skills'; comment = 'Core Competencies - Quick skills scan' },
        @{ key = 'experience'; comment = 'Professional Experience - Most important for senior roles' },
        @{ key = 'languages'; comment = 'Languages - International capability' },
        @{ key = 'certifications'; comment = 'Certifications - Credentials' },
        @{ key = 'education'; comment = 'Education - Academic background' },
        @{ key = 'projects'; comment = 'Community & Open-Source Projects - Innovation' },
        @{ key = 'interests'; comment = 'Interests & Volunteering - Cultural fit' },
        @{ key = 'testimonials'; comment = 'Testimonials - Social proof' }
    )

    foreach ($section in $sectionOrder) {
        if ($enabledSections -contains $section.key) {
            $content += "`n    % $($section.comment)"
            $content += "`n    \input{sections/$($section.key)}"
            $content += "`n"
        }
    }

    $content += @"

\end{document}
"@

    Set-Content -Path $MainFile -Value $content -Encoding UTF8
    Write-Host "  [OK] cv.tex generated" -ForegroundColor Green
}

function Build-CV {
    Write-Host "Building CV ($Lang)..." -ForegroundColor Green
    Write-Host ""

    # Load language labels
    Write-Host "Loading language labels ($Lang)..." -ForegroundColor Cyan
    $labels = Load-Labels $Lang
    Write-Host "  [OK] Labels loaded" -ForegroundColor Green

    # Parse YAML data
    Write-Host "Parsing YAML data from $DataFile..." -ForegroundColor Cyan
    try {
        $data = Parse-FullYaml $DataFile
        Write-Host "  [OK] YAML parsed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Failed to parse YAML: $_" -ForegroundColor Red
        exit 1
    }

    Write-Host ""

    # Generate section files
    $enabledSections = Generate-Sections $data $labels

    Write-Host ""

    # Generate main tex file
    Generate-MainTex $enabledSections

    Write-Host ""

    # Compile LaTeX (run twice for references)
    Write-Host "Compiling LaTeX..." -ForegroundColor Cyan
    Push-Location $ScriptDir
    try {
        pdflatex -interaction=nonstopmode cv.tex | Out-Null
        pdflatex -interaction=nonstopmode cv.tex | Out-Null
    } finally {
        Pop-Location
    }

    $cvPdf = Join-Path $ScriptDir "cv.pdf"
    if (Test-Path $cvPdf) {
        # Ensure output directory exists
        $cvOutputDir = Join-Path $ScriptDir "output\cv"
        if (-not (Test-Path $cvOutputDir)) {
            New-Item -ItemType Directory -Path $cvOutputDir -Force | Out-Null
        }

        # Rename to "Name LastName yyyyMMdd_lang.pdf"
        $date = Get-Date -Format "yyyyMMdd"
        # Get name from YAML, format as title case, remove accents
        $name = $data.name -replace '"', ''
        $name = [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($name))
        $name = (Get-Culture).TextInfo.ToTitleCase($name.ToLower())
        $outputName = Join-Path $cvOutputDir "${name} ${date}_$Lang.pdf"
        # Remove existing file if present, then move
        if (Test-Path $outputName) {
            Remove-Item $outputName -Force
        }
        Move-Item -Path $cvPdf -Destination $outputName -Force
        Write-Host ""
        Write-Host "[OK] CV compiled successfully! Output: output\cv\$(Split-Path $outputName -Leaf)" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[ERROR] Build failed! Check cv.log for errors." -ForegroundColor Red
        exit 1
    }
}

function Clean-BuildFiles {
    Write-Host "Cleaning build files..." -ForegroundColor Yellow

    # Remove generated .tex files (CV and letter)
    $cvTexFile = Join-Path $ScriptDir "cv.tex"
    $letterTexFile = Join-Path $ScriptDir "letter.tex"
    if (Test-Path $cvTexFile) { Remove-Item $cvTexFile -Force }
    if (Test-Path $letterTexFile) { Remove-Item $letterTexFile -Force }
    Write-Host "  [OK] Removed .tex files" -ForegroundColor Green

    # Remove sections/*.tex files
    if (Test-Path $SectionsDir) {
        Get-ChildItem -Path $SectionsDir -Filter "*.tex" -ErrorAction SilentlyContinue | Remove-Item -Force
        Write-Host "  [OK] Removed sections/*.tex files" -ForegroundColor Green
    }

    # Remove auxiliary files by explicit names (cv.* and letter.*)
    $auxExtensions = @("aux", "log", "out", "toc", "fdb_latexmk", "fls", "synctex.gz")
    foreach ($ext in $auxExtensions) {
        Remove-Item -Path (Join-Path $ScriptDir "cv.$ext") -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $ScriptDir "letter.$ext") -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  [OK] Removed auxiliary files" -ForegroundColor Green

    Write-Host "  [OK] Cleanup complete!" -ForegroundColor Green
}

function Compile-Only {
    Write-Host "Compiling existing .tex files..." -ForegroundColor Green
    Write-Host ""

    # Check if cv.tex exists
    if (-not (Test-Path $MainFile)) {
        Write-Host "  [ERROR] cv.tex not found. Run 'build' or 'generate' first." -ForegroundColor Red
        exit 1
    }

    # Parse YAML just to get the name for output file
    Write-Host "Reading name from $DataFile..." -ForegroundColor Cyan
    try {
        $data = Parse-FullYaml $DataFile
    } catch {
        Write-Host "  [ERROR] Failed to parse YAML: $_" -ForegroundColor Red
        exit 1
    }

    Write-Host ""

    # Compile LaTeX (run twice for references)
    Write-Host "Compiling LaTeX..." -ForegroundColor Cyan
    Push-Location $ScriptDir
    try {
        pdflatex -interaction=nonstopmode cv.tex | Out-Null
        pdflatex -interaction=nonstopmode cv.tex | Out-Null
    } finally {
        Pop-Location
    }

    $cvPdf = Join-Path $ScriptDir "cv.pdf"
    if (Test-Path $cvPdf) {
        # Ensure output directory exists
        $cvOutputDir = Join-Path $ScriptDir "output\cv"
        if (-not (Test-Path $cvOutputDir)) {
            New-Item -ItemType Directory -Path $cvOutputDir -Force | Out-Null
        }

        # Rename to "Name LastName yyyyMMdd_lang.pdf"
        $date = Get-Date -Format "yyyyMMdd"
        $name = $data.name -replace '"', ''
        $name = [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($name))
        $name = (Get-Culture).TextInfo.ToTitleCase($name.ToLower())
        $outputName = Join-Path $cvOutputDir "${name} ${date}_$Lang.pdf"
        if (Test-Path $outputName) {
            Remove-Item $outputName -Force
        }
        Move-Item -Path $cvPdf -Destination $outputName -Force
        Write-Host ""
        Write-Host "[OK] CV compiled successfully! Output: output\cv\$(Split-Path $outputName -Leaf)" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[ERROR] Build failed! Check cv.log for errors." -ForegroundColor Red
        exit 1
    }
}

#######################################
# MAIN SCRIPT LOGIC
#######################################

switch ($Action.ToLower()) {
    "build" {
        Build-CV
    }
    "clean" {
        Clean-BuildFiles
    }
    "rebuild" {
        Clean-BuildFiles
        Build-CV
    }
    "generate" {
        # Only generate tex files without compiling
        Write-Host "Generating .tex files from YAML ($Lang)..." -ForegroundColor Green
        $labels = Load-Labels $Lang
        $data = Parse-FullYaml $DataFile
        $enabledSections = Generate-Sections $data $labels
        Generate-MainTex $enabledSections
        Write-Host ""
        Write-Host "[OK] Generation complete! Run 'compile' to build PDF from existing .tex files." -ForegroundColor Green
    }
    "compile" {
        # Only compile existing tex files without regenerating from YAML
        Compile-Only
    }
    "letter" {
        # Build a motivation letter
        if ([string]::IsNullOrEmpty($LetterName)) {
            Write-Host "  [ERROR] Please specify a letter name." -ForegroundColor Red
            Write-Host ""
            Write-Host "Available letters:" -ForegroundColor Yellow
            Get-ChildItem -Path $LettersDir -Filter "*.md" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "_TEMPLATE.md" } | ForEach-Object {
                Write-Host "    - $($_.BaseName)" -ForegroundColor Gray
            }
            if (-not (Get-ChildItem -Path $LettersDir -Filter "*.md" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "_TEMPLATE.md" })) {
                Write-Host "    (none yet - copy _TEMPLATE.md to create one)" -ForegroundColor Gray
            }
            Write-Host ""
            Write-Host "Usage: .\build.ps1 letter <LetterName>" -ForegroundColor Yellow
            Write-Host "Example: .\build.ps1 letter Google_DataEngineer" -ForegroundColor Gray
            exit 1
        }
        Build-Letter $LetterName
    }
    default {
        Write-Host "Usage: .\build.ps1 [build|clean|rebuild|generate|compile|letter] [-Lang <code>]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "CV Commands:" -ForegroundColor Cyan
        Write-Host "  build    - Generate .tex files from YAML and compile CV (default)" -ForegroundColor Gray
        Write-Host "  clean    - Remove all generated files (.tex, .pdf, auxiliaries)" -ForegroundColor Gray
        Write-Host "  rebuild  - Clean and build" -ForegroundColor Gray
        Write-Host "  generate - Only generate .tex files without compiling" -ForegroundColor Gray
        Write-Host "  compile  - Only compile existing .tex files (for manual edits)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Letter Commands:" -ForegroundColor Cyan
        Write-Host "  letter <name> - Build a motivation letter from Data/MotivationLetters/<name>.md" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Cyan
        Write-Host "  -Lang <code>  - Language code (default: en). Uses Data/PersonalResumeData_<code>.md" -ForegroundColor Gray
        Write-Host "                  and config/labels_<code>.yaml for translations." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  .\build.ps1                        # Build CV (English)" -ForegroundColor Gray
        Write-Host "  .\build.ps1 -Lang de               # Build CV (German)" -ForegroundColor Gray
        Write-Host "  .\build.ps1 rebuild -Lang de        # Clean + build German CV" -ForegroundColor Gray
        Write-Host "  .\build.ps1 letter Google_DataEng  # Build motivation letter" -ForegroundColor Gray
    }
}
