# docs(docs): drop the surveycore pin from the export-metadata plans

**Date**: 2026-11-04
**Branch**: docs/export-metadata-surveycore-floor

## Changes

- Add the export-metadata implementation plan and its review to git. Both
  files were in the working tree but not tracked.
- Remove the `Remotes: JDenn0514/surveycore@develop` pin from the plans.
  surveycore 1.2.0 is on CRAN, and `develop` already reads
  `surveycore (>= 1.2.0)` with no `Remotes:` line (#13). Spec section IX and
  plan PR 1 required the pin and a `>= 1.1.0.9000` floor.
- Plan PR 1 keeps its branch name and its task numbers. Tasks 5 to 8 now check
  `DESCRIPTION` and the installed surveycore, and edit nothing.
- Record that the CRAN 1.2.0 build exports every surveycore name the plan
  calls, and that the spec's facts were measured against `1.1.0.9000` and not
  measured again.

No R source file, roxygen comment, or test file changed.

## Files Modified

- `plans/spec-export-metadata.md` — v0.21.0; rewrote section IX and the
  matching section 8 checklist item
- `plans/impl-export-metadata.md` — new to git; v4.1.0; PR 1 tasks 5 to 8,
  task 22, acceptance criteria, write surface, the "facts a PR description
  must carry" section, and the ordering table
- `plans/plan-review-export-metadata.md` — new to git; unchanged
- `plans/decisions-export-metadata.md` — appended the 2026-11-04 entry
- `changelog/docs-export-metadata-surveycore-floor.md` — new; this file
