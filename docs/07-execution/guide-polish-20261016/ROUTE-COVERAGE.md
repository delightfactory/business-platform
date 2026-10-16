# Bounded source route coverage - 2026-10-16

Base: 896cc2a476127bfd7e7b1b82a992fc0eacd8b7fe plus the seven-file UI polish diff in ui/.
All 87 route paths were enumerated and actual source excerpts read. YES below means source inspected at the explicitly stated depth, not whole-file semantic acceptance. Long routes were checked through selected entry/auth, title/action, failure/empty/return excerpts; nested imported form implementations were not exhaustively reviewed. No browser journey, role impersonation, numeric N/C/P/I/B measure, build, financial retest or production execution was performed by this audit. Do not describe 87 YES rows as full runtime coverage.

| # | Route source | Inspected? | Depth | Finding |
|---:|---|---|---|---|
| 1 | `src/app/auth/employee-account-activation/callback/page.tsx` | YES | Expanded route-source review | F1: invalid reference without state keeps misleading default instruction and no confirm control |
| 2 | `src/app/auth/employee-account-activation/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 3 | `src/app/auth/forgot-password/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 4 | `src/app/auth/invitations/accept/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 5 | `src/app/auth/invitations/callback/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 6 | `src/app/auth/login/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 7 | `src/app/auth/membership-invitations/accept/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 8 | `src/app/auth/membership-invitations/callback/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 9 | `src/app/auth/password/update/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 10 | `src/app/dev/ui-gallery/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 11 | `src/app/operator/commercial/[tenantId]/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 12 | `src/app/operator/commercial/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 13 | `src/app/operator/companies/[tenantId]/limits/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 14 | `src/app/operator/companies/[tenantId]/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 15 | `src/app/operator/companies/[tenantId]/services/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 16 | `src/app/operator/companies/[tenantId]/status/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 17 | `src/app/operator/companies/new/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 18 | `src/app/operator/companies/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 19 | `src/app/operator/entitlements/[tenantId]/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 20 | `src/app/operator/entitlements/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 21 | `src/app/operator/invitations/new/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 22 | `src/app/operator/invitations/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 23 | `src/app/operator/onboarding/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 24 | `src/app/operator/operators/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 25 | `src/app/operator/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 26 | `src/app/operator/statutory/comparisons/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 27 | `src/app/operator/statutory/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 28 | `src/app/operator/team/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 29 | `src/app/operator/tenants/[tenantId]/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 30 | `src/app/operator/tenants/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 31 | `src/app/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 32 | `src/app/tenant/[tenantId]/attendance/[instanceId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 33 | `src/app/tenant/[tenantId]/attendance/calendar/page.tsx` | YES | Expanded route-source review | Fixed in UI batch: bottom review link preserves payroll scope |
| 34 | `src/app/tenant/[tenantId]/attendance/import/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 35 | `src/app/tenant/[tenantId]/attendance/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 36 | `src/app/tenant/[tenantId]/attendance/review/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 37 | `src/app/tenant/[tenantId]/attendance/sources/[sourceId]/events/[eventId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 38 | `src/app/tenant/[tenantId]/attendance/sources/[sourceId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 39 | `src/app/tenant/[tenantId]/attendance/sources/new/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 40 | `src/app/tenant/[tenantId]/attendance/sources/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 41 | `src/app/tenant/[tenantId]/attendance/unassigned/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 42 | `src/app/tenant/[tenantId]/branding/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 43 | `src/app/tenant/[tenantId]/entities-sites/[entityId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 44 | `src/app/tenant/[tenantId]/entities-sites/[entityId]/sites/new/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 45 | `src/app/tenant/[tenantId]/entities-sites/new/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 46 | `src/app/tenant/[tenantId]/entities-sites/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 47 | `src/app/tenant/[tenantId]/leave/balances/[accountId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 48 | `src/app/tenant/[tenantId]/leave/balances/annual/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 49 | `src/app/tenant/[tenantId]/leave/balances/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 50 | `src/app/tenant/[tenantId]/leave/new/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 51 | `src/app/tenant/[tenantId]/leave/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 52 | `src/app/tenant/[tenantId]/leave/requests/[requestId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 53 | `src/app/tenant/[tenantId]/leave/settings/[employerId]/calendars/[calendarId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 54 | `src/app/tenant/[tenantId]/leave/settings/[employerId]/calendars/new/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 55 | `src/app/tenant/[tenantId]/leave/settings/[employerId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 56 | `src/app/tenant/[tenantId]/leave/settings/[employerId]/types/[typeId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 57 | `src/app/tenant/[tenantId]/leave/settings/[employerId]/types/new/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 58 | `src/app/tenant/[tenantId]/leave/settings/[employerId]/year-periods/new/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 59 | `src/app/tenant/[tenantId]/leave/settings/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 60 | `src/app/tenant/[tenantId]/me/attendance/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 61 | `src/app/tenant/[tenantId]/me/leave/[requestId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 62 | `src/app/tenant/[tenantId]/me/leave/new/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 63 | `src/app/tenant/[tenantId]/me/leave/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 64 | `src/app/tenant/[tenantId]/me/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 65 | `src/app/tenant/[tenantId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 66 | `src/app/tenant/[tenantId]/payroll/advances/page.tsx` | YES | Selected entry/render/return-state source excerpts | F3: same empty-state copy for first use, search and cursor exhaustion |
| 67 | `src/app/tenant/[tenantId]/payroll/corrections/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 68 | `src/app/tenant/[tenantId]/payroll/inputs/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 69 | `src/app/tenant/[tenantId]/payroll/output/page.tsx` | YES | Selected entry/render/return-state source excerpts | Fixed in UI batch: read-only save warning |
| 70 | `src/app/tenant/[tenantId]/payroll/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 71 | `src/app/tenant/[tenantId]/payroll/payments/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 72 | `src/app/tenant/[tenantId]/payroll/reports/page.tsx` | YES | Selected entry/render/return-state source excerpts | Fixed in UI batch: read-only save warning; branch/department search examples |
| 73 | `src/app/tenant/[tenantId]/payroll/runs/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 74 | `src/app/tenant/[tenantId]/payroll/setup/configuration/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 75 | `src/app/tenant/[tenantId]/payroll/setup/employee/page.tsx` | YES | Selected entry/render/return-state source excerpts | F2: unauthenticated redirect discards task query, unlike sibling routes |
| 76 | `src/app/tenant/[tenantId]/payroll/setup/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 77 | `src/app/tenant/[tenantId]/people/[employeeId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 78 | `src/app/tenant/[tenantId]/people/import/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 79 | `src/app/tenant/[tenantId]/people/new/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 80 | `src/app/tenant/[tenantId]/people/organization/[kind]/[recordId]/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 81 | `src/app/tenant/[tenantId]/people/organization/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 82 | `src/app/tenant/[tenantId]/people/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 83 | `src/app/tenant/[tenantId]/people/work-policies/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 84 | `src/app/tenant/[tenantId]/settings/page.tsx` | YES | Expanded route-source review | No additional concrete issue established in sampled source |
| 85 | `src/app/tenant/[tenantId]/users/invite/page.tsx` | YES | Selected entry/render/return-state source excerpts | F4: login next omits employee/profile return query; broader context handling needed |
| 86 | `src/app/tenant/[tenantId]/users/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |
| 87 | `src/app/tenant/select/page.tsx` | YES | Selected entry/render/return-state source excerpts | No additional concrete issue established in sampled source |

## Follow-up findings (not implemented in the seven-file batch)

F1. Employee activation callback lines 13-17: if valid=false and no state, default says to verify email and continue setting the password, while confirm form is hidden. Safe copy: "رابط التفعيل غير مكتمل. افتح أحدث رسالة وصلتك أو اطلب من الموارد البشرية إعادة إرساله." No auth or token behavior change.

F2. Payroll setup employee line 17 redirects to /auth/login without next. Preserve the same validated employer/period/employee/task query in next so login resumes the exact task. This requires checking existing query shape/allowlist; do not invent a separate destination or pick another employee.

F3. Advance list line 68 uses "لا توجد سلف مطابقة لهذا البحث." even on the empty first visit. Recommended source branches: after cursor => "لا توجد سلف إضافية في هذه الصفحة." plus link resetting after only; nonempty q => "لا توجد سلف تطابق البحث." plus link clearing q and after; first visit => "لا توجد سلف مسجلة لهذه الجهة بعد." The existing permission/entitlement-gated new advance control already supplies the next action; do not duplicate it.

F4. users/invite line 24 keeps only route path in login next, while normal rendered back link supports employee/profile return. Lost context if session expires. Reported separately; no auth behavior change in this UI batch.

## Preserved or deferred

LeaveWorkspaceTabs retained: requests and settings read can_view, balances can_view || can_adjust. No evidence that manager-only filtering is correct; it could hide legitimate read access.

MappingForm explicit UTC input is a genuine source complexity but not a cosmetic patch: local time conversion and ambiguous/nonexistent DST time rules require a scoped behavior contract. Deferred as requested.

Mobile wide tables and quick-navigation priority need rendered responsive/role evidence before altering columns or task priority. Source overflow rules alone do not establish failed usability.

All 87 runtime statuses: NOT RUN by this audit. Full nested component/form/state partition coverage: NOT CLAIMED.
