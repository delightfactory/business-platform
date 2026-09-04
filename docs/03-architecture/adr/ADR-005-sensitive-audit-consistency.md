# ADR-005 — Sensitive Audit Consistency Must Fail Closed

## Status

**Proposed**

## Context

Wave 1 requires auditability for tenant lifecycle, membership, authorization, entitlement, limit, and platform-operator changes. A design where the protected mutation succeeds but the mandatory audit record silently fails would create an unverifiable security/control-plane state.

## Decision

For actions classified by the governing specification as requiring a **mandatory success audit event**, the system must not acknowledge the protected mutation as successfully committed unless the corresponding audit event has been durably persisted through the same consistency boundary.

Preferred implementation is atomic persistence when the selected stack supports it. If the technical architecture later requires asynchronous delivery, it must use a durable transactional/outbox-style boundary or an equivalent mechanism that prevents a successful protected mutation from becoming permanently unaudited.

A best-effort/log-only audit call that can fail open is not acceptable for mandatory sensitive success events.

Denied/failed-operation security telemetry may use a different non-transactional path when the business mutation did not commit, provided failure of that telemetry cannot accidentally authorize or commit the protected action.

## Consequences

- sensitive administrative history is trustworthy;
- control-plane support/review does not depend on best-effort logging;
- selected persistence architecture must provide an appropriate consistency mechanism;
- noncritical diagnostic logging remains separate and may be best-effort.

## Rejected alternatives

### Perform mutation, then try to write audit and ignore failure

Rejected because a successful sensitive state change could become permanently untraceable.

### Treat application logs as the authoritative audit trail

Rejected because operational logs may be sampled, rotated, reformatted, or contain inappropriate payloads and do not provide the required business/security consistency semantics.
