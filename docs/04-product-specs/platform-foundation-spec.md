# Platform Foundation Specification

## Status

**Proposed — Phase 0D implementation-readiness draft.**

This specification governs the minimum shared SaaS foundation required before tenant-owned HR Product Code is implemented. It defines product/behavioral invariants, ownership boundaries, and acceptance criteria without freezing the technology stack or physical database schema.

## Governing inputs

- Accepted Product Charter and Product Principles.
- Accepted Master Product Blueprint.
- Accepted V1 Capability Decomposition.
- Accepted V1 Implementation Waves.
- Completed Edara SaaS Extraction Audit.
- Architecture Principles, Security Baseline, Data Classification/Privacy baseline, Definition of Ready, and Definition of Done.

## Scope

This specification covers Wave 1 capabilities:

- PLT-001 Tenant/customer account.
- PLT-002 Employer/legal entity.
- PLT-003 Sites/branches.
- PLT-004 Authentication boundary.
- PLT-005 Membership + explicit tenant context.
- PLT-006 Authorization foundation.
- PLT-007 Capability catalog, entitlements and limits.
- PLT-008 Minimum Tech Edge control plane.
- PLT-009 Sensitive-operation audit foundation.
- PLT-010 Minimum versioned configuration primitives needed by downstream domains.

## Explicit non-goals

Wave 1 must not expand into:

- public self-signup;
- payment gateways, coupon engines, or self-service billing;
- a generic workflow/BPM engine;
- a generic dynamic-form engine;
- broad customer-facing API/webhook products;
- full document management;
- broad notification/inbox platform;
- HR business rules or HR data models;
- native mobile applications;
- microservices or event-bus infrastructure without demonstrated need.

---

# 1. Core organization model

## 1.1 Tenant

A **Tenant** is the top-level customer isolation and commercial-access boundary.

A tenant owns or scopes all tenant-specific platform and domain data. Tenant identity must be explicit on every persistent tenant-owned aggregate or be derivable through an enforced, unambiguous ownership relationship.

A tenant must have at minimum:

- immutable system identity;
- human-readable display name;
- lifecycle/access status;
- creation metadata;
- commercial/entitlement association;
- audit identity for sensitive administrative changes.

### Tenant lifecycle states

V1 platform access states are:

- `active` — normal tenant access subject to permissions and entitlements;
- `suspended` — normal tenant business operations are denied; tenant data is preserved, while Tech Edge control-plane and explicitly allowed recovery/administrative operations remain available;
- `archived` — normal tenant business operations are denied and the tenant is no longer treated as operationally active; data remains preserved according to retention policy and cannot be silently reused as a new tenant.

A separate commercial contract/subscription status may later have more detailed states. Tenant lifecycle and commercial billing concepts must not be collapsed into one field merely for convenience.

Deletion of a tenant is not a normal V1 product workflow.

## 1.2 Employer / legal entity

An **Employer / Legal Entity** represents the legal employment/payroll boundary inside a tenant.

Rules:

- a tenant may own one or more legal entities;
- V1 onboarding may default to creating one legal entity for simple customers;
- the model must not permanently assume one tenant equals one legal entity;
- payroll/employment records must ultimately identify their legal employer;
- legal entities may be independently active/inactive without deleting historical payroll context.

Minimum legal-entity facts required by Platform Core are identity/display facts only. Statutory/payroll-specific facts belong to the owning Payroll/Compliance specification.

## 1.3 Site / branch / operating location

A **Site** is a domain-neutral physical or operating location associated with a tenant and, where applicable, a legal entity.

Rules:

- sites are reusable by HR and future domains;
- a one-site tenant must remain simple in UX;
- site identity must not create a second role/permission system;
- future domain scopes may reference sites through the shared Platform identity;
- deactivating a site preserves historical references;
- site limits, when commercially enforced, are Entitlement limits rather than package-name conditions.

---

