# Edara SaaS Extraction Audit

## Status

**Completed for Phase 0B — donor-platform extraction audit.**

This audit approves architectural lessons and target redesign directions. It does **not** approve copying the donor repository, its schema, migrations, RPC set, or application code wholesale.

Any later direct code reuse must be qualified component-by-component against the active Business Platform specifications and quality gates.

## Audit references

- Target repository baseline reviewed from: `business-platform` main at `cf17bd55c32f2c0f38c5d7e1d3a31165f488e157`.
- Donor repository reviewed from: `edara-saas` at `ae97cae81b68f91463e8cfe2460dba5479d88494`.
- Audit date: 2026-09-04.

The donor revision is recorded so later changes to the donor do not silently change the evidence behind this audit.

## Purpose

Determine which platform ideas and implementation patterns from Edara SaaS should inform Business Platform while preventing service-center assumptions, historical technical debt, or accidental complexity from becoming part of the new foundation.

Edara SaaS is treated as a **donor platform**, not a base application.

## Classification model

Every reviewed area is classified as one of:

- **Reuse** — implementation is sufficiently generic and qualified to adopt with minimal adaptation.
- **Refactor** — the implementation/pattern has high value, but the new platform should redesign/harden it before adoption.
- **Concept Only** — preserve the product/architecture lesson, but implement the capability afresh.
- **Reject** — do not carry the pattern into the new platform for the active scope.

### Important result

No reviewed subsystem is approved for blind/direct code reuse in Phase 0B.

This is not a negative finding. The donor's largest value is that it already exposed real SaaS concerns — tenancy, entitlements, subscription lifecycle, control-plane operations, authorization, RLS failure modes, and migration complexity — so Business Platform can start with a cleaner model instead of rediscovering them.

---

# Executive conclusion

The donor validates several strategic decisions already present in the Business Platform blueprint:

1. Multi-tenancy must be explicit and first-class.
2. A user may belong to multiple tenants/organizations.
3. Commercial packages should resolve into stable capabilities/entitlements.
4. Tenant-specific subscription overrides are commercially valuable.
5. Subscription lifecycle needs explicit state/history rather than a boolean `is_paid` model.
6. Platform administration is a separate control-plane concern from tenant business operations.
7. Entitlements and user authorization are separate concerns.
8. Shared organization locations/branches are useful platform concepts, but their business policies must remain domain-owned.
9. Sensitive platform actions need authoritative security and audit behavior.
10. Migration/RLS discipline must be designed from the first schema rather than repaired after feature growth.

The donor also demonstrates patterns that must **not** be inherited:

- implicit tenant selection through `LIMIT 1` or “first membership” semantics;
- fixed product-wide roles as the final authorization model;
- branch-local permission systems that compete with the main authorization model;
- domain-specific fields inside shared tenant/platform models;
- hard-coded commercial pricing, discount, tax, trial, renewal, and reactivation rules;
- generic full-row audit capture for every sensitive table;
- silent/fail-open audit behavior for actions whose audit record is itself a required invariant;
- broad use of privileged database functions without a deliberately minimal security surface;
- copying historical setup/fix scripts as a new migration baseline;
- building every operational/security utility in the business database merely because it can be built there.

---

# Final adoption matrix

