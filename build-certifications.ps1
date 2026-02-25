# build-certifications.ps1
# Generates a consolidated Certifications & Diplomas PDF
# Source: Data/Education/Formal and Data/Education/Courses
# Filename convention: Provider - Certification Name - YYYY.MM.pdf

param()

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptDir) { $ScriptDir = Get-Location }

$FormalDir  = Join-Path $ScriptDir "Data\Education\Formal"
$CoursesDir = Join-Path $ScriptDir "Data\Education\Courses"
$StagingDir = Join-Path $ScriptDir "sections\certs_staging"
$OutputDir  = Join-Path $ScriptDir "output\certifications"
$TexFile    = Join-Path $ScriptDir "certifications_book.tex"

#######################################
# HELPERS
#######################################

function Escape-LaTeX {
    param([string]$text)
    $text = $text -replace '\\',  '\textbackslash{}'
    $text = $text -replace '&',   '\&'
    $text = $text -replace '%',   '\%'
    $text = $text -replace '\$',  '\$'
    $text = $text -replace '#',   '\#'
    $text = $text -replace '_',   '\_'
    $text = $text -replace '\{',  '\{'
    $text = $text -replace '\}',  '\}'
    $text = $text -replace '~',   '\textasciitilde{}'
    $text = $text -replace '\^',  '\textasciicircum{}'
    return $text
}

function Sanitize-Filename {
    param([string]$name)
    $name = $name -replace '[^\w\.\-]', '_'
    $name = $name -replace '_+', '_'
    return $name
}

# Parses: Provider - Certification Name - YYYY.MM.pdf
function Parse-CertFile {
    param([System.IO.FileInfo]$file)

    $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $date = ""

    # Extract trailing date: " - YYYY.MM" (preferred) or " YYYY.MM" (fallback)
    if ($base -match '^(.*\S)\s*-\s*(\d{4}\.\d{2})\s*$') {
        $base = $matches[1].Trim()
        $date = $matches[2]
    } elseif ($base -match '^(.*\S)\s+(\d{4}\.\d{2})\s*$') {
        $base = $matches[1].Trim()
        $date = $matches[2]
    }

    # Split on first " - " to get Provider and Title
    $provider = ""
    $title    = $base
    if ($base -match '^(.+?)\s+-\s+(.+)$') {
        $provider = $matches[1].Trim()
        $title    = $matches[2].Trim()
    }

    return @{
        Provider     = $provider
        Title        = $title
        Date         = $date
        OriginalFile = $file
    }
}

function Build-IndexRow {
    param([hashtable]$cert)
    $esc_prov  = Escape-LaTeX $cert.Provider
    $esc_title = Escape-LaTeX $cert.Title
    $lbl       = $cert.Label
    $prov_cell = if ($esc_prov) { $esc_prov } else { '\textit{\color{gray}---}' }
    return "  $prov_cell & $esc_title & $($cert.Date) & \hyperref[$lbl]{\pageref{$lbl}} \\"
}

function Build-Include {
    param([hashtable]$cert)
    $lbl  = $cert.Label
    $path = $cert.TexPath -replace '\\', '/'
    $display = Escape-LaTeX $(
        if ($cert.Provider -and $cert.Title) { "$($cert.Provider) -- $($cert.Title)" }
        elseif ($cert.Provider)              { $cert.Provider }
        else                                 { $cert.Title }
    )
    return "\includepdf[pages=-, addtotoc={1, subsection, 2, {$display}, $lbl}]{$path}"
}

#######################################
# MAIN
#######################################

# Read author name from data file
$DataFile = Join-Path $ScriptDir "Data\PersonalResumeData_en.md"
if (-not (Test-Path $DataFile)) {
    Write-Host "[ERROR] Data file not found: $DataFile" -ForegroundColor Red
    exit 1
}
$rawData = Get-Content $DataFile -Raw -Encoding UTF8
if ($rawData -notmatch 'name:\s*"?([^"\r\n]+)"?') {
    Write-Host "[ERROR] Could not read 'name' field from $DataFile" -ForegroundColor Red
    exit 1
}
$authorName = $matches[1].Trim() -replace '"', ''