# 2. Identity, authentication, membership, and tenant context

## 2.1 User identity

A **User** represents an authenticated human account.

User identity is platform identity and is not the same as an Employee record. An Employee may exist without a User account.

Authentication provider mechanics are selected by a later technology ADR, but the application must consume a stable authenticated user identity and must not trust client-provided role/tenant claims as sole authority.

## 2.2 Tenant membership

A **Membership** links a User to a Tenant and carries tenant-scoped access metadata.

Required semantics:

- one user may belong to multiple tenants;
- membership has an explicit active/inactive state;
- inactive membership grants no tenant access;
- membership removal/deactivation does not delete user identity or historical audit references;
- membership operations are auditable;
- tenant access is denied unless an active membership or a separately governed platform-operator authority exists.

## 2.3 Explicit tenant context

Every tenant-scoped interactive/request operation must execute against an explicit tenant context.

Rules:

- no `first tenant`, `LIMIT 1`, last-row, or hidden fallback may establish authorization scope;
- a remembered tenant selection may improve UX but never creates authorization;
- the server/authoritative layer must validate that the current user is allowed to operate in the supplied/resolved tenant context;
- switching tenant context must invalidate/reload tenant-scoped cached state;
- tenant context must be available to authorization, entitlement, audit, and data-access enforcement;
- platform-operator flows that act on a tenant must record the target tenant explicitly.

For users with exactly one active membership, the UX may auto-select that tenant, but the authoritative operation still resolves and validates a concrete tenant ID.

---

# 3. Tenant isolation

Tenant isolation is a Foundation Obligation, not an optional feature.

## 3.1 Isolation invariant

A tenant user must never read, create, update, delete, execute, export, or infer tenant-owned data belonging to another tenant through supported application/data access paths unless an explicitly authorized platform-operator workflow exists.

## 3.2 Enforcement requirements

- authoritative enforcement must exist below presentation/UI visibility;
- tenant scoping must apply to direct reads, mutations, privileged application operations, exports, search, reports, files, and background jobs;
- privileged helpers must be narrowly scoped and must not become a general bypass channel;
- service/background operations must carry explicit target tenant context when processing tenant-owned data;
- cross-tenant negative tests are mandatory for every new tenant-owned domain capability;
- logs/errors must not leak another tenant's sensitive identifiers or payloads.

## 3.3 Failure behavior

When tenant context is absent, invalid, or unauthorized, the operation must fail closed. The system must not guess a tenant.

---

# 4. Authorization foundation

## 4.1 Separation of concerns

Three independent questions must remain separate:

1. **Authentication:** who is the user?
2. **Entitlement:** has the tenant been granted this product capability/limit?
3. **Authorization:** may this user perform this action in this tenant/scope?

A positive answer to one does not imply a positive answer to the others.

## 4.2 Permission catalog

The platform uses stable permission keys owned by the domain/capability that defines the protected action.

Permission keys should describe business authority, not pages or buttons.

Platform Wave 1 must support at least these permission families:

- tenant/company settings view/manage;
- membership/user-access view/manage;
- legal-entity view/manage;
- site/location view/manage;
- role/permission assignment view/manage;
- entitlement/subscription visibility for tenant administrators where product UX exposes it;
- sensitive audit visibility where permitted.

Exact technical key strings may be finalized in implementation naming conventions, but semantics above are fixed.

## 4.3 Roles are assignments/templates, not a hard-coded universal enum

The authorization model must support roles as named bundles of permissions.

V1 requirements:

- default role templates may be supplied for fast onboarding;
- role identity must not be encoded as a universal application enum that domains depend on;
- future tenant-defined/custom roles must be possible without re-platforming, even if advanced role-building UX is not required in first Wave 1 UI;
- direct user overrides should be avoided unless a concrete V1 need requires them; role assignment is the default mechanism;
- site/location scope, when needed later, is a scope applied to authority — not a separate competing permission system.