| Donor area | Classification | Adoption priority | What is valuable | What must change in Business Platform |
|---|---|---:|---|---|
| Tenant / organization identity | **Refactor** | Critical | Explicit tenant entity, tenant ownership, active/inactive lifecycle | Reframe around domain-neutral Organization/Tenant model; remove service-center semantics; define lifecycle independently from billing status |
| Tenant membership | **Refactor** | Critical | User-to-tenant membership and multi-tenant membership support | Require explicit tenant context for tenant-scoped operations; never infer tenant from first membership; define protected ownership/admin semantics separately from business roles |
| Tenant switcher / active tenant UX | **Concept Only / Refactor** | High | User can select among authorized tenants | Client-selected tenant is navigation context only; backend/database independently verifies membership; avoid full-reload/localStorage coupling as the architecture |
| Feature definitions / capability catalog | **Refactor** | Critical | Stable keys, default state, limits, categories | Make definitions domain-neutral and avoid duplicating presentation metadata into plan rows; distinguish entitlement metadata from UI navigation metadata where needed |
| Plan feature assignments | **Refactor** | Critical | Plans are compositions of capabilities and limits | Model as plan entitlements rather than product-specific “modules”; preserve explicit limits and effective behavior |
| Subscription-specific feature overrides | **Refactor — highest-value donor pattern** | Critical | Override precedence and per-subscription enable/disable/limits | Preserve precedence semantics, but require explicit tenant/subscription context, auditable changes, typed limit semantics, and invariant tests |
| Entitlement resolution precedence | **Refactor** | Critical | `Subscription Override → Plan → Default` concept | Freeze exact precedence and behavior in a dedicated entitlement spec/ADR; do not infer active subscription ambiguously |
| Feature-gated navigation/UI | **Concept Only / Refactor** | High | Progressive disclosure based on enabled capability set | Treat UI gating as UX only, never authorization; centralize a tenant-aware entitlement snapshot/provider |
| Subscription lifecycle | **Refactor** | High | Active/trial/expiry/grace/suspension/reactivation history and reminders | Separate lifecycle state from hard-coded commercial actions; configure or explicitly spec renewal/grace semantics; state transitions authoritative and tested |
| Subscription history | **Refactor** | High | Preserve why/when subscription state changed | Use structured transition/event history sufficient for support and audit; avoid relying only on free-text notes |
| Trial behavior | **Concept Only / Refactor** | Medium | Trial as first-class subscription state | Trial availability/duration is commercial configuration, not a platform constant |
| Subscription reminders | **Concept Only** | Medium | Reminder scheduling around lifecycle | Implement through notification/job infrastructure only when required; cadence/content not embedded in core subscription invariants |
| Super-admin / platform control plane | **Refactor** | Critical | Separate operator surface for tenants, plans, subscriptions, billing and platform health | Rebuild against new domain-neutral core; enforce strict platform-operator privileges and auditable sensitive actions |
| Fixed roles `owner/admin/manager/member` | **Concept Only / Reject as final model** | Critical | Simple protected owner/admin hierarchy is understandable | Do not make fixed roles the universal business authorization model; introduce tenant-scoped roles/templates and permissions appropriate to domains |
| Permission catalog | **Refactor** | Critical | Permission keys with action/resource semantics | Namespaces align to platform/domain ownership; keys are stable security contracts, not navigation labels |
| Role-permission defaults | **Refactor** | High | Reusable role templates reduce setup cost | Separate system templates from tenant-defined roles; do not hard-code all tenants to one role matrix |
| Per-user permission overrides | **Concept Only / Optional** | Low initially | Supports exceptional access cases | Defer unless concrete V1 need proves value; overrides increase explainability/support complexity and must not be the default authorization model |
| Branch / location entity | **Refactor** | High | Tenant-scoped named locations/sites with address/code/status | Use neutral Organization Site/Location concept; keep HR working-time policy and service-center configuration out of shared location record unless truly shared |
| Branch-user assignment | **Concept Only** | Medium | Location-scoped user access can be useful | Model scope within the main authorization system; do not create a second branch role + JSON permission system |
| Branch working-hours JSON | **Reject from Platform Core** | — | Demonstrates location-specific policy need | Working schedules belong to the owning business domain (HR/time or operations), not generic Platform Core |
| Plan usage/limits | **Refactor** | High | User/branch/resource limit accounting | Build explicit usage metrics only for limits we sell/enforce; avoid generic usage infrastructure before a real entitlement requires it |
| Billing invoices/payments for platform subscriptions | **Concept Only / Refactor** | Medium | Tech Edge needs commercial subscription operations | Keep as **Platform Commercial/Control Plane**, separate from future tenant Finance/Accounting domain; define only V1 commercial workflow actually needed |
| Manual payment methods / payment proof | **Concept Only** | Low/Medium | Useful for local manual subscription collection | Add only if active commercial process requires it; payment account details are confidential; storage/access and approval need dedicated policy |
| Coupons/discounts | **Concept Only** | Low | Demonstrates pricing flexibility | Defer until commercial need; never hard-code discount formulas into entitlement or domain logic |
| Hard-coded billing cycles/pricing formulas/tax | **Reject** | — | None as architecture | Pricing/tax/discount semantics are configuration or explicit commercial rules; never implicit platform constants |
| Audit log concept | **Refactor** | Critical for sensitive operations | Actor, tenant, action, entity, time and context are valuable | Design event-specific audit contracts; redact/minimize payloads; use correct tenant context; define retention by data class/use case |
| Generic full-row OLD/NEW audit triggers | **Reject as default** | — | Easy broad coverage | Can leak payroll/PII/secrets, grows storage and obscures intent; sensitive workflows need deliberately shaped audit events |
| Fail-open generic audit writes | **Reject for audit-required invariants** | — | Prevents telemetry failures blocking ordinary business operations | Distinguish optional telemetry from mandatory audit; protected transitions need a reliable consistency strategy |
| Notifications foundation | **Concept Only / Refactor** | Medium | Platform and tenant notifications are useful | Keep transport/content/lifecycle separate from domain state transitions; domain expresses intent/event rather than owning every delivery detail |
| Realtime subscriptions | **Concept Only** | Low until needed | Can improve live administration UX | Enable realtime only when a workflow needs it; do not make broad publication part of baseline architecture |
| `SECURITY DEFINER` helper pattern for RLS | **Refactor cautiously** | Critical | Can break recursive RLS and centralize trusted tenant checks | Minimize privileged functions, lock search paths, revoke unnecessary execution, keep narrow contracts, and cover with negative cross-tenant tests |
| Historical RLS recursion fixes | **Concept Only — lesson** | Critical | Concrete evidence of recursive-policy failure modes | Design a small non-recursive isolation pattern from first migration and rehearse it on a fresh DB |
| Database rate limiting | **Reject from default core** | — | Shows abuse-protection concern | Prefer platform/gateway/auth-provider mechanisms unless a concrete operation requires DB-authoritative limiting |
| Failed-login tracking/account locking in app DB | **Reject from default core** | — | Shows security intent | Prefer identity/auth provider controls; do not duplicate authentication security state without a demonstrated gap |
| System health/admin metrics | **Concept Only** | Low initially | Operational visibility matters | Add observability proportional to active deployment and support needs; avoid custom health infrastructure before meaningful signals exist |
| Generic cleanup jobs | **Concept Only** | Low | Background maintenance eventually necessary | Retention follows data classification/business/compliance rules; do not use one arbitrary cleanup duration globally |
| Storage tenant-folder isolation | **Refactor** | High when files appear | Tenant-scoped object ownership is useful | Centralize storage authorization conventions; private by default for sensitive files; path naming alone is not an authorization mechanism |
| Service-center CRM/vehicles/work orders | **Reject from HR V1 / Platform Core** | — | Future donor material for other domains | Revisit only when the corresponding CRM/Operations domain becomes active |
| Donor migration/setup history | **Reject as new baseline** | — | Excellent source of lessons and regression cases | Start Business Platform with clean ordered migrations representing target model; preserve donor fixes as test cases/risks, not inherited history |
| Donor consolidated clone schema | **Reference only** | — | Confirms final platform breadth and operational dependencies | Do not bootstrap Business Platform by importing donor dump; design minimum target schema from frozen specs |

