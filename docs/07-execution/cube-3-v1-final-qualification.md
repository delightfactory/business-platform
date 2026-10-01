# Cube 3 V1 — final local qualification

2026-10-01. Cube 3 is technically qualified for the bounded V1 scope on the Cube 3 branch. This consolidates the earlier slice checkpoints and closes their annual-policy and replacement-interface gates. Deployment and production statutory acceptance are separate.

## Completed workflows

| V1 scope | Implementation and qualification |
|---|---|
| Employee own Leave | Linked Employee isolation, balance/history, submission/withdrawal, approved cancellation request; [employee interface](cube-3-employee-leave-interface-qualification.md) and [cancellation interface](cube-3-employee-cancellation-interface-qualification.md) |
| HR Leave | Recording for Employees with or without User accounts, separate approval/rejection, queue, atomic consumption/reversal and linked approved replacement; [audit fixes](cube-3-v1-journey-audit-fixes.md) and [replacement](cube-3-v1-replacement-ui-closure.md) |
| Configuration and balances | Employer calendars, explicit periods, Leave types, non-expiring attributable ledger, openings/grants/adjustments, usable settings and balance interfaces |
| Annual entitlement | Accepted employer calculation policy, automatic cumulative grant/differences, dated HR-verified category changes and bounded company settings, qualified below |
| Half-day and Attendance | Explicit versioned half-day mapping, fractional classification, conservative approved-fact conflicts, and explicit reviewed Time successors with retained evidence; [integration](cube-3-halfday-time-integration-qualification.md), [classified facts](cube-3-classified-attendance-facts.md), [classification interface](cube-3-attendance-classification-ui.md) and [mapping UX](cube-3-v1-journey-audit-fixes.md) |
| Payroll boundary | Approved-only, versioned, read-only facts remain projection_only and unconsumed; [projection](cube-3-payroll-facts-projection-qualification.md) |
| Security and closure | Tenant/Employer/Employee scopes, separate permissions, accountless HR, own-link isolation and disabled-entitlement history/closure without new work or balance growth |

The proposed joint Leave/Time coordinator is not included. The implemented V1 path rejects conflicting replacement/approval, exposes cancellation reconciliation, and lets authorized HR append an explicit Time successor. It never silently rewrites an approved Attendance fact. Earlier engineering notes about a broader atomic coordinator do not expand the Frozen V1 contract into a general correction engine.

## Annual calculation delivered

Migration 20261001220000_cube3_annual_entitlement_calculation adds immutable company-policy versions and calculation receipts. The annual balance journey opens the reviewed calculator. Defaults are 15/21 annual days, eligibility after 180 service days and a 365-day basis. Authorized HR may configure bounded, more favourable values per Tenant + Employer + Leave Type. This is numeric configuration, not a rules engine.

Actual calendar service days are segmented by dated rates. Exact segment numerators are summed before one division; cumulative entitlement rounds upwards to 0.01 day. Only the difference from previously granted cumulative entitlement is posted. Consumption does not lower the entitlement baseline. A single base grant and subsequent adjustments preserve the account and audit history.

The user accepted this employer-policy arithmetic; it is not represented as a complete statutory formula. HR supplies evidence for protected categories rather than inferring age, disability or job classification. See [legal evidence and accepted policy](cube-3-legal-calculation-evidence.md).

## Final verification

- Fresh application replay: 109 repository migrations, excluding the isolated joint-preview draft. Retained-data local upgrade: the same 109-migration history. Annual function definitions, ACLs, table columns/defaults, constraints, indexes and triggers match exactly.
- Full database regression: 58 SQL files / 2,448 assertions passed on each database. The new annual suite contributes 35 assertions per database, including service boundaries, sum-before-rounding, policy CAS, immutable receipts, scope/permission denials, duplicate/replay protection and legacy manual-account refusal.
- The upgrade harness uses a test email namespace and isolates two global Operator grant/audit suites inside their existing BEGIN/ROLLBACK transactions. Initial fixture-pollution failures are retained as evidence; no application fix or persistent fixture deletion was required.
- Real local Auth → browser → Server Action → RPC → database: base grant, dated category difference, company-rule save, stale policy refusal, retained fields, response dropped after committed posting, exact receipt replay, reload recovery and zero-delta/no-extra-ledger confirmed.
- Two simultaneous authenticated HTTP grant commands: one succeeded and one returned a stale-review conflict, with one base grant.
- Failed preview clears the old confirmation. Native browser validation cannot bind an old quote to changed inputs. A renewed preview displays the actual policy snapshot used by the server.
- Phone/tablet/desktop widths 390/820/1280 have no horizontal overflow; phone and desktop screenshots inspected.
- TypeScript, ESLint, production webpack build and independent backend/UI review passed. Review used fresh read-only Codex reviewers; external-provider review remained unavailable due to service capacity errors.

Detailed non-secret gate summaries and synthetic browser evidence are retained outside the repository in the existing Cube 3 run directory: slice30-fresh-application.json, slice30-schema-parity.json, business_platform_cube3_annual_fresh_qa-tests-summary.json, slice30-upgrade-full-suite.json, slice30-annual-browser.json, slice30-preview-error-browser.json and slice30-final-browser.json. Failed attempts are preserved alongside the corrected results. Credentials and runtime configuration are excluded from Git.

## Operational limits

Accounts with a manual opening or manual annual grant stay in manual mode for that period; the calculator provides a direct adjustment link. Automatic accrual starts in a period without those legacy entries. A reduced calculation and multiple Employment records during one period require HR review. Future service is never granted.

Cube 4 monetary calculation, Payroll locks/consumption, full ESS/MSS, broad rules engines and production statutory qualification are outside this local closure. No main merge, deployment or remote database migration is included.
