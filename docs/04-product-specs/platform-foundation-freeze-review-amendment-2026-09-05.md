# Platform Foundation Freeze-Review Amendment — 2026-09-05

## Status

**Accepted corrective review amendment for Phase 0D.**

This amendment records the corrections approved after an independent architecture review of the Phase 0D Platform Foundation draft and ADR-001 through ADR-010.

It does **not** itself mark the Platform Foundation Specification as Frozen and does **not** accept ADR-001 through ADR-010. Those artifacts remain `Proposed` until the post-amendment acceptance/freeze review confirms that the complete Foundation set is coherent.

Until the source documents are consolidated, this amendment is normative where it narrows or removes ambiguity in the current Platform Foundation draft or ADR wording.

No Product Code is authorized by this amendment.

---

# 1. Authoritative data-access contract

The Foundation must not leave business authorization split ambiguously between UI/application code and directly exposed database access.

## 1.1 Required invariant

Every supported tenant-owned operation must have one authoritative, testable access path that proves all applicable conditions before success:

1. authenticated principal identity;
2. explicit validated tenant context;
3. active Membership or separately governed Platform Operator authority;
4. required business Permission;
5. required Capability Entitlement and applicable Limit semantics;
6. row/resource scope and tenant ownership;
7. any operation-specific lifecycle preconditions.

A UI control, route guard, navigation filter, or client-side check is never sufficient authority.

## 1.2 Direct database/Data API exposure

The implementation must use an explicit allowlist rather than accidental exposure.

Rules:

- database object grants are revoke-by-default for application roles unless access is deliberately required;
- internal/domain tables that do not require direct client/Data API access should live behind non-exposed/private boundaries or have no usable direct grants;
- a direct mutation is allowed only when the database-authoritative policy for that mutation enforces the same tenant, permission, entitlement, scope, and lifecycle rules required by the owning specification;
- when those rules cannot be expressed safely and clearly at the direct-access boundary, the mutation must use a narrow application command / transactional RPC / equivalent authoritative operation boundary;
- sensitive multi-write transitions use one transactional boundary and do not expose constituent writes as an alternate path;
- views exposed to tenant users must not bypass the caller's effective authorization context;
- privileged database functions must use least privilege, controlled execution grants, safe search-path behavior, and fully qualified object references where applicable;
- `service_role` or equivalent bypass credentials are server-only emergency/operational capabilities and must never become the normal tenant-user data-access layer.

## 1.3 Tenant context binding

A tenant identifier supplied by a client may express the tenant the user wishes to operate in, but it is never trusted as authorization truth.

The authoritative layer must resolve and validate that concrete tenant against current Membership/Operator authority before it is used for tenant-owned access. Authorization must not rely solely on stale client claims or remembered tenant state.

## 1.4 Required design artifact before Wave 1 implementation

ADR-008 must contain or reference an **Authoritative Access Matrix** that classifies each Platform Foundation operation family as one of:

- direct read under explicit grants + authoritative row/resource policy;
- direct mutation under explicit grants + complete authoritative policy;
- application command / RPC / transactional operation only;
- Platform Operator / system-only operation.

The matrix must also identify where Permission and Entitlement enforcement occurs for each path.

---

# 2. Same-tenant referential integrity

RLS/row filtering alone is not sufficient to protect the integrity of relationships between tenant-owned records.

## 2.1 Required invariant

Every persistent relationship from one tenant-owned record to another tenant-owned record must guarantee that both records belong to the same Tenant, unless a separately specified cross-tenant platform relationship explicitly permits otherwise.

A row owned by Tenant A must never be able to persist a foreign reference to a Tenant B employee, site, role assignment, payroll record, file metadata record, or future domain record merely because the referenced identifier exists globally.

## 2.2 Enforcement

The invariant must be enforced authoritatively by schema/constraint/transactional-command design, not by UI filtering.

Acceptable implementation patterns include:

- composite references such as `(tenant_id, resource_id)` backed by an appropriate unique key;
- an equivalent database constraint;
- a narrow atomic command whose invariant cannot be bypassed by any alternate supported write path.

The chosen physical pattern may vary by aggregate, but the invariant may not.

## 2.3 Qualification

Every tenant-owned relationship introduced by a Wave must include negative tests proving that a valid identifier from another Tenant cannot be linked, written, imported, or processed.

---

# 3. Invitation, Membership, and protected tenant-administrator lifecycle

The Platform Foundation must freeze the root-of-trust lifecycle sufficiently to prevent orphaned tenants, ambiguous invitations, and accidental administrative lockout.

## 3.1 Invitation lifecycle

A V1 tenant invitation must have explicit states/outcomes equivalent to:

