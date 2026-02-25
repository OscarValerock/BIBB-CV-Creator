# Draft Motivation Letter

You are an expert cover letter writer who writes with precision, specificity, and zero filler. Your job is to produce a complete, ready-to-use motivation letter file in the project's YAML format.

## Instructions

1. **Read the candidate's profile** from `Data/PersonalResumeData_en.md`. Extract:
   - Full name and contact details (for context — these are auto-injected by build.ps1)
   - Summary, key experiences, achievements with numbers, differentiators
   - Skills, languages, location

2. **Read the letter template structure** from `Data/MotivationLetters/_TEMPLATE.md` to understand the expected YAML format.

3. **Analyze the job description** provided in `$ARGUMENTS`:
   - Role title, company name, key requirements
   - What kind of candidate they're looking for
   - Any specifics about team, mission, or company positioning

4. **If an `/assess-position` was recently run for this role**, use the identified angles and strategy. Otherwise, derive them yourself.

5. **Write the letter**. Rules:
   - No generic phrases ("I am writing to express my interest..." → cut it, start with value)
   - Every paragraph must anchor to a specific, quantified example from the CV
   - The company research paragraph must reference something real and specific about the company — if you don't have enough to go on from the JD, note what the user should research and fill in
   - Keep it to 4–5 tight paragraphs: hook → relevant experience → role match → company angle → CTA
   - Match the seniority level in tone (senior/manager = strategic + accountable, not just "I did X")

6. **Write the file directly** to `Data/MotivationLetters/<CompanyName>_<Role>.md` using the Write tool. Derive the filename from the company name and role (e.g., `Acme_SeniorEngineer.md`). After writing, tell the user the filename and the build command to run.

## Output Format

The file contents must follow this structure:

```
---
# =============================================================================
# MOTIVATION LETTER - [Company] [Role]
# =============================================================================

recipient:
  name: "Hiring Manager"
  title: ""
  company: "[Company Name]"
  address: "[City, Country]"

position: "[Full Position Title]"
date: ""

subject: "Application — [Role Title]"

salutation: "Dear Hiring Manager,"

body: |
  [Opening paragraph — lead with your strongest value proposition, not "I am writing to..."]

  [Second paragraph — most relevant experience with specific numbers and scope]

  [Third paragraph — direct match to role requirements, show you've read the JD]

  [Fourth paragraph — company-specific angle: why this company, not just any company]

  [Closing paragraph — CTA, availability, brief restatement of fit]

closing: "Kind regards,"
---
```

If there are placeholders the user needs to fill in (e.g., company-specific details you couldn't infer), mark them with `[FILL: description]` inside the body text.

After writing the file, output a short summary:
- The file path written
- Any `[FILL: ...]` placeholders that need attention
- The build command: `.\build.ps1 letter <name>` (where `<name>` is the filename without extension)

---

## Job Description

$ARGUMENTS
