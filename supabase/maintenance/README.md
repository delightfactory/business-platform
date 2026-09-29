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
