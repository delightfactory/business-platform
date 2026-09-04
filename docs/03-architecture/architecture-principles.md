# Architecture Principles

## Purpose

These principles define the architectural boundaries of the platform before technology-specific implementation decisions are frozen.

## 1. Multi-tenancy is foundational

Tenant context and tenant isolation must be explicit from the first persistent data model. Authentication alone is not tenant isolation.

## 2. Platform Core remains business-neutral

Shared platform services must not encode HR-specific assumptions. Domain-specific entities and rules belong to their owning domain.

## 3. Modular monolith first

Prefer a modular monolith with strong internal boundaries over premature distributed systems. Microservices require a demonstrated operational or scaling need.

## 4. Explicit domain boundaries

Each domain owns its business rules, invariants, and authoritative data. Cross-domain access should happen through explicit contracts, application services, events, or APIs rather than ad-hoc table coupling.

## 5. Controlled configuration

Configuration must be bounded, validated, versionable where necessary, and understandable by operators. Avoid unrestricted scripting or generic rule engines until multiple concrete use cases justify them.

## 6. Entitlements are separate from permissions

Entitlements answer: "has this tenant purchased/accessed this capability?"

Authorization answers: "may this user perform this action?"

The two concerns must not be conflated.

## 7. Employee identity is not user identity

Business persons/entities may exist without authentication accounts. A future user account may be linked where required, but login must never be a prerequisite for representing a business person.

## 8. Integration through boundaries

External ERPs, biometric devices, accounting systems, and other integrations should connect through adapters, APIs, imports/exports, or connectors. Core domain logic must not depend directly on a particular external vendor.

## 9. Historical correctness

Finalized financial or compliance-sensitive outcomes must reference the effective rule/configuration context used to produce them. Later configuration changes must not rewrite history silently.

## 10. Migration discipline

Database changes must be reproducible from a clean environment. Schema evolution should be tracked through ordered migrations and verified as part of quality gates.

## Complexity Budget

Every new abstraction, framework, engine, or generalized subsystem must answer:

1. Which current, demonstrated problem does it solve?
2. Which active release requires it?
3. What is the simpler alternative?
4. What ongoing operational and cognitive cost does it add?

If the only justification is "we may need it later," implementation should normally be deferred.

## Foundation Obligations

The following are not optional simplifications and are not classified as overengineering:

- tenant isolation;
- authorization boundaries;
- data integrity;
- migration reproducibility;
- auditability of sensitive operations;
- financial calculation correctness and reproducibility;
- secure secret handling;
- backup/recovery considerations appropriate to the stage;
- tests for critical invariants.

These obligations protect the product from shortcuts that create structural rework or unacceptable risk.
