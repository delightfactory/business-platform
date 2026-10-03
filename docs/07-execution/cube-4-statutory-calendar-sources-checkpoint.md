# Cube 4 source-bound calendar facts — QA145

Completion-route step2 is in progress. This change connects factual calendar boundaries to the actual employee statutory source projection and authenticated calculation path. It does not calculate legal duration, assign insured-month ownership, calculate net, or qualify a full financial candidate.

The projection binds one actual Employment and matching Employee identity, checks the exact period/employment clipping and bounded366-day coverage, and partitions covered dates into calendar months and years. Each month retains its complete calendar end, covered date range/count, full-service/start/end facts and dated statutory context fragments with exact source head/version and wage data. Changed wage versions are preserved separately; no averaging or gross-based insurance wage inference occurs. Employment absence/ambiguity remains unknown. Missing insurance context remains absent; it is not a zero contribution or exclusion.

Calendar day counts remain distinct from `legal_duration_days:null`; month fragments remain distinct from `obligation_months:null`. Source-based legal applicability and the payroll assignment decision must be resolved before those values can be derived. The manifest engine fingerprint changes for new calculations; retained candidates are never rewritten. Existing legal, net and finalization gates remain intact.

## Primary source boundary and pending assignment decision

The current [ETA FAQ v4](https://www.eta.gov.eg/sites/default/files/2026-05/faqs-payroll-system-v4.pdf), technical questions39–40 at PDFpage17, distinguishes entitlement months from filing/payment and actual daily work from monthly duration convention. It does not by itself establish the complete legal treatment of every non-calendar or cross-year company cycle. No company salary proration convention was substituted for tax duration.

The [NOSI-hosted original Law148/2019](https://www.nosi.gov.eg/ar/Lists/NOSILibrary/2-12-2019%20%D9%83%D8%AA%D8%A7%D8%A8%20%D8%A7%D9%84%D9%82%D8%A7%D9%86%D9%88%D9%86%20%D8%A7%D9%84%D8%AC%D8%AF%D9%8A%D8%AF.pdf), Article115 at PDFpage75, distinguishes contribution wage/category and joining/ending month treatment. This is an original2019 publication, not evidence of consolidated2026 category applicability or a full current rule pack. No statutory rate or liability was activated from it.

Owner question pending: assign a legally due calendar-month insurance obligation to the payroll cycle containing calendar month-end, or to the cycle containing termination when service ends before month-end; ensure exactly-once month ownership. This is proposed internal assignment, not a legal liability formula. The question is awaiting an explicit answer; no ownership implementation or deduction depends on elapsed time. Independent calendar/source work continues.

## Evidence

- `cube4-statutory-calendar-sources-qualification.json`: first-run27 focused assertions on each local QA144 baseline, migration/fixture/test rollback PASS. Cases include25→24, year crossing, clipped join/end, dated wage versions,29-day leap February, identity/boundary refusals and unknown versus zero. One reused setup-only fixture reaches actual authenticated calculate and confirms January/February annotations while net remainsNULL. No unchanged source or arithmetic suites rerun.
- `reviews/cube4-statutory-calendar-sources-review.json`: independent read-only PASS for three exact source/test/fixture hashes; same-provider separate context, not external legal review. Reviewer did not execute tests or mutate the database.
- `cube4-statutory-calendar-sources-local-install.json`: reviewed migration installed once in each dedicated local QA database, ledger144→145. Input, pack, candidate, run and comparison digests unchanged.

No frontend was edited, so no browser/static frontend rerun was warranted. This is not full integration acceptance, official numeric qualification, actual insurance consumption, public net activation, or full Cube4 closure. Next: consume these source-bound date facts in the financial composition, with reviewed legal duration and confirmed insurance ownership; keep the unresolved portions explicit.
