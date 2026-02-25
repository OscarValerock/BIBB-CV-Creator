# CV & Motivation Letter Builder

Generates professional PDF CVs and motivation letters from YAML data files using PowerShell and LaTeX. Supports multiple languages and market-specific variants.

---

## Requirements

- Windows with PowerShell
- LaTeX (MiKTeX recommended): https://miktex.org/download
- After installing MiKTeX, open **MiKTeX Console** → **Updates** → **Check for updates** → **Update now**
- In **Packages**, set **Install missing packages on-the-fly** to **Yes**

---

## Try the Demo

Test the builder right after cloning — no setup needed beyond LaTeX.

1. Rename the example file (removes the `.example` extension):
   ```powershell
   Rename-Item Data\PersonalResumeData_en.md.example Data\PersonalResumeData_en.md
   ```
2. Build the demo CV:
   ```powershell
   .\build.ps1
   ```
3. Build the sample motivation letter:
   ```powershell
   .\build.ps1 letter _SAMPLE
   ```

Output: `output/cv/John Doe YYYYMMDD_en.pdf` and `output/letters/_SAMPLE (YYYY.MM.DD).pdf`

> When you're ready to use your own data, edit `Data/PersonalResumeData_en.md` in place.

---

## Quick Start

### Build Your CV

1. Copy `Data/PersonalResumeData_en.md.example` → `Data/PersonalResumeData_en.md`
2. Edit your data in `Data/PersonalResumeData_en.md`
3. Run:
   ```powershell
   .\build.ps1
   ```
4. Output: `output/cv/Your Name YYYYMMDD_en.pdf`

> First build may take several minutes while MiKTeX downloads required packages.

### Build a Motivation Letter

A ready-to-use sample letter is included for testing:

```powershell
.\build.ps1 letter _SAMPLE
```

Output: `output/letters/_SAMPLE (YYYY.MM.DD).pdf`

> Requires `Data/PersonalResumeData_en.md` to exist (personal info is pulled from it automatically).
> If you haven't done so yet, rename the example file first — see [Try the Demo](#try-the-demo).

To write your own letter:

1. Copy `Data/MotivationLetters/_TEMPLATE.md` → `Data/MotivationLetters/CompanyName_Position.md`
2. Fill in recipient info and letter body
3. Run:
   ```powershell
   .\build.ps1 letter CompanyName_Position
   ```
4. Output: `output/letters/[LetterName] (YYYY.MM.DD).pdf`

Personal info (name, contact) is automatically pulled from your CV data file.

### Build in Another Language

1. Copy the example for your language and edit the content:
   - `Data/PersonalResumeData_de.md.example` → `Data/PersonalResumeData_de.md`
   - `Data/PersonalResumeData_es.md.example` → `Data/PersonalResumeData_es.md`
2. Run:
   ```powershell
   .\build.ps1 -Lang de    # German
   .\build.ps1 -Lang es    # Spanish
   ```

---

## Commands Reference

### CV Commands

| Command | What it does |
|---------|--------------|
| `.\build.ps1` | Build English CV (default) |
| `.\build.ps1 -Lang de` | Build German CV |
| `.\build.ps1 clean` | Remove all generated files |
| `.\build.ps1 rebuild` | Clean + build |
| `.\build.ps1 rebuild -Lang de` | Clean + build in German |
| `.\build.ps1 generate` | Generate `.tex` files only (no PDF) |
| `.\build.ps1 compile` | Compile existing `.tex` without regenerating |

**Tip:** Use `generate` + manual edits + `compile` to tweak LaTeX directly.

### Letter Commands

| Command | What it does |
|---------|--------------|
| `.\build.ps1 letter <name>` | Build letter from `Data/MotivationLetters/<name>.md` |
| `.\build.ps1 letter <name> -Lang de` | Build letter using German labels |

```powershell
.\build.ps1 letter Google_DataEngineer
.\build.ps1 letter Microsoft_PlatformLead -Lang de
```

---

## Editing Your CV

Open `Data/PersonalResumeData_en.md`. The file contains sections for:

- **Personal info** — name, headline, contact details, photo
- **Summary** — professional summary
- **Skills** — grouped by category
- **Experience** — jobs with dates and achievements
- **Education**, **Certifications**, **Languages**, **Projects**, **Testimonials**

### Toggle Sections On/Off

```yaml
sections:
  header: true
  professional_summary: true
  experience: true
  education: true
  # set any to false to hide it
```

---

## Folder Structure

