# Platform experience architecture

Status: working design contract for the shared application structure, pending rendered verification. It applies the accepted Product Charter, Master Product Blueprint, Platform Foundation Specification, ADR-002, ADR-003, ADR-004, and ADR-010. It does not supersede them, add a Business Domain, or change the authoritative access model.

## The product the shell must serve

Business Platform is one multi-tenant SaaS application with a business-neutral Platform Core and independently bounded Business Domains. HR and Payroll are the first commercial domains, not the application's root. The same structure must admit Sales, Inventory, Finance, CRM, and other domains without turning every screen into an HR variation or rebuilding navigation for each launch.

The application structure has to make three relationships obvious to a user: **which workspace am I in, which business area am I using, and what task or record am I working on?** A beautiful Tenant administration page cannot compensate for an application frame that has no place for future domains.

```text
Authenticated User
  ├── Platform Operator workspace (separate authority)
  └── Tenant workspace (one explicit, authorised Tenant)
        ├── Workspace home
        ├── Business areas (only implemented and available Domains)
        │     └── Domain home → work area → task or record
        └── Company administration (Platform Core)
              └── people with access, legal structure/Sites, identity, etc.
```

The Operator workspace is not a Business Domain, and company administration is not a submodule of HR. A user who has both Operator and Tenant authority switches workspaces deliberately and can always tell which authority context is active.

## Ownership and boundaries

| Layer | Owns | Does not own |
| --- | --- | --- |
| Shared application shell | Account identity, active workspace and Tenant, workspace switch, top-level navigation, accessible responsive frame, common feedback and focus behavior | HR/Payroll terminology, domain records, business process sequencing, universal branch selection |
| Platform Core experience | Tenant administration, membership, Legal Entity and Site identity, branding, Operator controls, commercial access visibility | Employer/payroll facts, warehouse or sales semantics for a Site, domain-specific configuration |
| Business Domain experience | Its landing page, work-area navigation, tasks, records, statuses, empty/error states, and authorised entry points | Global Tenant switching, Platform Operator authority, redefining the shared frame |

Every Domain uses the same shell and shared interaction primitives, but it owns its internal information architecture. A Domain should not be forced into a generic dashboard, CRUD page template, or workflow engine to achieve consistency.

An internal engine is not automatically a navigation destination. Calculation, audit, import, policy, and integration engines may power a task or expose a status in their owning area without becoming separate top-level modules. Navigation follows a user's work, while code ownership follows architectural boundaries.

## Navigation hierarchy

### 1. Workspace selection

After authentication, the user enters a concrete authorised Tenant or the separate Operator workspace. A sole active Tenant may be selected for convenience, with authoritative validation on every operation. Multiple memberships require a clear choice or switcher. Switching Tenant clears or reloads Tenant-scoped data and returns to a safe Tenant landing page; it does not carry stale Site, Legal Entity, record, or domain filters into another Tenant.

### 2. Global destinations inside a Tenant

The top level contains **Home**, **Business areas**, and **Company administration**. These are product concepts, not a flat list of every screen. The active Tenant and current Business Domain remain visible as orientation. Company administration has a smaller, separate group for access, structure, and identity; it does not compete visually with daily domain work.

Implemented, entitled Domains are discoverable under Business areas. No link is shown for a future Domain that has no product surface. Entitlement alone cannot make an unimplemented screen appear. Permission may narrow the work areas a user can enter. The destination and data boundary still validate Tenant state, entitlement, and permission independently of navigation visibility.

The hierarchy should read approximately as follows when real Domains exist; names and order are tested with users rather than copied mechanically into code:

```text
Acme Egypt                  ← active Tenant / switch when applicable
الرئيسية                    ← workspace home
مجالات العمل                ← implemented and available Domains
  الموارد البشرية            ← Domain entry, if implemented and available
  المبيعات                   ← later, only after its Domain is shipped
  المخزون                    ← later, only after its Domain is shipped
إدارة الشركة                ← Platform Core destinations
  المستخدمون
  الفروع والجهات القانونية
  هوية الشركة
الحساب                      ← personal/session controls
```

For a Tenant with only HR available, the list contains only HR. For a Tenant with no Business Domain available, the Business areas group explains the state instead of displaying dead links. Operator navigation has its own task groups and does not insert the Operator into this Tenant menu as another Domain.

### 3. Navigation inside a Domain

A Domain landing page exposes the work areas and next useful actions that exist in that Domain. Domain-owned local navigation can use tabs, a subsection list, or a task index when its real depth warrants it. Global navigation names the Domain; it does not expand into every People, Attendance, Leave, Payroll, Sales, or Inventory action. This keeps the shell stable as domains grow.

### 4. Task and record location

Each task or record shows its Domain, work area, record identity, current state, and a route back to the correct collection. The page carries the business decision and consequence. Breadcrumbs are used when actual depth needs them, not as decoration on every page.

## The smallest expansion seam

When the first Business Domain is implemented, its code contributes a small, code-owned navigation description: stable Domain ID, human name, landing route, and the capability/permission conditions for its visible entry points. The shell reads those descriptions to render the available destinations in the current Tenant. Authoritative route/data checks remain in the Domain and Platform access boundaries.

This is a compile-time composition seam within the modular monolith, not a database-driven plugin marketplace, dynamic page builder, or universal module framework. A second Domain contributes another description and its own routes. A fifth Domain does the same; the shell groups top-level entries and allows the list to scroll or be searched only if actual use makes that necessary. No shell code should branch on `if HR then ...` to decide the application's primary structure.