---

# Detailed findings

## 1. Tenancy and membership

### Valuable donor pattern

Edara SaaS correctly evolved toward:

- a tenant entity;
- user membership records;
- a user being able to participate in more than one tenant;
- tenant switching in the application;
- backend membership checks before returning a selected tenant.

This validates the new platform's requirement that tenant context is first-class.

### Main donor risk

Several donor RPCs historically resolve the “current tenant” using the first active membership or similar implicit selection behavior. That becomes ambiguous as soon as one user belongs to multiple organizations.

### Target rule

Business Platform must distinguish:

- **authenticated identity** — who the user is;
- **authorized memberships** — which organizations the user may access;
- **active tenant context** — which organization the current request intends to operate on;
- **authoritative tenant isolation** — database/server verification that the identity may act on that tenant.

An active tenant identifier stored in client state, URL state, cookie, or session is context — never proof of authorization.

### Onboarding lesson

The donor has flows that combine tenant creation, owner membership, trial subscription, subscription history and invoice creation in one broad onboarding operation.

The new platform should preserve transactional coherence where needed but avoid making Organization creation conceptually dependent on billing artifacts. Platform identity/membership and commercial subscription orchestration should have explicit boundaries.

---

## 2. Entitlements

This is the strongest reusable donor design area.

### Preserve

The donor demonstrates a commercially useful precedence model:

1. subscription-specific override;
2. plan assignment;
3. capability default.

It also supports numerical limits in addition to boolean capability state.

This maps closely to the Business Platform principle that internal architecture understands capabilities/entitlements while marketing bundles may change freely.

### Redesign

The new model should avoid:

- deriving a subscription from an ambiguous “first tenant” query;
- duplicating capability names/descriptions into every plan assignment;
- coupling capability categories to a historical service-center navigation taxonomy;
- treating every possible resource limit as a field on a Plan table;
- assuming every core/default capability is permanently free/available without product review.

### Target conceptual model

A likely target shape to validate in a later frozen spec is:

```text
CapabilityDefinition
        |
        +---- PlanEntitlement
        |
        +---- SubscriptionEntitlementOverride

Tenant/Organization
        |
        +---- Subscription ---- Plan
```

The exact schema is **not frozen by this audit**.

### Entitlements versus permissions

The donor reinforces the need to keep these checks separate:

- entitlement: may this tenant use the capability?
- authorization: may this user perform this action inside the tenant?

Frontend navigation may use both to reduce clutter, but authoritative operations enforce both at the appropriate trusted layer.

---

## 3. Subscription lifecycle

The donor has a materially useful lifecycle instead of a simplistic paid/unpaid flag.

Useful concepts include:

- trial;
- active;
- expiry;
- grace period;
- suspension;
- reactivation;
- transition history;
- expiry reminders.

### What must not be inherited

Some donor transitions embed commercial behavior such as fixed extension periods or reminder schedules directly in implementation logic.

For Business Platform:

- state-transition invariants belong to the subscription domain;
- commercial terms such as duration, grace, renewal behavior and price belong to explicitly governed product/commercial rules;
- reminders are side effects of lifecycle facts, not lifecycle truth themselves;
- lifecycle processing must be idempotent and safe under retries/concurrency.

---

## 4. Authorization and roles

### Valuable donor pattern

The donor moved beyond a single role string toward:

```text
Permission catalog
    -> role defaults
    -> optional user override
```

Permission checks also demonstrate the correct idea that membership in the requested tenant must be established before evaluating permissions.

### Why direct reuse is rejected

The donor authorization system still carries fixed roles such as owner/admin/manager/member and product-specific module categories. Separately, branch assignment introduced another role/permission mechanism.

That can lead to a split-brain authorization model where effective access is difficult to explain.

### Target direction

Business Platform should later freeze a model containing at least these conceptual layers:

- protected platform/tenant ownership semantics;
- tenant-scoped roles or role templates;
- stable permission keys owned by Platform Core or a Business Domain;
- explicit resource/site scope where required;
- user-specific overrides only if a demonstrated use case justifies the extra complexity.

A role must not automatically be an HR job title. Employment position and application authorization are different concepts.

---

## 5. Tenant isolation and RLS

The donor contains important historical evidence: tenant-user and profile policies required multiple later fixes to resolve recursive RLS behavior and permission edge cases.

This is a major lesson, not a reason to avoid database enforcement.

### Target direction

The new platform should begin with:

- a deliberately small tenant-isolation helper surface;
- non-recursive policy design;
- explicit tenant IDs in tenant-scoped contracts;
- secure function search paths and minimal privilege;
- default-deny behavior for unrecognized tenant context;
- cross-tenant negative tests from the first tenant-owned table;
- fresh-database migration rehearsal.

### Additional caution

A donor rule allowing same-tenant users broad teammate/profile visibility must not be assumed appropriate for HR. HR contains salary, disciplinary, identity and other confidential data that require finer authorization than “same tenant”.

---

## 6. Organization locations / branches

The donor proves that organizations commonly need named branches/sites and user/site scoping.

The shared concept is valuable, but the new platform should avoid putting every domain's branch policy into Platform Core.

### Platform-owned location facts may include

- organization/tenant owner;
- name/code;
- status;
- address/geographic coordinates where needed;
- basic contact information;
- main/default site designation where justified.

### Domain-owned facts should remain outside generic location core

Examples:

- HR working schedule;
- attendance geofence policy;
- service-center operational hours;
- inventory-specific warehouse rules;
- sales-territory rules.

Those domains can reference an Organization Site without turning the site record into a universal JSON settings bucket.

---

## 7. Platform commercial control plane

The donor contains substantial real work around:

- plans;
- subscriptions;
- invoices;
- payments;
- payment proofs;
- coupons;
- lifecycle administration;
- administrative dashboards/reports/settings.

This validates a separate Tech Edge operator/control-plane surface.

### Boundary with future Finance domain

Platform subscription billing answers:

> How does Tech Edge commercially provide and collect for access to this SaaS product?

Future tenant Finance/Accounting answers:

> How does a customer organization manage its own accounting and financial books?

These remain separate domains even if both contain words such as invoice or payment.

### V1 rule

Do not rebuild the donor's entire billing suite automatically.

The first commercial workflow should be specified from Tech Edge's actual selling/collection process. Add payment proofs, coupons, multiple cycles, automatic tax handling, or gateway integration only when active commercial requirements require them.

---

## 8. Audit

