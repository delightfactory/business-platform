# Product Specifications

This directory contains implementation-governing Product Specs.

## Active specification set

| Specification | Wave | Status | Gate |
|---|---:|---|---|
| Platform Foundation | 1 | Frozen | Wave 1 may implement |
| HR People & Work Context | 2 | Proposed freeze candidate | Must be Frozen before Wave 2 code |
| Attendance & Leave | 3 | Proposed freeze candidate | Must be Frozen before Wave 3 code |
| Employee Finance & Payroll | 4 | Proposed freeze candidate | Must be Frozen before Wave 4 code |
| Attendance Channel | 5 | Proposed freeze candidate | Must be Frozen before Channel Core/mobile code; vendor-specific biometric adapter also requires its bounded adapter sub-spec |

## Governing rule

A specification is implementation authority only when its lifecycle status is `Frozen` or when an Accepted amendment explicitly governs it.

All V1 specs inherit the product-wide operational-simplicity rule: internal technical/domain complexity is absorbed behind task-oriented workflows, progressive disclosure and exception-focused operation. Simplicity never weakens tenancy, authorization, audit, financial correctness, compliance or historical reproducibility.
