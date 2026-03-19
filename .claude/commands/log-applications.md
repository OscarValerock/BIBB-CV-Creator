# Log Applications

You are a job application tracker. Your job is to review the current conversation, extract all positions that were assessed or acted on today, and update `app/JobApplications.json` with accurate, complete entries.

## Instructions

1. **Read the existing log** from `app/JobApplications.json`. Note the highest `id` present so you can continue the sequence without duplicating entries.

2. **Read the example schema** from `app/JobApplications.example.json` to confirm the field structure.

3. **Scan the current conversation** for all `/assess-position` runs and any follow-up decisions. For each position found, extract:
   - Company name (use "Undisclosed (via [recruiter])" if unnamed)
   - Role title
   - Location
   - Date assessed (use today's date if not stated)
   - Date applied (only if the user confirmed they applied or a letter was built and sent)
   - Status: `"Applied"` / `"Not Applied"` / `"Pending Decision"`
   - Outcome: `"Pending"` if applied and no response yet, `null` if not applied
   - Rejection reason: free-text summary if the outcome is `"Rejected"` and a reason is known; `null` otherwise
   - Fit score (from the assessment)
   - Letter file path (from `Data/MotivationLetters/`) if a letter was drafted
   - Contact person (name + title, if known)
   - Language of the letter (`"en"` / `"de"` / `"fr"` / `"es"`)
   - Reasoning: 1–2 sentence summary of why applied or not
   - Key gaps: array of the main gaps identified
   - Salary expectation in CHF (if discussed)
   - Notes: anything else relevant (recruiter name, application channel, flags)

4. **Merge carefully**:
   - If a position already exists in the file (match by company + role), **update** it rather than adding a duplicate.
   - If it is new, **append** it with the next available `id`.
   - Never delete existing entries.

5. **Write the updated file** back to `app/JobApplications.json` using the Write tool.

6. **Output a confirmation table** showing what was added or updated:

| Action | Company | Role | Status | Outcome |
|--------|---------|------|--------|---------|
| Added / Updated | ... | ... | ... | ... |

Keep the JSON clean: valid syntax, consistent field order, no trailing commas.