The donor audit work contains valuable fields and operational experience, but the implementation history exposes two important risks.

### Risk A — generic row snapshots

Capturing entire OLD/NEW rows can unintentionally store:

- salaries;
- identity data;
- secrets or tokens accidentally persisted in a row;
- confidential metadata;
- large payloads unrelated to the audit purpose.

The new platform should design meaningful audit events with deliberate payload minimization/redaction.

### Risk B — fail-open versus mandatory audit

The donor later introduced behavior that avoids failing the original business action if generic audit logging fails. That can be correct for telemetry, but not necessarily for a sensitive workflow where auditable completion is a required invariant.

Business Platform must distinguish:

- **best-effort telemetry/observability**, which may fail independently;
- **required business/security audit**, which requires a reliable consistency strategy with the protected action.

Payroll finalization, permission changes, tenant administration, and other sensitive transitions need explicit treatment in their frozen specs.

---

## 9. Notifications, jobs and realtime

The donor proves that lifecycle reminders, admin notifications, realtime updates and maintenance jobs become useful as a SaaS product matures.

They should not all become mandatory Platform Core infrastructure on day one.

### Target rule

Build the smallest shared mechanism required by active workflows.

A domain should normally express a notification intent/event; delivery channels and user notification UX remain a shared concern where reuse is real.

Realtime is a UX/performance capability, not a correctness mechanism. Authoritative state remains in the trusted data/domain layer.

---

## 10. Security utility layer

The donor includes database-level rate limiting, failed-login tracking, validation helpers, system-health views and maintenance utilities.

These are useful evidence of operational concerns but should not be copied automatically.

### Prefer platform-native responsibility first

Where the selected auth/deployment stack already provides mature controls for authentication throttling, abuse protection, secret storage, logs or health monitoring, use them instead of recreating parallel business-database systems.

Only introduce a custom database-authoritative mechanism when the product requirement actually needs database-level semantics.

---

## 11. Frontend donor patterns

Useful patterns found in the donor UI include:

- centralized tenant context;
- multi-tenant switcher behavior;
- centralized feature/capability provider;
- navigation filtered by available capabilities;
- shared admin/tenant/public surface separation.

These are **conceptual donors**, not UI code baselines.

Business Platform already has a stronger Frontend/UX Baseline requiring adaptive desktop/mobile composition and centrally governed reusable primitives. The donor frontend predates that baseline and must not define the new design system or responsive architecture.

---

# Migration and database lessons

The donor maintains setup scripts, migrations, consolidated dumps, seed data, Edge Functions and operational setup documentation. It also contains multiple later repair scripts for RLS, audit, subscription selection, permissions and plan limits.

This history is extremely useful as a **regression-case catalog**.

It is not suitable as the new platform's migration history.

## Adopt these process lessons

- migrations must be ordered and reproducible;
- dependencies between helpers/policies/functions must be explicit;
- destructive/replacement behavior must be deliberate;
- fresh-environment rehearsal is required;
- RLS must be tested for both intended access and forbidden cross-tenant access;
- generated/final schema snapshots may aid diagnostics but do not replace migrations as source of truth;
- operational functions/jobs/storage policies are part of deployability and must be reproducible, not remembered manual steps.

## Do not mechanically adopt

- “idempotent setup scripts” as a substitute for immutable production migration history;
- repeated drop/recreate scripts that erase the historical reason for a change;
- huge consolidated schema imports as the normal foundation workflow;
- manual dashboard configuration that is not captured/verified by deployable configuration when the selected stack allows automation.

---

# Donor patterns explicitly rejected for the new foundation

The following should be treated as prohibited defaults unless a later accepted decision explicitly reintroduces them for a demonstrated reason:

1. Forking `edara-saas` as the Business Platform base application.
2. Importing the donor consolidated schema into the new database.
3. Copying service-center domain tables into Platform Core.
4. Implicit “current tenant” resolution by first membership or `LIMIT 1`.
5. Treating client-selected tenant state as authorization.
6. Fixed owner/admin/manager/member as the universal domain authorization model.
7. A second permission system inside branches/sites.
8. Whole-row generic audit snapshots as the default for sensitive entities.
9. Silent best-effort audit for an operation whose audit trail is mandatory.
10. Hard-coded subscription tax, discount, trial, billing-cycle or reactivation rules.
11. Database-based login lock/rate-limit infrastructure without a demonstrated need beyond the selected identity/platform provider.
12. Publishing every potentially useful table through Realtime by default.
13. Global arbitrary retention/cleanup durations for all classes of data.
14. Business-domain configuration hidden inside generic Platform Core JSON merely to avoid defining a proper domain model.

