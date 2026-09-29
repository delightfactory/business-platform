import pg from "pg";

const { Client } = pg;
const args = process.argv.slice(2);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const usage = "Use --tenant <tenant-uuid> or --platform, optionally with --limit <1-100>.";
const databaseUrl = process.env.PLATFORM_OPERATOR_MAINTENANCE_DATABASE_URL;
let tenantId = null;
let platform = false;
let limit = 50;
let limitSpecified = false;
let invalid = false;

for (let index = 0; index < args.length; index += 1) {
  const option = args[index];
  if (option === "--tenant" && tenantId === null && !platform) {
    tenantId = args[++index];
  } else if (option === "--platform" && !platform && tenantId === null) {
    platform = true;
  } else if (option === "--limit" && !limitSpecified) {
    limitSpecified = true;
    const value = args[++index];
    if (!/^(?:[1-9]|[1-9][0-9]|100)$/.test(value ?? "")) invalid = true;
    else limit = Number(value);
  } else {
    invalid = true;
  }
}

async function main() {
  if (!databaseUrl) {
    console.error("Inject PLATFORM_OPERATOR_MAINTENANCE_DATABASE_URL in the controlled maintenance runner.");
    process.exitCode = 1;
  } else if (invalid || (tenantId === null && !platform) || (tenantId !== null && !uuid.test(tenantId))) {
    console.error(usage);
    process.exitCode = 1;
  } else {
    const client = new Client({ connectionString: databaseUrl, application_name: "platform-audit-review" });
    try {
      await client.connect();
      await client.query("BEGIN READ ONLY");
      const { rows: roleRows } = await client.query("SELECT current_user AS role");
      if (roleRows[0]?.role !== "postgres") throw new Error("maintenance_role_required");
      const { rows } = await client.query(platform ? platformQuery : tenantQuery, platform ? [limit] : [tenantId, limit]);
      for (const row of rows) console.log(JSON.stringify(row));
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK").catch(() => {});
      console.error(error?.message === "maintenance_role_required"
        ? "Audit review requires the controlled postgres maintenance role."
        : `Audit review failed (SQLSTATE ${error?.code ?? "unknown"}); connection details were suppressed.`);
      process.exitCode = 1;
    } finally {
      await client.end().catch(() => {});
    }
  }
}

// Only bounded identifiers, actions, timestamps, and entered reasons leave the database.
// Raw audit details and stored email/name/path fields remain in protected tables.
const tenantQuery = `
  SELECT $1::uuid AS tenant_id, category, action, event_id, actor_class, actor_user_id, subject,
    CASE WHEN action = 'delivery_failed' THEN 'failed' ELSE 'succeeded' END AS outcome,
    reason, occurred_at FROM (
    SELECT 'tenant_onboarding' category, a.event_key action, a.id event_id,
      'platform_operator'::text actor_class, a.actor_user_id, a.subject_user_id::text subject, NULL::text reason, a.created_at occurred_at
    FROM platform_core.audit_events a WHERE a.tenant_id = $1::uuid
    UNION ALL
    SELECT 'membership', a.action, a.id, CASE WHEN a.actor_user_id IS NULL THEN 'system' ELSE 'tenant_user' END, a.actor_user_id,
      COALESCE(a.subject_user_id::text, a.invitation_id::text), NULL::text, a.created_at
    FROM platform_core.tenant_membership_audit_events a WHERE a.tenant_id = $1::uuid
    UNION ALL
    SELECT 'tenant_lifecycle', a.from_state || '_to_' || a.to_state, a.id, 'platform_operator',
      a.actor_user_id, a.tenant_id::text, a.reason, a.created_at
    FROM platform_core.tenant_lifecycle_audit_events a WHERE a.tenant_id = $1::uuid
    UNION ALL
    SELECT a.resource_type, a.action, a.id, 'tenant_user', a.actor_user_id,
      a.resource_id::text, a.reason, a.created_at
    FROM platform_core.tenant_entities_sites_audit_events a WHERE a.tenant_id = $1::uuid
    UNION ALL
    SELECT 'commercial_limit', a.capability_key || ':' || a.limit_key, a.id, 'platform_operator',
      a.actor_user_id, a.tenant_id::text, a.reason, a.created_at
    FROM platform_core.tenant_capability_limit_audit_events a WHERE a.tenant_id = $1::uuid
    UNION ALL
    SELECT 'entitlement', a.capability_key, a.id, 'platform_operator',
      a.actor_user_id, a.tenant_id::text, a.reason, a.created_at
    FROM platform_core.tenant_capability_entitlement_audit_events a WHERE a.tenant_id = $1::uuid
    UNION ALL
    SELECT 'branding', 'updated', a.id, 'tenant_user', a.actor_user_id,
      a.tenant_id::text, a.reason, a.created_at
    FROM platform_core.tenant_branding_audit_events a WHERE a.tenant_id = $1::uuid
  ) events ORDER BY occurred_at DESC, category, event_id DESC LIMIT $2::integer`;

const platformQuery = `
  SELECT tenant_id, category, action, event_id, actor_class, actor_user_id, subject,
    CASE WHEN action = 'delivery_failed' THEN 'failed' ELSE 'succeeded' END AS outcome,
    reason, occurred_at FROM (
    SELECT NULL::uuid AS tenant_id, 'operator_authority' category, a.action, a.id event_id,
      a.actor_class, a.actor_user_id, a.target_user_id::text subject, a.reason, a.created_at occurred_at
    FROM platform_private.platform_operator_audit_events a
    UNION ALL
    SELECT i.tenant_id, 'first_admin_invitation', a.action, a.id, a.actor_class, a.actor_user_id,
      a.invitation_id::text, NULL::text, a.created_at
    FROM platform_core.tenant_admin_invitation_audit a
    JOIN platform_core.tenant_admin_onboarding_intents i ON i.id = a.invitation_id
  ) events ORDER BY occurred_at DESC, category, event_id DESC LIMIT $1::integer`;

await main();
