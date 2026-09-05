# Platform Foundation Specification

## Status

**Proposed — Phase 0D implementation-readiness draft, consolidated after the 2026-09-05 freeze review.**

This specification governs the minimum shared SaaS foundation required before tenant-owned Business Domain Product Code is implemented. It defines product/behavioral invariants, ownership boundaries, and acceptance criteria without turning Platform Core into the architectural root of HR or any future Business Domain.

## Governing inputs

- Accepted Product Charter and Product Principles.
- Accepted Master Product Blueprint.
- Accepted V1 Capability Decomposition.
- Accepted V1 Implementation Waves, as amended by the Phase 0D staged-freeze clarification.
- Accepted `DEC-016` No Dead-End Workflows principle and Post-V1 Operational Completion Roadmap.
- Accepted `platform-foundation-freeze-review-amendment-2026-09-05.md` corrective constraints.
- Completed Edara SaaS Extraction Audit.
- Architecture Principles, Security Baseline, Data Classification/Privacy baseline, Definition of Ready, and Definition of Done.

## Scope

This specification covers Wave 1 capabilities:

- PLT-001 Tenant/customer account.
- PLT-002 Legal Entity identity/lifecycle foundation.
- PLT-003 Sites/branches.
- PLT-004 Authentication boundary.
- PLT-005 Membership + explicit tenant context.
- PLT-006 Authorization foundation.
- PLT-007 Capability catalog, entitlements and limits.
- PLT-008 Minimum Tech Edge control plane.
- PLT-009 Sensitive-operation audit foundation.
- PLT-010 Minimum shared temporal/versioning contract needed by downstream domains.

## Explicit non-goals

Wave 1 must not expand into:

- public self-signup;
- payment gateways, coupon engines, or self-service billing;
- a generic workflow/BPM engine;
- a generic dynamic-form engine;
- a generic business-rules/configuration engine;
- broad customer-facing API/webhook products;
- full document management;
- broad notification/inbox platform;
- HR business rules or HR data models;
- payroll/statutory rules owned by Platform Core;
- native mobile applications;
- generic user impersonation;
- microservices or event-bus infrastructure without demonstrated need.

## Operational completion rule

Wave 1 may remain intentionally small, but no Platform workflow may create an operational dead end. Each material lifecycle must define a supported terminal/closure state or explicit governed handoff.

Examples:

- tenant onboarding ends in a usable active tenant or an explicit failed/cancelled/recoverable onboarding outcome;
- invitation creation ends in accepted, expired, or revoked outcome rather than remaining indefinitely ambiguous;
- membership activation/deactivation/removal preserves historical attribution and never silently removes the final recoverable tenant administrator;
- tenant suspension/reactivation/archive are explicit access states, not hidden flags with undefined operational behavior;
- entitlement or limit changes preserve existing data and make the next allowed action clear;
- when commercial billing automation is deferred, the Tech Edge control plane is the explicit operational handoff rather than leaving customer access state unresolved.

Post-launch expansion may automate these handoffs, but V1 must already make them explicit and supportable.

---

# 1. Core organization model

## 1.1 Tenant

A **Tenant** is the top-level customer isolation and commercial-access boundary.

A tenant owns or scopes all tenant-specific Platform and Business Domain data. Tenant identity must be explicit on every persistent tenant-owned aggregate or be derivable through an enforced, unambiguous ownership relationship.

A tenant must have at minimum:

- immutable system identity;
- human-readable display name;
- lifecycle/access status;
- creation metadata;
- commercial/entitlement association;
- audit identity for sensitive administrative changes.

### Tenant lifecycle states

V1 Platform access states are:

- `active` — normal tenant access subject to permissions and entitlements;
- `suspended` — normal tenant business operations are blocked; data is preserved; controlled Tech Edge administration/recovery remains available;
- `archived` — tenant is no longer operationally active; normal tenant business operations remain unavailable; data remains preserved according to retention policy; controlled Platform administration/export/recovery may remain available according to policy; the identity cannot be silently reused as a new tenant.

A separate commercial contract/subscription status may later have more detailed states. Tenant lifecycle and commercial billing concepts must not be collapsed into one field merely for convenience.

Deletion of a tenant is not a normal V1 product workflow.

## 1.2 Legal Entity

A **Legal Entity** is a domain-neutral legal/business identity owned within a Tenant.

Rules:

