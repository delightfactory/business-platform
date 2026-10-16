# Release qualification checkpoint

Source and guide build PASSED: npm run build (Next16.3.6/webpack, TypeScript, all routes including settings). Changed-source ESLint PASSED; final six UI amendments also linted; git diff --check PASSED. Browser started the built server on owned loopback61194 and loaded authenticated attendance/calendar and settings successfully. It retains the selected day15October; settings exposes actual payrollsetup. No dev compiler is serving this verification.

Official Claude final PASS: session9b0c5f11-798e-4d0e-93d6-1560b3d4e771, first-party claude-opus-5-5, medium, read-only. Known late bounded copy/disclosure improvements were checked by parent through lint/build/UI; no third review loop. Detailed evidence and explicit limits in QUALIFICATION.md and CLAUDE-FINAL.md.

Production stage/deployment identity, additive RPC migration verification, promotion and live browser proof will be appended after actual release. The goal remains active until release and scoped cleanup finish.

Rollback frontend: preserve existing production deploymentdpl_CHVLjiVVuuuUhpZPbHYHaArsm7zv. The new functions are additive and can remain during frontend rollback; preserve command receipts/history. Never delete operational rows to undo a release. No rollback performed.
## Runtime patch before promotion

The first staged deploymentdpl_BFwYZgTzCqwZBsKmXHUpbLwXoRXh reached READY but was not promoted. Its install output exposed pre-existing dependency advisories. A bounded follow-up changes next16.3.6→16.3.8 and matching eslint-config-next, plus source-map-js1.2.1→1.2.2 in the lockfile. Only matching Next/env/SWC/lint packages and source-map-js changed; no feature code or unrelated major upgrades. Maintainer advisory https://github.com/vercel/next.js/security/advisories/GHSA-cjq9-62q9-8jv4 and registry audit were checked. No remotePatterns, draftMode/use-cache or tenant SSG features were added.

After patch: npm audit --omit=dev reports0 vulnerabilities; the full audit still reports5 development-tool findings and is not represented as clean. No npm audit fix --force was used. Rebuild on Next16.3.8 PASSED including TypeScript and routes; representative source ESLint with matching lint package PASSED. The owner Free plan and production data remain unchanged. Actual UI on the patched built server is checked before the new stage is promoted.

Production additive migrations succeeded: edara_payroll_record_workspace_20261016 at20261016180204 and employee_activity_workspace_20261016 at20261016180208. Three function hashes match the tested local definitions exactly: payroll_create_run ad89c805c0775898baa3ec47d4836e10; payroll_run_collection 9f91860877b7c8f42d637aa1b09ca824; people_employee_activity a823156e8a6b3ec2f726523401e35ebf. All SECURITY DEFINER with emptysearch_path; authenticated execute granted, anon/service_role execute denied. No operational row mutation by either migration.