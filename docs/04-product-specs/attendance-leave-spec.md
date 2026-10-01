# Attendance & Leave Specification

## Status

**Frozen — final documentation alignment approved 2026-09-29; Cube 3 Leave is amended by Accepted DEC-025 and `cube-3-leave-self-service-amendment-2026-10-01.md`.**

This specification governs Wave 3 — Attendance, Exceptions & Leave. It freezes the authoritative Time-domain behavior that turns source events and leave records into reviewable facts without allowing raw attendance to silently become irreversible payroll money.

## Governing inputs

- Accepted Product Charter, Product Principles, Master Product Blueprint and V1 Capability Decomposition.
- Frozen Platform Foundation and Accepted ADR-001 through ADR-010.
- HR People & Work Context Specification.
- DEC-012, DEC-013 and DEC-016.
- Security, Privacy, Frontend/UX, Definition of Ready and Definition of Done baselines.
- Product rule: internal event matching, effective dating and exception logic are backend concerns; ordinary users must work through simple operational views, plain language and obvious next actions.

## Outcome

An authorized operator can define bounded working-time policies, capture/import attendance, interpret work sessions including overnight shifts, resolve exceptions, approve overtime/attendance facts, record and approve leave, and hand approved non-financial facts to Payroll.

## Scope

This specification covers:

- HRT-002 Canonical attendance events.
- HRT-003 Manual/admin attendance entry.
- HRT-004 Spreadsheet attendance import.
- HRT-005 Attendance interpretation and exceptions.
- HRT-006 Overtime determination.
- HRT-007 Exception review and correction.
- HRL-001 Leave types and bounded leave policy.
- HRL-002 Leave balances/entries.
- HRL-003 Leave request/record + simple approval.
- Attendance/leave operational reports and Payroll input boundary.

HRT-008 biometric/device transport and HRT-009 mobile geofence capture are governed by the Attendance Channel Specification.

## Explicit non-goals

V1 does not build:

- a generic workforce-optimization/rota engine;
- arbitrary rules scripting;
- multi-level generic approvals;
- continuous employee location tracking;
- automatic irreversible monetary deductions directly from raw attendance;
- universal biometric vendor support;
- hidden auto-fixes that overwrite source history.

## 1. Time model and operational workday

### Time storage

- physical instants are stored as UTC;
- business interpretation uses an explicit IANA timezone inherited from the effective Site/Tenant policy;
- Egypt deployments use `Africa/Cairo` rather than a fixed UTC offset so daylight-saving changes do not corrupt historical interpretation;
- source device timestamp, server receipt timestamp and source timezone/offset evidence are retained where material.

### Work Instance

Attendance is interpreted against a **Work Instance**: one expected period of work for one Employee.

A Work Instance has:

- operational work date;
- expected start/end;
- applicable Work Policy and Shift version;
- Employee/Employment/Assignment context;
- status and interpreted facts.

### Cross-midnight rule

A shift may cross calendar midnight.

For a scheduled shift beginning on day D and ending after midnight on D+1:

- its **operational work date remains D**;
- punches after midnight that fall within the configured attribution window remain part of the same Work Instance;
- midnight does not auto-close the shift, auto-check-out the Employee, or create a new attendance day;
- an Employee can check out after midnight normally;
- a new next-day Work Instance begins only according to the actual schedule/attribution rules, not merely because the clock reached 00:00.

This is a hard invariant and must be covered by regression tests.

## 2. Work Policy and shift variants

V1 supports bounded policy configuration rather than a generic rule engine.

### Supported shift forms

1. **Fixed-time shift**
   - expected local start;
   - expected local end, including next-day end;
   - optional break duration;
   - attendance attribution window.

2. **Flexible-duration workday**
   - expected required duration;
   - optional earliest/latest accepted punch window;
   - no mandatory exact start time unless a policy adds one.

3. **Dated shift assignment/override**
   - an authorized operator may assign or override the applicable Shift for a specific date/range;
   - this supports rotating operational rosters without building a speculative scheduling optimizer.

### Policy parameters

