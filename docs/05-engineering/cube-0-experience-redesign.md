# Cube 0 experience redesign: Operator and Tenant

Status: design direction for implementation and device review. It is not UX acceptance. The [platform experience architecture](platform-experience-architecture.md) governs the application-wide shell and future Business Domain expansion; this document applies it to the current Operator and Tenant administration journeys.

## Why this redesign is necessary

The owner rejected the phone experience after trying the working product. The complaint covers page composition, visual hierarchy, terminology, navigation, action feedback, and the burden of scanning long pages. Fixing the menu button or styling the toast alone does not address it. The current screens often place navigation, summaries, creation forms, record actions, and success messages at similar visual weight. A user must inspect the page to discover the next task.

The redesign keeps the Cube 0 domain and security contracts. It changes the journey and presentation of the existing capabilities. The first Claude design review identified the task-versus-resource problem and the need to separate app chrome, work canvas, and focused action surfaces. A corrective Claude review retracted unsupported assumptions about hydration, instant updates, tenant creation on invitation, and branch-user assignments. This document selects only proposals supported by the current source and product scope.

## Product truth that the UI must preserve

- A First Admin invitation is **pending** after sending. The Tenant and its default Legal Entity and Site are created on acceptance. A separate Operator path creates a Tenant directly for a confirmed existing account.
- A Site belongs to a Legal Entity. Cube 0 does not assign users to Sites.
- Tenant administration covers membership, member invitations, Legal Entities, Sites, and branding. Operator administration covers the authorised Operator team, First Admin invitations, Tenant lifecycle, seat/Site limits, and domain entitlements. Operator grants target existing accounts; Cube 0 has no separate Operator invitation flow.
- Operator capabilities and Tenant permissions determine which destinations and actions appear; hiding a control does not replace server enforcement.
- Suspension, archiving, role changes, limits, and invitations have distinct consequences. The UI must show their durable state and correction route.

## Experience concept: a calm operating workspace

The interface should feel like one application with two clear contexts. The persistent frame answers **where am I and for which company?** The page answers **what state needs attention?** A focused task surface answers **what will this action change?**

The visual language is restrained and practical: Cairo for Arabic, a legible type scale, strong title and row hierarchy, compact record lists, measured whitespace, and semantic colour only for identity, current selection, status, and risk. Avoid a grid of identical floating cards, giant outlined action buttons, badges that substitute for feedback, and explanatory paragraphs before every task. Tenant branding may accent the Tenant context without changing control semantics or contrast.

The same shared shell serves Operator and Tenant. Its navigation content and context label change with permissions. Operator is visibly marked as platform operation; Tenant shows the active company and a clear company switch when available. No Operator impersonation is introduced.

### Visual direction to prototype before broad implementation

Use an **operations desk**, not a dashboard kit, as the composition metaphor. A stable dark-ink navigation plane establishes place. The work plane is light and almost flat; row separators and aligned columns communicate relationships. Reserve the Tenant accent for selection and primary actions. Status colour never carries meaning alone. Use Cairo at readable regular and bold weights; avoid oversized display text on task pages. The record name and current state lead each detail page, while secondary metadata recedes. Shadows should signal an actual floating surface such as a task sheet, not appear on every list item.

Prototype the **application frame and workspace navigation first** with zero, one, and several fixture Business Domains, multiple Tenants, and Operator access. Then use the Operator invitation collection and Tenant Legal Entity/Site detail to pressure-test the frame against real Cube 0 tasks: permissions, pending states, long forms, nested records, RTL, and phone density. Capture 360 px, tablet, and desktop views before turning the visual language into shared components. A prototype that looks attractive but hides the invitation state, Site parent relationship, or available Domain choices fails.

### Spatial rules

| Surface | Phone | Tablet | Desktop |
| --- | --- | --- | --- |
| App frame | Compact context header; high-frequency destinations within reach; full authorised menu through a labelled sheet | Context header plus explicit menu; use width for the work content | Persistent navigation rail and bounded work canvas |
| Collection | Page title and one primary action, then dense readable rows with name, state, and one next action | Rows with more metadata in aligned columns | Compact table-like rows, optional detail pane only where comparison helps |
| Record detail | Identity/status, relevant facts, related records, then rare actions | Single or two-column according to task | Facts and related records may sit side by side; risk actions remain separate |
| Focused task | Full screen with an obvious cancel/back action and a visible submit area above the keyboard when practical | Focused panel or page | Panel for short edits; dedicated page for the longer First Admin invitation |

