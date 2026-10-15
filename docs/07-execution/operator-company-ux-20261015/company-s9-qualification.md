# S9 bounded qualification supplement

UI source94ced01; this supplement supersedes the remaining-runtime checklist in company-s9-checkpoint.md only where explicitly proven below. Entire Company acceptance still needs official Claude complete source coverage and verdict.

## Role and keyboard evidence

Real Auth browser receipts are retained in qa/s9-ui-role-receipts.json. Home capture waits for the actual Today heading; initial skeleton-only home observations were replaced, not treated as evidence. Normal role snapshots are in s9-role-read-results.json and s9-policy-role-positive.json.

| Role | Actual UI result | Authority evidence |
|---|---|---|
| Protected administrator without work bundles, Company06 | Today setup guide: work access/basic identity/People/Leave/Payroll/attendance source responsibilities, administration links | Only tenant.owner_admin.v1 in actual member receipt; no work bundle added |
| No-work member, Company05 | Today has ready-space explanation and no task links | Separate synthetic member, zero work bundles |
| HR preset | Today pending leave request, cancellation handoff, People, attendance read/source entries; no payroll task | Exact5 bundles saved from UI; separate Auth probe payroll_run_access42501 |
| Leave balance manager | Today read-follow-up, Time -> balances -> four-step account movement workspace | can_adjust=true, can_manage/can_approve=false; no balance mutation in this supplement |
| Payroll approver | Today payroll/input/report entries; review states10 source/financial blockers, no actionable financial approval | can_approve=true, prepare/lock/payment false |
| Finalizer | Same scoped payroll entry; blocked/stale review exposes only review filter button, no final save | can_lock=true; prepare/approve/payment false |
| Exporter | Payroll/report entry; report chooser explicitly has no employers with a final output | Real grant/navigation; report can_export source audited. No final output invented to probe it |
| Payment recorder | Payroll/report entry; blocked review offers no payment execution | can_payment_record=true; prepare/approve/lock false |
| Correction requester | Today payroll/input/report entry | payroll.correct=true, prepare/approve/lock/payment false; no final-output correction created |

Previously verified employee, own-only, limited HR reader, leave approver, payroll viewer/preparer, compensation manager, policy manager and attendance reviewer evidence remains in S1-S8/S9 checkpoints. Role receipts distinguish API authority from visible enabled actions; a blocked financial candidate never becomes an enabled action merely because the actor has the role.

Permission editor actual keyboard sequence: focus trigger+Enter, two Tabs to HR preset, Enter; visible exact5 additions and sensitive consequence; three ShiftTabs wrap focus to Save; Enter saves. Normal authoritative member read proves exact preset5 and denied payroll. Reopen with Enter then Escape closes; document focus returns to تعديل الصلاحيات with a solid outline and0 dialogs. Images permission-keyboard-preview/saved retained. Actor is synthetic only. No existing user's grants were broadened.

The12 additional QA actors increased membership usage beyond the original fixture's10 seats. A separate normal authorized Operator set_tenant_capability_limit call with expected timestamp adjusted only this owned local QA capacity19/10->19/30. Journal s9-qa-capacity-adjustment.json; no production or permission semantics changed. Earlier capacity-specific tests remain their historical fixtures.

## Attendance channel event

Created one named external QA source through normal original-admin RPC, then submitted an unmapped synthetic event twice with the same stable key. First state unmapped/mapping, second duplicate;1 replay and0 canonical punches. No device/mobile/physical capture and no employee mapping. Journal s9-channel-event.json retained. Actual HR reader opened its event page: state and next-step explanation visible; no management buttons; processing attempts and support details both collapsed by default. Screenshot company-s9-channel-event-collapsed.png. Existing Today/Yesterday and keyboard approval evidence is in S9 checkpoint.

The event's default timestamp explicitly displays UTC because no employee/site mapping supplies a working timezone. This is observed honestly for final G8 judgment; do not silently claim zero technical timezone strings across all pages. Current policy catalog also retains a default timezone value; full source review must assess remaining G8 presentation compliance and issue a finite correction list if needed.

## Financial output boundary

Company05 has no final output. Exporter sees the honest empty report chooser, not a failed download, and no export ran. Source-based output/payment/export acceptance without fabricating a final payroll is explicitly allowed by R1 item5 and frozen qualification limits. No legal/financial qualification, finalization, real payment or first physical attendance capture is claimed.

No production code changes in this supplement, so the successful94ced01 TS/lint/13 focused tests/coherent build remain applicable. No repeated calculation suites. Source clean and development-only push required. All private credentials/QA/evidence remain external to source and OneDrive. Active review/evidence/dependencies retained; no deletion or cloud quota recovery claimed.