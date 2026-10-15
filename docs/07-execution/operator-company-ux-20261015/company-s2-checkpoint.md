# Company S2: Today and first-use setup guidance

Today now orders attention tasks, the existing personal attendance component plus history link, administrator setup guidance, remaining work and self-service links. The administrator-only guide shows six responsibilities from existing authorized reads: work access, basic entity/site, employee readiness, leave setup, payroll cycle and attendance sources. No invented counts or completion percentage. It hides once all calculable setup checks are done; employee/source readiness still belongs to their dedicated pages.

The existing leave next-step decision was extracted and reused, so the home guide opens the same calendar/year/type step as the leave settings page. Payroll with exactly one authorized employer displays saved-cycle versus missing-cycle facts and carries that employer to the workspace. A saved cycle never claims financial qualification, approval or finalization. Failed reads remain unknown; denied domains name the responsible role. Manual checks use the visible label «راجع الجاهزية» while keeping the unknown state, distinguishing them from transport errors. The generic ReadinessList is small and reusable for employee readiness.

Invitation acceptance keeps its existing validation, password/identity and RPC contracts. Only the successful destination adds joined-admin/joined, with the appropriate Today message. Actual invitation delivery/acceptance combinations remain integrated S3/S9 qualification, not claimed from manually entering a notice query.

Verification on owned synthetic QA:

- Three focused tests PASS against actual readiness/cache/parser code with the SDK transport as the boundary: optional read failure preserves verified facts/unknown states; denied domains hand off without unauthorized action links; leave creation requires enabled editing, and payroll viewer does not acquire setup authority.
- TypeScript, focused lint, Git whitespace check and one coherent production build PASS (build process50215 terminal exit0). No SQL/business calculation changes, so no repeated financial suites.
- Actual Company05 admin Today: authoritative cycle-missing summary with employer link, personal capture-unavailable state, six-step guide and honest leave/payroll role handoffs. No location permission or capture attempt.
- Actual Company06 first-use/default setup with services unavailable: guide remains usable and shows only authorized actions. At390px document client width and scroll width both375px (15px scrollbar), no horizontal overflow.
- Actual employee-only Auth login: personal Today section and own services, no administrator setup guide or team domains.
- Actual suspended Company06: normal Operator lifecycle RPC changed active→suspended with expected-state check; company picker displayed suspension and home showed suspended message with no work/setup data. Immediately restored suspended→active through the same RPC; external journal `qa/s2-company06-lifecycle.json` confirms active/pending=false. Audit history retained.
- Existing zero-space login verified in S1 remains relevant; no entry-contract change here.
- Representative images retained externally: `evidence/company-s2-readiness-1366.png`, `evidence/company-s2-first-use-390.png`. These are staged evidence, not full Company acceptance.

All output remains outside OneDrive. Reclaimed bytes0 in this slice: active dependencies/cache, private QA and operation journals, representative evidence and unresolved Docker repair evidence retained. No obsolete disposable run-owned output identified; no broad cleanup. Temporary browser tab closed and dev listener stopped before build. No merge, production deployment or real-data changes. S3-S9 and independent Company acceptance remain open.