The Operator invitation task has several required fields and limits. It deserves a focused page with small groups rather than a narrow drawer or an arbitrary three-step wizard. A short edit such as changing one limit can use a panel. Dangerous state changes use a confirmation that describes their effect. These choices are based on task size and consequence, not one universal component rule.

## Information architecture

| Page role | User question | Default composition |
| --- | --- | --- |
| Home | What can I do or what needs attention? | Short contextual heading, one relevant next action, concise status and routes to the other work areas. Never invent an alert count or recommendation. |
| Collection | Which invitation, person, company, or Legal Entity? | Title, primary action, scannable rows, visible state, empty-state action. Search/filter only when a real list size needs it. |
| Record detail | What is true about this specific record? | Identity and status first, related data second, actions grouped by frequency and risk. A clear way back to the collection. |
| Focused task | What information is required to complete one action? | Single purpose form or confirmation with an explicit result, cancel path, validation, pending state, and preserved input on error. |

### Operator journeys

1. **Invite a first administrator:** start from Operator home or company invitations; enter the supported company/admin details; submit with visible pending state; return to the invitation record showing **awaiting acceptance** and available reissue/revoke actions. Acceptance, not sending, creates the Tenant. The existing-account onboarding path is clearly separate and labelled by its prerequisite.
2. **Manage a company:** select a Tenant from the company collection; read current lifecycle state; open the specific lifecycle action; see the effect and required reason before confirming; return to the same record with changed state and a recovery action where allowed.
3. **Manage commercial access:** select a Tenant, read current seat and Site usage beside each current limit, change one limit or entitlement at a time, supply a reason, and see the effective decision after return. Keep conflict/future-conflict states visible and actionable according to current rules.
4. **Manage Operators:** see who has each active capability; grant, change, or revoke one account's capability set in a focused task, with an explicit confirmation for revocation and protected-account constraints.

#### Representative Operator screen flow

```text
Operator home
  → "دعوة مسؤول لشركة جديدة" (primary when authorised)
  → focused invitation task: company identity / first administrator / initial seat and Site limits
  → submit pending; retain values and explain any field or delivery failure
  → invitation collection with the new row selected:
       "بانتظار القبول" + delivery state + reissue/revoke when valid
  → after acceptance, Tenant appears in company collection with active state
```

The invitation collection and the company collection are separate because an unaccepted invitation is not a Tenant. Their relationship is explicit, without showing a pending invitation as an inactive company.

### Tenant journeys

1. **Work in the right company:** the active company stays visible in the frame; a user with multiple memberships can switch without confusing company data. Suspended, archived, denied, and missing-membership paths explain what happened and provide the available route back.
2. **Manage people:** show members and pending invitations as distinguishable views; make invitation the primary action where authorised; each row exposes its current role/state and only its relevant reissue, revoke, disable, reactivate, promote, or demote action. Protected Admin constraints are explained at the decision point.
3. **Manage Legal Entities and Sites:** show a compact Legal Entity collection and each Entity's Site count; enter an Entity detail to see its Sites. Add a Legal Entity from the collection, add a Site within its parent Entity, and keep default/active state on the relevant row. Rare or risky changes should not be rendered as a wall of open controls.
4. **Set company identity:** separate display name, logo, and colour from legal identity. Keep a realistic preview next to the form on wide screens and after the controls on a phone. Show the saved state in context.

#### Representative Tenant screen flow

```text
Company home
  → "الفروع" (common-language navigation; page explains legal grouping once)
  → Legal Entity collection: registered identity and Site count per Entity
  → Entity detail: name/default state + Site rows and current active state
  → "إضافة فرع" within this Entity → focused short task
  → pending state → return to same Entity with new Site row visible
```

If there is only the default Legal Entity, the first view can lead with its Sites and keep the legal grouping discoverable in the page context. Multiple Entities remain visible as distinct groups. This is progressive disclosure of complexity, not a change in data model.

## Shared shell by device

**Desktop:** stable navigation rail on the RTL start side; compact top area with current context and account actions; bounded work canvas with title, brief orientation, and page action. Use width for record comparisons and details, not stretched cards. Keep Operator and Tenant frame geometry consistent.

**Tablet:** keep context visible and use a compact rail or explicit menu according to available width. Collection/detail can become a two-pane view only where the task gains from it; otherwise use the same single-column hierarchy as desktop. No accidental intermediate layout.

**Phone (including 360px):** compact context header with a working menu control and clear current location. A short bottom destination bar may expose the highest-frequency authorised areas; a clearly named More destination opens all other authorised areas in a full-height sheet. The bar must not hide content or actions and must account for safe areas. Primary action appears before long explanatory content. Lists become readable rows; record details and focused tasks occupy the screen, with one column and an accessible back/cancel route. Do not depend on hover or horizontal scroll.