A Work Policy may define, with safe defaults:

- lateness grace minutes;
- early-leave grace minutes;
- minimum worked duration for full-day interpretation where used;
- absence determination behavior;
- overtime eligibility;
- overtime minimum threshold;
- overtime rounding increment;
- automatic approval eligibility for clean ordinary days;
- exception review requirement;
- attendance source priority/evidence requirements.

Policy changes are effective-dated. A policy change does not reinterpret already approved/consumed historical facts silently.

## 3. Canonical attendance event

Every attendance source normalizes into a canonical event.

Minimum contract:

- Tenant;
- Employee;
- event instant;
- source type;
- source/system identifier;
- source event key or deterministic idempotency key;
- received/imported time;
- optional declared direction `in | out | unknown`;
- optional Site/device/channel metadata;
- optional bounded evidence metadata;
- immutable source provenance.

Rules:

- the canonical event is evidence, not a payroll deduction;
- duplicate source events are idempotently ignored/linked rather than double-counted;
- raw source history is not overwritten by later correction;
- biometric templates/fingerprints are not stored by the SaaS merely to record an attendance event;
- a source event referring to another Tenant's Employee/Site/device cannot be persisted.

## 4. Attendance interpretation

Interpretation produces facts from canonical events + effective Work Policy/Shift.

Possible facts include:

- first in / final out;
- worked duration;
- late minutes;
- early-leave minutes;
- approved/unapproved absence unit;
- overtime candidate minutes;
- missing punch;
- unassigned schedule;
- conflicting/ambiguous punches;
- outside-window event;
- duplicate/replayed source evidence.

Interpretation must be deterministic for the same frozen inputs/policy version.

### Event pairing

V1 may infer in/out pairing from ordered events where source direction is unavailable, but:

- ambiguous sequences create an exception instead of guessing a financially material result;
- an event may not be silently reassigned to a different Work Instance after approval;
- the exact pairing algorithm is isolated and covered by golden tests for ordinary, overnight, duplicate and missing-punch scenarios.

## 5. Attendance states

A Work Instance uses business-facing states equivalent to:

- `open` — still in progress or not yet ready for interpretation;
- `ready` — interpreted with no blocking exception;
- `needs_review` — one or more blocking/meaningful exceptions require action;
- `approved` — authorized attendance facts are final for ordinary downstream use;
- `corrected` — prior approved facts were superseded through an explicit correction path.

Technical sub-states may exist internally, but the UI must not expose a state-machine vocabulary when “Needs review” or “Approved” communicates the business meaning.

## 6. Exceptions and correction

Blocking/meaningful exception families include at least:

- missing check-in;
- missing check-out;
- no schedule/work policy;
- conflicting punch sequence;
- attendance outside accepted window;
- unexplained absence;
- source mapping failure;
- a correction that changes previously approved facts.

### Resolution

An authorized reviewer can:

- add a missing manual event with reason;
- exclude/mark an erroneous event without deleting its source history;
- choose the correct Work Instance when an event is genuinely ambiguous;
- approve an absence/attendance fact;
- approve/reject overtime candidate;
- add a plain-language reason/evidence note.

Every material correction preserves:

- original evidence;
- corrected interpretation;
- actor;
- time;
- reason.

No “edit the final row until it looks right” workflow is permitted.

## 7. Overtime

Attendance owns the determination of **time quantity and approval**, not the final monetary valuation.

V1 overtime flow:

`worked beyond policy threshold -> overtime candidate -> reviewer classification and approval/rejection -> approved overtime quantity -> Payroll input`

Cube 2 V1 decision (2026-09-30): no Work Policy permits automatic overtime approval. Classification and approval require an authorized reviewer because the platform has no approved rules for nighttime, weekly-rest, or official-holiday classification. Policy-authorized automation may be introduced only with explicit, validated classification rules and its own acceptance evidence; it is not part of Cube 2 closure. This does not change the separate opt-in clean ordinary attendance auto-approval path.

Approved overtime carries the applicable category needed by Payroll, including ordinary daytime/nighttime overtime and, where applicable, weekly-rest or official-holiday work.

