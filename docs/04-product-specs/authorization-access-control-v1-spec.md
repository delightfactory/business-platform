# Authorization & Access Control V1 Specification

## Status

**Frozen — final documentation alignment approved 2026-09-29.**

This is a cross-domain V1 application contract subordinate to the Frozen Platform Foundation Specification and Accepted ADR-004 and ADR-008. It does not replace their Operator bootstrap, protected-administrator, audit, Tenant lifecycle, or authoritative-access rules.

## Purpose

Define the authorization model used by the Business Platform so all domains consume one consistent access model.

## Principles

- Authorization is enforced below the UI.
- Tenant context is authoritative.
- Permissions describe allowed actions.
- Roles are reusable permission bundles.
- Domain modules do not create independent authorization systems.

## V1 model

Hierarchy:

User
→ Tenant Membership
→ Tenant Role assignments
→ Permissions

Optional customization:

- Tenant-owned custom roles may compose known business Permission keys when a confirmed V1 workflow needs them.
- Advanced self-service role editing is not a default Cube 0 requirement; default role templates cover ordinary onboarding.
- Role-template revisions cannot silently change an existing Tenant's effective authority.
- Role and Permission assignment changes are sensitive audited operations.

## V1 scope

Supported:

- Stable Platform and Domain Permission keys with unknown keys denied.
- Tenant-scoped role templates and role assignments on active Memberships.
- Bounded Tenant custom roles only where a confirmed V1 workflow requires them.
- Membership, invitation, and protected last-administrator lifecycles governed by the Platform Foundation Specification.
- A separately governed Platform Operator authority, never created by Tenant roles.
- Audit of access changes and protected transactional consistency where required.

Domain owners define their business Permission keys and any resource scope needed by the workflow. They consume the shared authoritative access contract rather than creating a second role system.

Deferred unless proven necessary:

- Attribute based access control.
- Generic policy language.
- Complex permission inheritance trees.
- Enterprise approval workflows for every permission change.
- Direct per-user Permission grants or denies without a separately accepted V1 case.

## Security rules

- UI visibility is not authorization.
- Current active Membership, explicit Tenant context, Tenant lifecycle state, Permission, Entitlement, resource scope, and operation preconditions are checked at the authoritative path defined by ADR-008.
- A role in Tenant A never grants authority in Tenant B; inactive Membership and unknown Permission fail closed.
- Direct Data API access cannot bypass the application's Permission or Entitlement denial.
- Tenant role management cannot grant or revoke Platform Operator authority; Operator access uses ADR-004's separate grant and bootstrap/recovery path.
- Sensitive changes require the mandatory audit and consistency boundary in ADR-005.

## Cube 0 acceptance

- Default Tenant Owner/Admin and Member templates support onboarding without forcing custom-role setup.
- Two-Tenant, inactive-Membership, unknown-Permission, and direct-access bypass tests prove authoritative denial.
- Role changes do not silently alter other Tenants or centrally update existing Tenant authority.
- Removing or demoting the last recoverable Tenant administrator is denied until replacement authority exists.
- Tenant roles cannot manufacture Platform Operator authority; Operator bootstrap and recovery retain the ADR-004 tests.
- If a bounded custom-role workflow is activated for V1, its creator, assignable Permission set, change audit, and safe edit/revoke behavior are specified and tested before that workflow ships.

## Design goal

Provide enough flexibility for real companies while keeping administration understandable and avoiding unnecessary IAM complexity in V1.
