# Cube 4 Slice 5 — source checkpoint

2026-10-02. Status: source-ready for independent review; NOT database/runtime qualified. The sole writer has stopped source edits. Applied Slices1–4 and previous evidence remain unchanged.

## Bounded behavior

External-payment recording only, against an existing immutable final payable. Explicit Employee amounts (up to100 per request), or one reviewed full-remaining action resolved into exact Employee allocations. Non-positive/excess, duplicate allocation, stale revision and altered replay intents are refused. No automatic partial distribution, bank execution, public lock, legal formula, refund or write-off.

Immutable original events and allocations retain date/reference/reason, responsible actor snapshot and audit/receipt. Mistaken-record correction is whole original entry once, linked and attributable; requires current payroll.payment_record AND payroll.correct before replay and after compatible locks. It does not attest a bank refund. The existing correction-request bundle can be combined with the new narrow recorder bundle; prior bundles are not broadened. ANY historical payment permanently remains ever-paid, even if all recordings are later compensated; the private same-period succession guard refuses amendment replacement.

Payment authority is checked before scoped output lookup/replay and after locking; active membership/current capability remain required. Entitlement loss permits only closure of this existing final obligation. Compatible finite locks: Tenant advisory0→90427, authority, deterministic Employee→Employment→Employer, payment head CAS. Payment-only and view actors receive an audited narrow financial projection; review-only actors cannot read it. Employee detail pages30 and history20, including selected-event allocations30; no whole-company raw manifest. Mandatory failed audit rolls back payment/event/allocation/head/receipt or prevents financial serialization.

Arabic journey: period/state/remaining, Employee matching, then primary “تسجيل دفعة تم صرفها خارج النظام”; optional evidence history and whole-entry correction. Pending fields are disabled, controlled values survive reset/errors; explicit stale refresh retains fields/selections. Uncertain outcome preserves the original attempt and intent, blocks altered requests until same-request recovery, and never retries automatically. A saved receipt requires an explicit new-payment action. Final-output/run history links preserve Employer/output scope. UI day limit comes from immutable period timezone.

## Checks actually performed

Affected ESLint and typecheck PASS. Initial checks ran once; the follow-up checked the actual changed recovery action/page and typecheck after recovery/period-timezone edits. Repository git diff --check and new-file whitespace checks PASS. SQL delimiter/required security-anchor static checks PASS; these are not SQL execution or concurrency evidence.

New rollback suite has58 authored assertions, NOT RUN. It uses two new Employees and privileged explicitly SYNTHETIC_NONLEGAL final fixtures solely inside ROLLBACK; immutable role snapshots remain intact and memberships switch among temporary narrow fixture roles. Assertions cover scoped/denied audited reads, actor/entry allocations, decimal rejection, per-Employee excess, exact replay/canonical intent, CAS, authority loss before receipt, separate correction authority, mandatory audit rollback, entitlement-loss obligation closure, exact partial/full/compensated reconciliation, immutable evidence and ever-paid succession refusal. No previous suite was rerun; no DB apply/build/browser/commit/remote operation by writer.

## Independent next gates / open limits

Root: fresh bounded source review before apply, then new58 rollback assertions on both exact retained QA chains. Actual independent-session races still required: allocation vs allocation/full remaining at same revision, exact-attempt replay, and whole-entry compensation vs remaining in both orders; verify waits/CAS/no overpayment and atomic audit/receipt. Root owns authenticated payment-only/view/review-denied and correction-authority journeys, pending/uncertain recovery, two-Employee allocations, history/reload, and responsive visual checks. No race PASS is claimed here.

Genuine candidates still have unqualified statutory net; legal pack/goldens/G4/public G6 finalization and complete financial-consumption qualification remain open. Private fixtures do not qualify a legal payroll or public lock. Amendment/paid correction and external settlement workflow remain ordered Slice6; actual excess has an owned correction/settlement handoff and cannot be recorded as an arbitrary balance. Supporting attachments are not implemented in this bounded slice.

