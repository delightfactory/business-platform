# Guided Egyptian payroll setup — 2026-10-16

Scope: company payroll preparers can select a period and employee, use the active published Egyptian baseline, confirm insurance facts and prior income, and save the required drafts atomically. Advanced treatment/category/duration remain editable. Existing opening balances are preserved. No approval, finalization or payment is automatic.

Validation before release:
- Full public financial journey: 68/68 pgTAP assertions passed in isolated QA database, including the new guided entry, authorization denial, atomic rollback, exact replay, changed intent and stale context; existing finalization, correction and recorded-payment safeguards passed.
- Next production build including TypeScript: PASS. Scoped ESLint and git diff whitespace check: PASS.
- Independent read-only review: PASS after fixing canonical prior-output lookup, eligible opening selection and duplicate import. Success link targets the saved record, and revalidation preserves the form action result.
- Arabic guide source and HTML updated together; full PDF regenerated (38 pages). Payroll pages visually inspected for readable Arabic and complete steps.

Defaults are suggestions: monthly tax duration uses 30 for a complete month and bounded employment overlap for a partial month; daily pay requires actual eligible days. Insured wage is never guessed. A zero opening requires explicit company confirmation of no prior income. Cross-month and special cases retain the advanced route. Existing company-wide proration policy is not overwritten.

Storage: worktree, dependencies and intermediate PDF renders remain outside OneDrive. The owned temporary QA server was stopped before the final build; active shared dependencies and historical evidence are retained.
