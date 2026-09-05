# Platform Foundation Pre-Merge Hardening Amendment — 2026-09-05

## Status

**Accepted corrective pre-merge amendment.**

This amendment closes the remaining material ambiguities identified by the independent pre-merge review of PR #4 at reviewed HEAD `ad7b9d891445efc2cd6f95aa40df79b5ffd30796`.

It amends, where applicable:

- the Frozen Platform Foundation Specification;
- ADR-003, ADR-004, and ADR-008;
- the Accepted V1 Capability Decomposition and Implementation Waves;
- the earlier 2026-09-05 freeze-review amendment.

Where wording in an older accepted/frozen artifact conflicts with this amendment, this amendment is authoritative until the source artifact is corrected. Product Code is not introduced by this amendment.

---

# 1. Tenant lifecycle is an authoritative access gate

Tenant lifecycle/access state is an independent required condition for every tenant-owned operation. Authentication, Membership, Permission, and Entitlement are insufficient when the Tenant state does not permit the requested operation.

## 1.1 V1 access-state matrix

| Tenant state | Tenant-user business access | Platform Operator access | Allowed lifecycle transitions |
| --- | --- | --- | --- |
| `active` | Normal reads/writes/search/export subject to Membership, Permission, Entitlement, Limit, resource scope, and lifecycle rules | Bounded operator operations with explicit target Tenant and required audit | `active -> suspended`, `active -> archived` |
| `suspended` | No normal tenant-owned business read/write/search/export. A minimal non-sensitive suspension/status/support surface may remain visible, but it must not expose normal business data. | Explicit recovery/support/inspection/export operations only when the Operator capability permits them | `suspended -> active`, `suspended -> archived` |
| `archived` | No tenant-user tenant-owned operations. | Explicit inspect/export/recovery operations only when separately authorized and audited | `archived -> suspended` through explicit restore; normal operation then requires a separate `suspended -> active` reactivation |

Rules:

- tenant state is checked authoritatively on every tenant-owned direct read, direct mutation, command/RPC, export, search/report, file access, and tenant-targeted background/system operation;
- `suspended` or `archived` must never be bypassed merely because Membership, Permission, or Entitlement is otherwise valid;
- archive is non-destructive and preserves identity/history;
- restoring an archived Tenant requires an explicit Platform Operator recovery action, target Tenant, reason, and mandatory success audit;
- V1 restore moves `archived -> suspended`; a separate reactivation action is required to reach `active`;
- the control plane must expose archive and restore/recovery as explicit sensitive operations rather than hidden database edits.

---

# 2. Platform Operator root of trust and bootstrap

Platform Operator authority remains separate from tenant RBAC and infrastructure credentials.

## 2.1 Operator grant model

Wave 1 uses an application-owned `PlatformOperatorGrant` authority record or equivalent authoritative representation.

Rules:

- Platform Operator authority is attached to an authenticated User/principal, not to `service_role` or another database bypass credential;
- Operator management requires the stable Platform permission/capability `platform.operator.manage` or an equivalent accepted key;
- after bootstrap, only an active Platform Operator with operator-management authority may grant/revoke ordinary Platform Operator authority;
- every grant/revoke is mandatory-audited;
- Tenant administrators can never grant/revoke Platform Operator authority;
- losing Tenant Membership has no effect on Platform Operator status and vice versa.

## 2.2 First-operator bootstrap

The first recoverable Platform Operator is established through a **repository-controlled one-time bootstrap/maintenance command**.

Requirements:

- the command is server/maintenance-only and is not exposed as a normal application endpoint;
- it uses a deployment-scoped bootstrap/recovery principal or secret stored outside tenant-controlled data;
- the bootstrap principal is recorded in audit as a distinct actor class such as `platform_bootstrap`; infrastructure credentials may execute the command but are not recorded as the human/product actor;
- the operation creates the first authenticated Operator grant and mandatory success audit atomically where practical;
- the bootstrap credential/path is disabled, rotated, or otherwise made non-routine after successful bootstrap.

## 2.3 Last-operator-manager protection and break-glass recovery

The system must not allow normal Operator grant/revoke operations to remove the final active recoverable Operator with `platform.operator.manage` authority.

A narrow repository-controlled break-glass recovery command may re-establish one Operator manager when no recoverable manager exists or when an explicitly declared emergency requires it.

The break-glass path:

- is not available to tenant users;
- is not a normal control-plane UI action;
- uses separately controlled deployment/recovery authority;
- records a mandatory audit event with reason and target principal;
- does not turn `service_role` into a durable product actor.

No four-eyes approval engine or enterprise IAM subsystem is required in Wave 1.

---

# 3. V1 authentication, invitation, and Membership lifecycle semantics