- a tenant may own one or more Legal Entities;
- V1 onboarding may create one default Legal Entity automatically for simple customers;
- the persistent model must not permanently assume one Tenant equals one Legal Entity;
- Platform Core owns only shared identity/display/lifecycle facts;
- deactivation preserves historical references;
- a Business Domain may assign domain meaning to the shared Legal Entity without moving its business rules into Platform Core.

For HR/Payroll, the owning Domain may designate/reference a Legal Entity as the legal Employer for an Employment/Payroll relationship. A future Finance, Sales, Procurement, Inventory, or other Domain may use the same Legal Entity for its own domain boundary.

Employer registrations, payroll statutory attributes, tax/social-insurance configuration, and other domain-specific legal facts are not Platform-owned simply because HR is the first consumer.

## 1.3 Site / branch / operating location

A **Site** is a domain-neutral physical or operating location associated with a Tenant and, where applicable, a Legal Entity.

Rules:

- sites are reusable by HR and future domains;
- a one-site tenant must remain simple in UX and may receive a default Site during onboarding;
- Site identity must not create a second role/permission system;
- future domain scopes may reference Sites through the shared Platform identity;
- deactivating a Site preserves historical references;
- Site limits, when commercially enforced, are Entitlement limits rather than package-name conditions;
- HR schedule/geofence rules, warehouse rules, sales territory rules, and other domain-specific location semantics remain owned by their Domains.

---

# 2. Identity, authentication, invitations, membership, and tenant context

## 2.1 User identity

A **User** represents an authenticated human account.

User identity is Platform identity and is not the same as an Employee record. An Employee may exist without a User account, and a User may exist without an Employee record.

The application consumes a stable authenticated user identity and must not trust client-provided role, tenant, entitlement, or operator claims as sole authority.

## 2.2 Invitation lifecycle

A pending invitation does not grant tenant access.

V1 invitation outcomes are equivalent to:

`pending -> accepted | expired | revoked`

Required semantics:

- acceptance binds the invitation to an authenticated User under an authoritative claim rule;
- when an invitation targets a specific email/identity, another identity cannot silently claim it;
- expired/revoked invitations cannot later grant access;
- resend/reissue semantics must not leave ambiguous independently claimable invitations;
- material invitation actions are auditable;
- invitation recovery never bypasses Membership or role authority rules.

## 2.3 Tenant Membership

A **Membership** links a User to a Tenant and carries tenant-scoped access metadata.

Required semantics:

- one User may belong to multiple Tenants;
- Membership has an explicit active/inactive access state;
- inactive Membership grants no tenant access;
- reactivation is an explicit authorized action;
- removal/revocation preserves historical audit attribution rather than erasing identity/history;
- Membership operations are auditable;
- tenant access is denied unless an active Membership or a separately governed Platform Operator authority exists;
- no Membership state may create Platform Operator authority implicitly.

## 2.4 Initial administrator bootstrap

Tenant onboarding is not successfully operational until at least one protected tenant administrator/owner authority exists.

Bootstrap must be atomic or explicitly recoverable. A partially created Tenant with no authorized administrator is a failed/recoverable onboarding state rather than hidden success.

The system prevents Membership deactivation/removal, role demotion/removal, template migration, or self-removal/self-demotion from leaving an operational Tenant with no recoverable authorized tenant administrator.

A protected administrator may be replaced only after replacement authority is established.

This protection concerns application administration authority, not HR job title or employment position.

## 2.5 Explicit tenant context

Every tenant-scoped interactive/request operation executes against an explicit concrete Tenant context.

Rules:

- no `first tenant`, `LIMIT 1`, last-row, or hidden fallback may establish authorization scope;
- remembered/auto-selected Tenant may improve UX but never creates authorization;
- a client-supplied Tenant identifier may express requested context but is not trusted as authorization truth;
- the authoritative layer validates the current User against current Membership or separately governed Platform Operator authority before tenant-owned access proceeds;
- authorization must not depend solely on stale JWT/custom claims, route parameters, headers, or remembered client state;
- switching Tenant context invalidates/reloads tenant-scoped cached state;
- Tenant context is available to authorization, entitlement, audit, and data-access enforcement;
- Platform Operator flows acting on tenant data record the target Tenant explicitly.

For a User with exactly one active Membership, UX may auto-select that Tenant, but the authoritative operation still validates a concrete Tenant ID.

---

