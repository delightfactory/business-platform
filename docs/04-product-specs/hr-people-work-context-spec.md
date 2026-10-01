# HR People & Work Context Specification

## Status

**Frozen — final documentation alignment approved 2026-09-29; §7's bounded own-Employee link use is clarified by Accepted DEC-025.**

This specification governs Wave 2 — People & Work Context. It converts the accepted HR People scope into implementation-ready behavior without making Employee identity a Platform identity and without requiring Contracts/Documents/ESS.

## Governing inputs

- Accepted Product Charter, Product Principles, Master Product Blueprint and V1 Capability Decomposition.
- Frozen Platform Foundation Specification and Accepted ADR-001 through ADR-010.
- Accepted V1 Implementation Waves.
- DEC-005: digital Contract Management is optional.
- DEC-012: Payroll depends on People/compensation/payroll configuration, not on Attendance/Leave/Employee Finance entitlements.
- DEC-016: no dead-end workflows.
- Frontend/UX, Security, Privacy, Definition of Ready and Definition of Done baselines.
- Product rule: operational complexity must be absorbed by the product; ordinary users should see business intent, current state and next action rather than implementation mechanics.

## Outcome

An authorized HR operator can create or import a worker, establish the minimum employment, organization, location, compensation and work-policy context required by downstream attendance/payroll, change those facts over time without rewriting history, and safely end the employment relationship.

## Scope

This specification covers:

- HRP-001 Employee Core.
- HRP-002 Departments / jobs / reporting context.
- HRP-003 Employment and compensation facts.
- HRP-004 optional Employee ↔ User link foundation.
- HRP-005 workforce bulk import.
- HRT-001 work policies and shift assignment context needed before Attendance interpretation.

## Explicit non-goals

V1 People does not require:

- digital employment contracts or contract-document lifecycle;
- general employee document management;
- recruitment, performance, training or talent management;
- a generic organization-graph engine;
- unrestricted custom fields or dynamic forms;
- full ESS/MSS;
- employee login accounts for ordinary workforce records;
- arbitrary formula/rules scripting.

## Domain ownership

Platform owns Tenant, Legal Entity, Site, authenticated User, Membership and Platform authorization primitives.

HR / People owns Employee, Employment, HR organization context, compensation facts and work assignment.

A Platform Legal Entity becomes an **Employer** only through an HR Employment relationship. HR must not move employer/payroll attributes into Platform Legal Entity.

## 1. Employee identity

An Employee is the stable workforce identity inside one Tenant.

Required V1 facts:

- immutable internal identity;
- Tenant ownership;
- unique human/business employee code within the Tenant;
- display/full name;
- active workforce status;
- basic contact/identity data only when required by an active workflow;
- created/updated provenance.

Rules:

- Employee is not a User and does not require Auth identity;
- employee code is visible and searchable; internal UUIDs are not ordinary UI concepts;
- National ID, insurance number and other sensitive identifiers are optional until a workflow requires them and are handled as Confidential data;
- an Employee record is never destructively deleted after payroll/attendance/finance history exists;
- duplicate prevention uses employee code plus bounded identity checks; similarity warnings may assist users but never merge records automatically.

### Employee lifecycle

V1 Employee status is intentionally small:

- `active` — participates in active workforce operations;
- `inactive` — retained but excluded from new normal workforce operations;
- `ended` — employment has ended; historical records remain visible according to permission.

Reactivation of an inactive Employee is explicit and audited where sensitive. An ended Employment is not silently reopened; a new Employment relationship is created when rehiring is required.

## 2. Employment relationship

Employment is a distinct effective-dated relationship between an Employee and an Employer Legal Entity.

Minimum V1 facts:

- Employee;
- Employer Legal Entity;
- employment start date;
- optional end date;
- employment status;
- pay basis;
- base compensation;
- payroll eligibility;
- statutory/payroll identifiers only when needed.

Supported V1 pay bases:

- `monthly`;
- `daily`.

Hourly and piece-rate pay bases are deferred until a concrete customer requirement justifies their additional payroll semantics. Overtime may still be valued by an hourly-derived rate in Payroll without making the employee's primary pay basis hourly.

Rules:

- one Employee may have historical Employment records;
- overlapping active Employment relationships for the same Employee + Employer are rejected unless a later specification explicitly introduces concurrent employment;
- start/end changes that would affect a locked payroll period cannot silently rewrite the locked result;
- ending Employment preserves historical pay/work context and exposes downstream settlement/payroll implications;
- Contract Management is not required to create or operate Employment.

## 3. HR organization context

### Departments

V1 supports Tenant-owned departments with:

- code/name;
- active/inactive lifecycle;
- optional parent department for a simple hierarchy.

The hierarchy must prevent cycles. It is HR context, not a Platform-wide organization graph.

### Jobs

V1 supports a lightweight Job/Position catalog with:

- code/name;
- active/inactive lifecycle;
- optional department association.

Job title is not application authorization. Changing a job never silently changes permissions.

### Reporting context

An Employee may have one effective primary manager/reporting Employee reference when needed for bounded review UX.

Reporting links:

- must remain in the same Tenant;
- do not create application permissions by themselves;
- cannot form self-reference;
- are not a generic matrix-organization engine.

## 4. Work assignment

A Work Assignment binds an Employment to operational context over an effective period:

- Site;
- Department;
- Job;
- optional manager;
- Work Policy / Shift assignment when Attendance is enabled.

Assignments are effective-dated so a transfer does not rewrite prior attendance/payroll context.

Rules:

- there is at most one primary effective assignment for an Employment at an instant;
- assignment changes close/supersede the prior interval;
- cross-Tenant references are impossible through authoritative constraints/commands;
- downstream finalized records retain the historical assignment/context they consumed.

