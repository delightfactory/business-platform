# Delight payroll production journey — 2026-10-16

## Outcome

The actual company administrator (`ahmeddalia101@gmail.com`) completed calculation, approval, immutable finalization, and a synthetic external-payment record through the production UI. No bank transfer or real payment occurred. Supabase Free was retained.

The original Delight period, 16–31 October, remains open. Its future attendance capture windows cannot be approved in advance. A clearly named non-operational test employer inside the same Delight tenant was used for the completed one-day journey. This is a bounded demonstration, not a claim that every payroll scenario has been tested or financially certified.

## Actual production scope

- Domain: `https://platform.delight-world.com`
- Supabase: `business-platform-production`, `msryvzefjdqjcfikerne`.
- Tenant: `417689ee-c388-43df-91a2-8d2fc84c8a50`.
- Test employer: `d33e1b56-77be-4d68-a950-ac6734910bd4`, **اختبار الرواتب — غير تشغيلي**. Its legal-name field explicitly says it is a fictional test entity.
- Test employee: `34e37125-4e73-4589-9911-95559dd1b097`, code `E-7HG4UKJRRCJZ`, **موظف اختبار الرواتب المصرية — غير حقيقي**.
- Employment: `ac609d07-2bbd-4570-a10f-9f3dbeff18d2`; daily rate EGP 1,000.
- Period: `e73f292f-4fd8-4eab-a1f2-fb6d5bf6861f`, 16 October only.
- Attendance: `3a8a9933-67ba-4259-a435-b38ff49217e4`; explicit synthetic manual punches 06:00–14:00 Cairo, 480 minutes, approved through the administrator UI after the capture window closed.
- Final output: `1ae29443-c66c-447a-b939-d3c3f6dd8476`; run `1eb9f2ed-c2ef-40fe-9c89-2079ef5a38ea` is locked, revision 9.
- Payment event: `b97d63a9-ddfc-4c78-808b-8e37dd54ed74`; reference `UAT-DELIGHT-DEMO-PAYMENT-20261016`. The event description explicitly states no money was paid or transferred. Read-only SQL confirmed exactly one payment event.

## Independent expected and observed values

The expected values were recorded outside the source tree before the actual calculation. A daily employee with no prior employment/income was selected; prior taxable duration is explicitly zero, with zero-balance coverage from 1 January to 15 October. The insured wage is EGP 6,000 and a full monthly obligation is an explicit synthetic test assumption. It is not inferred from one day of salary and is not a real worker's eligibility determination.

| Item | Independent expected | Actual final result |
|---|---:|---:|
| Gross | 1,000.00 | 1,000.00 |
| Employee insurance | 660.00 | 660.00 |
| Employer insurance | 1,125.00 | 1,125.00 |
| Wage tax | 28.42 | 28.42 |
| Net | 311.58 | 311.58 |
| Recorded synthetic payment | 311.58 | 311.58 |
| Remaining | 0.00 | 0.00 |

Tax check: `(1000 − 660) × 360 − 20000 = 102400` annual taxable basis; the configured treatment-01 bands produce annual tax 10,230, divided by 360 and rounded to 28.42 for the test day. The UI's employer-cost line shows employer contributions, 1,125; gross plus employer contributions is 2,125.

The activated pack is `72fd1a82-bcdd-4aac-ae13-152e311d4fde`, `EG-2026-PRIVATE-GENERAL`, valid 1 January 2026 through before 1 January 2027. It covers the ordinary private-sector test category outside UHIA and special reductions, not every sector or employee automatically. External accounting comparisons remain optional.

## Defects found and repaired

1. Existing employee payroll inclusion had no usable update path. A permission-aware switch was added and independently qualified in `inclusion-qualification.md`. It uses real source locks and append-only audit receipts.
2. Daily-source error-array concatenation lost the actual blocker because the JSON operator lacked parentheses, producing a null issue and a server-rendering failure. Fixed the merge. Malformed historical issues now remain visible blocking items in a read-only projection; saved candidate history is unchanged.
3. A current approved clean worked fact stores absence as not-applicable/null. Reconciliation now treats only this explicit, current worked outcome with valid quantities as zero absence. Missing, stale and genuine unknown-absence facts remain blocked. A manifest engine suffix forces recalculation.
4. A saved opening-balance/statutory draft could not be completed at its existing effective date. A same-date save now appends a new immutable draft revision. Permissions, expected-version checks, exact-intent replay, effective-date bounds and frozen-financial correction paths remain in force.
5. A blank employer legal name caused finalization to fail with a generic uncertainty message. An early review-page notice now links to the actual entity edit screen; the known backend error has specific Arabic guidance. The finalization requirement itself remains unchanged. The test employer's name was completed through the UI; no actual company legal identity was invented.

The first failed finalization was reconciled as closed/uncommitted before continuing. Updating the employer name correctly made the approved candidate stale; it was returned to review, recalculated and approved again before successful finalization.

## Verification and review

- New worked-day reconciliation suite: 10/10 pgTAP assertions passed.
- Actual public financial journey suite: 60/60 passed, including six new draft/history/replay/frozen checks. Tests use explicit BEGIN/ROLLBACK and the owned `business_platform_cube4_adam_positive_qa` database. No production test-fixture SQL writes were used.
- Earlier inclusion qualification: 16/16 public-RPC assertions and then-current financial journey suite passed.
- Scoped ESLint for the final two UI files passed; optimized Next build and TypeScript passed.
- Independent read-only reviewer `/root/worked_day_review`: PASS on the reconciliation, same-date draft and final UI guidance. A migration ordering finding was corrected by naming the draft migration `20261016170000`, after the function it patches.
- Root-cause log evidence: React server error digest `3986718195`, null `owner`, and later PostgreSQL `payroll_legal_employer_missing`. Both were handled without retrying an uncertain final write blindly.
- Actual production calculation, review, approval, finalization, output page and external-payment UI were exercised. Reload retained full-paid state. SQL corroborated locked output, exact gross/net and one payment event.
- Source/ACL hashes for the changed SQL functions matched the qualified QA database; private helper ACLs remain postgres-only.

## Original Delight period and remaining company inputs

The original employer is `8a1b12b7-be0e-4f34-8183-8082ef8abde2`, period `93436ce8-d3b7-4648-9c12-9ddb750c89c2`. Calendar, company fixed-30 policy, employee inclusion, statutory context and explicit zero opening coverage were saved through the actual UI. Existing wage history (6,000 then 6,500 from 22 October) was preserved.

Its refreshed review still has 12 future attendance windows and one day needing review. No future attendance was fabricated, no service was disabled, and the period was not finalized. The primary employer has no supplied legal name; its actual legal identity must be entered by the company before genuine final payroll documents. The synthetic test entity is not its substitute.

## Storage and release boundaries

All work, dependencies and captures are outside OneDrive in the owned external run. No new dependency installation, Docker reset, database wipe, cloud deletion or paid subscription change was performed. Final evidence and audit/recovery records are retained. The earlier cleanup rejection was not bypassed; no reclaimed disk/cloud-space claim is made. The temporary QA preview on 61193 was stopped; unrelated user services and databases were preserved.

Database-only fixes are commits `07c6a0d` and `5f4419f`; final guidance source is `5ba8397a10e38aaa2e347d48653284f0695c8dea`. All are on pushed development branch `codex/operator-company-ux`, with no main merge. Final deployment identity and rendered verification are recorded separately in `release-verification.md`.