# 3. Tenant isolation and relationship integrity

Tenant isolation is a Foundation Obligation, not an optional feature.

## 3.1 Isolation invariant

A tenant user must never read, create, update, delete, execute, export, or infer tenant-owned data belonging to another Tenant through supported application/data access paths unless an explicitly authorized Platform Operator workflow exists.

## 3.2 Same-tenant referential-integrity invariant

Every persistent relationship from one tenant-owned record to another tenant-owned record must guarantee that both records belong to the same Tenant, unless a separately specified cross-tenant Platform relationship explicitly permits otherwise.

A Tenant A row must never persist a foreign reference to a Tenant B Employee, Site, Membership, role assignment, file metadata record, payroll record, or future Domain record merely because the referenced identifier exists globally.

Enforcement is authoritative through schema/constraint/transactional-command design, such as:

- composite `(tenant_id, resource_id)` references backed by an appropriate unique key;
- equivalent database constraints;
- a narrow atomic command whose invariant cannot be bypassed through another supported write path.

UI filtering/application convention alone is insufficient.

## 3.3 Enforcement requirements

- authoritative enforcement exists below presentation/UI visibility;
- tenant scoping applies to direct reads, direct mutations, privileged application operations, exports, search, reports, files, and background jobs;
- object grants are deliberate rather than accidental;
- privileged helpers are narrowly scoped and do not become a general bypass channel;
- service/background operations carry explicit target Tenant context when processing tenant-owned data;
- every new tenant-owned capability receives positive and negative isolation tests;
- every new tenant-owned relationship receives a negative test using a valid identifier from another Tenant;
- logs/errors do not leak another Tenant's sensitive identifiers or payloads.

## 3.4 Failure behavior

When Tenant context is absent, invalid, inactive, or unauthorized, the operation fails closed. The system never guesses a Tenant.

---

# 4. Authorization foundation

## 4.1 Separation of concerns

Three independent questions remain separate:

1. **Authentication:** who is the User?
2. **Entitlement:** has the Tenant been granted this product Capability/Limit?
3. **Authorization:** may this User perform this action in this Tenant/resource scope?

A positive answer to one does not imply a positive answer to the others.

## 4.2 Permission catalog

The Platform uses stable business Permission keys owned by Platform Core or the Business Domain defining the protected action.

Permission keys describe business authority, not pages/buttons, and unknown/unrecognized permission keys fail closed.

Platform Wave 1 supports at least these Permission families:

- tenant/company settings view/manage;
- membership/user-access view/manage;
- Legal Entity view/manage;
- Site/location view/manage;
- role/permission assignment view/manage;
- entitlement/subscription visibility where product UX exposes it;
- sensitive audit visibility where permitted.

Exact technical key strings may be finalized in implementation naming conventions, but the semantics above are fixed.

## 4.3 Roles and templates

Roles are named bundles/templates of Permissions, not universal hard-coded business enums that Domain logic switches on.

Wave 1 requirements:

- default templates may be supplied for fast onboarding;
- at minimum there is a broad Tenant Owner/Admin template and a minimal Tenant Member template;
- later Domains may add HR Officer, Payroll Officer, Manager/Supervisor, etc. without changing the Platform model;
- direct per-user overrides are not a default Wave 1 mechanism;
- Site/location scope is a scope applied to authority, not a competing permission system;
- role identity is not an Employee job title, department, or reporting position.

### Role-template stability

The effective Permission set for an existing Tenant must not change silently because a centrally supplied default template was edited later.

Implementation therefore uses explicit template versioning, copy-on-provisioning, immutable template revisions, or another equivalent non-silent model.

Intentional authority changes for existing Tenants require an explicit governed change/migration action and appropriate audit where sensitive.

Advanced custom-role UX is deferred until demonstrated need.

## 4.4 Platform Operator authority

Tech Edge Platform Operators are a separate Platform authority class, not ordinary tenant roles.

Rules:

- Operator grants/revocations are governed outside tenant role assignments;
- normal tenant administrators cannot grant, revoke, or manufacture Operator authority;
- granting/revoking Operator authority is a sensitive audited Platform operation;
- Operator status does not imply tenant Membership, and Membership does not imply Operator status;
- infrastructure bypass credentials such as `service_role` are not a product-level Platform Operator identity;
- an Operator action against tenant-owned state requires explicit target Tenant and an approved Operator capability;
- Operator authority does not silently bypass required business lifecycle/integrity invariants;
- generic user impersonation remains out of V1 unless separately designed and accepted.