# Title-cased ASCII version for the output filename (strips accents)
$authorNameFile = [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($authorName))
$authorNameFile = (Get-Culture).TextInfo.ToTitleCase($authorNameFile.ToLower())

# Setup directories
New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir  | Out-Null
Get-ChildItem $StagingDir -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "Scanning certifications..." -ForegroundColor Cyan

$formalParsed  = @(Get-ChildItem $FormalDir  -Filter "*.pdf" | ForEach-Object { Parse-CertFile $_ } | Sort-Object { if ($_.Date) { $_.Date } else { '0000.00' } } -Descending)
$coursesParsed = @(Get-ChildItem $CoursesDir -Filter "*.pdf" | ForEach-Object { Parse-CertFile $_ } | Sort-Object { if ($_.Date) { $_.Date } else { '0000.00' } } -Descending)

Write-Host "  Formal   : $($formalParsed.Count) files" -ForegroundColor Gray
Write-Host "  Courses  : $($coursesParsed.Count) files" -ForegroundColor Gray

# Stage files with sanitized names and build cert list
$allCerts = [System.Collections.Generic.List[hashtable]]::new()
$counter  = 0

foreach ($group in @(
    @{ Items = $formalParsed;  Section = "formal"  },
    @{ Items = $coursesParsed; Section = "courses" }
)) {
    foreach ($cert in $group.Items) {
        $counter++
        $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($cert.OriginalFile.Name)
        $stageName = "cert_{0:D3}_{1}.pdf" -f $counter, (Sanitize-Filename $baseName)
        $stagePath = Join-Path $StagingDir $stageName

        Copy-Item $cert.OriginalFile.FullName $stagePath -Force

        $allCerts.Add(@{
            Label    = "cert$counter"
            Provider = $cert.Provider
            Title    = $cert.Title
            Date     = $cert.Date
            Section  = $group.Section
            TexPath  = "sections/certs_staging/$stageName"
        })
    }
}

# Build LaTeX content blocks
$formalCerts  = @($allCerts | Where-Object { $_.Section -eq "formal"  })
$coursesCerts = @($allCerts | Where-Object { $_.Section -eq "courses" })

$formalIndexRows  = ($formalCerts  | ForEach-Object { Build-IndexRow $_ }) -join "`n"
$coursesIndexRows = ($coursesCerts | ForEach-Object { Build-IndexRow $_ }) -join "`n"
$formalIncludes   = ($formalCerts  | ForEach-Object { Build-Include  $_ }) -join "`n"
$coursesIncludes  = ($coursesCerts | ForEach-Object { Build-Include  $_ }) -join "`n"

$authorEsc = Escape-LaTeX $authorName

#######################################
# GENERATE TEX
# Single-quoted here-string: $ signs are literal, no expansion risk.
# Dynamic content substituted via .Replace() below.
#######################################

$template = @'
%% certifications_book.tex -- auto-generated by build-certifications.ps1
\documentclass[10pt, a4paper]{article}

\usepackage[ignoreheadfoot, top=2cm, bottom=2cm, left=2cm, right=2cm, footskip=1.0cm]{geometry}
\usepackage[dvipsnames]{xcolor}
\definecolor{accentcolor}{RGB}{0, 79, 144}
\definecolor{primaryColor}{RGB}{0, 0, 0}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{titlesec}
\usepackage{booktabs}
\usepackage{longtable}
\usepackage{array}
\usepackage{needspace}
\usepackage{charter}
\usepackage[
    pdftitle={TMPL_AUTHOR -- Certifications and Diplomas},
    pdfauthor={TMPL_AUTHOR},
    colorlinks=true,
    urlcolor=primaryColor,
    linkcolor=accentcolor,
    bookmarks=true,
    bookmarksnumbered=false,
    bookmarksopen=true
]{hyperref}
\usepackage{pdfpages}
\usepackage{bookmark}

