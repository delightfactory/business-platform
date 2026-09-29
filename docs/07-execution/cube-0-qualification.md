# Cube 0 qualification record

## Scope and decision

This record checks the Platform Foundation & Experience Layer against the [Cube execution plan](v1-cube-execution-plan.md) and [final readiness amendment](final-implementation-readiness-amendment.md). The reviewed `main` commit is `df0f658906cc6461aa667dd2a8c977f6918c8258` (2026-09-29). Cube 0 establishes the shared SaaS foundation; HR and Payroll behavior starts in later cubes.

**Engineering decision:** the implemented Cube 0 foundation is ready for the next cube. This is not a production launch approval. Hosted email, domain, backup/restore, and pilot checks belong to release qualification.

## Capability closure

| Contract | Implemented user or Operator path | Qualification evidence |
| --- | --- | --- |
| Tenant onboarding and lifecycle | First-Admin invitation creates a Tenant, default Legal Entity and Site, protected Admin, and initial limits on acceptance. Operator can suspend, archive, restore to suspended, and reactivate with reasons. | `tenant_onboarding`, `tenant_admin_invitations`, and `tenant_lifecycle` database tests; Operator onboarding and lifecycle UI. |
| Tenant isolation and authorization | Database functions and policies scope membership, Entity, Site, branding, and Operator actions. Tenant pages fail closed for a missing or unauthorized Tenant and offer a route back to Tenant selection. | Isolation and negative authority cases in the database suite; browser denial/recovery journey. |
| Users, memberships, invitations, roles | Invite-only Auth; Member invitation, reissue, revocation, acceptance, disable/reactivate; protected Admin promotion and demotion. Custom role infrastructure remains available for a proven domain need; no generic role editor is required in Cube 0. | `tenant_member_invitations`, `tenant_admin_role_governance`, and `platform_operator_authority` tests; Tenant users UI. |
| Legal Entities and Sites | Default creation, naming, activation/deactivation, Site attachment and active Site limit. Legal identity is separate from branding. | `tenant_legal_entities_sites` tests; Tenant Entities/Sites UI. |
| Commercial access | Operator manages effective user/Site limits and `hr.people`/`hr.payroll` entitlement decisions with reasons; missing entitlement denies access. Domain operations must enforce these decisions when those domains are built. | `operator_commercial_access` and `tenant_capability_entitlements` tests; Operator commercial/entitlement UI. |
| Operator authority and recovery | Manager-granted Operator capabilities, separate bootstrap/recovery commands, read-only scoped audit review, and append-only change history. | `platform_operator_management`, `operator_access_rpc`, and `platform_operator_authority` tests; maintenance documentation and local command checks. |
| Tenant experience | Arabic RTL shell with Cairo font, compact mobile navigation, shared success/error feedback, private branding/logo, Tenant switching, and denial recovery. | Browser checks at 360, 768, and 1280 px on representative Operator and Tenant pages; no horizontal overflow observed. |

## Verification run

- On a disposable, clean local Supabase project, all 13 migrations applied and all **447/447 assertions** in the 12 SQL test files passed. This clean project was separate from the populated demo database. The suite covers isolation, authorization denials, audit, limits, lifecycle, invitations, effective dates, and recovery constraints.
- GitHub Actions reported **SUCCESS** for lint, typecheck, and build on PR #28, merged as the reviewed `main` commit above. No database migration changed after the clean SQL run.
- The public demo login and Tenant/Operator routes returned successfully through a temporary HTTPS tunnel. A newly reissued Member invitation generated a public callback URL; that URL returned HTTP 200 with the verification action. The disposable invitation was revoked after the check. This proves the callback page is reachable; it does not claim completed acceptance by a remote phone or production email delivery.
- Representative mobile, tablet, and desktop checks covered Operator navigation, invitation history/form, Tenant users, Entities/Sites, and unauthorized Tenant recovery. The user should still perform a hands-on phone acceptance pass against the current demo before a product sign-off.

## Deliberate boundaries

- The local demo tunnel and its Auth redirect allowlist are temporary environment configuration. A hosted environment needs its own stable public origin, redirect allowlist, invitation templates, and SMTP before real users are invited.
- EGP formatting has no monetary value to display in Cube 0 workflows. Date and numeric presentation are exercised in administration views; monetary formatting must be checked when the first priced or financial workflow is introduced.
- Entitlements in Cube 0 are commercial decisions and audit records. They do not imply that the future People or Payroll domains already exist or are gated.
- This record does not qualify production operations, real customer data, or a final mobile device acceptance. Those checks remain in the release and pilot gates.
