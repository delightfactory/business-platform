# EDARA workflow transformation — qualification

Source baseline abe7ee93b4753815c30ac7194141739dd1199506; development branch codex/operator-company-ux. Integration and all dependencies/evidence outside OneDrive. Actual EDARA reference boundaries remain in docs/04-product-specs/ux-redesign/edara-experience-direction-20261016.md. No main merge, paid plan change or real bank transfer.

## Result implemented

Company navigation now opens the actual work directly: employees, attendance, leave, payroll, advances and reports. Settings are one separate authorized hub. Shared neutral surfaces, readable Arabic type, record tables, consistent tabs and focused actions replace nested daily-work menus. Existing tenant branding remains editable.

Employees open as a searchable record list. New employee creation has four short stages with auto-generated editable code and review, then opens that employee's record. The profile gathers work, salary, account, attendance, leave, final payroll and advances. Payroll tax/insurance preparation uses the real Egyptian form inside salary; no invented employee insurance facts or previous-income zeros. Its confirmed save returns to the same profile with visible feedback. Financial history only loads when the user opens payroll, avoiding false financial-access audit events. Other tabs stay mounted to retain forms; initial server rendering hides other panels and no-JavaScript navigation remains available.

Attendance uses day/month/review tabs with the selected day retained when opening the month. The actual monthly calendar opens the chosen day's records. Ordinary work-policy assignment is prominent; temporary overrides and history are collapsed. Phone attendance remains the normal setup choice; rare location fields are behind help/advanced details without changing consent or retention decisions. Leave uses requests/balances/settings. Requests retain their decision, return context, balance effect and correction routes, while uncommon closed-payroll options and cancellation/replacement history are collapsed.

Payroll starts with the list of actual saved periods/runs, state, employee count, gross/net and recorded/remaining payment when permitted. New run selects an existing uncalculated/cancelled period or the next period; first setup uses editable dates. A single atomic command creates/generates and calculates, then opens that same run. Employee review is a table with exact repair links and return context. Company deductions and tax/social deductions are separately named using actual returned amounts. Approval and closing retain their independent permissions; payment recording is inside the same run. Advances use a collection and focused record/form. Operator company lists and profile tabs share the record-first pattern.

Unknown outcomes retain their original request journal. Creation only clears it after success or three exact receipt-aware terminal conflicts. Payment copies share a display-only active flag while Web Locks and server receipts remain authoritative. Normal recording displays a busy message, not a spurious recovery failure. Original financial history, published correction identity and recorded external payment semantics are retained.

## Executed evidence

- Navigation10/10: allowed destinations preserved; direct work entries; employer context without forcing an old period.
- New employee activity SQL28/28, dedicated named QA database, ROLLBACK: exact tenant/employee/employment/employer joins, paging and allowed/denied permissions. These read-boundary tests are not financial-calculation certification.
- Atomic payroll SQL24/24, ROLLBACK: create+calculate, saved-period calculation, cancelled restart, replay, no duplicate period/candidate, failed-work rollback and denied scope.
- Actual public financial journey75/75, ROLLBACK: calculation, approval, closing, correction, recorded payment, replay, balances, published successor and original-run selection during an unpublished amendment. No mocked financial issuer replaces the real public commands.
- Browser UI on owned synthetic loopback QA: created employee c99c877d-68e8-43a6-8cb0-3e28d450f209 and opened its profile; saved explicit employee Egyptian setup and verified persistent success. Opened profile overview without final-payroll audit(count0), then clicked payroll once and loaded exact employee history(count1).
- Browser UI actual payroll cycle: selected saved one-day NONLEGAL period, calculated gross168.75, company deductions0, tax/social16.88 and net151.87; approved review; closed; recorded151.87 with remaining0. Corrected that test payment through the UI while retaining the original, then recorded the remaining again. The busy message was verified after the fix, and the final remaining was0. This bounded fixture proves mechanics and navigation; it is not a legal-rate or full-month acceptance statement.
- Browser UI approved existing synthetic leave request911a9170-b40a-4569-a23c-6cad0d45cc74; state becameapproved on the same record with no pending action. No production company records were changed by these fixtures.
- Actual desktop1366 and phone390 views inspected; tablet768 confirmed by DOM dimensions with tab-scoped emulation. Earlier mislabeled duplicate tablet screenshot is not qualification evidence.
- Role-filtered guide source and HTML updated; PDF38pages/A4 generated from the current HTML. First page and payroll setup page22 rendered and visually inspected.
- Official Claude Opus5.5 Medium: first review identified3P2 issues plus one unconfirmed amendment concern. The3were corrected; amendment concern disproved by actual SQL test. Final review PASS in session9b0c5f11-798e-4d0e-93d6-1560b3d4e771. Its exact read limits are in CLAUDE-FINAL.md. Two bounded reviews; no indefinite review loop.

## Scope and release boundary

Current/future payroll is an explicitly preliminary calculation for the complete selected period. The existing engine does not support an independent until-yesterday financial cut-off; no fake net, future attendance or tax figures were added. Missing facts remain actionable and finalization remains governed by actual calculations. The source-level Egyptian settings remain editable. Managed backups remain subject to the owner's Free-plan choice; no paid change occurred.

Some narrow-screen financial tables scroll horizontally. The period/name remains a direct record link. This is an explicit responsive tradeoff, not hidden pagination or a claim that all columns fit390px.

Production preflight: Supabase business-platform-production/msryvzefjdqjcfikerne, eu-west-1, existing latest ledgerpayroll_egypt_guided_setup_20261016. Three new public RPCs absent before release. Dependency definitions/ACLs captured externally in production-preflight-snapshot.json. Both migrations add new functions only; they do not replace existing financial commands or alter operational rows. Vercel correct projectprj_O5OSEuyyJkJZtVW5sRXm7M4XfPaa/teamteam_AYQTvxuQJ1EepKxDVhzjX1ew; old domain deploymentdpl_CHVLjiVVuuuUhpZPbHYHaArsm7zv retained for rollback.

Build, final source lint and staged/live release identity are recorded in RELEASE.md after their actual completion. Do not infer release from this qualification alone.