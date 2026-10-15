# User manual authoring source review

Date: 2026-10-15. Authoring baseline observed HEAD: `42f1016097aa4c62d9a6b3ceda74f3f8036a54b4` in the external worktree. Parent is concurrently implementing field guidance; manual wording deliberately refers to a help mark only where available. This file is an internal authoring companion, NOT part of the company-facing guide.

Deliverable: external `user-manual-draft.md`, UTF-8. No repository edit, service mutation, database operation, commit, Claude call, cleanup or runtime test by this authoring agent. No all-routes runtime claim. No financial/legal qualification claim. No screenshots invented. Manual contains no localhost address, secret, real tenant identifier or synthetic credential.

## Instructions applied

- worktree AGENTS.md, especially mandatory complete journey requirement.
- `docs/04-product-specs/ux-redesign/journey-improvement-contract.md`.
- `C:/Users/DELL/.codex/skills/arabic-ux-writing/SKILL.md`.
- Actor, entry, choices, steps, observable outcome, recovery, next responsible role per journey.
- Owner steering: examples/placeholders plus subtle on-demand help, not a persistent UI wall of prose; essential warnings remain visible.

## Source-to-manual matrix

Paths below relative to worktree; `[tenantId]` and similar are literal directory names. Large source reads were bounded and some returned output truncated; this matrix represents consulted contracts and UI text, NOT an assertion that every line in all 62 routes was read in full.

| Manual area | Source inspected | Authoritative facts used |
|---|---|---|
| Role catalog and separation | `src/app/tenant/[tenantId]/users/bundles.ts` | All current bundles and presets, sensitive finance separation, HR salary access, policy-only manager, employee rights limited |
| Today and navigation entries | `src/app/tenant/[tenantId]/today.tsx`, `layout.tsx` search | Permission-specific task entries, independent unassigned queue, own attendance/leave/profile, exporter follow-up wording |
| Employee tabs | `people/[employeeId]/EmployeeProfileTabs.tsx` | Overview/work/compensation/account/employment areas, no tab switch while action busy |
| Account provisioning and link | `people/[employeeId]/EmployeeUserLinkPanel.tsx` | Existing active confirmed member link, invite then link, provision account then employee confirms password, recovery/readiness, manual-review guard, unlink history |
| Self-service grants | `people/[employeeId]/EmployeeSelfServices.tsx` | Permission separate from work readiness, membership active, account link, service prerequisites |
| Employment end and rehire | `people/[employeeId]/EmploymentLifecyclePanel.tsx` | Today/past end only, no auto final settlement, rehire same person/new employment, previous history protected |
| Employee import | `people/import/page.tsx`, `WorkforceImportForm.tsx` | 256KiB/100rows UTF-8, exact template, monthly/daily true/false, organization codes, preview/confirm, no policy/balance assignment |
| Branding | `branding/BrandingEditor.tsx` | Display identity/preview; legal name unchanged |
| Work policies | `people/work-policies/WorkPolicyEditor.tsx` | Fixed/flexible, minutes/timezone, cross-midnight, half-day breaks, attribution window, overtime rounding, new-day auto-approval only |
| Attendance source/privacy | `attendance/sources/ChannelForms.tsx` | Mobile/external, retention60..2592000seconds, location age not retention, radius/accuracy/tolerance, reject/review, reason, stop preserves records |
| External mapping/reprocessing | Same `ChannelForms.tsx` | External key identity, UTC interval end excluded, no overlap, reprocess vs review distinction, external source not hardware integration |
| Employee punch | `me/attendance/MobilePunch.tsx` label/action search | Slide confirm, pending check, safe same-attempt resend, new attempt only after terminal refresh |
| Attendance CSV | `attendance/import/AttendanceImportForm.tsx` first160lines | 5columns, max100events/256KiB, explicit offset, source event identity, preview vs committed receipt, partial outcomes retained |
| Leave setup | `leave/settings/rules.ts` | Calendar -> year period -> type progression, paid/unpaid vs tracked/untracked distinct, working/calendar days, half-day, immutable versions |
| Leave admin decisions | `leave/new/RecordLeaveForm.tsx` and `leave/requests/[requestId]/ReviewIntentForm.tsx` bounded outputs | Approve/reject reason, preview version, cancellation/replacement inputs, historical payroll correction responsibility |
| Balance ledger | `leave/balances/PostBalanceForm.tsx` first90lines | Operation journal and account scoped context, unknown safe recovery; no blind opposite posting |
| Annual entitlement | `leave/balances/annual/AnnualForm.tsx` | Preview then delta post, documented categories, current policy and service, reviewed input invalidation, prior debit preserved |
| Employee leave submit | `me/leave/new/NewLeaveRequestForm.tsx` lines125+ | Dates first -> types -> preview -> reason -> submit; submitted no reservation until approval |
| Employee leave cancellation | `me/leave/[requestId]/page.tsx` first85lines | Submitted/withdrawn, cancellation pending preserves approved original, current access snapshot |
| Calendar | `payroll/CalendarForm.tsx` source search | Cutoff/payment-day/month/timezone/reason, preview then period creation, no rewrite of existing period bounds |
| Payroll input types | `payroll/inputs/rules.ts`, `InputForm.tsx` | All7kinds, labels/options, statutory vs YTD fields, manual/time mutual selection, conditional approval, one-time policy set, no free formulas |
| Payroll input historical correction | `payroll/inputs/CorrectionForm.tsx` | Records responsibility, doesn't reopen or mutate old payroll automatically |
| Payroll review | `payroll/runs/page.tsx` search, `SourceExplanation.tsx` search | Operational vs qualified, stale data, grouped owners/issues, attention filter not all employees, original source details, no assumed zero variance |
| Run operations | `payroll/runs/RunActions.tsx` bounded output | Prepare/recalculate/cancel and local recovery journal; final scope includes employer/period/count/gross/net |
| Finalize/approve labels | `payroll/runs/page.tsx` current source | Approval tied to current candidate, release to review before recalculation; final output separate |
| Final reports | `payroll/reports/rules.ts` | Exact7report names and snapshot/previous/replacement fields; exporter separate |
| Advances | `payroll/advances/page.tsx`, `AdvanceForm.tsx` | Draft/principal/installments, genuine external disbursement, settlement oldest, deferral not debt cancellation, correction linked/qualified, journal recovery |
| Payment recording | `payroll/payments/PaymentForm.tsx` | Exact allocations or whole remaining, external actual date/reference, confirmation, full record compensation not bank refund, original attempt recovery |
| Locked payroll correction | `payroll/corrections/CorrectionForms.tsx`, `page.tsx` source search | Source authorization +correction/finalize, reviewed liability not net guess, later input vs external settlement, recover original |
| Operator task map | `operator/team/OperatorTeam.tsx` | Five task capabilities, existing confirmed account, diff preview, last-manager invariant, explicit self change warning |
| Company onboarding | `operator/companies/new/CompanySetup.tsx` | Invite vs existing confirmed account, invitation not yet company, delivery sent not receipt/acceptance |
| Services | `operator/companies/[tenantId]/services/ServiceManager.tsx` | Switches, dependents plan/confirm, expired duration, parent bound, note optional, current snapshot/unknown recovery |
| Usage limits | `operator/companies/[tenantId]/limits/LimitManager.tsx` | Limited/unlimited, existing resources remain after cap decrease, unknown reread |
| Lifecycle | `operator/companies/[tenantId]/status/LifecycleManager.tsx` | Active/suspended/archived, archive restores suspended first, reason/confirmation retained |
| Statutory | `operator/statutory/DraftForm.tsx`, `comparisons/IssuanceForm.tsx` | Draft sources/versions, compare current version, issue not universal financial qualification, exact same-attempt recover |