---

# 5. Capabilities, entitlements, limits, and commercial access

## 5.1 Capability catalog

A **Capability** is a stable product-level unit such as `hr.people`, `hr.payroll`, `hr.attendance.biometric`, etc.

Rules:

- Capability keys are stable product architecture identifiers;
- package names/marketing tiers compose Capabilities and never enter Business Domain branching logic;
- Capability dependencies are explicitly declared/validated;
- catalog records may include category, description, deliberate default state, and supported Limit definitions;
- Capability existence does not automatically grant access.

## 5.2 Entitlement evaluation

Effective tenant Entitlement follows this conceptual precedence:

1. explicit tenant/contract/subscription override, when present;
2. assigned plan/bundle Entitlement, when a plan/bundle model is used;
3. Capability default only where the product deliberately defines a default.

An explicit deny can override a plan enable. An explicit enable can extend a plan when commercially authorized.

For optional/commercial Capabilities, absence of an effective grant is deny-by-default. Missing/ambiguous Entitlement data never enables a paid Capability accidentally.

V1 may use a simpler internal commercial representation if these semantics remain stable and future plan composition does not require changing historical meaning.

## 5.3 Limits

Capabilities may expose typed commercial Limits such as employee count, Site count, device count, or other demonstrated resource limits.

Rules:

- Limits are values, not package-name conditionals;
- unlimited has explicit semantics rather than magic accidental numbers;
- Limit evaluation is authoritative below UI;
- Limit changes never delete existing data;
- if current usage exceeds a lowered Limit, existing data remains and new growth is blocked by default until resolved, unless the owning Capability Spec defines a safer specific continuation rule.

## 5.4 Entitlement loss / suspension

Removing/suspending a Capability:

- never automatically deletes tenant data;
- never mutates finalized historical financial/compliance outcomes;
- blocks new prohibited operations at the authoritative layer;
- structurally removes/disables normal capability UX;
- may preserve controlled read/export access where required by compliance/history rules;
- must not strand in-flight work without a defined continuation/recovery/handoff rule in the owning Spec.

## 5.5 Dependency validation

The control plane rejects impossible Entitlement combinations when a true hard dependency exists.

Commercial bundles may contain convenient combinations, but they do not manufacture technical dependencies that are not logically required.

---

# 6. Minimum Tech Edge control plane

Wave 1 requires an internal control plane sufficient to operate early customers safely.

## 6.1 Required Operator capabilities

Tech Edge must be able to:

- create/onboard a Tenant;
- create/manage initial Legal Entity and Sites as part of onboarding/support;
- view Tenant lifecycle/access status;
- suspend/reactivate Tenant access;
- assign/remove Capabilities;
- assign/modify Limits;
- apply explicit Entitlement overrides;
- inspect effective Entitlement state;
- inspect Tenant Membership summary for support without exposing unnecessary sensitive Domain data;
- review sensitive Platform audit events subject to separate audit-view authority.

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

Audit targets security/compliance-sensitive actions rather than indiscriminate full-row snapshots.

## 7.1 Minimum audit event fields

A sensitive Platform audit event identifies:

- event/action type;
- actor User or system principal;
- actor authority class when relevant (tenant user/Platform Operator/system job);
- target Tenant;
- target resource type and opaque/system identifier where safe;
- authoritative timestamp;
- outcome;
- bounded change metadata sufficient to explain the action without unnecessary sensitive payloads;
- request/correlation identifier where available.

## 7.2 Mandatory Wave 1 audit events

At minimum:

- Tenant creation;
- Tenant suspend/reactivate/archive;
- invitation creation/acceptance/revocation and material recovery events;
- Membership activation/deactivation/removal;
- role/Permission assignment changes;
- Capability/Entitlement enable/disable/override changes;
- Limit changes;
- Legal Entity/Site sensitive lifecycle changes;
- Platform Operator grant/revoke and tenant-affecting Operator actions;
- security-sensitive configuration changes.

## 7.3 Audit safety and consistency