`pending -> accepted | expired | revoked`

Required behavior:

- a pending invitation cannot grant tenant access by itself;
- acceptance binds the intended invitation to an authenticated User under an authoritative claim rule;
- where the invitation is addressed to a specific email/identity, a different identity cannot silently claim it;
- expiration and revocation are terminal for that invitation artifact;
- resend/reissue behavior must not leave multiple ambiguous independently claimable invitations without an explicit rule;
- invitation creation, acceptance, expiry/revocation where materially relevant, and recovery actions are auditable.

## 3.2 Membership lifecycle

Membership access state must be explicit and historical references must be preserved.

At minimum:

- `active` grants only the authorities separately assigned to that Membership;
- `inactive` grants no tenant access and may be reactivated by an authorized workflow;
- removal/revocation of access must preserve historical audit attribution even if the product no longer shows the Membership as active;
- no Membership state may implicitly create Platform Operator authority.

## 3.3 Initial administrator bootstrap

Tenant onboarding must atomically or recoverably establish at least one protected tenant administrator/owner authority before the tenant is considered successfully operational.

A partially created tenant with no authorized administrator must be an explicit failed/recoverable onboarding state, not a hidden success.

## 3.4 Last-administrator protection

The system must prevent a transition that leaves an operational tenant with no authorized tenant administrator capable of recovery.

This applies to:

- Membership deactivation/removal;
- role removal or demotion;
- permission-template changes affecting protected administration authority;
- self-removal/self-demotion.

A protected administrator may be replaced, but the replacement authority must be established before the final protected administrator is removed.

This protection concerns application administration authority, not HR job titles or employment position.

---

# 4. Platform Operator root of trust

Platform Operator authority is a separate Platform authority class, not an elevated tenant role and not an implication of possessing infrastructure credentials.

## 4.1 Grant/revoke boundary

- Platform Operator grants/revocations are stored and governed outside tenant role assignments;
- normal tenant administrators cannot grant, revoke, or manufacture Platform Operator authority;
- granting/revoking Platform Operator authority is itself a sensitive audited Platform operation;
- the authority used to govern Platform Operators must be narrower and explicitly controlled rather than available through normal tenant administration;
- losing tenant Membership does not implicitly create or preserve Platform Operator authority, and Platform Operator status does not imply tenant Membership.

## 4.2 Tenant operations

When an operator acts on tenant-owned state:

- the target Tenant is explicit;
- the operation is bounded to an approved operator capability;
- required sensitive audit is recorded;
- operator authority does not silently bypass business lifecycle invariants that the operation is required to preserve.

Generic user impersonation remains out of V1 unless separately designed and accepted.

Infrastructure bypass credentials such as `service_role` are not a product-level Platform Operator identity and must not be treated as one.

---

# 5. Role-template stability

Default role templates exist to accelerate onboarding; they must not become a hidden centrally mutable source of authority for existing tenants.

Required semantics:

- permission keys are stable, namespaced by owning Platform/Domain authority where appropriate, and unknown/unrecognized permissions fail closed;
- the effective permission set for an existing tenant must not change silently because a centrally supplied default template was edited later;
- implementation must therefore use explicit template versioning, copy-on-provisioning, immutable template revisions, or another model with equivalent non-silent semantics;
- intentional permission changes for existing tenants require an explicit governed migration/change action and appropriate audit where sensitive;
- tenant role identity must not be confused with Employee job title, department, or reporting position.

Advanced custom-role UX remains deferred until demonstrated need; this requirement protects authority semantics without requiring a generic role-builder in Wave 1.

---

# 6. Sensitive audit is append-only for application authority

The existing mandatory-success-audit consistency rule remains required and is strengthened by an append-only runtime invariant.

## 6.1 Runtime mutation rule

Normal application roles, tenant roles, and ordinary Platform Operator workflows must not have `UPDATE` or `DELETE` authority over persisted mandatory audit events.

Audit event identity and authoritative event time must be generated/controlled by the trusted persistence boundary rather than accepted as arbitrary client truth.

## 6.2 Controlled exceptional handling

Retention enforcement, legal deletion obligations, schema migration, or exceptional security repair may require separately governed maintenance procedures. Those procedures are not normal application audit mutation paths and must themselves leave appropriate evidence.

## 6.3 Read separation

Permission to perform a sensitive action does not automatically imply permission to browse all sensitive audit history. Audit visibility is separately authorized and data-minimized.

The existing rule still applies: if a protected transition requires mandatory success audit, the protected state change and durable success audit share one consistency boundary and either both succeed or neither is acknowledged as successful.

---

# 7. Narrow PLT-010 to shared temporal/versioning semantics