### Default Wave 1 tenant templates

At minimum:

- **Tenant Owner/Admin template** — broad tenant administration authority excluding Tech Edge internal control-plane authority.
- **Tenant Member template** — minimal platform access; business-domain authority is added by domain role templates later.

The later HR specs may add HR Officer, Payroll Officer, Manager/Supervisor, etc. without changing the Platform authorization model.

## 4.4 Platform operator authority

Tech Edge platform operators are not ordinary tenant roles.

Rules:

- platform-operator authority is separately governed;
- operator actions against a tenant require explicit target tenant context;
- sensitive operator actions are audited;
- operator authority must not be derivable by editing tenant role assignments;
- normal tenant users cannot grant themselves platform-operator authority.

---

# 5. Capabilities, entitlements, limits, and commercial access

## 5.1 Capability catalog

A **Capability** is a stable product-level unit such as `hr.people`, `hr.payroll`, `hr.attendance.biometric`, etc.

Rules:

- capability keys are stable product architecture identifiers;
- package names and marketing tiers compose capabilities and must not appear in domain business logic;
- capability dependencies are explicitly declared/validated;
- capability catalog records may include category, description, default state, and supported limit definitions;
- capability existence does not automatically grant access.

## 5.2 Entitlement evaluation

Effective tenant entitlement follows this conceptual precedence:

1. explicit tenant/contract/subscription override, when present;
2. assigned plan/bundle entitlement, when a plan/bundle model is used;
3. deliberate capability default only for capabilities explicitly classified by the product as included Platform Core behavior.

Commercial and optional capabilities are **deny-by-default** when no effective grant exists. Missing or incomplete entitlement data must never fail open.

An explicit deny override must be able to disable a capability otherwise enabled by a plan. An explicit enable override may enable a capability outside the plan when commercially authorized.

The implementation may use a simpler internal representation in V1 if it preserves these semantics and future plan composition without data migration that changes meaning.

## 5.3 Limits

Capabilities may expose typed commercial limits such as:

- employee count;
- site count;
- biometric device count;
- other proven future resource limits.

Rules:

- limits are values, not package-name conditionals;
- unlimited must have explicit semantics rather than magic accidental numbers;
- limit evaluation is server-authoritative;
- limit changes do not delete existing data;
- behavior when a tenant is already above a newly lowered limit must be capability-specific and non-destructive; default behavior is to block new growth while preserving existing data until resolved.

## 5.4 Entitlement loss / suspension

Removing or suspending a capability:

- must never automatically delete tenant data;
- must not mutate finalized historical payroll/compliance outcomes;
- blocks new prohibited operations at the authoritative layer;
- should structurally remove/disable capability UX for normal usage;
- may preserve controlled read/export access where required by the capability's compliance/history rules.

## 5.5 Dependency validation

The control plane must reject impossible entitlement combinations when a capability has a hard dependency.

Commercial bundles may contain convenient combinations, but they must not manufacture technical dependencies that are not logically required.

---

# 6. Minimum Tech Edge control plane

Wave 1 requires an internal control plane sufficient to operate early customers safely.

## 6.1 Required operator capabilities

Tech Edge must be able to:

- create/onboard a tenant;
- create/manage tenant legal entity and sites as part of onboarding/support;
- view tenant lifecycle/access status;
- suspend/reactivate tenant access;
- assign/remove capabilities;
- assign/modify limits;
- apply explicit entitlement overrides;
- inspect effective entitlement state;
- inspect tenant membership summary for support without exposing unnecessary sensitive domain data;
- review sensitive platform audit events.

## 6.2 Not required in V1 control plane

- public checkout;
- payment gateway integration;
- coupons;
- automatic invoice lifecycle;
- revenue accounting;
- partner commission accounting;
- CRM pipeline;
- generic impersonation of tenant users.

If support impersonation is introduced later, it requires a separate security decision and explicit audit/consent controls.

---