Rules:

- overtime is measured in minutes internally and displayed in understandable hours/minutes;
- rounding follows the effective Work Policy;
- rejected overtime remains historically visible;
- changing the overtime policy does not rewrite already approved inputs;
- Payroll determines money using its component/rate configuration and applicable statutory rules.

## 8. Automatic versus manual review

The system must avoid creating unnecessary HR workload.

Default behavior:

- clean ordinary Work Instances may become approved automatically only when the effective policy explicitly allows it and no exception exists;
- exception days are routed to a focused review queue;
- reviewers can resolve/approve in bulk when the records share the same safe action;
- the product must not require opening every employee/day simply to confirm normal attendance.

Automation may reduce clicks but never bypass a blocking exception or required approval rule.

## 9. Payroll input boundary

Attendance does not directly mutate salary/deduction rows.

After approval, Time may publish/version an approved payroll input containing only the facts Payroll needs, such as:

- late minutes;
- unpaid absence units;
- approved overtime minutes plus the applicable overtime/rest-day/holiday category;
- paid/unpaid work units where relevant;
- source Work Instance and effective policy version.

The boundary is:

- explicit;
- Tenant-scoped;
- idempotent/versioned;
- attributable to source records;
- replaceable only through a governed correction path.

If Payroll has already locked the affected period, a later Attendance correction becomes an explicit Payroll correction/next-period adjustment requirement. It does not reopen or mutate the locked run silently.

## 10. Spreadsheet attendance import

Flow:

1. upload;
2. map/confirm fields;
3. validate;
4. preview accepted/warning/rejected rows;
5. confirm;
6. commit canonical events;
7. expose resulting exceptions.

Rules:

- source Employee can be mapped by employee code or another approved stable external key;
- duplicate events are idempotent;
- invalid timezone/date formats are rejected with row guidance;
- partial import outcomes are explicit; the user receives counts and reject details;
- imported data follows the same interpretation/correction rules as other sources.

## 11. Leave types and policy

V1 Leave is intentionally bounded.

A Leave Type defines:

- name/code;
- paid or unpaid payroll effect;
- balance-tracked or untracked;
- allowed unit: full day and/or half day;
- optional annual entitlement;
- optional partial-year proration;
- active/inactive lifecycle.

V1 balance modes:

1. **Manual/opening balance** — authorized HR establishes and adjusts balance through ledger entries.
2. **Annual entitlement** — the system creates the annual entitlement according to the configured yearly amount and optional proration.

Complex monthly accrual formula engines, carry-forward matrices and advanced expiry rules are deferred unless a concrete requirement is added through change control.

### Balance ledger

Balances are derived from auditable ledger entries such as:

- opening balance;
- annual grant;
- approved leave consumption;
- cancellation/reversal;
- authorized adjustment.

The system does not overwrite “current balance” without preserving the event that changed it.

## 12. Leave workflow

Full Employee Self-Service is not required for V1. Under Accepted DEC-025, V1 includes a bounded own-Leave view, request, and withdrawal surface for a User linked to their own Employee. This is a Leave workflow surface, not the full `hr.ess` capability; broad People self-service and full ESS/MSS remain deferred.

Supported entry modes:

- an authorized HR operator records Leave on behalf of an Employee;
- a linked Employee submits their own Leave request through the bounded own-Leave surface;
- both paths keep recording/submission separate from the approval decision and use one bounded approval stage.

The Leave-record transitions are:

`draft -> submitted`; `submitted -> approved | rejected | withdrawn`; `approved -> cancelled | superseded`.

An Employee may withdraw their own pending request. A held `leave.approve` Permission may approve a request even when the approver is its requester; V1 does not impose a separate maker-checker rule. Approval and cancellation decisions preserve actor identity, time, and reason. Every submitted request has an identified authorized owner/queue. After approval, the Employee may request cancellation; an authorized HR approver decides that request through `pending -> accepted | rejected`: acceptance cancels the Leave and appends a balance reversal/restore entry; rejection leaves the approved Leave in effect. A governed correction marks the prior approved record `superseded` and links its replacement.

