# Cube 4 Slice 3 — source review checkpoint

Status: source candidate ready for independent review. SQL has not been applied by the writer. No build or runtime qualification is claimed.

## Implemented boundary

- Calculate, review and cancel through scoped commands with CAS, durable attempts, mandatory audit and one active run per Employer/period. Cancelled runs retain history; a later calculation creates another run identity.
- Immutable private candidate manifest and output with engine version. Current source changes produce specific stale/recalculate reasons. Calculation does not register financial consumption or freeze People/input versions.
- Accepted ordinary calendar-days/fixed30 and transition salary arithmetic; dated active recurring components, once-per-component numeric rounding, unchanged approved adjustments and approved daily units at an unchanged daily rate. Unknown dated unit allocation is an owned blocker.
- Versioned statutory pack boundary without statutory constants or guessed formulas. Net, statutory deductions and contributions are unavailable. Enabled Time/Leave integration produces explicit owned blockers; absent optional modules do not block their integration independently.
- Arabic period selection, paged Employee review, issues before optional commands, preserved pending form state, immutable calculation/cancellation history and honest draft-to-draft variance availability. Detail projects contiguous unchanged segments with dates, day counts, rate/value and denominator. Exact raw arithmetic remains private.
- Narrow review-only discovery/read authority and an appended reviewer role bundle. Main Payroll navigation opens operational review; calendar configuration remains available separately.

## Source files

Migration: `supabase/migrations/20261002010419_cube4_payroll_candidates.sql`.

Focused rollback suite: `supabase/tests/cube4_payroll_candidates.test.sql`.

UI/service boundary: `src/app/tenant/[tenantId]/payroll/runs/{page.tsx,RunActions.tsx,actions.ts,rules.ts}`; additive recurring-proration field in `payroll/inputs/{InputForm.tsx,rules.ts}`; context links in `payroll/inputs/page.tsx` and `payroll/page.tsx`; calendar error mapping in `payroll/rules.ts`; reviewer bundle in `users/{page.tsx,actions.ts}`; operational entry in `src/components/context-navigation.tsx`.

Accepted additive decisions: fixed30 amendment (DEC028), recurring-proration amendment (DEC029), Payroll spec links and decision-log entries. Earlier Frozen text and decision history remain intact.

## Writer verification

- Changed-code ESLint passed.
- TypeScript typecheck passed after correcting JSX closure and using the project's supported BigInt constructor form.
- Four focused formatter assertions passed, including negative sub-unit money and values beyond JavaScript safe integer precision.
- `git diff --check` passed; focused static check found no improper single-dollar SQL delimiters.
- New SQL rollback suite is authored, not executed. Root owns independent SQL review, guarded QA apply, rollback execution, build and browser journeys.

## Open qualification gates

This checkpoint does not qualify G3 final consumption/People insertion races, G4 Attendance/Leave adapters, statutory pack/engine/golden cases, production financial approval/lock/payment, fresh-chain parity or company-scale performance. Candidate locks and freshness are preparatory evidence only. Daily rate changes and in-period mixed paid-full behavior remain explicit owned blockers with recovery copy; no allocation is inferred.

The known gross is clearly partial where coverage or source ambiguity prevents an authoritative operating total. A legal blocker always remains visible until the independent statutory boundary is qualified.

## Independent review cycle 1 — bounded correction

- Manual units now resolve the latest revision separately for each head, then exclude cancelled or inapplicable current heads. One approved current head supplies the units. Multiple live applicable heads produce an owned ambiguity blocker; revisions from unrelated heads are never compared to choose a winner. The focused suite adds cancelled revision 3 followed by approved replacement revision 2, non-resurrection and ambiguity cases.
- Review-to-calendar links retain Employer, period and Employee search. Calendar keeps Employee search in a separate validated `review_q` parameter; its `q` remains Employer search. Returning to review restores the original scope, and selecting another Employer clears the old period/search.
- Calendar availability copy now identifies candidate calculation as available and distinguishes saved calendar dates from source/candidate and financial/legal qualification.
- Affected-file lint and TypeScript passed after this correction. Formatter code is unchanged, so its prior passing assertions were not repeated. SQL regression execution, apply, build and browser review remain root-owned and unexecuted by the writer.


## Later focused rounding evidence — 2026-10-02

The original 57 assertions and observed UI journeys remain actual passing evidence. A later independent root rollback probe of 12 exact half-cent percentage cases found five failures caused by division truncation before component summation; a separate partial base/fixed-component tie also failed. Therefore those original observations do not establish general accepted half-away rounding. Slice4 adds an exact rational arithmetic correction under a new engine identity and invalidates earlier candidates. Delta SQL qualification remains pending; historical evidence is preserved.