\titleformat{\section}{\needspace{4\baselineskip}\bfseries\large\color{accentcolor}}{}{0pt}{}[\vspace{-8pt}\textcolor{accentcolor}{\titlerule}]
\titlespacing{\section}{-1pt}{0.3cm}{0.2cm}
\setcounter{secnumdepth}{0}
\setlength{\parindent}{0pt}
\setlength{\topskip}{0pt}
\raggedright
\pagestyle{plain}

\begin{document}

%% Cover
\thispagestyle{empty}
\vspace*{0.8cm}

\noindent{\fontsize{25pt}{25pt}\selectfont\bfseries\color{accentcolor} TMPL_AUTHOR}

\vspace{5pt}

\noindent{\small\color{gray}\textit{Certifications \& Diplomas}}

\vspace{8pt}
\noindent\textcolor{accentcolor}{\rule{\linewidth}{0.5pt}}
\vspace{1.5cm}

%% Index
\section{Index}

\begin{longtable}{@{} p{3cm} p{9.5cm} p{1.8cm} r @{}}
  \toprule
  \textbf{Provider} & \textbf{Certification} & \textbf{Date} & \textbf{Page} \\
  \midrule
  \endfirsthead
  \multicolumn{4}{c}{\small\textit{(continued \ldots)}} \\[4pt]
  \toprule
  \textbf{Provider} & \textbf{Certification} & \textbf{Date} & \textbf{Page} \\
  \midrule
  \endhead
  \bottomrule
  \endlastfoot

  \multicolumn{4}{@{}l}{\small\bfseries\color{accentcolor}Formal Education} \\[3pt]
TMPL_FORMAL_INDEX
\noalign{\vspace{6pt}}
  \multicolumn{4}{@{}l}{\small\bfseries\color{accentcolor}Courses \& Certifications} \\[3pt]
TMPL_COURSES_INDEX
\end{longtable}

\newpage

%% Formal Education
\section{Formal Education}

TMPL_FORMAL_INC

%% Courses and Certifications
\section{Courses \& Certifications}

TMPL_COURSES_INC

\end{document}
'@

$tex = $template.Replace('TMPL_AUTHOR',        $authorEsc)
$tex = $tex.Replace('TMPL_FORMAL_INDEX',  $formalIndexRows)
$tex = $tex.Replace('TMPL_COURSES_INDEX', $coursesIndexRows)
$tex = $tex.Replace('TMPL_FORMAL_INC',    $formalIncludes)
$tex = $tex.Replace('TMPL_COURSES_INC',   $coursesIncludes)

[System.IO.File]::WriteAllText($TexFile, $tex, [System.Text.Encoding]::UTF8)
Write-Host "Generated: certifications_book.tex" -ForegroundColor Green

#######################################
# COMPILE
#######################################

Write-Host "Compiling (pass 1)..." -ForegroundColor Cyan
Push-Location $ScriptDir
try {
    pdflatex -interaction=nonstopmode certifications_book.tex | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] Pass 1 had issues -- check certifications_book.log" -ForegroundColor Yellow
    }
    Write-Host "Compiling (pass 2)..." -ForegroundColor Cyan
    pdflatex -interaction=nonstopmode certifications_book.tex | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Pass 2 failed -- check certifications_book.log" -ForegroundColor Red
        Pop-Location
        exit 1
    }
} catch {
    Write-Host "  [ERROR] $_" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

#######################################
# MOVE OUTPUT
#######################################

$srcPdf  = Join-Path $ScriptDir "certifications_book.pdf"
$outName = "$authorNameFile Education $(Get-Date -Format 'yyyyMMdd').pdf"
$destPdf = Join-Path $OutputDir $outName

if (Test-Path $srcPdf) {
    Move-Item $srcPdf $destPdf -Force
    Write-Host "Done: output/certifications/$outName" -ForegroundColor Green
} else {
    Write-Host "[ERROR] PDF not produced -- check certifications_book.log" -ForegroundColor Red
    exit 1
}

# Clean auxiliary files
foreach ($aux in @("aux", "log", "out", "toc", "tex")) {
    $f = Join-Path $ScriptDir "certifications_book.$aux"
    if (Test-Path $f) { Remove-Item $f -Force }
}
