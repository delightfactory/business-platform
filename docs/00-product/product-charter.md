# Product Charter

## Product definition

Business Platform is a modular, multi-tenant SaaS platform for operating business domains through a shared platform foundation.

HR & Payroll is the first commercial domain. The platform itself must remain business-domain neutral so future domains can be added without rebuilding the foundation.

## Product objective

Deliver commercially useful business software quickly while preserving the structural qualities required for secure multi-tenant growth, configurable customer needs, and future domain expansion.

## First commercial outcome

The first sellable product is an HR & Payroll domain capable of supporting the essential employee-to-payroll operating cycle without requiring unnecessary enterprise complexity.

## Target spectrum

The platform must support a spectrum of organizations:

- small organizations that need a simple operational flow and minimal configuration;
- growing organizations that need branches, policies, approvals, and integrations;
- larger organizations that need stronger controls, richer configuration, and advanced integrations.

The product must not force enterprise complexity onto smaller customers.

## Strategic product model

The platform is composed of:

1. **Platform Core** — shared, business-neutral capabilities.
2. **Business Domains** — independently bounded operational areas such as HR, CRM, Sales, Inventory, Procurement, and Finance.
3. **Entitlements** — control which capabilities are commercially available to each tenant.
4. **Configuration** — allows bounded operational variation without customer-specific code forks.

## V1 principle

V1 is not defined as the smallest possible demo. It is the smallest commercially coherent release that completes the primary job safely and correctly.

For HR & Payroll, that primary job is:

> manage employees and their working time and entitlements, then produce a correct, reviewable, approved, and reproducible payroll.

## Product non-goals for the initial phase

The initial phase does not attempt to build:

- a complete ERP suite;
- generic workflow/BPMN infrastructure;
- unrestricted rule scripting;
- universal dynamic forms;
- microservices for their own sake;
- customer-specific forks;
- speculative abstractions without a demonstrated use case.

## Change rule

Any material change to this charter must be documented and reviewed before it becomes an implementation assumption.