Capabilities inside one Domain may be independently entitled. The Domain decides which work areas are visible and how to explain a partially available product. For example, enabling People without Payroll must not create a dead Payroll route or make People unusable. This product rule remains in that Domain's spec; the shell only presents the resulting authorised Domain entry.

## Workspace home under different commercial states

| Tenant state | Home behavior |
| --- | --- |
| No implemented Business Domain enabled | Company administration and its real setup actions remain usable. Explain plainly that no business area is available yet and direct an authorised admin to the current Operator/commercial handoff; do not show fake module tiles. |
| One Domain enabled | Show that Domain as the obvious work entry and any real pending/setup state supplied by it. Company administration remains reachable but secondary. |
| Several Domains enabled | Show a concise, ordered Business areas list and only genuine cross-domain attention items where an owning Domain exposes them. Avoid a speculative universal inbox or AI recommendation layer. |

Home is an orientation and launch surface, not a warehouse of generic metric cards. A Domain may own its own operational dashboard if that serves real work.

## Responsive frame

**Desktop:** a persistent RTL-start navigation region shows the workspace identity, top-level Business areas, Company administration, and account control. The current Domain may add local navigation within its own canvas. The work canvas has a stable title/action hierarchy and controlled content width; data-dense work can use more width without stretching every form.

**Tablet:** preserve the same hierarchy with an explicit, labelled menu or compact rail according to available room. A narrow icon-only rail is not the default; it removes labels precisely where users are learning the platform. Domain content may use two panes when a list/detail task benefits.

**Phone:** the header always exposes the active Tenant or Operator context and current location. A small set of stable, labelled destinations leads to Home, Business areas, and Company administration in the Tenant workspace; Operator has its own Home, companies, and operational controls. The full authorised destination list is one reliable action away in an accessible sheet. The phone does not try to fit one tab per Domain, and a Domain does not add another permanent bottom bar by default. Safe areas, software keyboard, touch targets, focus, Escape/back behavior, and long Arabic company/Domain names are part of shell acceptance.

The exact placement of the phone destinations is verified with rendered prototypes and real tasks. The structural hierarchy above remains stable even if a bottom bar proves inferior to another accessible pattern in testing.

## Context and cross-domain work

Tenant is the global data and authority context. Legal Entity and Site are shared identities but **not universal global filters**: Payroll may need an Employer/Legal Entity scope, Inventory may need a warehouse Site, and CRM may not need either. Each Domain declares the scope of its own task and validates it. The shell may display a chosen context when the Domain asks, but must not silently apply one selected Site or Legal Entity to every Domain.

Moving between Domains preserves the Tenant and the user's orientation, then enters the target Domain's safe landing page or an explicit authorised deep link. Deep links carry a concrete Tenant and record context; they must survive normal refresh and fail safely when membership, Tenant state, entitlement, or permission changes. No cross-domain workflow engine is required to navigate between related tasks.

## Identity and visual coherence

The shell owns typography, spacing, focus, control states, page hierarchy, navigation geometry, and status language. Domain identity is conveyed through clear names and optional restrained visual cues, not wholly different component systems. Tenant branding can supply a logo and safe accent within the agreed token roles; it does not rewrite warning, error, success, or access semantics. Operator mode has an unmistakable authority label and context treatment.

Lists, forms, and record details should share interaction behavior while allowing different information density for Payroll review, Inventory stock work, CRM relationships, or Company administration. Consistency means the user can predict where to find state, actions, errors, and recovery, not that every Domain is forced into the same card layout.

## State and recovery contract

| Condition | User-facing result |
| --- | --- |
| No session | Sign in, preserving a safe intended destination. |
| No active membership or wrong Tenant | Explain lack of access and offer Tenant selection where another membership exists. Never silently choose another Tenant as authority. |
| Tenant suspended or archived | Show the minimal status and support/recovery route allowed by policy. Ordinary business data remains unavailable. |
| Domain not implemented | No navigation entry; a direct unsupported URL is unavailable. |
| Domain not entitled | No normal work entry. A direct route explains that this business area is not available for the company and identifies the current commercial/Operator handoff where appropriate. |
| Entitled but User lacks permission | Explain the access limitation and how to return or request access from the Tenant administrator. |
| Empty but authorised Domain | The Domain shows the first useful task or an explicit governed handoff. |
| Entitlement or permission changes during work | The next protected operation fails closed, preserves safe context where possible, and offers a clear return. Historical data handling follows the owning Domain's contract. |

## What Cube 0 must build and prove

Cube 0 implements the shared shell and Platform Core destinations, not mock HR/Sales/Inventory products. It must prove:

1. Operator and Tenant are separate authority contexts within one coherent visual system.
2. Single-Tenant, multi-Tenant, denied, suspended, and no-enabled-Domain journeys have clear destinations.
3. Navigation and page composition work at phone, tablet, and desktop widths with Arabic RTL, long names, keyboard and touch.
4. Permission and entitlement affect discoverability without replacing authoritative enforcement.
5. A design review can render the navigation model with zero, one, and several **fixture** Domains without exposing fake products to customers. The first real Domain adds its code-owned entry when implemented.
6. Tenant branding changes a safe accent/identity slot while preserving platform semantics and readable contrast.

Domain-specific task navigation, domain dashboards, and business-specific legal/Site filters belong to the owning Cubes. The Cube 0 shell is complete only when its currently implemented Platform journeys are usable and its expansion seam is explicit and small. This is a product UX acceptance condition alongside the existing engineering qualification, not a claim that future Domains have been built.