Rules:

- submitted requests cannot remain ownerless; a role/queue owns the next action;
- approval checks overlap, Employment state and balance policy;
- pending Leave does not reserve or consume balance; balance eligibility is rechecked at approval, and the approval decision plus balance-consumption entry commit atomically;
- cancellation of approved leave creates a reversal/restore entry rather than deleting history;
- unpaid leave produces an approved Payroll input through the domain boundary;
- paid leave can affect Attendance interpretation without necessarily reducing pay.

Leave uses an independently configured Leave Calendar and Leave Year with explicit account-period boundaries; they do not derive from the Payroll Calendar or Attendance Work Policy, and no calendar-year, fiscal-year, or hire-anniversary default is imposed. Annual Leave is counted in eligible working days under the configured Leave Calendar; weekly-rest days and official holidays are excluded according to Article 124 of the cited law. Where the Leave Type permits half-day use, it consumes `0.5` balance day; this does not define an intraday time interval or remaining Attendance obligation. Leave remains usable without Attendance entitlement or configuration. Annual grants are unique to Employer Legal Entity + Employee + Leave Type + configured Leave-Year account period; changing a policy version does not create another grant for the same account period. Proration, rounding, category transitions, and half-day timing remain subject to the verification boundary in §13 and the Cube 3 amendment. Unused balance does not expire automatically; complex carry-forward matrices and expiry rules remain deferred.

## 13. Egypt statutory work-time/leave baseline

For standard private-sector Employees governed by Egypt Labour Law No. 14 of 2025, the initial Egypt policy pack must encode and test the applicable statutory baseline rather than relying only on tenant-entered values.

Official law reviewed for the initial baseline: https://portal.eta.gov.eg/sites/default/files/2026-03/law.no_.14.of_.2025.pdf

Key standard-worker anchors include:

- ordinary actual work: no more than 8 hours/day or 48 hours/week, excluding meal/rest breaks, subject to lawful category-specific exceptions;
- break periods: aggregate at least 1 hour and ordinarily no more than 5 consecutive work hours without a break, subject to ministerial exceptions;
- ordinary span between start and end including breaks: generally no more than 10 hours/day, with specified special-category exceptions;
- weekly rest: at least 24 consecutive paid hours after no more than 6 consecutive work days, subject to lawful aggregation exceptions;
- exceptional additional work under Article 121: overtime compensation must not be less than the ordinary hourly wage plus 35% for daytime overtime and plus 70% for nighttime overtime; work on the weekly rest day receives the statutory compensatory treatment and substitute day;
- total presence under the Article 121 exceptional-work rule must not exceed 12 hours/day;
- official-holiday work follows the compensation/substitute-day rule in Article 129 rather than being treated as ordinary overtime;
- annual paid leave under Article 124: 15 days in the first year, 21 days from the second year, 30 days after 10 complete years of service with one or more employers or after age 50, and 45 days for covered persons with disabilities/dwarfism; service below one year is prorated after at least six months, with the statutory additional seven days for covered hazardous/harmful/remote work.

These are **effective-dated statutory policy data/constraints**, not scattered hard-coded UI defaults. The product must support lawful exceptions/categories without weakening the default baseline. Where legal classification or an exception is uncertain, the system must require explicit authorized configuration/evidence rather than silently treating the Employee as exempt.

Tenant policy may be more favorable where legally allowed. A configuration that appears less favorable than an applicable mandatory floor must be blocked or surfaced as a compliance-blocking validation according to the active verified statutory pack.

The statutory pack must retain source/version/effective-date metadata so future legal amendments do not reinterpret historical approved attendance or leave.

**Cube 3 legal verification boundary:** eligible Leave days use the configured Leave Calendar's working days, excluding weekly-rest days and official holidays, as stated in Article 124 of the cited law. A permitted half-day uses `0.5` balance day. These rules do not define half-day clock timing or remaining Attendance obligation. Statutory proration/rounding, Employee eligibility and category transitions, and half-day timing require further legal/compliance verification before code depends on them. Do not infer these details from examples above. DEC-023's production statutory qualification gate remains in force.

