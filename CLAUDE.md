# CLAUDE.md — Project Context for Claude Code

## Project Purpose

CV & Motivation Letter Builder: generates professional PDF documents from YAML data files using PowerShell (`build.ps1`) and LaTeX (pdflatex via MiKTeX).

---

## Architecture Map

| Path | Role |
|------|------|
| `Data/PersonalResumeData_<lang>.md` | YAML frontmatter — all CV content, one file per language |
| `config/labels_<lang>.yaml` | Structural text: section titles, date formats, letter prefixes |
| `templates/*.tex.template` | LaTeX templates using `{{PLACEHOLDER}}` substitution |
| `build.ps1` | Parses YAML, loads labels, generates `.tex` sections, compiles PDF |
| `output/cv/` | Generated CV PDFs |
| `output/letters/` | Generated letter PDFs |
| `sections/` | Intermediate `.tex` files (auto-generated, gitignored) |

---

## Key Patterns

- Data files use `_<lang>.md` suffix — there is no bare `PersonalResumeData.md`
- `{{SECTION_TITLE}}` and similar placeholders in templates are replaced from label values
- Label fallback: `de_ch` → uses `labels_de.yaml` (only base lang needs a labels file)
- Date formatting via .NET `CultureInfo` — controlled by `letter_date_culture` in labels
- YAML parser is custom (no external dependencies): `Parse-FullYaml`, `Parse-LetterYaml`, `Load-Labels` in `build.ps1`
- Personal data files are gitignored; only `.md.example` files are tracked

---

## Build Commands

```powershell
.\build.ps1                              # Build English CV
.\build.ps1 -Lang de                     # Build German CV
.\build.ps1 -Lang es                     # Build Spanish CV
.\build.ps1 -Lang de_ch                  # Build Swiss German CV
.\build.ps1 rebuild -Lang de             # Clean + build German CV
.\build.ps1 letter <name>                # Build letter (English labels)
.\build.ps1 letter <name> -Lang de       # Build letter (German labels)
.\build.ps1 clean                        # Remove generated files
.\build.ps1 generate                     # Generate .tex only (no PDF)
.\build.ps1 compile                      # Compile existing .tex (no regeneration)
```

---

## Languages & Variants

| Code | Language | Labels file | Notes |
|------|----------|-------------|-------|
| `en` | English (default) | `labels_en.yaml` | |
| `de` | German | `labels_de.yaml` | |
| `es` | Spanish | `labels_es.yaml` | |
| `de_ch` | German/Swiss | *(falls back to `labels_de.yaml`)* | Includes `personal_details` block in header, no testimonials |

**Personal details block** (Swiss/DACH variant) — optional fields in the data file:

```yaml
personal_details:
  date_of_birth: "15. März 1985"
  nationality: "Kolumbianisch / Aufenthaltsbewilligung C"
  residence: "Zürich, Schweiz (seit 2018)"
  marital_status: "Verheiratet, 2 Kinder"
```

Only present fields are rendered. When the block is absent, the header is unchanged.

---

## File Conventions

- Templates must not contain hardcoded language text — use `{{PLACEHOLDER}}` only
- Labels files are flat YAML key-value pairs (no nesting)
- Example files use `.md.example` extension with dummy "John Doe" data
- Output naming: `Name LastName YYYYMMDD_lang.pdf` (CV), `LetterName (YYYY.MM.DD).pdf` (letters)

---

## Skills & Workflow

Two slash commands are available for AI-assisted job application work. See their files in `.claude/commands/` for full behavior.

| Command | Purpose |
|---------|---------|
| `/assess-position` | Evaluate fit for a role: fit score, matched requirements, gaps/disqualifiers, strategy |
| `/draft-letter` | Draft a complete motivation letter `.md` file ready to paste and build |

**Typical workflow**:
1. Find a job posting
2. Run `/assess-position` with the job description — decide whether to apply and what angles to use
3. Run `/draft-letter` with the job description — get a ready-to-paste letter body
4. Save to `Data/MotivationLetters/CompanyName_Role.md`, refine, then run `.\build.ps1 letter <name>`
