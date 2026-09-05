# ADR-005 — Sensitive Audit Consistency Must Fail Closed

## Status

**Accepted — Phase 0D Platform Foundation freeze review, 2026-09-05.**

## Context

Wave 1 requires auditability for tenant lifecycle, membership, authorization, entitlement, limit, and Platform Operator changes. A design where the protected mutation succeeds but the mandatory audit record silently fails would create an unverifiable security/control-plane state.

Durable persistence alone is not enough if normal application or operator authority can later update or delete the resulting audit event. Mandatory audit therefore requires both transactional success consistency and append-only runtime semantics.

## Decision

For actions classified by the governing specification as requiring a **mandatory success audit event**, the system must not acknowledge the protected mutation as successfully committed unless the corresponding audit event has been durably persisted through the same consistency boundary.

Preferred implementation is atomic persistence when the selected stack supports it. If the technical architecture later requires asynchronous delivery, it must use a durable transactional/outbox-style boundary or an equivalent mechanism that prevents a successful protected mutation from becoming permanently unaudited.

A best-effort/log-only audit call that can fail open is not acceptable for mandatory sensitive success events.

Denied/failed-operation security telemetry may use a different non-transactional path when the business mutation did not commit, provided failure of that telemetry cannot accidentally authorize or commit the protected action.

## Append-only runtime invariant

Persisted mandatory audit events are append-only to normal runtime application authority.

Rules:

- tenant roles, normal application roles, and ordinary Platform Operator workflows must not have `UPDATE` or `DELETE` authority over persisted mandatory audit events;
- audit event identity and authoritative event time are generated/controlled by the trusted persistence boundary rather than accepted as arbitrary client truth;
- permission to perform a sensitive action does not automatically grant permission to browse all sensitive audit history;
- audit visibility is separately authorized and payloads remain data-minimized;
- corrective facts are represented by new audit events rather than rewriting prior history.

## Exceptional maintenance boundary

Retention enforcement, legal deletion obligations, schema migration, or exceptional security repair may require separately governed maintenance procedures.

Those procedures are not normal application audit mutation paths and must:

- use explicit elevated maintenance authority separate from tenant/application roles;
- be narrowly scoped to the maintenance purpose;
- leave appropriate evidence of the exceptional action where legally and technically permissible.

This exception must not become a general-purpose audit editing API.

## Consequences

- sensitive administrative history is trustworthy both at commit time and afterward;
- control-plane support/review does not depend on best-effort logging;
- selected persistence architecture must provide an appropriate consistency mechanism;
- noncritical diagnostic logging remains separate and may be best-effort;
- ordinary application/operator authority cannot silently rewrite or erase mandatory audit history;
- retention/legal maintenance remains possible through a separately governed boundary rather than weakening runtime audit integrity.

## Rejected alternatives

### Perform mutation, then try to write audit and ignore failure

Rejected because a successful sensitive state change could become permanently untraceable.

### Allow normal application/admin roles to update or delete audit rows

Rejected because durable audit would still be mutable by the same operational authority whose actions it is intended to evidence.

### Treat application logs as the authoritative audit trail

Rejected because operational logs may be sampled, rotated, reformatted, or contain inappropriate payloads and do not provide the required business/security consistency semantics.
