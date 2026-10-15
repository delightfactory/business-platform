# Commercial limit contract checkpoint

Migration `20261015012244_operator_commercial_limit_editor.sql` implements approved AM-03 / specification section4.2. `set_tenant_capability_limit` accepts a desired limit and expected current revision, with an optional trimmed note. Authority, the shared tenant lock, authority recheck, tenant existence and scheduling/conflict checks precede desired-state reconciliation. Matching current mode/value returns `unchanged`; a different desired value with an outdated revision returns `stale`. Neither appends history. The response reports current usage, over-capacity and the authorized company snapshot.

Existing members/sites are retained when the limit is lowered. Limit changes and audit insertion remain atomic. New rows use `operator_commercial_access:limit_editor` provenance; new audit rows carry `operator_limit_editor`, NULL reason and a separate optional note. Existing callers keep their mandatory reason and the truthful `legacy_rpc_reason` audit default. No historical audit row is updated. Lifecycle, team and statutory reasons remain mandatory.

The maintenance audit report now emits source and optional note separately for commercial and service decisions, with an explicit legacy-source label rather than assuming a human wrote the old reason. Service metadata extraction also works before the later service-audit migration. No runtime audit-read grant is added.

Verification on the owned synthetic QA project only:

- New limit editor pgTAP suite:16 assertions PASS, rolled back. Covers access denial before unchanged, stale/no-op audit behavior, future conflict before unchanged, over-capacity with preserved memberships, optional note separation, legacy mandatory reason and atomic audit failure.
- Existing commercial access pgTAP suite:34 assertions PASS, rolled back, including membership/site creation and reactivation after reduced limits.
- Actual maintenance report SQL executed with legacy and temporary new-source audit rows:PASS; temporary fixture rolled back.
- Security advisors, error level:exit0/no issues. `node --check` audit script and whitespace check PASS.
- Migration applied and recorded once after verification; owned QA revision now `20261015012244`.

This is a backend checkpoint. The new limit editor UI is not implemented yet. Atomic service switches/dependency plans and their audit contract remain open, followed by D3-D7. Entire Operator acceptance and all company-workspace redesign remain open. No merge, production deployment or real-data change occurred.

Storage: reuse owned external dependencies and QA; retain compact SQL evidence and journals. No obsolete large output generated or deletion/reclaimed bytes claimed in this checkpoint.