## Role coverage checklist

- Operator: company onboarding/invitations, commercial entitlements/limits, lifecycle, team manager, statutory rules issuer/editor. These are capabilities, not invented new predefined roles.
- Company admin/membership manager separate from domain rights.
- People reader/operations/compensation reader/manager/import operator.
- Attendance reader/operator/reviewer/policy manager and source/channel tasks only when authorized.
- Leave reader/manager/approver/balance manager; employee own request/withdraw/cancellation.
- Payroll reader/preparer/reviewer/calendar manager/input approver/finalizer/exporter/payment recorder/correction requester.
- Employee-finance reader/author/approver, advances authority described conditionally rather than claiming nonexistent bundle entries.
- Employee own profile/attendance/leave separate from access to colleagues/financial administration.

## Accuracy and delivery limits to retain

1. Manual is source-informed and should be rendered/visually reviewed by parent. It does not certify a training session or every live business outcome.
2. Field help implementation is parent-owned and in flight; validate final account-menu label `دليل الاستخدام والتدريب` and rendered help mark in the final build.
3. Some specialized decisions deliberately say “according to displayed allowed action” instead of claiming every role can do them, especially source management, advances approval and settlement.
4. No recommendation for actual retention period, tax/insurance rate, compensation, leave allowance, or legal debt classification. Unit conversions are examples only.
5. No statement that payroll financial/legal readiness is established for all demo employees. Gates remain explicit.
6. Manual has no production identity claims. Publication and current-version stamping belongs in final parent artifact manifest.
7. Reference illustrative employee codes and monetary values are fictitious; no actual tenant IDs/credentials included.

## Suggested renderer checks

- RTL body; Latin codes isolated LTR; Arabic font embedded/available; searchable PDF text.
- Headings/bookmarks or clickable contents; no table clipping; keep small tables with next context.
- No empty overflow pages, clipped glyphs, flipped numeric examples or orphaned headings.
- Print representative dense table page, policy-help example page, employee request page and final signoff page.
- Guide/menu link opens offline static HTML without revealing secrets or developer source paths.
