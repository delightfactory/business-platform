# Authorization & Access Control V1 Specification

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
→ Roles
→ Permissions

Optional customization:

- Tenant custom roles are supported where required.
- Permission changes are audited.

## V1 scope

Supported:

- Platform roles.
- Tenant roles.
- Permissions.
- Role assignment.
- Membership lifecycle.
- Audit of access changes.

Deferred unless proven necessary:

- Attribute based access control.
- Generic policy language.
- Complex permission inheritance trees.
- Enterprise approval workflows for every permission change.

## Security rules

- UI visibility is not authorization.
- Server-side checks are mandatory.
- Database protection must enforce tenant isolation.
- Sensitive actions require audit evidence.

## Design goal

Provide enough flexibility for real companies while keeping administration understandable and avoiding unnecessary IAM complexity in V1.