Wave 1 uses **invite-only email identity** through the accepted Supabase Auth provider. Public self-signup remains disabled.

## 3.1 Authentication

- primary V1 interactive login is email + password;
- email verification is required before an invitation can be accepted into an active Membership;
- password recovery uses the provider's email recovery flow and changes authentication credentials only; it does not change Tenant Membership, roles, Entitlements, or Operator authority;
- a successfully authenticated User still receives no Tenant access without current application-owned Membership/Operator authority.

Additional login methods such as SSO or passwordless may be added later without moving Tenant/RBAC authority into the identity provider.

## 3.2 Invitation semantics

- invitation lifecycle is `pending -> accepted | expired | revoked`;
- Wave 1 invitation validity is **7 days** from issue time;
- at most one claimable pending invitation may exist for the same Tenant + normalized target email at a time;
- reissue revokes the previous pending invitation and creates a new invitation/token with a fresh expiry;
- acceptance requires an authenticated verified User whose normalized verified email matches the invitation target;
- acceptance is idempotent: replaying an already accepted invitation returns the existing accepted outcome and must not create a duplicate Membership;
- accepting one invitation invalidates any obsolete alternative invitation for the same intended Membership target;
- expired or revoked invitations cannot grant access.

## 3.3 Membership semantics

Wave 1 has one persistent Membership identity per User + Tenant relationship.

Runtime access state is:

- `active` — eligible for separately assigned tenant authority;
- `inactive` — grants no tenant access.

"Remove" or "revoke access" is a lifecycle action that makes the Membership inactive and records revocation metadata/history; it is not a destructive deletion of the Membership identity.

Re-inviting a User who has an existing inactive Membership targets that same Membership relationship. Acceptance reactivates it; prior role assignments are **not silently restored**. The authorized invitation/reactivation flow must explicitly establish the current role assignment set while preserving historical role/audit records.

---

# 4. Wave 1 commercial-access source of truth

Wave 1 intentionally does **not** introduce a Subscription, Billing, Invoice, or generic Commercial Agreement subsystem.

The authoritative commercial-access representation is the smallest model needed by PLT-007/PLT-008:

- effective-dated tenant Capability grants/denials;
- effective-dated Capability Limits;
- optional commercial/source reference and reason metadata;
- `valid_from` and optional `valid_until` semantics where access is time-bounded;
- audit/provenance for changes.

Conceptually these may be represented as `TenantCapabilityGrant` / `TenantCapabilityLimit` or equivalent records. Exact table names are implementation detail.

Rules:

- direct effective grants/denials and limits are the Wave 1 source of truth for customer product access;
- an expired `valid_until` means the grant is no longer effective at authoritative evaluation time; no manual Tenant status mutation is required to make the Capability unavailable;
- Tenant lifecycle state is separate from commercial entitlement state;
- package/plan composition may be added later as an input to the same effective-entitlement contract, without changing Domain capability keys;
- negotiated/manual contract information may be stored as a bounded reference/reason, but Wave 1 does not require a full contract/subscription state machine;
- self-service billing/payment/invoices/coupons remain deferred.

Any older wording that requires Wave 1 to "record subscription/contract access state" is amended to mean recording the effective-dated grants/limits and bounded commercial reference above, not building a Subscription entity.

---

# 5. Legal Entity baseline correction

For all Platform Foundation and V1 scope documents:

- `PLT-002` is **Legal Entity identity/lifecycle foundation**;
- Platform Core owns domain-neutral legal/business identity, display, and lifecycle facts only;
- HR/Payroll owns the Employment/Employer relationship and payroll/statutory attributes that reference the shared Legal Entity;
- future Business Domains may reference the same Legal Entity without inheriting HR semantics.

Any older wording that defines Platform Legal Entity itself as the payroll/employment boundary is superseded.

---

# 6. Final pre-merge verification requirements

Before PR #4 is merged, the exact candidate revision must confirm:

- Tenant lifecycle state is present in the ADR-008 authoritative access contract/matrix;
- suspended/archived tenant-user business access fails closed through direct and command paths;
- archive/restore/reactivate semantics are explicit and auditable;
- first Platform Operator bootstrap, operator-management authority, last-manager protection, and break-glass recovery are defined;
- invite-only email/password, verified-email claim, 7-day expiry, reissue, idempotent acceptance, and Membership reactivation semantics are consistent;
- Wave 1 commercial access uses direct effective-dated grants/limits rather than an unimplemented Subscription source of truth;
- PLT-002 and related accepted scope wording are domain-neutral;
- no Product Code, migrations, secrets, or production configuration are introduced by these documentation corrections;
- `main` remains unchanged until the explicit merge decision;
- review threads are clear and PR metadata names the exact final reviewed HEAD.
