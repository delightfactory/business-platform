# Cross-cube integrity and scale qualification — 2026-09-30

This record closes the concrete People/Attendance consistency and unbounded-list findings identified after local Cube 2 closure. No remote database migration or production deployment is claimed.

## Changes

| Finding | Implemented closure |
| --- | --- |
| A People assignment or employment end could invalidate a materialized Attendance day | Unique `(tenant_id, employment_id, operational_date)` Work Instance key; trigger guards on Assignment changes and Employment end; shared Employment lock discipline for day opening, CSV confirmation, and attachment of unassigned evidence. |
| A completed Attendance CSV batch blocked a second batch in the same page session | The preview and confirmation state are linked to their attempt, so a new successful preview exposes its own confirmation form. |
| Directory search and tenant/operator lists scaled with their full response size | Tenant-scoped directory search/order indexes; 25-row member, invitation, and operator list RPCs; summary-only read for navigation and invite form; direct lookup for one operator Tenant or invitation. Legacy list RPCs remain for existing callers. |
| Attendance review repeated whole-day enrichment for counts and page | Exact day counts are retained; the ordered page is selected before per-item overtime enrichment. |

The new list RPCs enforce their own authorization. Returned People directory rows still omit compensation. List search remains case-insensitive and uses literal substring semantics. Historical invitations display their effective expired state; the read-only Tenant list no longer writes expiry audits on every navigation. Mutating invitation actions still enforce expiry and audit their transitions. Operator invitation listing expires and audits only the displayed page.

## Verification

- Local Supabase migrations through `20260930162029_operator_listing_pagination.sql` applied without a reset. The live demo database remained at two Tenants and five Employees; synthetic scale rows were never inserted there.
- Six focused People/Attendance database suites passed 258 assertions after the CSV lock-order correction and removal of four source-text assertions. A two-session QA regression verified that CSV confirmation waits on the Employment lock and revalidates a transferred Assignment. Directory search passed 14; Tenant member pagination passed 22; Attendance review scale passed 21; operator list pagination passed 29. Relevant existing invitation, admin-role, lifecycle, and commercial suites passed after their fixture counts were scoped to their own test Tenants.
- `npm run build`, `npm run lint`, and `git diff --check` passed. The tenant Users and Invitations pages rendered with the new counts, search, and bounded list in a local mobile-width browser view on port 3300. Browser-controlled clicks were inconclusive, so this record does not claim click-through acceptance.
- Before merge, the complete local pgTAP suite passed: 33 files and 1,144 assertions. It ran against an isolated clone of the local demo database with only the clone's existing Platform Operator grants cleared, because the one-time bootstrap tests require that starting state. The demo database was unchanged. The compensation-history test now expects the `initial_scheduled` state introduced by the future-hire migration; the UI already distinguishes it from a later scheduled pay change.

## Representative-size read measurement

A disposable local PostgreSQL 17.6 database was restored from the local demo snapshot, then populated with **1,000 Tenants**, **25,000 Employees in one Tenant**, **25,000 Memberships in that Tenant**, and **24,998 Work Instances on one operational day**. No synthetic row was written to the demo database. Four independent `pgbench` sessions used 4 clients, 2 worker threads, and a 10-second warm-cache run per RPC. Each transaction set an authenticated local role and called one RPC. Latencies below are milliseconds for the entire transaction, calculated from the per-transaction `pgbench` log, nearest-rank percentiles.

| RPC workload | Transactions | Failed | p50 | p95 | p99 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Directory substring search, one Tenant | 915 | 0 | 42.63 | 58.64 | 64.30 |
| Member email substring search, one Tenant | 804 | 0 | 46.73 | 72.67 | 87.54 |
| Attendance exceptions for a 24,998-instance day | 580 | 0 | 68.20 | 85.06 | 91.13 |
| Operator lifecycle list, page 40 of 1,000 Tenants | 29,357 | 0 | 1.22 | 1.99 | 2.96 |

The measurements exercise a maximum-sized individual Tenant and a 1,000-Tenant catalog. They do **not** prove throughput for 1,000 simultaneously full 25,000-Employee Tenants (25 million Employees), production network latency, concurrent writes, cold-cache operation, or mobile-device acceptance. A production-sized infrastructure/load test is a release capacity gate if that simultaneous fleet envelope is required; it is not evidence for changing the modular-monolith architecture now. The directory indexes were built while the local demo had five Employees. Applying equivalent indexes to an already large live table would require a planned online index build or a maintenance window.