# 7. Sensitive-operation audit foundation

Audit is targeted at security/compliance-sensitive actions rather than indiscriminate full-row snapshots.

## 7.1 Minimum audit event fields

A sensitive platform audit event must be able to identify:

- event/action type;
- actor user or system principal;
- actor authority class when relevant (tenant user/platform operator/system job);
- target tenant;
- target resource type and opaque/system identifier where safe;
- timestamp;
- outcome (success/denied/failure where appropriate);
- bounded change metadata sufficient to explain the action without storing unnecessary sensitive payloads;
- request/correlation identifier where available.

## 7.2 Mandatory Wave 1 audit events

At minimum:

- tenant creation;
- tenant suspend/reactivate/archive;
- membership invitation/creation/activation/deactivation/removal;
- role/permission assignment changes;
- capability/entitlement enable/disable/override changes;
- limit changes;
- legal-entity/site sensitive lifecycle changes;
- platform-operator actions affecting a tenant;
- security-sensitive configuration changes.

## 7.3 Audit safety and consistency

- passwords, secrets, auth tokens, raw biometric payloads, exact payroll contents, and unnecessary personal data must never be copied into platform audit payloads;
- for every action classified as requiring a mandatory successful audit event, the protected mutation must not be acknowledged as successfully committed unless its audit event is durably persisted through the same consistency boundary;
- preferred implementation is atomic persistence; if later architecture requires asynchronous delivery it must use a durable transactional/outbox-style mechanism or equivalent that cannot leave a successful protected mutation permanently unaudited;
- best-effort fail-open audit for mandatory sensitive success events is prohibited;
- denied/failed-operation security telemetry may use a separate non-transactional path when no protected mutation committed;
- audit records themselves are authorization-protected and tenant/platform scoped.

---

# 8. Versioned configuration primitive

Wave 1 must provide only the minimum shared capability needed for downstream rules whose historical meaning changes over time.

The primitive must support:

- configuration identity/type;
- tenant or jurisdiction/global scope where appropriate;
- version/effective-from semantics;
- immutable historical version references once consumed by finalized sensitive outcomes;
- explicit replacement/supersession rather than silent historical mutation.

Wave 1 must not build a generic scripting/rule engine.

---

# 9. UX requirements for Platform Foundation

The platform foundation UI must comply with `frontend-ux-baseline.md`.

## 9.1 Tenant selection

- multi-tenant users receive an explicit tenant switcher/context indicator;
- single-tenant users may be auto-selected but still operate under validated explicit context;
- switching tenant clears/reloads tenant-scoped screens and cached state;
- the current tenant must be visually unambiguous in sensitive administration workflows.

## 9.2 Capability-disabled behavior

- normal navigation/actions for disabled optional capabilities disappear or become structurally unavailable;
- direct navigation/API attempts still fail authoritatively;
- users should receive a clear product-access message rather than a misleading generic application error where disclosure is safe.

## 9.3 Control plane

- Tech Edge operator surfaces are visually/structurally distinct from normal tenant administration;
- tenant target context is always visible before sensitive operator actions;
- destructive/access-changing actions require appropriate confirmation.

---

# 10. Error and denial semantics

The application must distinguish internally between:

- unauthenticated;
- invalid/inactive membership;
- invalid tenant context;
- unauthorized permission;
- capability not entitled;
- commercial/resource limit reached;
- tenant suspended or archived;
- resource not found within authorized scope.

External messages may intentionally avoid leaking sensitive existence information, but the server-side outcome and audit/diagnostics must preserve the correct reason.

---

# 11. Critical invariants

Wave 1 is not Done unless all are true:

1. A user can belong to multiple tenants without implicit tenant selection becoming authorization.
2. Cross-tenant access is denied at the authoritative layer.
3. Platform operators and tenant roles are separate authority classes.
4. Entitlements and permissions are independently enforced.
5. Commercial/optional capabilities fail closed when no effective entitlement grant exists.
6. Capability/package names do not enter business-domain branching logic.
7. Entitlement disable/suspension never deletes customer data automatically.
8. Limits do not destructively trim existing data.
9. Employee/user identity coupling is not introduced by Platform Core.
10. Sites do not create a second permission system.
11. Sensitive platform changes are auditable without copying sensitive business payloads.
12. Tenant/legal-entity/site lifecycle changes preserve historical references.
13. No generic engine or infrastructure is added without a current Wave 1 requirement.
14. A mandatory audited sensitive mutation cannot succeed while its mandatory success audit event is silently lost.

---

# 12. Acceptance criteria / qualification matrix

## 12.1 Tenant and membership

- create tenant and initial owner/admin membership;
- one user can hold active memberships in two tenants;
- explicit switch selects authorized tenant context;
- requesting an unowned tenant context is denied;
- inactive membership is denied immediately without deleting history;
- tenant suspension blocks normal tenant operations without deleting data while Tech Edge recovery/administration remains possible;
- archived tenant blocks normal tenant operations and remains historically preserved.

## 12.2 Isolation

- tenant A cannot read tenant B resources;
- tenant A cannot mutate tenant B resources;
- tenant A cannot export/search/infer tenant B data through supported endpoints;
- privileged helpers/background jobs demonstrate explicit tenant targeting;
- negative isolation tests run on a clean environment.

## 12.3 Authorization

- tenant member without permission is denied even when capability is entitled;
- tenant admin receives defined platform administration authority;
- tenant role assignments cannot grant platform-operator authority;
- UI hiding alone is never the only enforcement evidence.

## 12.4 Entitlements and limits

- plan/bundle entitlement can enable a capability;
- explicit override can enable or deny according to precedence;
- missing optional/commercial entitlement state is denied rather than enabled;
- effective entitlement is inspectable;
- capability dependency violations are rejected;
- limit blocks new growth at threshold;
- lowering a limit below current usage preserves existing data;
- disabling a capability preserves data/history while blocking prohibited operations.

## 12.5 Audit

- all mandatory Wave 1 sensitive events produce reviewable audit records;
- a simulated mandatory-audit persistence failure proves the protected sensitive mutation does not commit/acknowledge success without its audit record;
- unauthorized/denied sensitive actions are captured where security value justifies it;
- audit payload review proves prohibited sensitive values are absent;
- actor, target tenant, action, time, and outcome are attributable.

## 12.6 UX

- representative tenant admin workflows pass desktop/laptop and mobile acceptance;
- tenant switching is unambiguous and safe;
- control-plane tenant target context is always clear;
- disabled entitlement UX matches server-authoritative behavior.

## 12.7 Reproducibility

- clean environment can reproduce the Platform Foundation schema/configuration once implementation begins;
- migration order has no hidden manual production dependency;
- qualification evidence refers to the exact implementation revision and Frozen spec revision.

---

# 13. Required supporting ADRs

Before this specification may become Frozen for Wave 1 implementation, the following architecture decisions must be Accepted:

- ADR-001 — Tenant, Legal Entity, and Site separation.
- ADR-002 — Explicit Tenant Context and authoritative isolation.
- ADR-003 — Entitlement precedence, limits, and non-destructive disable semantics.
- ADR-004 — Authorization model: permission catalog + role templates, no fixed universal role enum.
- ADR-005 — Sensitive audit consistency must fail closed.

Technology/deployment ADRs may be completed in the same Phase 0D before coding begins; they do not change the behavioral invariants in this specification.

# 14. Freeze gate

This specification may move from Proposed to Frozen only when:

- supporting ADRs are Accepted;
- no material tenant/isolation/authorization/entitlement/control-plane behavior is unresolved;
- security/privacy review finds no contradiction with the baselines;
- acceptance criteria are testable with the selected implementation approach;
- technology choices selected for Wave 1 can satisfy these invariants without weakening them.
