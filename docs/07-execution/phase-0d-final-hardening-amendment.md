# Phase 0D Final Hardening Amendment — Pre-Implementation Closure

## Purpose

This amendment records the final planning corrections identified during external architecture review before implementation begins.

The objective is alignment and clarity, not changing the platform direction.

## Accepted architecture

The following remain approved:

- Multi-tenant SaaS platform.
- Modular monolith.
- Platform Core independent from business domains.
- HR as first business domain, not platform root.
- Cube-based implementation.

## Final corrections

### Specification lifecycle consistency

Implementation authority requires matching lifecycle status across indexes, specs and execution documents. No Cube starts against a non-approved specification.

### Cube 0 expansion

Cube 0 includes the complete reusable foundation:

- Tenant and isolation.
- Legal Entity foundation.
- Sites.
- Tenant Branding foundation.
- Users and Memberships.
- Invitations and recovery.
- Roles and Permissions foundation.
- Entitlements and Limits.
- Operator control-plane foundation.
- Audit.
- Versioning primitives.
- Application shell.
- Design system.
- Responsive experience foundation.

### Authorization V1 boundary

V1 supports:

- Roles.
- Permissions.
- Tenant-scoped access.
- Custom roles where required.
- Audited permission changes.

Direct per-user overrides remain a future extension unless a confirmed V1 requirement requires them. The architecture must not prevent later addition.

### Branding and Legal Entity identity

Tenant Branding is a platform capability. Official documents must distinguish Tenant identity from Employer Legal Entity identity.

### People and Attendance boundary

People owns employee and employment context. Attendance owns time interpretation and calculation rules.

### Payroll Calendar

Payroll periods are organization-configurable and are not assumed to equal calendar months. Cutoff changes must not silently rewrite finalized history.

### UX baseline

V1 establishes:

- Arabic-first readiness.
- RTL-compatible design.
- Consistent date/number/currency handling.
- Mobile, tablet and desktop acceptance.

A full localization framework is deferred until needed.

## Implementation rule

Build complete bounded capabilities with the minimum necessary complexity.

Do not add enterprise complexity without a real requirement.