- passwords, secrets, auth tokens, raw biometric payloads, exact payroll contents, and unnecessary personal data are never copied into Platform audit payloads;
- audit records are separately authorization-protected and tenant/Platform scoped;
- mandatory audit event identity/time are controlled by the trusted persistence boundary rather than arbitrary client input;
- normal application roles, tenant roles, and ordinary Platform Operator workflows have no `UPDATE` or `DELETE` authority over persisted mandatory audit events;
- corrective facts are represented through new audit events rather than rewriting prior history;
- permission to perform an action does not automatically grant permission to browse all sensitive audit history;
- where a governing Spec classifies success audit as mandatory, protected state change and durable success audit share one consistency boundary and either both succeed or neither is acknowledged as successful;
- denied/failed attempt telemetry may use a separate safe diagnostic path if the business mutation did not commit;
- retention/legal deletion/schema migration/exceptional security repair use separately governed maintenance procedures and do not create a normal audit-editing API.

See `ADR-005-sensitive-audit-consistency.md`.

---

# 8. Shared temporal/versioning contract (PLT-010)

PLT-010 exists only to preserve shared historical meaning where downstream Domain rules/configuration change over time. It is not a generic rules engine or universal configuration repository.

## 8.1 Platform-owned semantics

Platform Core may define only shared conventions/primitives such as:

- stable configuration/version identity;
- effective-from/supersession semantics where a concrete consumer needs them;
- immutable historical version reference once consumed by a finalized sensitive outcome;
- common provenance/actor metadata where genuinely shared;
- safe Tenant/jurisdiction/global scope vocabulary only when a concrete Domain consumer requires it.

## 8.2 Domain ownership

The owning Business Domain owns its actual business rules/configuration and validation.

Examples:

- Payroll/Compliance owns tax/social-insurance/statutory calculation rules and calculation versions;
- HR owns employment/work/leave policy configuration;
- future Inventory, Sales, Finance, or Procurement Domains own their own rules.

Platform Core must not become a generic JSON settings store, policy DSL, scripting engine, or jurisdiction rules repository.

## 8.3 Wave 1 complexity budget

Wave 1 implements only the smallest temporal/versioning support proven necessary by an active Foundation use case or required to establish a stable downstream contract. Speculative generalized configuration infrastructure is prohibited.

---

# 9. Authoritative data-access contract

The Foundation must not leave business authority split ambiguously between UI/application guards and a more permissive directly exposed data path.

## 9.1 Required invariant

Every supported tenant-owned operation has one authoritative, testable access path proving all applicable conditions before success:

1. authenticated principal;
2. validated explicit Tenant;
3. active Membership or separately governed Platform Operator authority;
4. required Permission;
5. required Entitlement and applicable Limit semantics;
6. row/resource ownership and same-Tenant relationships;
7. operation-specific lifecycle preconditions.

## 9.2 Exposure rule

- database objects are revoke-by-default for application roles unless access is deliberately required;
- internal/domain tables without a direct Data API use case remain private/non-exposed or without usable direct grants;
- direct reads are allowed only through deliberately allowlisted objects with complete authoritative visibility rules;
- direct mutations are allowed only when the database-authoritative policy enforces the complete tenant + Permission + Entitlement + Limit + scope + lifecycle + relationship-integrity rules;
- when complete authoritative mutation policy is not safely expressible, the operation uses a narrow application command / transactional RPC / equivalent authoritative boundary;
- multi-write or mandatory-audit transitions use one transactional consistency boundary and constituent writes are not exposed as alternate bypass paths;
- privileged functions use least privilege, controlled execution grants, safe search-path behavior, and schema-qualified references where applicable;
- exposed views preserve the caller's effective authority;
- `service_role`/secret bypass credentials are server-only and never the normal tenant-user DAL or a Platform Operator identity.

ADR-008 contains the governing Authoritative Access Matrix for direct read/direct mutation/command/operator/system paths.

---

# 10. UX requirements for Platform Foundation

The Platform Foundation UI complies with `frontend-ux-baseline.md`.

## 10.1 Tenant selection

- multi-Tenant Users receive an explicit Tenant switcher/context indicator;
- single-Tenant Users may be auto-selected but still operate under validated explicit context;
- switching Tenant clears/reloads tenant-scoped screens and cached state;
- current Tenant is visually unambiguous in sensitive administration workflows.

## 10.2 Capability-disabled behavior

- normal navigation/actions for disabled optional Capabilities disappear or become structurally unavailable;
- direct navigation/API attempts still fail authoritatively;
- users receive a clear product-access message rather than misleading generic application error where disclosure is safe.

