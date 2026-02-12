# CV & Motivation Letter Builder

A simple system to build professional PDF CVs and motivation letters from YAML data files.

## Requirements

- Windows with PowerShell
- LaTeX (MiKTeX recommended): https://miktex.org/download
- After installing MiKTeX, open **MiKTeX Console** and run **Updates** -> **Check for updates** -> **Update now**
- In **Packages**, set **Install missing packages on-the-fly** to **Yes**

## Quick Start

### Build Your CV

1. **Copy the example file**: `Data/PersonalResumeData_en.md.example` → `Data/PersonalResumeData_en.md`
2. **Edit your data** in `Data/PersonalResumeData_en.md`
3. **Build the PDF**:
   ```powershell
   .\build.ps1
   ```
4. Your CV will be saved in `output/cv/Your Name YYYYMMDD_en.pdf`

**Note:** The first build may take several minutes while MiKTeX downloads required packages.

### Build a Motivation Letter

1. **Copy the template**: `Data/MotivationLetters/_TEMPLATE.md` → `Data/MotivationLetters/CompanyName_Position.md`
2. **Edit the letter** with recipient info and your letter content
3. **Build the PDF**:
   ```powershell
   .\build.ps1 letter CompanyName_Position
   ```
4. Your letter will be saved in `output/letters/[LetterName] (YYYY.MM.DD).pdf`

Personal info (name, contact) is automatically pulled from your CV data file.

### Build in Another Language

1. **Copy the example file** for your language:
   - German: `Data/PersonalResumeData_de.md.example` → `Data/PersonalResumeData_de.md`
   - Spanish: `Data/PersonalResumeData_es.md.example` → `Data/PersonalResumeData_es.md`
2. **Edit your data** (translate content from the English file)
3. **Build the PDF**:
   ```powershell
   .\build.ps1 -Lang de    # German
   .\build.ps1 -Lang es    # Spanish
   ```
4. Your CV will be saved in `output/cv/Your Name YYYYMMDD_<lang>.pdf`

Language labels (section titles, date formats, letter prefixes) are stored in `config/labels_<lang>.yaml`. Currently supported: `en` (English), `de` (German), `es` (Spanish), `de_ch` (German/Swiss).

### Create a Market-Specific Variant

You can create locale-style variants for different markets (e.g., Swiss, US, UK). For example, a Swiss German version:

1. **Copy your existing data file**: `Data/PersonalResumeData_de.md` → `Data/PersonalResumeData_de_ch.md`
2. **Adjust the data file** — e.g., add `personal_details` block (see below), disable testimonials, expand achievements
3. **Build**: `.\build.ps1 -Lang de_ch`

No separate labels file needed — variants automatically fall back to the base language labels (e.g., `de_ch` uses `labels_de.yaml`).

#### Optional: Personal Details (Swiss/DACH CVs)

Swiss recruiters often expect personal info in the CV header. Add this optional block to your data file:

```yaml
personal_details:
  date_of_birth: "15. März 1985"
  nationality: "Kolumbianisch / Aufenthaltsbewilligung C"
  residence: "Zürich, Schweiz (seit 2018)"
  marital_status: "Verheiratet, 2 Kinder"
```

Each field is optional — only included fields will render. When omitted entirely, the header stays unchanged.

## How It Works

```
Data/PersonalResumeData_en.md      -->  build.ps1              -->  Oscar Martinez 20260120_en.pdf
Data/PersonalResumeData_de.md      -->  build.ps1 -Lang de     -->  Oscar Martinez 20260120_de.pdf
Data/PersonalResumeData_es.md      -->  build.ps1 -Lang es     -->  Oscar Martinez 20260120_es.pdf
Data/PersonalResumeData_de_ch.md   -->  build.ps1 -Lang de_ch  -->  Oscar Martinez 20260120_de_ch.pdf
    (edit these files)                   (run this)                  (your CV)
```

All your CV content lives in one file per language: `Data/PersonalResumeData_<lang>.md` (e.g. `_en.md` for English, `_de.md` for German, `_es.md` for Spanish).

## Editing Your CV

Open `Data/PersonalResumeData_en.md` in any text editor. The file has sections for:

- **Personal info** - name, headline, contact details
- **Summary** - your professional summary
- **Skills** - grouped by category
- **Experience** - jobs with dates and achievements
- **Education** - degrees and certifications
- **And more** - languages, projects, testimonials

### Toggle Sections On/Off

At the top of the file, you'll see:

```yaml
sections:
  header: true
  professional_summary: true
  experience: true
  education: true
  # ... etc
```

Set any section to `false` to hide it from your CV.

## Commands

### CV Commands

