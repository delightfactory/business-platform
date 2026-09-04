# Security Baseline

## Purpose

Define minimum security expectations that cannot be traded away for delivery speed.

## Tenant isolation

- Tenant-owned data must be scoped by authoritative tenant context.
- UI filtering is never an isolation mechanism.
- Cross-tenant negative tests are required for tenant-sensitive critical paths.

## Authentication and authorization

- Authentication establishes identity; authorization establishes permitted action.
- Authorization must be enforced at an authoritative server/database boundary appropriate to the operation.
- Entitlement checks do not replace authorization checks, and authorization does not replace entitlement checks.

## Secrets

- No credentials, tokens, service-role keys, production secrets, or private customer data may be committed.
- Public repository status must be assumed when writing documentation, examples, fixtures, and configuration.

## Sensitive data

- Collect only data needed for active product functions.
- Location and biometric-related information requires explicit minimization and stronger handling.
- Logs and audit records must avoid unnecessary exposure of sensitive payloads.

## Sensitive operations

High-impact actions such as payroll finalization, permission changes, tenant administration, destructive operations, and security configuration should have explicit authorization, validation, and auditability.

## Secure-by-default behavior

When access state is uncertain, sensitive operations should fail closed rather than infer access from client state.

## Security changes

Security-sensitive changes require targeted regression evidence and must not be merged solely because general application tests pass.
