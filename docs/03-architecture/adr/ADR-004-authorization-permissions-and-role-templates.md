# ADR-004 — Authorization via Permission Catalog and Role Templates

## Status

**Proposed**

## Context

The donor SaaS used useful module/action permission patterns but also accumulated fixed role assumptions and branch-level permission complexity. The new platform must support simple onboarding now while allowing HR and future domains to add authority without changing a universal role enum.

## Decision

Authorization is built from stable business permission keys owned by Platform Core or the relevant domain.

Roles are named bundles/templates of permissions. They are not universal hard-coded business enums that domain logic switches on.

Wave 1 provides at least:

- Tenant Owner/Admin default template;
- Tenant Member minimal template.

Later domain specs can add HR Officer, Payroll Officer, Manager/Supervisor and other default templates by composing domain permissions.

Tech Edge platform-operator authority is a separate authority class and cannot be granted through tenant role assignment.

Site/location restrictions, when later required, are scopes on authority rather than a separate role/permission subsystem.

Direct per-user permission overrides are not a default Wave 1 mechanism and should be added only when a concrete use case justifies their complexity.

## Consequences

- simple customers get useful defaults;
- future tenant-defined roles remain possible without re-platforming;
- domains own their permission semantics;
- branch/site scoping can evolve without duplicating RBAC;
- UI visibility remains secondary to authoritative permission enforcement.

## Rejected alternatives

### Fixed `owner/admin/manager/member` enum as business authority

Rejected because future HR and non-HR domains would either overload those meanings or require structural changes.

### Separate branch role/permission engine

Rejected because it creates competing authorization sources and hard-to-audit precedence.

### Page/button permission keys

Rejected because presentation structure is not the durable business authority model.