## 10.3 Control plane

- Tech Edge Operator surfaces are visually/structurally distinct from normal tenant administration;
- target Tenant is always visible before sensitive Operator actions;
- destructive/access-changing actions require appropriate confirmation.

## 10.4 Workflow continuity

- Platform workflows expose current state and available next actions;
- successful creation/update cannot leave a record with no governed completion, cancellation, recovery, or external-handoff path;
- records affected by Membership, Tenant status, Entitlement, Permission, or Limit changes have defined continuation/recovery behavior rather than becoming invisible stranded state.

---

# 11. Error and denial semantics

The application distinguishes internally between:

- unauthenticated;
- invalid/inactive Membership;
- invalid Tenant context;
- unauthorized Permission;
- Capability not entitled;
- commercial/resource Limit reached;
- Tenant suspended;
- lifecycle precondition failure;
- relationship-integrity failure;
- resource not found within authorized scope.

External messages may intentionally avoid leaking sensitive existence information, but server-side outcome and audit/diagnostics preserve the correct reason.

---

# 12. Critical Foundation invariants

Wave 1 is not Done unless all are true:

1. A User can belong to multiple Tenants without implicit selection becoming authorization.
2. Cross-Tenant read/write/export/search/inference is denied authoritatively.
3. Cross-Tenant foreign references between tenant-owned records cannot be persisted through supported paths.
4. Platform Operators and tenant roles are separate authority classes.
5. Infrastructure bypass credentials are not Platform Operator identity and are not the normal tenant-user DAL.
6. Entitlements and Permissions are independently enforced.
7. Direct data mutations cannot bypass required Permission/Entitlement/lifecycle rules.
8. Capability/package names do not enter Business Domain branching logic.
9. Entitlement disable/suspension never deletes customer data automatically.
10. Limits do not destructively trim existing data.
11. User/Employee identity coupling is not introduced by Platform Core.
12. Legal Entity remains domain-neutral; HR decides Employer semantics inside HR/Payroll.
13. Sites do not create a second permission system.
14. Existing tenant authority cannot silently change because a central default role template changed.
15. An operational Tenant cannot be left without a recoverable protected administrator.
16. Sensitive Platform changes are auditable without copying sensitive business payloads.
17. Mandatory audit is append-only to normal runtime authority and fail-closed with protected success where required.
18. Tenant/Legal Entity/Site lifecycle changes preserve historical references.
19. PLT-010 does not become a generic business-rules/configuration engine or own Domain rules.
20. No generic engine/infrastructure is added without a current Wave 1 requirement.
21. Commercial/optional Capabilities fail closed when no effective Entitlement grant exists.
22. Suspended/archived Tenants cannot perform normal tenant business operations; controlled Platform administration/recovery remains separately governed.
23. No Wave 1 lifecycle creates a stranded operational state without a supported terminal/closure or explicit handoff path.

---

# 13. Acceptance criteria / qualification matrix

## 13.1 Tenant onboarding, invitation, and Membership

- create Tenant and establish initial protected administrator authority atomically or through an explicit recoverable onboarding flow;
- onboarding reaches active success or explicit failed/cancelled/recovery outcome;
- invitation moves from pending to accepted/expired/revoked under authoritative claim semantics;
- expired/revoked invitation cannot grant access;
- one User can hold active Memberships in two Tenants;
- explicit switch selects an authorized Tenant context;
- requesting an unowned/inactive Tenant context is denied;
- inactive Membership is denied without deleting history;
- final protected administrator cannot self-remove, be deactivated, or be demoted until replacement authority exists;
- tenant suspension blocks normal operations without deleting data;
- tenant reactivation restores allowed operation without reconstructing Tenant identity/data.

## 13.2 Isolation and relational integrity

- Tenant A cannot read Tenant B resources;
- Tenant A cannot mutate Tenant B resources;
- Tenant A cannot export/search/infer Tenant B data through supported endpoints;
- a valid Tenant B resource identifier cannot be linked from a Tenant A tenant-owned record;
- privileged helpers/background jobs demonstrate explicit Tenant targeting;
- negative isolation and relationship-integrity tests run on a clean environment.

## 13.3 Authorization and access paths

