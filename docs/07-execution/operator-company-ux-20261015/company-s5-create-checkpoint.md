# S5 first verified slice: employee creation and uncertain outcomes

S5 remains open. This coherent slice covers its employee-creation path; it does not replace EmployeeReadiness, account choices/self-service, policy presentation, decimal display, tab/return context, limited roles or final Company acceptance.

The server render proposes E- plus six characters from23456789ABCDEFGHJKMNPQRSTUVWXYZ once. It is visible/editable and persists in the action state across failures. Focus starts on the employee name. Existing employer/site/start/pay-basis defaults and atomic create_people_employee contract remain unchanged.

An interrupted, malformed or unclassified creation result keeps the submitted data/code and offers a code-filtered directory link before another attempt. A duplicate of that same code following an uncertain attempt warns that the first request may already have succeeded. An ordinary duplicate or a deliberately changed code retains the normal duplicate guidance. There is no automatic retry or regeneration, and no blanket assertion that an unknown result saved nothing.

Evidence:

- Four focused tests PASS against the actual server action and server-client helper at the SDK boundary: unknown→same-code collision, malformed/unclassified outcomes, ordinary/changed-code duplicates, validated confirmed creation. Decimal amount remains a string in the RPC payload. These are simulated transport outcomes, not browser network fault injection.
- Focused lint, TypeScript, whitespace checks and one coherent build PASS (1866 terminal exit0).
- Actual existing administrator Auth on Company05: proposed code E-4N632F, employer/site/current date already selected; filled name and amount, explicitly excluded this synthetic employee from payroll, submitted once and reached its profile. Created employee d1f1a158-1efa-4a78-88d4-910387e6155d. qa/s5-created-employee.json has pending=false. Preserve this fixture for the forthcoming account/self-service journey; do not recreate it blindly.
- Representative company-s5-created-1366.png retained outside Git/OneDrive and visually inspected. Browser tab closed, viewport reset and owned development process stopped before building.

Q-R1 source inspection for the next S5 work: attendance_channel_sources is paginated and exposes site_name rather than site_id or mobile configuration. The detail read exposes site_id but hides config from read-only channel viewers. Name matching or one first page cannot prove another employee's site readiness, and fetching every source/detail would be unbounded. The conditional B3 needs a bounded explicitly authorized read design; do not use the employee's own-only capture snapshot as a shortcut.

S4 supplement: focused branding-upload tests exercise actual server action with rejected storage, lost authority and invalid content. They assert no branding save/no unauthorized upload; real provider/network failure in the browser is not claimed. The unchanged S4 upload code is the source under test.

Storage cleanup owner Codex; reclaimed bytes0. Active dependencies/cache, compact evidence, private fixtures and recovery journals remain needed. No production mutation, merge or deployment. Complete S5-S9 and final independent Claude acceptance remain mandatory.
