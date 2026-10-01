# Cube 3 attendance classification interface

This V1 slice connects the qualified attendance classification APIs to the existing attendance detail page. It displays full leave coverage and fractional absence, requires a reason, and creates an explicit successor when an approved result needs correction. Existing facts remain visible in history.

A stale review requires explicit renewal and preserves the entered reason. Retries retain the operation key for the same reviewed plan and reason; a changed intent receives a different key. Server actions authenticate the session and submit the qualified version and fingerprint checks.

## Qualification

- TypeScript and ESLint passed.
- Real local Auth, REST, browser and database checks passed for half-day approval, cancellation followed by explicit correction with the exact previous fact retained, stale submission and renewal with the reason preserved, and full unpaid leave coverage without absence.
- Follow-up browser checks verified successful approval feedback and accurate approved outcome wording, plus the review form at widths 390, 820 and 1280 without horizontal overflow.
- Independent read-only Antigravity review passed; no review writes were detected. The final feedback wording correction was verified separately in the browser.
- Evidence is retained outside the repository in the run's slice26-classification-ui-browser.json and slice26-classification-ui-copy-check.json. No credentials or synthetic fixture files are included in this commit.

## Scope

This is a local V1 interface slice, not complete Cube 3 qualification. Linked leave replacement UI and the V1 annual entitlement gate remain open. The broader joint Leave/Time preview draft is isolated and is not part of this delivery. No production database changes or deployment are included.
