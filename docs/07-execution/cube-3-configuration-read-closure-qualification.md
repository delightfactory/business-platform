# Leave HR configuration read closure qualification

The existing configuration snapshot is needed by the UI for members who can manage or approve Leave. Its current `leave.view`-only gate disagrees with the tenant access snapshot, which reports manage/approve as HR visibility. The implementation uses a narrow internal authorization helper for exactly `leave.view`, `leave.manage`, or `leave.approve`, followed by the existing active tenant/member/user check with `new_work=false`. It does not accept `leave_balance.adjust` or self permissions. Historical reads remain available after entitlement closure.

`public.leave_configuration_snapshot(tenant, employer)` retains its existing configuration payload and signature while using the shared narrow HR-read authorization. It requires the employer to belong to that tenant but permits inactive entities for historical reference.

`public.leave_configuration_employers(tenant, query='', after_name=NULL, after_id=NULL, limit=50)` returns `{items, limit, has_more, next_after_name, next_after_id}`. Each item is `{id, display_name, is_active}`. Matching is case-insensitive literal substring search, sorted by `(display_name,id)`. The page limit is 1–100 and query length is capped at 120. The two keyset fields are supplied together. Inactive entities remain visible with their status so the UI can distinguish history from available new-work targets.

`public.leave_configuration_employer(tenant, employer)` returns one exact tenant-scoped `{id, display_name, is_active}` result, including inactive entities; missing or cross-tenant IDs return the same unavailable result. This supports existing records whose employer has since been deactivated.

All three RPCs are authenticated-only, use the same exact HR permission set, and expose no direct legal-entity table privileges. They only read. Existing write RPCs remain responsible for active-employer and entitlement checks before new configuration work.

## Acceptance cases

- `leave.manage` alone and `leave.approve` alone can load the configuration snapshot without `leave.view`.
- Self-only users, anonymous callers, service-role callers, and members trying another tenant are denied.
- 101 matching legal entities are traversable in a 100-item first page plus a one-item terminal page, in deterministic name/id order.
- `%` in a search is matched literally; query and page-size bounds reject invalid requests.
- Inactive employers appear with `is_active=false` in search and exact lookup, while the RPCs provide no mutation path.
- Reads remain authorized after HR entitlements are off because the calls are historical reads; new writes continue to be checked by their existing RPCs.

## Executed local qualification

- Supabase CLI 2.106.0 applied the new migration normally to authoring QA, the fresh application-chain QA, and the preserved source-clone upgrade QA. Each is a loopback-only database; no remote migration was applied.
- `cube3_leave_configuration_read_closure.test.sql`: 23 assertions passed on each of the three QA databases.
- Fresh and source-clone upgrade contain 96 migrations. Final function definitions and ACLs match. Full baseline row digests remain unchanged for 5 employees, 4 employments and 2 employee-user links.
- Evidence: external `slice8-function-data-comparison.json`, per-database pgTAP logs and summaries. Tests ran before this slice commit; only descriptive migration/header documentation changed afterward. No browser qualification of the settings interface is claimed here; that interface is a separate unfinished slice.
- Legal entity display names are bounded to 160 characters by the existing platform schema; the keyset cursor accepts that full bound.