| Command | What it does |
|---------|--------------|
| `.\build.ps1` | Build the PDF in English (default) |
| `.\build.ps1 -Lang de` | Build the PDF in German |
| `.\build.ps1 clean` | Remove all generated files (.tex, .pdf, auxiliaries) |
| `.\build.ps1 rebuild` | Clean + build |
| `.\build.ps1 rebuild -Lang de` | Clean + build in German |
| `.\build.ps1 generate` | Generate .tex files only (no PDF) |
| `.\build.ps1 compile` | Compile existing .tex files without regenerating from YAML |

**Tip:** Use `generate` + manual edits + `compile` if you want to tweak the LaTeX directly.
**Tip:** The `-Lang` parameter works with `build`, `rebuild`, `generate`, and `compile`.

### Letter Commands

| Command | What it does |
|---------|--------------|
| `.\build.ps1 letter <name>` | Build a motivation letter from `Data/MotivationLetters/<name>.md` |
| `.\build.ps1 letter <name> -Lang de` | Build a letter using German labels (date format, subject prefix) |

**Examples:**
```powershell
.\build.ps1 letter Google_DataEngineer
.\build.ps1 letter Microsoft_PlatformLead -Lang de
```

## Folder Structure

```
CV-Creation/
├── Data/
│   ├── PersonalResumeData_en.md.example  <-- English example (copy & edit)
│   ├── PersonalResumeData_de.md.example  <-- German example
│   ├── PersonalResumeData_es.md.example  <-- Spanish example
│   ├── PersonalResumeData_en.md          <-- YOUR CV DATA - English (gitignored)
│   ├── PersonalResumeData_de.md          <-- YOUR CV DATA - German (gitignored)
│   ├── PersonalResumeData_es.md          <-- YOUR CV DATA - Spanish (gitignored)
│   ├── PersonalResumeData_de_ch.md       <-- YOUR CV DATA - Swiss variant (gitignored)
│   └── MotivationLetters/
│       ├── _TEMPLATE.md                  <-- Copy this for new letters
│       └── CompanyName_Position.md       <-- Your letter files (gitignored)
├── output/                                <-- Generated PDFs (gitignored)
│   ├── cv/
│   └── letters/
├── build.ps1                              <-- Build script
├── templates/                             <-- LaTeX templates (don't edit)
├── sections/                              <-- Generated .tex files (auto-created)
├── config/
│   ├── labels_en.yaml                     <-- English labels
│   ├── labels_de.yaml                     <-- German labels
│   ├── labels_es.yaml                     <-- Spanish labels
│   ├── packages.tex                       <-- LaTeX packages (don't edit)
│   └── settings.tex                       <-- LaTeX styling (don't edit)
├── CLAUDE.md                              <-- Claude Code project instructions
└── README.md                              <-- This file
```

## Adding a New Language or Variant

1. Create `config/labels_xx.yaml` (copy from `labels_en.yaml` and translate all values)
2. Create `Data/PersonalResumeData_xx.md` (copy from the English file and translate content)
3. Optionally create `Data/PersonalResumeData_xx.md.example` with placeholder data for others to use
4. Build with `.\build.ps1 -Lang xx`

For market-specific variants, use locale-style codes like `de_ch` (Swiss German), `en_us` (US English), etc. Variants only need a data file — labels automatically fall back to the base language (e.g., `de_ch` uses `labels_de.yaml`).

The labels file controls section headings ("Professional Experience" → "Berufserfahrung"), competency category names, date separators (`/` vs `.`), the "Present" label, letter-specific labels (subject prefix, date format, date culture), and personal details field labels.

## Tips

- Use quotes around text with special characters: `"Manager – Data & BI"`
- Dates use format: `2024-07` for July 2024
- For current jobs, use: `end_date: "Present"`
- Achievements are bullet points - start each with a `-`
- **Photo**: Place your photo as `photo.png` or `photo.jpg` in the root folder. PNG is checked first, then JPG. See `photo.png.example.png` for reference.

## Troubleshooting

**Build fails?**
- Check `cv.log` for error details
- Make sure MiKTeX is installed and in your PATH

**Cannot find data file?**
- Copy `Data/PersonalResumeData_en.md.example` to `Data/PersonalResumeData_en.md` first

**MiKTeX not activated / first run issues?**
- Open **MiKTeX Console** and run **Updates** -> **Check for updates** -> **Update now**
- In **Packages**, set **Install missing packages on-the-fly** to **Yes**
- Close and reopen VS Code (not just the terminal) so PATH changes are picked up

**pdflatex not recognized?**
- Close and reopen VS Code (not just the terminal) so MiKTeX PATH is loaded
- Verify with: `pdflatex --version`

**First build taking forever?**
- This is normal — MiKTeX downloads missing packages on first run (can take 2-10+ minutes)
- Subsequent builds will be much faster

**PDF not updating?**
- Close the PDF if it's open in a viewer
- Run `.\build.ps1 rebuild`