PLT-010 must not become a generic global configuration repository or rules engine merely because later HR/Payroll domains need effective-dated rules.

## 7.1 Platform-owned contract

Platform Core may define only the shared conventions/primitives needed to preserve temporal meaning, such as:

- stable configuration/version identity;
- `effective_from` / supersession semantics where needed;
- immutable reference to a historical version once consumed by a finalized sensitive outcome;
- common provenance/actor metadata where genuinely shared;
- safe tenant/jurisdiction/global scope vocabulary only when a concrete consuming domain requires it.

## 7.2 Domain ownership

The owning Business Domain owns its actual business configuration and rules.

Examples:

- Payroll/Compliance owns statutory payroll rules, tax/social-insurance configuration, calculation versions, and their domain validation;
- HR owns HR work/leave/employment policy configuration;
- future Inventory, Sales, Finance, or Procurement domains own their own business rules.

Platform Core must not become a generic JSON settings store, scripting engine, policy DSL, or jurisdiction rules repository.

## 7.3 Wave 1 implementation budget

Wave 1 must implement only the smallest temporal/versioning support proven necessary by an active Foundation use case or required to establish a stable downstream contract. It must not build speculative generalized configuration infrastructure before a consuming domain proves the requirement.

---

# 8. Staged Phase 0D freeze and implementation gates

The project uses a staged specification-freeze model to avoid both premature coding and unnecessary blocking of the domain-neutral Platform Spine.

## 8.1 Platform Foundation gate

Wave 1 — Platform Spine may begin only after:

- Platform Foundation Specification is `Frozen`;
- ADR-001 through ADR-010 are `Accepted` as a coherent implementation set;
- the corrections in this amendment have been incorporated or remain explicitly referenced as governing normative constraints;
- no material unresolved Foundation behavior remains in tenant isolation, Membership/authorization, entitlements, operator authority, audit, or authoritative data access.

Wave 1 may begin at that point even if later HR-domain Specs are still being finalized, because Wave 1 is explicitly domain-neutral and must not contain HR Product Code.

## 8.2 Domain-wave gates

No Business Domain implementation wave may begin from a merely `Proposed` governing Product Spec.

At minimum:

- Wave 2 People & Work Context requires its governing People/Work Context Spec to be Frozen;
- Wave 3 Attendance/Leave requires its governing Attendance/Leave Spec to be Frozen;
- Wave 4 Employee Finance/Payroll requires its governing Employee Finance/Payroll Spec to be Frozen;
- Wave 5 attendance channels requires its governing Attendance Channel Spec to be Frozen.

A later Spec may be authored while an earlier independent Wave is being implemented, but its Product Code cannot start before its own freeze gate passes.

## 8.3 Meaning of "Phase 0D complete"

The umbrella Phase 0D is fully complete only when all implementation-ready V1 Product Specs required by the accepted implementation plan have passed their respective freeze gates.

Starting Wave 1 after the Platform Foundation freeze does not falsely declare the entire Phase 0D complete; it uses the dependency-driven staged freeze defined above.

## 8.4 Codex/executor rule

An executor must not invent material Business Domain behavior merely because a later Spec is unfinished. If implementation reaches an unresolved product decision, work stops at that domain boundary and the governing Spec is completed through change control first.

---

# 9. Post-amendment acceptance checklist

Before changing the Platform Foundation Specification from `Proposed` to `Frozen`, the acceptance review must verify all of the following on one exact repository revision:

- [ ] ADR-008 contains/references the Authoritative Access Matrix and no ambiguous alternate mutation authority remains.
- [ ] same-tenant referential-integrity invariant is represented in Foundation isolation/data rules.
- [ ] invitation, Membership, bootstrap, and last-administrator lifecycles have testable completion/recovery semantics.
- [ ] Platform Operator grant/revoke authority is separate from tenant roles and infrastructure bypass credentials.
- [ ] role-template updates cannot silently rewrite existing tenant authority.
- [ ] mandatory audit is append-only to normal application/operator authority while retaining the existing atomic success-audit invariant.
- [ ] PLT-010 is a narrow temporal/versioning contract, not a speculative generic configuration engine.
- [ ] the staged Phase 0D/Wave gate is unambiguous and prevents HR Product Code from preceding its Frozen Spec.
- [ ] Definition of Ready/Done and Wave planning do not contradict these constraints.
- [ ] no change in this amendment introduces public signup, self-service billing, generic workflow/BPM, generic impersonation, microservices, event bus, or another speculative platform subsystem.

If these checks pass, the remaining acceptance decision is whether ADR-001 through ADR-010 can be marked `Accepted` and the Platform Foundation Specification can be marked `Frozen` on that exact revision.