No Attendance interpreter may infer a clock interval or remaining Attendance obligation from `0.5` balance-day units alone. Verify half-day timing and applicable protected categories before code depends on those details. The request, review, and ledger lifecycle may proceed independently of pending calculations.

## 14. Attendance/Leave operational simplicity contract

Normal users should operate through:

- **Today / current shift** views for immediate attendance;
- **Exceptions needing review** as the primary HR queue;
- **Employee attendance summary** rather than raw event tables;
- **Leave requests/balances** in business language.

Required UX constraints:

- filter panels are collapsible and compact by default;
- search/employee selection uses fast type-ahead and employee code/name context;
- raw device/source metadata is hidden behind “Details/Evidence”;
- advanced policy fields are grouped/collapsed and explained in plain language;
- overnight work is displayed as one shift on its operational date, not two confusing calendar records;
- the dominant next action is obvious;
- users are not asked to understand UTC, idempotency keys, RLS, source hashes or internal states;
- errors explain what the user can do next.

Simplicity must not hide unresolved punches, unpaid leave, or consequences that may affect Payroll.

## 15. Permissions

Permission families include at least:

- attendance.view;
- attendance.manage;
- attendance.correct;
- attendance.approve;
- attendance_policy.manage;
- leave.view;
- leave.manage;
- leave.approve;
- leave_balance.adjust;
- people.self.view, leave.self.view, and leave.self.request for the bounded own-Leave surface only. These do not grant tenant-wide People/Leave access and do not include `people.view`.

These permissions are limited to the authenticated User's own currently linked Employee and do not grant tenant-wide People or Leave access. HR permissions remain required for HR operations; role templates compose these keys under the shared authorization model.

Exact key spelling may be normalized during implementation.

## 16. Workflow Completion Maps

### Ordinary attendance

`scheduled Work Instance -> canonical events -> interpretation -> ready/auto-approved -> approved Payroll facts`

### Attendance exception

`interpretation -> needs review -> reviewer correction/decision -> approved OR explicitly unresolved with owner`

There is no hidden dropped-event state.

### Post-approval correction

`approved -> correction request/action -> corrected version -> downstream input superseded or Payroll correction required`

### Leave

`draft -> submitted -> approved/rejected/withdrawn`; after approval, `cancellation request -> accepted/rejected`; accepted cancellation appends a balance reversal. Governed correction may supersede and link the approved record. Pending requests do not consume balance; approval and consumption are atomic.

### Entitlement loss

If Attendance/Leave entitlement is removed:

- historical records remain readable according to policy;
- new prohibited operations are blocked;
- in-flight requests/exceptions remain available to authorized closure/export/correction rules defined for the capability;
- data is never deleted automatically.

For `hr.leave` specifically, authorized users may read historical records and perform bounded closure of existing work. New requests/records, annual grants, and positive balance growth are blocked while the entitlement is disabled. Only reversal/audit entries required to close an existing cancellation or correction may be appended.

## 17. Acceptance criteria

The Spec is satisfied only when:

- cross-midnight shifts remain one Work Instance and can close after midnight without auto-reset;
- UTC/timezone/DST interpretation is deterministic;
- duplicate/replayed events do not double-count;
- raw events cannot directly create irreversible money impact;
- missing/conflicting punches become visible exceptions;
- corrections preserve provenance;
- clean days do not require unnecessary manual review when policy permits safe automation;
- overtime produces approved quantities, not hidden monetary deductions;
- Leave balances are ledger-derived and reversible;
- locked Payroll cannot be rewritten by Attendance/Leave correction;
- representative mobile/desktop workflows satisfy the operational-simplicity contract;
- cross-Tenant relationship and access negative tests pass.

## 18. Deferred maturity

Later work may add:

- richer rostering/shift rotation planning;
- advanced accrual/carry-forward/expiry;
- multi-level leave approval;
- richer manager/employee self-service;
- period close/reopen if proven necessary;
- broader alerts/notifications;
- advanced field/offsite attendance controls.
