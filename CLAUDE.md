# CLAUDE.md - Project Instructions for Claude Code

## Project Overview

This is a **CV & Motivation Letter Builder** that generates professional PDF documents from YAML data files using PowerShell and LaTeX (pdflatex via MiKTeX).

## Architecture

- **Data files**: `Data/PersonalResumeData_<lang>.md` — YAML frontmatter with all CV content, one file per language
- **Label files**: `config/labels_<lang>.yaml` — structural text (section titles, competency category names, date formats, letter prefixes)
- **Templates**: `templates/*.tex.template` — LaTeX templates with `{{PLACEHOLDER}}` substitution
- **Build script**: `build.ps1` — PowerShell script that parses YAML, loads labels, generates .tex sections, and compiles PDF
- **Output**: `output/cv/` for CVs, `output/letters/` for motivation letters

## Key Patterns

- All data files use the `_<lang>.md` suffix (e.g. `_en.md`, `_de.md`, `_es.md`, `_de_ch.md`) — there is no bare `PersonalResumeData.md`
- Locale-style variants are supported (e.g. `de_ch` for Swiss German) — the `-Lang` parameter accepts any string
- The `-Lang` parameter defaults to `en` and selects both the data file and labels file (with fallback: `de_ch` → `labels_de.yaml`)
- Section templates use `{{SECTION_TITLE}}` which gets replaced from labels
- Letter templates use `{{SUBJECT_PREFIX}}`, `{{DATE}}` etc. from labels
- Date formatting uses .NET CultureInfo for localized month names (`letter_date_culture` in labels)
- The YAML parser is custom (no external dependencies) — see `Parse-FullYaml`, `Parse-LetterYaml`, `Load-Labels` in build.ps1
- Personal data files (`Data/PersonalResumeData_*.md`) are gitignored; only `.example` files are tracked

## Supported Languages / Variants

- `en` — English (default)
- `de` — German (Deutsch)
- `es` — Spanish (Español)
- `de_ch` — German/Swiss (Deutsch/Schweiz) — includes personal details in header, no testimonials

## Build Commands

```powershell
.\build.ps1                              # Build English CV
.\build.ps1 -Lang de                     # Build German CV
.\build.ps1 -Lang es                     # Build Spanish CV
.\build.ps1 -Lang de_ch                  # Build Swiss German CV (with personal details)
.\build.ps1 rebuild -Lang de             # Clean + build German CV
.\build.ps1 letter <name>                # Build letter (English labels)
.\build.ps1 letter <name> -Lang de       # Build letter (German labels)
.\build.ps1 clean                        # Remove generated files
.\build.ps1 generate                     # Generate .tex only (no PDF)
.\build.ps1 compile                      # Compile existing .tex (no regeneration)
```

## Adding a New Language or Variant

1. Create `config/labels_xx.yaml` (copy from `labels_en.yaml`, translate all values)
2. Create `Data/PersonalResumeData_xx.md` (copy from `_en.md`, translate content)
3. Optionally create `Data/PersonalResumeData_xx.md.example` (example with translated placeholder content)
4. Build with `.\build.ps1 -Lang xx`

For market-specific variants, use locale-style codes (e.g. `de_ch`, `en_us`). Variants only need a data file — labels automatically fall back to the base language.

## Optional: Personal Details (Swiss/DACH CVs)

The header template supports an optional `personal_details` block for markets that expect personal info:

```yaml
personal_details:
  date_of_birth: "15. März 1985"
  nationality: "Kolumbianisch / Aufenthaltsbewilligung C"
  residence: "Zürich, Schweiz (seit 2018)"
  marital_status: "Verheiratet, 2 Kinder"
```

Each field is optional. When the block is absent, the header renders as before. Labels for field names (e.g. "Geburtsdatum", "Nationality") come from the labels file (`personal_date_of_birth`, `personal_nationality`, etc.).

## File Conventions

- Templates in `templates/` should not have hardcoded language text — use `{{PLACEHOLDER}}` patterns
- Labels files are flat YAML key-value pairs (no nesting), parsed by `Load-Labels`
- Example files use `.md.example` extension and contain dummy "John Doe" data
- Output naming: `Name LastName YYYYMMDD_lang.pdf` for CVs, `LetterName (YYYY.MM.DD).pdf` for letters
