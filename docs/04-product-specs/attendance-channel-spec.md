# Attendance Channel Specification

## Status

**Frozen — final documentation alignment approved 2026-09-29.**

This specification governs Wave 5 attendance capture channels. It freezes the channel contracts, privacy/security behavior and user experience while keeping vendor-specific device transport outside Attendance business logic.

The first concrete biometric vendor/model is deliberately a **vendor sub-gate**: no vendor-specific adapter Product Code may begin until the selected hardware/path is recorded in a reviewed amendment or adapter specification. This does not block People, Attendance Core or Payroll waves.

## Governing inputs

- Accepted Product Charter, Product Principles, Master Product Blueprint and V1 Capability Decomposition.
- Frozen Platform Foundation and Accepted ADR-001 through ADR-010.
- Attendance & Leave Specification.
- DEC-013: source-neutral Attendance with manual/import, one prioritized biometric connector and optional mobile geofence.
- Security and Data Classification/Privacy baselines.
- Product rule: capture must feel simple to the Employee/operator even when mapping, idempotency, location validation and retry logic are complex internally.

## Outcome

Attendance channels can submit trustworthy canonical attendance events through one stable integration boundary, with clear failure/retry behavior and without coupling Time/Payroll rules to a device vendor or continuously tracking employees.

## Scope

This specification covers:

- HRT-008 biometric/device connector boundary and first-adapter qualification contract;
- HRT-009 mobile geofence attendance;
- source mapping;
- replay/deduplication;
- bounded evidence;
- offline/failure behavior;
- connector health/error states required to avoid lost events.

Manual entry and spreadsheet import remain governed by Attendance & Leave.

## Explicit non-goals

V1 does not promise:

- universal biometric device support;
- direct SaaS access to every LAN device;
- storage of fingerprint/face biometric templates;
- continuous/background location tracking;
- native mobile applications;
- silent offline “success” when the server has not received a punch;
- a generic IoT/device-management platform.

## 1. Source-neutral channel boundary

Every channel ends by submitting the canonical Attendance Event contract defined by the Attendance & Leave Spec.

Channel adapters may know vendor/API/file transport details. They must not decide:

- lateness;
- absence;
- overtime pay;
- payroll deductions;
- leave treatment;
- financial consequences.

Those remain owned by the Time/Payroll domains.

## 2. Source and mapping model

A Channel Source is Tenant-scoped and identifies a bounded capture source such as:

- biometric connector/device;
- mobile attendance;
- future external API adapter.

A biometric source may contain one or more physical devices.

Required mapping concepts:

- Tenant;
- source/device identity;
- external employee identifier;
- mapped internal Employee;
- optional Site;
- active/inactive state;
- mapping validity/effective period where required.

Rules:

- an external identifier is never globally trusted;
- mapping is resolved inside the explicit Tenant/source context;
- cross-Tenant Employee/Site mapping is authoritatively impossible;
- ambiguous/unmapped events become visible mapping exceptions and are not discarded;
- correcting a mapping may replay/reprocess retained unmapped evidence idempotently.

## 3. Idempotency and replay

Every connector submission needs a stable source-event identity.

Preferred order:

1. native immutable vendor event ID where reliable;
2. connector-generated durable event key;
3. deterministic bounded fingerprint from source/device/external employee/event time/direction where no native ID exists.

Rules:

- retries are expected and safe;
- the same source event cannot create duplicate canonical Attendance Events;
- replay after connector outage is supported;
- idempotency identity is scoped so two legitimate distinct punches are not collapsed merely because timestamps are close;
- duplicate/replay decisions are observable in diagnostics, not silently destructive.

## 4. Biometric/device connector architecture

### Preferred integration order

Choose the simplest reliable transport that the selected hardware supports:

1. vendor-supported HTTPS/cloud API;
2. reliable scheduled export/file/API bridge;
3. bounded local connector/gateway for LAN-only devices.

The Attendance domain must not require a specific option.

### Local connector/gateway

When LAN-only hardware requires a local connector:

- it runs as a separately bounded integration component, not inside the browser;
- it makes outbound authenticated connections to the SaaS where practical;
- Tenant/source credentials are least-privileged and environment-specific;
- it stores only the minimum queue/state needed for reliable delivery;
- retries are idempotent;
- upgrades/configuration cannot grant arbitrary database access;
- the connector cannot use a browser/service-role secret as a universal bypass;
- logs avoid raw biometric templates and unnecessary personal data.

### Device data minimization

The SaaS should receive only what attendance needs:

- external employee key;
- event time;
- direction if available;
- device/source identifier;
- minimal provenance.

Fingerprint/face templates, images or biometric matching artifacts are not imported unless a future separately approved capability proves a need and passes Restricted-data review.

## 5. Connector delivery states

A source event/connector batch must reach an actionable state equivalent to:

- received/accepted;
- duplicate;
- rejected with reason;
- unmapped;
- retrying;
- failed/action required.

“Sent” at the connector does not equal “recorded” until the SaaS acknowledges authoritative acceptance.

Failed batches/events remain inspectable and retryable according to retention policy. Silent data loss is prohibited.

## 6. Connector health

Minimum operator visibility:

- source/device name;
- last successful event/heartbeat where available;
- last failure;
- backlog/retry count where applicable;
- unmapped event count;
- clear recommended action.

This is not a generic observability product. It is only enough to answer: “Is attendance reaching the system, and if not, what should I do?”

## 7. First biometric adapter vendor sub-gate

The generic channel contract is implementation-ready without guessing a customer device.

Before vendor-specific HRT-008 adapter code begins, a reviewed bounded adapter record/spec must identify:

