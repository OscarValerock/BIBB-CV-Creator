# CV & Motivation Letter Builder

A simple system to build professional PDF CVs and motivation letters from YAML data files.

## Requirements

- Windows with PowerShell
- LaTeX (MiKTeX recommended): https://miktex.org/download
- After installing MiKTeX, open **MiKTeX Console** and run **Updates** -> **Check for updates** -> **Update now**
- In **Packages**, set **Install missing packages on-the-fly** to **Yes**

## Quick Start

### Build Your CV

1. **Copy the example file**: `Data/PersonalResumeData.md.example` → `Data/PersonalResumeData.md`
2. **Edit your data** in `Data/PersonalResumeData.md`
3. **Build the PDF**:
   ```powershell
   .\build.ps1
   ```
4. Your CV will be saved in `output/cv/[Your Name] (YYYY.MM.DD).pdf`

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

## How It Works

```
Data/PersonalResumeData.md  -->  build.ps1  -->  Your Name (2026.01.20).pdf
    (edit this file)            (run this)        (your CV)
```

All your CV content lives in one file: `Data/PersonalResumeData.md`

## Editing Your CV

Open `Data/PersonalResumeData.md` in any text editor. The file has sections for:

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
| `.\build.ps1` | Build the PDF (regenerates .tex from YAML) |
| `.\build.ps1 clean` | Remove all generated files (.tex, .pdf, auxiliaries) |
| `.\build.ps1 rebuild` | Clean + build |
| `.\build.ps1 generate` | Generate .tex files only (no PDF) |
| `.\build.ps1 compile` | Compile existing .tex files without regenerating from YAML |

**Tip:** Use `generate` + manual edits + `compile` if you want to tweak the LaTeX directly.

### Letter Commands

| Command | What it does |
|---------|--------------|
| `.\build.ps1 letter <name>` | Build a motivation letter from `Data/MotivationLetters/<name>.md` |

**Examples:**
```powershell
.\build.ps1 letter Google_DataEngineer
.\build.ps1 letter Microsoft_PlatformLead
```

## Folder Structure

```
CV-Creation/
├── Data/
│   ├── PersonalResumeData.md       <-- YOUR CV DATA (edit this!)
│   └── MotivationLetters/
│       ├── _TEMPLATE.md            <-- Copy this for new letters
│       └── CompanyName_Position.md <-- Your letter files
├── output/
│   ├── cv/                          <-- Generated CV PDFs
│   └── letters/                     <-- Generated letter PDFs
├── build.ps1                        <-- Build script
├── templates/                       <-- LaTeX templates (don't edit)
├── sections/                        <-- Generated .tex files (auto-created)
├── config/                          <-- LaTeX settings (don't edit)
└── README.md                        <-- This file
```

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

**Cannot find PersonalResumeData.md?**
- Copy `Data/PersonalResumeData.md.example` to `Data/PersonalResumeData.md` first

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