## 5. Compensation facts

Employment owns the base compensation fact required by Payroll.

Required behavior:

- amount uses exact decimal money semantics;
- currency is explicit; Egypt V1 payroll uses EGP;
- compensation is effective-dated;
- changing compensation creates/supersedes an effective version rather than rewriting history consumed by locked Payroll;
- recurring allowances/deductions beyond base compensation are owned by Payroll configuration, not hidden as arbitrary People fields;
- an optional social-insurance contributory wage fact may be stored when required, but the applicable statutory limits/rules remain Payroll/Compliance-owned.

Backdating a compensation change into a period already consumed by locked Payroll does not mutate history. The system surfaces a correction requirement to Payroll.

## 6. Work Policy / shift context

Wave 2 establishes the bounded named Work Policy and Shift templates needed for assignment when Attendance is enabled; detailed attendance interpretation is governed by the Attendance & Leave Spec. An Employee and Employment can be created, and Payroll can operate, without an Attendance entitlement or Work Policy assignment.

V1 Work Policy may reference:

- ordinary workweek;
- fixed shift template(s);
- timezone/site context;
- lateness/early-leave/overtime policy references defined by the Time domain.

A People screen must not expose raw attendance-rule internals. The HR operator selects a named policy such as “Factory day shift” and may open advanced policy setup only with the relevant permission.

## 7. Employee ↔ User link

Linking an Employee to an authenticated User is optional.

Rules:

- link requires same Tenant authority;
- one active Employee ↔ User link per Tenant is the default V1 invariant;
- unlinking does not delete either Employee or User;
- Employee status does not itself grant/revoke Tenant Membership or permissions;
- mobile attendance may require the link, while ordinary payroll/attendance records do not.
- the bounded Cube 3 own-Leave surface may use the link to show only that user's own Employee profile, Leave, and balance; it requires `people.self.view` and Leave-specific self permissions, plus current same-Tenant membership/entitlement checks;
- the link grants no `people.view`, People-management authority, access to another Employee, Tenant Membership, or permission by itself. A missing or inactive link denies the own-Employee surface.

## 8. Workforce import

V1 provides a safe spreadsheet import for People onboarding.

Flow:

1. upload a supported template/file;
2. map/confirm columns when needed;
3. validate all rows without committing partial hidden results;
4. show a human-readable summary: ready / warning / rejected;
5. user confirms;
6. valid rows commit through the same authoritative invariants as manual entry;
7. downloadable reject report explains row-level errors.

Rules:

- no direct database import bypass;
- employee codes and Tenant relationships are validated;
- ambiguous duplicates are rejected for review, not auto-merged;
- unknown departments/jobs/sites may be created only through an explicit allowed import option; default behavior is reject-with-guidance;
- a failed import does not leave invisible half-created workforce state.

## 9. Operational simplicity / UX contract

People workflows must be simpler than the underlying data model.

Required UX behavior:

- “Add employee” asks only for the minimum facts required for the user's selected outcome;
- optional and advanced fields are progressively disclosed;
- if the Tenant has one Employer/Site, safe defaults are preselected rather than forcing redundant choices;
- technical IDs, effective-interval mechanics and state-machine names are hidden from normal users;
- derived values are calculated rather than re-entered;
- users see plain-language consequences before sensitive changes such as end employment or backdated pay change;
- screens emphasize current state and next action, not every possible capability;
- a small company can operate Employee + Attendance + Payroll without creating contracts, user accounts, complex org charts or advanced approvals.

Complexity shielding must not hide material financial/security consequences. The product explains them in business language at the decision point.

## 10. Permissions

Domain permission families must include at least:

- people.view;
- people.self.view (only the bounded, own linked-Employee view defined by the Cube 3 Leave amendment);
- people.manage;
- employment.manage;
- compensation.view;
- compensation.manage;
- org_context.manage;
- workforce_import.execute.

Exact key spelling may be normalized during implementation, but compensation access must be separately controllable from basic employee-directory access.

## 11. Workflow Completion Maps

### Create/onboard Employee

`entry -> validate -> active Employee + Employment + Assignment`

Failure ends in a visible validation/reject state with no hidden partial success.

### Transfer/change assignment

`current assignment -> schedule effective change -> new assignment effective -> prior assignment historical`

A cancelled future change returns to the prior effective state.

### Compensation change

`current compensation -> future/backdated change -> validation -> new effective version`

If a locked payroll is affected, the change is preserved as a correction requirement rather than rewriting the locked run.

### End employment

`active Employment -> end action with effective date -> ended`

The system shows unresolved payroll/finance/leave items. V1 may hand final-settlement items to Payroll/manual approved adjustment where specialized termination calculation is outside scope, but the Employment cannot remain in an ownerless “ending” state.

### Rehire

`ended Employee -> create new Employment -> active`

Historical Employment remains immutable.

## 12. Acceptance criteria

The Spec is satisfied only when:

- Employee exists without User/Auth account;
- same-Tenant relationship negative tests pass for Employer/Site/Department/Manager links;
- pay/assignment history is effective-dated and reproducible;
- locked payroll history cannot be rewritten by People changes;
- bulk import has validate/confirm/reject-report behavior;
- end-employment and rehire paths are complete;
- compensation visibility is permission-bounded;
- representative mobile and desktop flows meet the operational-simplicity contract;
- no People workflow requires Contracts/Documents/ESS merely to reach a supported outcome.

## Deferred maturity

Later specifications may add:

- richer transfers/history;
- concurrent employment;
- hourly/piece-rate primary pay bases;
- contracts/documents;
- onboarding/offboarding checklists;
- employee data-change requests;
- richer org/reporting structures;
- ESS/MSS.

These additions must extend, not replace, the V1 People foundation.