---

# Target extraction map

The audit recommends the following order when later writing frozen Platform Foundation specifications.

```text
1. Organization / Tenant Identity
        |
2. Membership + Explicit Tenant Context
        |
3. Tenant Isolation / Security Enforcement Pattern
        |
4. Capability Catalog + Entitlement Resolution
        |
5. Subscription Lifecycle / Commercial Access
        |
6. Authorization Roles + Permissions
        |
7. Organization Sites / Locations
        |
8. Platform Operator Control Plane
        |
9. Audit / Notifications / Background Operations
```

This is a dependency-oriented planning order, not an instruction to implement every subsystem before HR work begins.

The Complexity Budget still applies: only the minimum production-grade subset required by the active Commercial V1 should be implemented.

---

# Recommended future ADR/spec candidates

This audit does **not** accept these technical decisions by itself. It identifies topics that deserve explicit resolution before dependent implementation begins.

1. **Tenant context and isolation contract**
   - explicit tenant selection;
   - authoritative membership check;
   - database enforcement/RLS pattern;
   - trusted helper surface.

2. **Entitlement resolution model**
   - capability identity;
   - plan entitlements;
   - subscription overrides;
   - boolean versus limit semantics;
   - precedence;
   - behavior when subscription state changes.

3. **Authorization model**
   - protected owner semantics;
   - tenant role templates versus tenant-defined roles;
   - permission key ownership/namespacing;
   - resource/site scoping;
   - whether V1 needs per-user overrides.

4. **Platform commercial subscription boundary**
   - subscription state machine;
   - grace/suspension semantics;
   - manual versus automated commercial operations;
   - separation from tenant Finance domain.

5. **Audit consistency model**
   - mandatory audit events;
   - best-effort telemetry distinction;
   - payload minimization/redaction;
   - retention policy ownership.

6. **Organization Site model**
   - platform-owned location identity facts;
   - domain-owned policy references;
   - authorization/location scoping if required by V1.

---

# Qualification rule for any later direct code reuse

A donor component may move from Refactor/Concept to direct **Reuse** only if all of the following are true:

1. The active Business Platform capability/spec actually requires it.
2. The code is independent from service-center domain assumptions or those assumptions are removed.
3. Tenant context is explicit and compatible with the accepted isolation model.
4. Authorization is enforced at the authoritative boundary.
5. `SECURITY DEFINER`/privileged behavior, if present, has a narrow reviewed contract and safe search path/grants.
6. Sensitive data handling is compatible with the Data Classification and Privacy Baseline.
7. Persistent data and migrations are reproducible from a fresh supported environment.
8. Relevant negative/security/regression tests exist in the new repository.
9. The implementation does not introduce a competing permission/configuration model.
10. The adopted code is simpler and lower risk than implementing the accepted target model afresh.

If these conditions are not met, the donor remains evidence/design input rather than implementation source.

---

# Phase 0B final decision

**Edara SaaS is formally accepted as a donor platform and formally rejected as the base project.**

The high-value extraction is:

- multi-tenant organization/membership concept;
- tenant switching with authoritative backend membership validation;
- capability catalog and entitlement model;
- subscription override precedence and limits;
- subscription lifecycle/history;
- separate platform operator/control-plane concept;
- permission catalog and role-default pattern;
- organization-site concept;
- commercial subscription billing patterns;
- audit/notification/operational lessons;
- the donor's RLS/migration repair history as regression-risk evidence.

The new Business Platform should implement these ideas against its own frozen architecture/specifications and quality baselines rather than inherit the donor's accumulated schema and implementation history.

## Phase 0B completion criteria

- [x] Donor revision pinned.
- [x] Core platform subsystems inspected.
- [x] Tenant/membership assumptions reviewed.
- [x] Entitlement resolution and subscription overrides reviewed.
- [x] Subscription lifecycle reviewed.
- [x] Authorization/role model reviewed.
- [x] Branch/location model reviewed.
- [x] Audit/RLS/security history reviewed.
- [x] Billing/control-plane boundary reviewed.
- [x] Frontend tenant/feature-context patterns reviewed.
- [x] Consolidated/deployment footprint reviewed.
- [x] Reuse/Refactor/Concept Only/Reject matrix completed.
- [x] Explicit no-copy risks documented.
- [x] Candidate future ADR/spec decisions identified.

**Phase 0B audit work is complete and ready for product/architecture review.**