- vendor/product family or concrete integration protocol;
- deployment topology (cloud/LAN/file);
- authentication method;
- event fields and timestamp semantics;
- stable event ID/idempotency strategy;
- employee/device mapping strategy;
- outage/replay behavior;
- test device/simulator evidence;
- privacy/security review.

Selecting a vendor is a procurement/integration fact, not an architectural decision. It must not force changes to the canonical Attendance contract.

## 8. Mobile geofence attendance

Mobile attendance is an optional entitled channel requiring an Employee ↔ User link.

### User flow

The primary Employee experience is intentionally small:

1. open attendance surface;
2. see current expected state: “Start shift” or “End shift”;
3. tap one primary action;
4. location permission/evidence is captured only for that punch when required;
5. receive an explicit success or actionable failure/pending outcome.

Employees are not shown geospatial formulas, raw coordinates or policy internals by default.

### Location evidence

When geofence validation is enabled, capture at punch time may include:

- latitude/longitude;
- reported accuracy;
- captured-at timestamp;
- Site/geofence version;
- validation result;
- minimal device/browser context needed for fraud/support evidence.

Rules:

- no continuous tracking;
- no background location history unrelated to a punch;
- evidence is retained only according to an explicit privacy/retention policy;
- low-accuracy/unavailable location does not silently become “inside”;
- Site/geofence changes do not rewrite old punch validation.

## 9. Geofence validation

A Site geofence uses a configured center/geometry and bounded tolerance appropriate to the supported implementation.

The validator considers:

- distance/containment;
- reported location accuracy;
- punch capture age;
- active Site/geofence version;
- configured policy.

Outcomes are equivalent to:

- valid inside;
- outside;
- insufficient accuracy/evidence;
- location unavailable;
- stale evidence.

A Tenant policy decides whether a non-valid result is rejected immediately or accepted as a visible review exception. The UI communicates the business outcome, not raw math.

## 10. Mobile offline/network failure

V1 does **not** claim a punch was recorded while the server is unreachable.

If network submission cannot complete:

- the Employee receives an explicit “not recorded yet / try again” or supported pending state;
- the UI never shows a final successful check-in/out unless the authoritative server accepted it;
- if a bounded client retry queue is implemented, it preserves capture time/evidence and visibly remains pending until acknowledged;
- server-side replay/idempotency prevents duplicate punches after retry.

Offline capture support is an implementation enhancement, not a reason to misrepresent success.

## 11. Permission-denied / location-unavailable behavior

If location permission is denied or unavailable:

- explain why location is required for this Tenant's attendance policy;
- provide the next allowed action: retry permission, use an authorized alternate channel, or contact supervisor/HR;
- do not trap the Employee on a dead-end spinner;
- do not weaken the policy by silently bypassing location.

Where geofence is not enabled for the Tenant, location is not requested unnecessarily.

## 12. Security and privacy

- mobile punch uses the authenticated User + current Tenant + linked Employee relationship;
- a User cannot punch for another Employee through client-supplied IDs;
- entitlement and permission/channel eligibility are enforced authoritatively;
- rate/replay abuse controls are bounded to the actual endpoint need;
- location data is Confidential/Restricted according to precision and retention;
- raw biometric templates remain outside V1 SaaS storage;
- channel secrets never reach browser code;
- connector/server operations carry explicit Tenant/source context;
- logs and support surfaces are data-minimized.

## 13. Operational simplicity / UX contract

### Employee

The Employee should normally answer only two questions:

- “Am I checked in or out?”
- “What action can I take now?”

Requirements:

- one dominant punch action;
- immediate understandable outcome;
- no manual Site/device selection when context can be derived safely;
- no technical error codes without a plain-language action;
- no continuous permission prompts beyond platform/browser necessity.

### HR/operator

The operator should primarily see:

- healthy sources;
- items needing action;
- unmapped Employees;
- failed/retrying events.

Raw payloads/protocol diagnostics live under advanced support detail, not the normal attendance workflow.

## 14. Workflow Completion Maps

### Biometric event

`device -> adapter/connector -> submit -> accepted canonical event | duplicate | visible rejected/unmapped/retry state -> Attendance interpretation`

No event may disappear between connector and Attendance without an inspectable result.

### Mobile punch

`employee action -> auth/link/entitlement check -> location evidence if required -> server validation -> accepted event OR actionable failure/pending -> Attendance interpretation`

### Mapping correction

`unmapped event -> operator maps external identity -> replay/reprocess -> accepted/duplicate -> exception cleared`

### Entitlement disabled

New channel capture is denied. Existing historical attendance/evidence remains preserved under domain retention/access rules.

## 15. Acceptance criteria

The Spec is satisfied only when:

- vendor/channel transport cannot bypass canonical Attendance interpretation;
- cross-Tenant device/employee mapping negative tests pass;
- replay/retry cannot double-count;
- unmapped/failed events are visible and recoverable;
- biometric templates are not required/stored for ordinary event ingestion;
- mobile punch requires the correct linked Employee/User/Tenant;
- geofence validation handles inside/outside/low-accuracy/unavailable/stale cases;
- offline/network failure never falsely reports final success;
- no continuous location tracking occurs;
- Employee and operator workflows meet the operational-simplicity contract;
- a selected vendor adapter passes its additional reviewed sub-gate before support is claimed.

## Deferred maturity

Later work may add:

- additional biometric vendors;
- richer connector fleet management;
- durable managed queues when volume justifies them;
- customer-facing integration API/webhooks;
- richer offline mobile capture;
- advanced anti-spoofing/device-attestation controls when risk/customer demand proves the need.
