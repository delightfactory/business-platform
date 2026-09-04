# Data Classification and Privacy Baseline

## Purpose

Define a minimum handling model for business and personal data before implementation begins, especially for HR, payroll, attendance, location, biometric-related, identity, and financial information.

This document defines engineering handling expectations. Jurisdiction-specific legal obligations must be researched, versioned, and documented separately before affected functionality is released.

## Data classes

### Public

Information intentionally safe for public disclosure.

Examples:

- public product documentation;
- public marketing content;
- non-sensitive public configuration examples.

### Internal

Operational information not intended for public disclosure but whose exposure would normally create limited harm.

Examples:

- internal product planning that contains no customer or security-sensitive information;
- non-sensitive operational metadata.

### Confidential

Tenant, business, or personal information whose unauthorized disclosure could materially affect a customer, employee, partner, or the platform.

Examples:

- employee profiles and contact details;
- salary and payroll information;
- attendance history;
- leave and disciplinary information;
- tenant commercial and operational records;
- invoices, payments, and financial exports;
- integration configuration that is not itself a secret.

### Restricted

Information requiring the strongest handling because compromise could create significant security, privacy, financial, or legal impact.

Examples:

- authentication secrets and credentials;
- service-role or infrastructure secrets;
- raw biometric templates or equivalent biometric identifiers if ever stored;
- highly sensitive identity documents where collected;
- sensitive location data beyond the minimum operational attendance evidence;
- cryptographic keys and recovery material.

## Default rule

When classification is uncertain, handle the data at the more restrictive reasonable level until classification is explicitly resolved.

## Collection and minimization

- Collect only information required by an active product capability or applicable obligation.
- Optional capabilities must not cause unnecessary collection when disabled.
- Location capture should be event-scoped when sufficient for attendance; continuous tracking is not a default requirement.
- Biometric-device integration should prefer receiving the minimum attendance event/identifier necessary instead of importing biometric templates into the SaaS platform where avoidable.
- Logs, telemetry, analytics, and support tooling must not become hidden secondary stores of sensitive payloads.

## Access and isolation

- Tenant-owned Confidential or Restricted data must be protected by authoritative tenant isolation.
- User authorization must be evaluated independently from tenant entitlement.
- Privileged platform access must be narrowly scoped and auditable where sensitive data can be accessed.
- UI hiding is not a privacy or authorization control.

## Storage and transmission

- Secrets must never be committed to source control.
- Sensitive data must use platform-appropriate protected transport and storage controls.
- Test fixtures must use synthetic or properly sanitized data unless an explicitly controlled exception is approved.
- Production-sensitive exports and backups must be treated according to the classification of the underlying data.

## Retention and lifecycle

Every capability that introduces Confidential or Restricted data must consider:

- why the data is retained;
- the required retention period or governing policy;
- correction/amendment behavior;
- deletion or de-identification behavior where applicable;
- export/portability requirements where applicable;
- what historical records must remain immutable for payroll, audit, or compliance reasons.

Retention rules must not be improvised globally before the governing use case or jurisdiction is known.

## Public repository rule

No Confidential or Restricted data may be committed to this public repository. Examples, screenshots, fixtures, logs, issue bodies, and PR evidence must be sanitized accordingly.

## Design review trigger

A feature requires explicit privacy/data-handling review when it introduces a new category of personal data, biometric-related data, location data, payroll/financial data, government identifiers, identity documents, external data sharing, or materially different retention behavior.