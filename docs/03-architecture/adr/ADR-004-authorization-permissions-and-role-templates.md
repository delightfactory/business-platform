# ADR-004 — Authorization via Permission Catalog and Role Templates

## Status

**Proposed**

## Context

The donor SaaS used useful module/action permission patterns but also accumulated fixed role assumptions and branch-level permission complexity. The new platform must support simple onboarding now while allowing HR and future domains to add authority without changing a universal role enum.

The Foundation also needs explicit root-of-trust rules so that role/membership changes cannot orphan a tenant, silently rewrite existing customer authority, or manufacture Platform Operator access from an ordinary tenant role.

## Decision

Authorization is built from stable business permission keys owned by Platform Core or the relevant domain.

Roles are named bundles/templates of permissions. They are not universal hard-coded business enums that domain logic switches on.

Permission keys must be stable and appropriately namespaced by their owning Platform/Domain authority. Unknown or unrecognized permission keys fail closed.

Wave 1 provides at least:

- Tenant Owner/Admin default template;
- Tenant Member minimal template.

Later domain specs can add HR Officer, Payroll Officer, Manager/Supervisor and other default templates by composing domain permissions.

Site/location restrictions, when later required, are scopes on authority rather than a separate role/permission subsystem.

Direct per-user permission overrides are not a default Wave 1 mechanism and should be added only when a concrete use case justifies their complexity.

## Role-template stability

Default templates accelerate onboarding but must not become a hidden centrally mutable source of authority for existing tenants.

The effective permission set for an existing tenant must not change silently because a centrally supplied default template is edited later.

The implementation must therefore use explicit template versioning, copy-on-provisioning, immutable template revisions, or another model with equivalent non-silent semantics.

Intentional permission changes for existing tenants require an explicit governed migration/change action and appropriate audit where sensitive.

Advanced custom-role UX is not required in Wave 1.

## Protected tenant-administrator semantics

Tenant onboarding must establish at least one protected tenant administrator/owner authority before the tenant is considered successfully operational.

The system must prevent Membership deactivation/removal, role removal/demotion, template migration, or self-removal/self-demotion from leaving an operational tenant with no authorized tenant administrator capable of recovery.

A protected administrator can be replaced, but replacement authority must be established before the final protected administrator is removed.

These semantics concern application administration authority and must never be inferred from HR job titles, employment position, department, or reporting relationships.

## Invitation and Membership authority boundary

A pending invitation does not grant access. Membership access is effective only in an explicit active state and only with separately assigned authority.

Invitation/Membership lifecycle completion semantics are governed by the Platform Foundation Specification and the accepted 2026-09-05 freeze-review amendment; role assignment must not bypass those lifecycle rules.

## Platform Operator authority

Tech Edge Platform Operator authority is a separate Platform authority class and cannot be granted through tenant role assignment.

Rules:

- Platform Operator grants/revocations are governed outside tenant role assignments;
- normal tenant administrators cannot grant, revoke, or manufacture Platform Operator authority;
- granting or revoking Platform Operator authority is a sensitive audited Platform operation;
- Platform Operator status does not imply tenant Membership, and tenant Membership does not imply Platform Operator status;
- infrastructure bypass credentials such as `service_role` are not a product-level Platform Operator identity;
- when a Platform Operator acts on tenant-owned state, the target Tenant is explicit and the operation is bounded by the operator capability being exercised.

Generic user impersonation remains outside V1 unless separately designed and accepted.

## Consequences

- simple customers get useful defaults;
- future tenant-defined roles remain possible without re-platforming;
- domains own their permission semantics;
- branch/site scoping can evolve without duplicating RBAC;
- UI visibility remains secondary to authoritative permission enforcement;
- existing tenant authority cannot drift silently because a shared template changed;
- an operational tenant cannot be accidentally left without a recoverable administrator;
- Platform Operator authority remains structurally separate from customer-controlled RBAC.

## Rejected alternatives

### Fixed `owner/admin/manager/member` enum as business authority

Rejected because future HR and non-HR domains would either overload those meanings or require structural changes.

### Centrally mutable live templates for all existing tenants

Rejected because a template edit could silently change customer authority without an explicit governed action.

### Separate branch role/permission engine

Rejected because it creates competing authorization sources and hard-to-audit precedence.

### Tenant role that can grant Platform Operator authority

Rejected because Platform Operator is a separate trust domain and must not be customer-manufacturable.

### Page/button permission keys

Rejected because presentation structure is not the durable business authority model.
