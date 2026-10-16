# Guided Egyptian payroll setup — 2026-10-16

Scope: company payroll preparers can select a period and employee, use the active published Egyptian baseline, confirm insurance facts and prior income, and save the required drafts atomically. Advanced treatment/category/duration remain editable. Existing opening balances are preserved. No approval, finalization or payment is automatic.

Validation before release:
- Full public financial journey: 68/68 pgTAP assertions passed in isolated QA database, including the new guided entry, authorization denial, atomic rollback, exact replay, changed intent and stale context; existing finalization, correction and recorded-payment safeguards passed.
- Next production build including TypeScript: PASS. Scoped ESLint and git diff whitespace check: PASS.
- Independent read-only review: PASS after fixing canonical prior-output lookup, eligible opening selection and duplicate import. Success link targets the saved record, and revalidation preserves the form action result.
- Arabic guide source and HTML updated together; full PDF regenerated (38 pages). Payroll pages visually inspected for readable Arabic and complete steps.

Defaults are suggestions: monthly tax duration uses 30 for a complete month and bounded employment overlap for a partial month; daily pay requires actual eligible days. Insured wage is never guessed. A zero opening requires explicit company confirmation of no prior income. Cross-month and special cases retain the advanced route. Existing company-wide proration policy is not overwritten.

Storage: worktree, dependencies and intermediate PDF renders remain outside OneDrive. The owned temporary QA server was stopped before the final build; active shared dependencies and historical evidence are retained.

Production acceptance:
- Source `7629f5d4444f4df457faa3469d5ec9c06360f721`, Vercel `dpl_HAjqQJ5se6gu7HhHy86Whko8C3X3`, READY and promoted to `platform.delight-world.com`.
- Additive migration applied to Supabase `msryvzefjdqjcfikerne`; anonymous execution denied, authenticated execution requires the existing scoped payroll authorization.
- Actual Delight company-admin session loaded the guided employee form and saved the existing synthetic employee draft successfully. Success retained its direct record link after revalidation. Existing wage 6000 and previously selected tax duration 15 remained unchanged; the opening was not overwritten.
- Responsive phone check: viewport and document width both 390, save action available. Desktop form captured in `setup-production.png`. Temporary viewport override removed.
- Live role-filtered guide contains both new journey sections; HTML and PDF endpoints return HTTP 200. No error/fatal runtime logs found for the new deployment in the checked 10-minute window.
- Removed four exact obsolete PDF/cropped-image intermediates after literal-path, run-boundary, Git and reparse checks: verified 711672 local bytes. Source, final PDF, representative screenshot, active shared dependencies and historical evidence retained; no cloud-quota claim.

The existing main Delight period still requires its operational source reviews; this UI release does not fabricate attendance, approve a real payroll or transfer money.