Navigation links and action buttons show an immediate pressed or pending response. The menu visibly opens, announces state, traps focus while open, closes on Escape/backdrop/selection, restores focus, and cannot remain over the next route.

## Interaction and feedback contract

- Every mutation has idle, pending, success, and failure states. Pending is visible in its own control and prevents duplicate submission. Navigating links show a pressed/loading affordance until the destination responds.
- Success is durable first: the changed invitation, member, Site, limit, or company state is visible on the resulting page. A short status message may supplement it; a global toast must not carry the only evidence of success or obstruct the active controls.
- Validation and action errors appear in or beside the task, use plain Arabic, preserve entered data where practical, and give a recovery action. Do not send a user to a generic page for an ordinary field error.
- Reversible low-risk actions need a clear result; high-impact actions require a focused confirmation explaining the effect and the reason requested by the existing contract.
- Use natural labels based on the user's job. Prefer «دعوة مسؤول للشركة» and «بانتظار قبول الدعوة» over internal state names; explain «الجهة القانونية» once as the registered identity and «الفرع» as a Site tied to it. Never use a term implying that an invitation already created a company.

## Small shared component set

Build only repeated interactions: `AppShell`, `ContextNav`, `PageHeading`, `RecordList`/`RecordRow`, `Status`, `TaskPanel` (phone full screen), `ConfirmAction`, `ActionButton`, `FieldError`, `EmptyState`, and contextual `Notice`. Use existing form controls where they work. Avoid a generic workflow engine, dynamic form builder, generic dashboard kit, or broad component library before real repetition appears.

## Coherent implementation sequence

1. **Platform frame and interaction foundation:** one domain-neutral shell with distinct Operator/Tenant contexts, Tenant switching, a scalable Business areas slot, device navigation, design tokens, action pending state, and feedback placement. Review the frame with zero, one, and several fixture Domains without shipping future-module placeholders. Verify route access and navigation on actual phone/browser conditions before moving on.
2. **Tenant work:** home, people/invitations, Legal Entity/Site collection and detail, branding. Complete each journey with empty, pending, success, failure, and denied states before starting the next.
3. **Operator work:** home and First Admin invitation, Tenant collection/lifecycle, limits/entitlements, Operator access. Verify that invitation wording reflects delayed Tenant creation.
4. **Whole-product qualification:** representative Operator and Tenant journeys at phone, tablet, and desktop; keyboard and touch; Arabic wording; RTL; no normal horizontal scroll; user review of the rendered result. Record screenshots, reviewed commit, and unresolved observations in the Cube 0 qualification record. Existing database assertions remain engineering evidence, not UX acceptance.

### Design and review capabilities used at each gate

| Gate | Applied capability | Concrete output |
| --- | --- | --- |
| Understand work | `enterprise-workflow-ux` and `product-flow-ux` | Actor, shortest real path, decision, result, failure and recovery map |
| Choose a visual direction | `frontend-design` (the installed Anthropic-origin skill) | Platform shell, workspace/Domain hierarchy, type, colour, density, navigation geometry and representative task compositions, checked for generic SaaS patterns |
| Write the interface | `arabic-ux-writing` | Page titles, actions, statuses, errors and empty states in consistent ordinary Arabic |
| Check rendered experience | `product-design:audit` plus browser inspection | Screenshots and findings tied to real Operator/Tenant steps at phone, tablet and desktop widths |
| Check capability closure | `backend-ui-closure` | Every shipped action reachable by its authorised role, with its true result and recovery path |

These skills are aids to judgment. A skill name, mockup, or passing build is not a user-acceptance result. Install or create another skill only if a specific missing capability emerges during the work; duplicated design checklists add noise without improving the interface.

## Acceptance gate

The redesign is not accepted merely because a component library, lint, or build passes. On a phone, a new user must identify where they are, reach the primary task, complete or safely cancel it, see a pending response, read the resulting durable state, and recover from a typical error without discovering hidden backend concepts. The same journeys must remain efficient on tablet and desktop. The owner must review the rendered journeys before Cube 0 product acceptance changes from open.

## Claims deliberately excluded

The Claude exploratory drafts proposed AI recommendations, Operator impersonation, branch-user assignment, tax fields, instant list updates without navigation, arbitrary response-time thresholds, fixed card counts, and a universal multi-step wizard. Those are not Cube 0 requirements. A `details` element alone does not prove a hydration defect; its current use is a composition problem to inspect, not an inferred root cause. This direction does not claim user acceptance or physical-device success before testing.
