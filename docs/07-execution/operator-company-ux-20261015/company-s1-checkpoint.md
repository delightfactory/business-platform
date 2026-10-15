# Company S1: task navigation and resilient workspace frame

Company navigation now uses explicit task order instead of URL length. Attendance precedes attendance administration; payroll overview precedes review, period inputs and setup. Labels use the small shared terms dictionary. Employee-only navigation opens `/me` as «يومي», keeps «إجازاتي» and «سجلي» separate, and places profile details in the account menu. Team members with self service retain team navigation and gain «يومي»/«ملفي» in their account menu. Every business destination still comes from an independent authorized server read.

When branding cannot be read, an authenticated user still receives the teal workspace frame. A successful membership read may supply the name; otherwise it displays «مساحة الشركة». Navigation retains its own permission reads. Sign-in with no usable memberships now checks actual Operator authority: only an active Operator reaches `/operator`; other accounts reach `/tenant/select`. Added a bounded same-company return-path helper for later employee/payroll flows. Employer+period propagation and destination-specific period validation remain the coherent S8 change, not claimed here.

Focused verification:

- Five production-logic tests cover explicit ordering, limited-role area matrix, employee daily/history separation, same-company return escapes/unsafe location syntax, and retained Operator destinations. No network or internal-helper mocks.
- TypeScript and focused ESLint PASS. Initial lint found the Next.js reserved `module` variable name in the test loader; renamed it and reran focused lint successfully.
- One coherent production build PASS (exit0); Git diff whitespace check PASS. No SQL/business calculation changes in this slice, so no repeated financial/database suites.
- Real browser: Company05 admin/team plus self service opens «يومي» through account-menu keyboard navigation. A separate synthetic employee-only account logs in, sees «يومي، إجازاتي، سجلي» at 390px, opens `/me`, and does not see team domains. Real Auth/RPC confirms own employee profile succeeds and team directory returns42501. No physical attendance capture or geolocation requested.
- Real browser: inaccessible synthetic company shows the workspace frame, generic identity, unavailable-state message and company-switch action, without administrative links. Successful membership-name fallback and transport-failure branches were reviewed in source; they are not separately fault-injected browser claims.
- Real browser: a genuine zero-membership/non-Operator account reaches `/tenant/select` with the empty-space message; active manager reaches `/operator`. The existing `outsider` fixture actually has a Company02 membership, so it was correctly not used as zero-membership evidence.
- Operator 1366px navigation compared against retained D1 image: ordering, identity and frame preserved. Directory contents differ because later QA journeys created two more companies; no pixel-identical/full-Operator requalification claim.
- Representative external evidence: `evidence/company-s1-account-1366.png`, `company-s1-employee-390.png`, `company-s1-operator-nav-1366.png`.

QA preparation is scoped to `business-platform-operator-ux-20261015`: added one employee-only identity/Company05 member and employee (code UX-S1-EMP, payroll ineligible), plus one identity with no memberships. Employee creation/linking and work bundles used normal RPCs; membership seed and Auth creation are synthetic fixture preparation. Original admin four-bundle state restored and protected administrator retained after the bounded role-mode check. Private fixture journals and credentials remain outside the repository/sync roots for S2-S9 qualification.

Storage: compacted the completed Company specification stream into41 Read receipts with0 tool errors, preserving result/model/session/effort/source identity and final specification. Exact owned non-reparse stream deletion verified **2,083,357 local bytes** reclaimed and unchanged Git state. Active QA, dependencies/build cache, review source, operation journals and essential before/after images retained. No cloud-quota savings claimed.

Full S2-S9 Company implementation and independent Claude acceptance remain open. No merge, production deployment or real-data mutation.
