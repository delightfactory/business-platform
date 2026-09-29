# Platform Operator bootstrap and recovery

These commands are for a controlled maintenance runner. They are not application routes and are never callable with a browser key or `service_role`.

The runner must inject `PLATFORM_OPERATOR_MAINTENANCE_DATABASE_URL` from a secret store. It must connect directly as the Supabase `postgres` maintenance database role. The script reads the URL from the environment, never writes it to a file, and suppresses connection details in errors. Do not place it in `.env`, source control, tenant data, or a command argument.

Bootstrap once, for an already existing, enabled Auth user with a verified email and usable password credential. An invited Auth user must first complete password setup through the application so its password-readiness record exists:

```powershell
npm run operator:bootstrap -- <auth-user-uuid>
```

After the successful first grant, remove the secret injection from the runner and rotate or disable that bootstrap access. Treat subsequent recovery as an explicitly scheduled break-glass operation.

Recovery always requires a reason. It is allowed when no recoverable active manager remains. If a recoverable active manager still exists, an emergency must be explicitly declared and explained:

```powershell
npm run operator:recover -- <auth-user-uuid> --reason "<operational reason>"
npm run operator:recover -- <auth-user-uuid> --reason "<emergency reason>" --emergency
```

Each command makes one database call to a private, non-Data-API function. That function commits the current authority grant and its mandatory append-only audit event in the same PostgreSQL transaction. A failure returns an error and commits neither. The audit actor is recorded as `platform_bootstrap`, not as an infrastructure/database role.

For local integration qualification, run `npm run test:db:operator` after `supabase start`. This uses the project-local ports 55320–55329 to avoid the default Supabase ports used by other local projects.

## Review sensitive audit events

Audit history is not a general Operator or Tenant action screen: the ability to change a setting does not grant permission to browse every audit record. A controlled maintenance runner can retrieve a bounded, read-only summary for an incident or qualification check:

```powershell
npm run operator:audit -- --tenant <tenant-uuid> --limit 50
npm run operator:audit -- --platform --limit 50
```

Inject `PLATFORM_OPERATOR_MAINTENANCE_DATABASE_URL` through the same controlled secret mechanism used above. The command requires the `postgres` maintenance role, opens a read-only transaction, and returns at most 100 recent records as JSON lines. `--tenant` includes onboarding, Membership, lifecycle, Legal Entity/Site, commercial Limit, Entitlement, and branding events for one Tenant. `--platform` includes Operator authority and first-Admin invitation events. Invitation events before acceptance have no Tenant ID; the invitation ID remains available for correlation.

The summary includes event ID, category/action, actor class and ID, target ID, outcome, timestamp, and an entered reason where present. It deliberately omits raw before/after payloads, emails, names, and storage paths. **Treat output as sensitive:** free-text reasons may themselves contain personal data. Send the output only to the authorized incident record and remove local copies according to the environment's retention policy. This command cannot edit audit history.