- Tenant member without Permission is denied even when Capability is entitled;
- Tenant admin receives only defined Platform administration authority;
- tenant role assignments cannot grant Platform Operator authority;
- Platform Operator grant/revoke uses separately governed Platform authority and produces required audit;
- UI hiding alone is never the only enforcement evidence;
- direct-access bypass attempts fail when the application would deny the operation;
- implementation classifies each Platform operation according to the ADR-008 Authoritative Access Matrix;
- role-template change cannot silently alter an existing Tenant's effective authority.

## 13.4 Entitlements and Limits

- plan/bundle Entitlement can enable a Capability where used;
- explicit override can enable or deny according to precedence;
- absence of effective optional/commercial grant denies access;
- effective Entitlement is inspectable;
- Capability dependency violations are rejected;
- Limit blocks new growth at threshold;
- lowering Limit below current usage preserves existing data;
- disabling Capability preserves data/history while blocking prohibited operations;
- Capability disable/Limit change leaves in-flight records in defined visible/recoverable states rather than stranded hidden state.

## 13.5 Audit

- all mandatory Wave 1 sensitive events produce reviewable audit records;
- mandatory-audit protected mutation cannot commit/return success when success-audit persistence fails;
- normal tenant/application/Operator authority cannot UPDATE/DELETE persisted mandatory audit events;
- denied sensitive actions are captured where security value justifies it;
- payload review proves prohibited sensitive values are absent;
- actor, target Tenant, action, authoritative time, and outcome are attributable;
- exceptional audit maintenance is not exposed as a normal application mutation path.

## 13.6 PLT-010/domain ownership

- shared temporal/versioning convention can preserve immutable historical version references where a consumer requires it;
- Platform Core contains no HR/Payroll statutory rule catalog or generic policy DSL merely to satisfy future possibilities;
- a Domain can own/version its business configuration without moving the business rules into Platform Core.

## 13.7 UX

- representative Tenant admin workflows pass desktop/laptop and mobile acceptance appropriate to the surface;
- Tenant switching is unambiguous and safe;
- control-plane target Tenant is always clear;
- disabled Entitlement UX matches authoritative denial;
- representative workflow states show a valid next action, terminal outcome, or explicit external/operator handoff.

## 13.8 Reproducibility

- clean environment can reproduce Platform Foundation schema/configuration once implementation begins;
- migration order has no hidden manual production dependency;
- qualification evidence refers to the exact implementation revision and Frozen Spec revision.

---

# 14. Required supporting ADRs

Before this specification may become Frozen for Wave 1 implementation, the complete Platform Foundation architecture set must be Accepted:

- ADR-001 — Tenant, Legal Entity, and Site separation.
- ADR-002 — Explicit Tenant Context and authoritative isolation, including same-Tenant referential integrity.
- ADR-003 — Entitlement precedence, Limits, and non-destructive disable semantics.
- ADR-004 — Permission catalog, role-template stability, protected tenant administration, and Platform Operator separation.
- ADR-005 — Mandatory sensitive audit consistency and append-only runtime semantics.
- ADR-006 — Next.js / Node web runtime.
- ADR-007 — Supabase PostgreSQL / Auth / bounded Storage.
- ADR-008 — Authoritative data access and transaction boundaries.
- ADR-009 — Vercel/Supabase environment and preview isolation.
- ADR-010 — Frontend Design System foundation.

These ADRs are evaluated as one coherent Wave 1 implementation set. Accepting only behavioral ADRs does not authorize Product Code.

---

# 15. Freeze and implementation gate

This specification may move from `Proposed` to `Frozen` only when:

- ADR-001 through ADR-010 are Accepted;
- the 2026-09-05 freeze-review constraints are incorporated or explicitly remain normative without contradiction;
- no material Tenant/isolation/Membership/authorization/Entitlement/Operator/audit/data-access behavior remains unresolved;
- lifecycle completion/handoff behavior for every material Wave 1 process is explicit;
- security/privacy review finds no contradiction with governing baselines;
- acceptance criteria are testable with the selected implementation approach;
- selected technology choices can satisfy these invariants without weakening them.

Once this Platform Foundation Spec is Frozen and ADR-001 through ADR-010 are Accepted, **Wave 1 — Platform Spine may begin** even while later Business Domain Specs are still being authored, because Wave 1 is domain-neutral.

No later Business Domain Product Code may begin until its own governing Product Spec is Frozen.

The umbrella Phase 0D is fully complete only after all implementation-ready V1 Product Specs required by the accepted wave plan have passed their respective freeze gates.
