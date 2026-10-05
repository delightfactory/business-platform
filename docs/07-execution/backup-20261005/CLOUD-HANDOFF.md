# Cloud continuation handoff — 2026-10-05

This is a preservation snapshot, not a merge, deployment or new qualification.

## Recommended source

Branch: codex/backup-20261005/cube5-adam-ui-closure-next
Accepted Cube5 source: 3a310d25c91a84eda52a47cf0491c5a235933a31
Accepted source tree: 1c06640dbbc0b3975c2cc8eff2cfe12345da66ea
Cube4 ancestor: ed26e49a9b1b577952a484bc55083bb6c41fb25e
The backup tip adds only preservation metadata, reviewed agent instructions, sanitized acceptance evidence and branch-scoped deployment suppression. Original accepted commits retain their SHA and tree.

Cube4-only branch: codex/backup-20261005/cube4-adam-closure
Cube5 prior candidate: codex/backup-20261005/cube5-adam-channels-mobile
Older Cube4 core: codex/backup-20261005/cube4-payroll-core
See branches.json for all preserved divergent histories and unqualified WIP snapshots. Keep WIP branches separate; they were not merged or retested and may contain incomplete dependencies, stale QA URLs or migration alternatives.

## Local setup in a fresh clone

Requirements: Node.js 24, npm, Supabase CLI, Docker Desktop. Obtain environment values securely outside chats and Git. Use a disposable local Supabase project, never a production target.

```powershell
git clone --branch codex/backup-20261005/cube5-adam-ui-closure-next https://github.com/delightfactory/business-platform.git business-platform
cd business-platform
git rev-parse HEAD
git merge-base --is-ancestor 3a310d25c91a84eda52a47cf0491c5a235933a31 HEAD
git rev-parse '3a310d25c91a84eda52a47cf0491c5a235933a31^{tree}'
npm ci
Copy-Item .env.example .env.local
supabase start
supabase migration up --local
# Fill .env.local securely using local Supabase configuration.
npm run dev
```

App: http://localhost:3000; local Supabase API: http://127.0.0.1:55321; Mailpit: http://127.0.0.1:55324. Keep the Auth site URL and redirect allowlist consistent with the local app. Public signup is disabled. A fresh database does not include the retired QA accounts/data: follow supabase/maintenance/README.md for local operator setup with a newly created verified test identity. No database reset is needed on an existing database; do not point commands at production.

Application environment variable names (no values): NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, NEXT_PUBLIC_APP_URL, SUPABASE_SECRET_KEY. The last key is server-only. Additional CLI/maintenance variable names are documented in supabase/maintenance/README.md; they are not client configuration.

## Verification status and acceptance limits

This backup task performed repository/tree/ancestry identity, file review, candidate/history secret checks and Git connectivity checks; no heavy tests were rerun. Existing evidence is tied to its original source SHA, not automatically to unrelated WIP.

Cube5 local QA on the accepted source: new build passed, 15 read-contract SQL checks, 12 retention SQL checks, 5 bundle-limit SQL checks, 19 synthetic journey result artifacts, sampled RTL widths 390/820/1440. Prior lint/typecheck evidence references the same unchanged source. See cube5-local/report-to-adam.md and sanitized manifest.

Open: real phone/browser and biometric connector/device qualification, approved location/privacy/retention policy, monitored production purge scheduling, real pilot, and Cube4 financial/legal acceptance. No claim of complete Cube5 closure or production readiness. Temporary QA access was revoked and owned services closed; shared PostgreSQL and QA data were preserved.

## Automation and local-only material

All inspected CI files (including current remote main) contain only a pull_request trigger. No PR is opened. Backup messages include [skip ci]. The vercel.json map disables Git deployments for the exact backup branch names only, leaving unspecified branches at their default. No repository, machine or Vercel project setting was changed.

See local-only.json: environment values, local databases, raw QA row snapshots/screenshots/request logs, temporary benchmark files and root helper/runtime artifacts remain on the laptop. These are not required to install project source, but a new synthetic QA fixture must be provisioned to rerun UI qualification.
