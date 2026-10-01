# Product Specifications

This directory contains implementation-governing Product Specs.

## Active specification set

| Specification | Execution scope | Status | Gate |
|---|---|---|---|
| Platform Foundation | Cube 0 / Wave 1 | Frozen | Foundation work may implement |
| Tenant Branding | Cube 0 / Wave 1 | Frozen | Cube 0 branding may implement |
| Authorization & Access Control V1 | Cube 0 / Wave 1 | Frozen | Supplemental contract; ADR-004/008 and Platform Foundation remain authoritative |
| HR People & Work Context | Cube 1 / Wave 2 | Frozen | People work may implement |
| Attendance & Leave | Cubes 2–3 / Wave 3 | Frozen | Attendance and Leave may implement |
| [Cube 3 Leave Self-Service Amendment](cube-3-leave-self-service-amendment-2026-10-01.md) | Cube 3 / Wave 3 | Accepted amendment | Governs the bounded own-Leave path; DEC-014 full ESS/MSS deferrals remain unchanged |
| Employee Finance & Payroll | Cube 4 / Wave 4 | Frozen | Payroll may implement; statutory production qualification remains required |
| Attendance Channel | Cube 5 / Wave 5 | Frozen | Channel Core/mobile may implement; vendor-specific biometric adapter still requires bounded adapter sub-spec |

## Governing rule

A specification is implementation authority only when its lifecycle status is `Frozen` or when an Accepted amendment explicitly governs it.

The final documentation alignment was approved on 2026-09-29; use the repository revision containing this index and its referenced specifications as the exact implementation baseline. Later material changes require the normal amendment process.

All V1 specs inherit the product-wide operational-simplicity rule: internal technical/domain complexity is absorbed behind task-oriented workflows, progressive disclosure and exception-focused operation. Simplicity never weakens tenancy, authorization, audit, financial correctness, compliance or historical reproducibility.
