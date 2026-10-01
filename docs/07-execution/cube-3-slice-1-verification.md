# Cube 3 Slice 1 — access foundation verification

Date: 2026-10-01. Branch: `codex/cube3-leave-v1`. Parent documentation baseline: `de16ef32a1d3841ab20de93b8c5751282ee68139`.

## Delivered scope

- `hr.leave` entitlement and People dependency, preserving existing entitlement behavior.
- Five narrow Leave role bundles alongside the existing nine bundles; existing role snapshots are unchanged.
- Current-user-only Employee snapshot and Arabic `ملفي` page. The API accepts Tenant identity only, resolves the current link, and returns no salary or sensitive HR fields.
- Protected-admin self-access grant/revoke, preserving administrative roles and auditing changes.

Implementation migration: `supabase/migrations/20261001004629_cube3_leave_access_foundation.sql`. Focused test: `supabase/tests/cube3_leave_access_foundation.test.sql`.

## Actual verification

Local PostgreSQL 17.6, Supabase CLI 2.106.0, Node 24.16.0.

| Check | Result |
|---|---|
| Guarded CLI upgrade of `business_platform_cube3_upgrade_qa`, 82 to 83 migrations | Passed |
| Guarded CLI full application installation into `business_platform_cube3_fresh_qa`, zero to 83 migrations | Passed |
| Own-access focused pgTAP | 44 assertions passed on both QA databases |
| Existing role-bundle pgTAP | 33 assertions passed on both QA databases |
| Existing capability-entitlement pgTAP | 29 assertions passed on both QA databases |
| Application function definitions and ACL comparison | Equal after normalizing Windows/Linux line endings |
| Upgrade employee, employment, current/historical link data | Ordered row-JSON hashes equal to the source QA clone: 5 employees, 4 employments, 2 links |
| `npm run typecheck` and targeted ESLint of affected TS/TSX files | Passed |
| `npm run build -- --webpack` | Passed |
| `git diff --check` | Passed |
| Auth password login → narrow-only own-profile navigation | Passed on isolated QA HTTP runtime |
| Own account directly visits People directory / another Tenant profile | Denied; no employee data returned |
| Desktop 1280px and mobile 390px, Cairo / RTL / no horizontal overflow | Passed; screenshots saved in the run directory |
| Mobile navigation open/close | Passed through actual browser clicks |

The clean installation uses Supabase-managed Auth/Storage/extensions as its framework foundation, with no existing application schemas or migration history. Both databases are isolated local QA targets. Original demo and remote databases were untouched.

Tests exercise authenticated RPCs, missing narrow permissions, cross-Tenant denial, unlink/relink, unconfirmed/banned Auth accounts, inactive membership, suspended Tenant, future/ended employment, disabled entitlements and retained historical access. Privileged fixture/audit assertions run separately from authenticated access tests; no private helper was exposed to make tests pass.

Reproducible test selection: `cube3_leave_access_foundation.test.sql`, `tenant_people_role_bundles_test.sql`, `tenant_capability_entitlements.test.sql`, executed by the guarded local `qa-tests.mjs` harness in the run directory. The harness records HEAD, dirty state, commands and individual results. Post-commit validation records the exact commit.

## Remaining scope

The browser runtime binds to loopback app port 3300 and an isolated Auth/REST gateway on 3303, backed only by the upgrade QA database. A separately recorded synthetic own-profile fixture was added **after** the data-preservation comparison; original source/demo data was not altered. Credentials and baseline/post-fixture manifests are outside Git. Profile rows use scoped compact responsive styling; the shared design system and other pages are unaffected.

This is a tested access slice, **not Cube 3 closure**. Calendar, balance, request/approval/cancellation/correction, Attendance integration, Payroll projection and their UX are subsequent slices. Complete Leave-journey browser qualification remains outstanding; physical phone/tablet acceptance is deferred by the owner. The broad final regression suite will run on the complete Cube 3 candidate.
