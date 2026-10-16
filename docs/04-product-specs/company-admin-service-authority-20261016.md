# Company administrator service authority

Status: owner-authorized change, 16 October 2026. The owner explicitly requested automatic operational authority for company administrators whenever a service is made available to their company. This amends the earlier requirement to assign separate operational bundles to every administrator; it does not amend financial validation or statutory issuance requirements.

## Authority

An active verified, non-banned user with an active membership in an active tenant inherits the bounded administrative operations of enabled services only when their assigned role both protects tenant administration and contains tenant.administer. Evaluate inheritance at the existing authoritative permission predicate; do not copy bundles or broaden ordinary-member roles.

Map the five existing services explicitly: People, Attendance, Leave, Payroll and Employee Finance. Preserve capability dependency evaluation. Unsupported permissions fail closed. Self-attendance, personal profile/leave and platform/operator/compliance authority are excluded. Explicit member grants keep their existing semantics.

An expired or disabled service removes inherited operations immediately. The administrator retains the mapped historical read/export authority only when that service has previously been granted with a start date not in the future. This retains access to existing history without allowing new writes. Removal of the protected admin role or membership/account/tenant eligibility removes inheritance, including historical access.

Financial actions still require their existing source validation, current entitlement, canonical calculation, review/approval, immutable history, idempotency and recovery gates. Inheritance supplies authority; it does not declare inputs or rule packs correct, invent another reviewer, execute bank payments or exempt an actor from an existing guard. Existing actor/role/entitlement audit and versioned deployment evidence remain authoritative.

## Experience

The company administrator starts at the company workspace and can enter each available service without requesting a second role. The member screen labels service administration as automatic and distinguishes any explicitly saved additional roles. Removing an additional checkbox does not imply removing administrator inheritance. Employee self-service remains separate and requires the actual employee context.

Operator payroll-rule administration remains an explicit audited task. The operator home exposes where to configure that task instead of silently hiding the existence of payroll rules. An operator without statutory authority cannot enter or modify the protected rules merely because a link is discoverable.

## Qualification

Cover enabled/disabled/re-enabled and parent-dependency transitions; existing and demoted admins; ordinary explicit members; tenant isolation; account/membership/tenant denial; unknown/operator/self permission exclusion; historical read continuity. Reuse actual operator last-manager and admin-governance protections. Do not seed official financial evidence or alter production grants to manufacture acceptance.