```
BIBB-CV-Creator/
├── Data/
│   ├── PersonalResumeData_en.md.example  ← English example (copy & edit)
│   ├── PersonalResumeData_de.md.example  ← German example
│   ├── PersonalResumeData_es.md.example  ← Spanish example
│   ├── PersonalResumeData_en.md          ← YOUR CV DATA - English (gitignored)
│   ├── PersonalResumeData_de.md          ← YOUR CV DATA - German (gitignored)
│   ├── PersonalResumeData_de_ch.md       ← YOUR CV DATA - Swiss variant (gitignored)
│   └── MotivationLetters/
│       ├── _TEMPLATE.md                  ← Copy this for new letters
│       ├── _SAMPLE.md                    ← Sample letter (tracked, for demo)
│       └── CompanyName_Position.md       ← Your letters (gitignored)
├── output/                               ← Generated PDFs (gitignored)
│   ├── cv/
│   └── letters/
├── build.ps1                             ← Build script
├── templates/                            ← LaTeX templates
├── sections/                             ← Generated .tex files (auto-created)
├── config/
│   ├── labels_en.yaml                    ← English section titles & labels
│   ├── labels_de.yaml                    ← German labels
│   ├── labels_es.yaml                    ← Spanish labels
│   ├── packages.tex                      ← LaTeX packages
│   └── settings.tex                      ← LaTeX styling
├── .claude/commands/                     ← Claude Code skills (see below)
├── CLAUDE.md                             ← Claude Code project context
└── README.md                             ← This file
```

---

## Customization

### Adding a New Language

1. Create `config/labels_xx.yaml` (copy from `labels_en.yaml`, translate all values)
2. Create `Data/PersonalResumeData_xx.md` (copy from `_en.md`, translate content)
3. Optionally create `Data/PersonalResumeData_xx.md.example` with placeholder data
4. Build with `.\build.ps1 -Lang xx`

The labels file controls section headings, competency category names, date separators, the "Present" label, letter subject prefix, date format/culture, and personal details field labels.

### Market-Specific Variants

Use locale-style codes (e.g., `de_ch`, `en_us`). Variants only need a data file — labels fall back to the base language automatically (e.g., `de_ch` → `labels_de.yaml`).

```powershell
# Create Data/PersonalResumeData_de_ch.md from your de.md, then:
.\build.ps1 -Lang de_ch
```

### Personal Details Block (Swiss/DACH CVs)

Swiss recruiters often expect personal info in the header. Add this optional block to your data file:

```yaml
personal_details:
  date_of_birth: "15. März 1985"
  nationality: "Kolumbianisch / Aufenthaltsbewilligung C"
  residence: "Zürich, Schweiz (seit 2018)"
  marital_status: "Verheiratet, 2 Kinder"
```

Only included fields are rendered. Omit the block entirely to keep the standard header.

---

## AI-Assisted Workflow (Claude Code)

If you use [Claude Code](https://claude.ai/code), two slash commands are available to help with job applications:

### `/assess-position`

Evaluates your fit for a role before you invest time in writing a letter.

**How to use**: Type `/assess-position` and paste the full job description.

**Output**:
- Fit score (%) with rationale
- Matched requirements mapped to your CV experience
- Gaps, red flags, and hard disqualifiers
- Strategy: if strong fit → key letter angles and differentiators; if weak fit → honest assessment of whether to apply and how to reframe

### `/draft-letter`

Drafts a complete motivation letter ready to paste into a `.md` file and build.

**How to use**: Type `/draft-letter` and paste the job description. If you've already run `/assess-position`, mention the role so the draft can pick up the identified angles.

**Output**: A complete YAML letter file (frontmatter + body) that you can save directly as `Data/MotivationLetters/CompanyName_Role.md` and build.

**Typical workflow**:
1. Find a job posting
2. `/assess-position` → decide whether to apply and what to emphasize
3. `/draft-letter` → get a ready-to-paste letter
4. Refine and run `.\build.ps1 letter <name>`

---

## Tips & Troubleshooting

**YAML tips:**
- Use quotes around text with special characters: `"Manager – Data & BI"`
- Dates: `2024-07` for July 2024; `end_date: "Present"` for current roles
- Achievements are bullet points — start each with `-`
- **Photo**: Place `photo.png` or `photo.jpg` in the root folder (PNG checked first)

**Build fails?**
- Check `cv.log` for error details
- Make sure MiKTeX is installed and in your PATH

**Cannot find data file?**
- Copy `Data/PersonalResumeData_en.md.example` to `Data/PersonalResumeData_en.md` first

**MiKTeX not activated / first run issues?**
- Open MiKTeX Console → Updates → Update now
- Set "Install missing packages on-the-fly" to Yes
- Close and reopen VS Code so PATH changes are picked up

**pdflatex not recognized?**
- Close and reopen VS Code (not just the terminal)
- Verify with: `pdflatex --version`

**First build taking forever?**
- Normal — MiKTeX downloads missing packages on first run (can take 2–10+ minutes)
- Subsequent builds are much faster

**PDF not updating?**
- Close the PDF viewer
- Run `.\build.ps1 rebuild`
