# Edara SaaS Extraction Audit

## Status

**In progress — donor-platform review only. No code reuse is approved by this document yet.**

## Purpose

Assess reusable platform concepts and implementation assets from a prior internal SaaS product without inheriting its domain-specific assumptions or technical debt.

## Classification model

Every reviewed component must be classified as one of:

- **Reuse** — implementation is sufficiently generic and sound to adopt with minimal adaptation.
- **Refactor** — implementation/pattern is valuable but requires redesign or hardening before adoption.
- **Concept Only** — retain the architectural/product idea, implement afresh.
- **Reject** — unsuitable for the new platform.

## Initial areas of interest

| Area | Initial direction | Reason |
|---|---|---|
| Tenant / membership model | Refactor | Strong reusable multi-tenant pattern; requires alignment with new domain-neutral organization model and isolation guarantees. |
| Plans / feature definitions / subscription overrides | Refactor | Closely matches desired entitlement architecture, including tenant-specific capability/limit overrides. |
| Subscription lifecycle | Refactor | Useful active/expiry/grace/suspension lifecycle patterns; commercial rules must remain configurable and platform-neutral. |
| Super-admin control plane | Concept / Refactor | Useful operational pattern; UI and workflows should be rebuilt against the new platform model. |
| Permission model | Concept / Refactor | Module/action permission pattern is useful, but fixed role assumptions must not constrain HR or future domains. |
| Branch/location model | Concept / Refactor | Useful shared organization-location capability if stripped of service-center semantics. |
| Billing/invoices/payments | Concept / Refactor | Potential shared commercial foundation; must be separated from future accounting domain responsibilities. |
| Notifications / audit | Concept / Refactor | Reusable foundation patterns require review against new security and domain boundaries. |
| Service-center operational modules | Reject for initial platform core | Domain-specific to the donor product; not part of the HR V1 or shared Platform Core. |

## Critical reuse rule

The donor repository is not a base project and must not be forked as the starting application. Reuse occurs component-by-component only after source, schema, RLS/authorization behavior, migration history, tests, and dependencies are reviewed.

## Required next audit steps

1. Map donor tables/RPCs/services to proposed Platform Core capabilities.
2. Inspect authoritative tenant-isolation enforcement and RLS assumptions.
3. Inspect entitlement evaluation and limit accounting semantics.
4. Inspect subscription lifecycle state transitions and failure cases.
5. Inspect role/permission coupling and tenant-user assumptions.
6. Identify dependencies on service-center domain entities.
7. Produce final Reuse / Refactor / Concept Only / Reject matrix.
8. Record any resulting architecture decisions as ADRs before implementation reuse.