## Source hashes

| File | SHA256 |
| --- | --- |
| supabase/migrations/20261002025507_cube4_payroll_external_payments.sql | ad93cee3b8e724fd446ae7b4bf0c9dcb5a7268db09ce7026ef467317ffdc4498 |
| supabase/tests/cube4_payroll_payments.test.sql | 2f8778c6f6ec1697eb662cf7fc3938165badbe43c4053466a03cbdcc54e5afb9 |
| src/app/tenant/[tenantId]/payroll/payments/actions.ts | 72de1e5c833d28380fc865eee24ca72274506d2a5cfb7be1fd8e5114b08ec043 |
| src/app/tenant/[tenantId]/payroll/payments/rules.ts | fd438b88b7eedbb09f3ce274126ac2445c60aba43c0efee375aa804d0ab1298e |
| src/app/tenant/[tenantId]/payroll/payments/PaymentForm.tsx | a30bab02117d0ab176442f645cf4e1edfb537d7c19aa11f0c5252dfab3c5ec2d |
| src/app/tenant/[tenantId]/payroll/payments/page.tsx | 9c40d03de10bd1f50181e1bcb354417835b74ab2511cc9f8a1dab91874ca088f |
| src/app/tenant/[tenantId]/payroll/payroll.module.css | 2a201b092aea603c51ad426fc30b9182e5bf1b783fc847f5f7ac24179056cea8 |
| src/app/tenant/[tenantId]/payroll/runs/page.tsx | 5412499732e0a2aaefdb9610f77b425436948b6a41a380cc50194e7f1f6ee252 |
| src/app/tenant/[tenantId]/payroll/output/page.tsx | f4f3f1e0e6a20afe40c1f7a5b44a299bb143d7dafacbdc77542d773f6436826f |
| src/app/tenant/[tenantId]/users/actions.ts | c48ffdcd9c56dc5ba99bb5014d467b8df41820a836cd5a672640f55fa4a0fbf0 |
| src/app/tenant/[tenantId]/users/page.tsx | 82a10eb54cd96574a06f739c234912876eff7ebfc9fbe7b1ad983a13983c8746 |

## Bounded independent review delta — 2026-10-02

Cycle1 found one P1: a response-lost committed payment could lose unresolved status after a later permission/lock error, permitting a changed request. Corrected only the server action: prior unresolved state survives every failed retry, including known SQL rejection, stale/excess and authority errors. No refresh or changed-intent command can release it; only successful original receipt recovery clears the attempt/signature. Fresh definite pre-mutation failures keep their existing recoverable semantics. Session/client/transport/local-validation branches preserve prior unresolved state. Migration and58 SQL assertions are unchanged.

The new recovery.test.mjs executes the actual transpiled server action with transport/session/cache stubs. Nine focused cases PASS: committed/lost response→retry42501/55P03/40P01/22023/23514/PT409/55000, changed-intent refusal, restored original receipt, original CAS despite refreshed revision; local/session/client/transport failure retention; fresh definite failure behavior. The tiny receipt stub confirms no second modeled event/allocation/audit/receipt/revision; it is state/transport evidence, NOT database or actual HTTP qualification. Root still owns the genuine lost-response/denial/lock-recovery journey.

Affected actions/test ESLint and typecheck PASS after this actual delta. The first Node --test invocation discovered zero tests because [tenantId] is treated as a pattern; direct file execution then ran all9 successfully. No old suite, DB apply, build or browser run. Writer source edits stopped for fresh cycle2 review.

| Delta file | SHA256 |
| --- | --- |
| src/app/tenant/[tenantId]/payroll/payments/actions.ts | 72de1e5c833d28380fc865eee24ca72274506d2a5cfb7be1fd8e5114b08ec043 |
| src/app/tenant/[tenantId]/payroll/payments/recovery.test.mjs | 56f899201466136444e092336267985c84587461c5988406a5df345583f1bf77 |
