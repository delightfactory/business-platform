# Cube 0 experience redesign: Operator and Tenant

Status: design direction for implementation and device review. It is not UX acceptance.

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

### Tenant journeys

1. **Work in the right company:** the active company stays visible in the frame; a user with multiple memberships can switch without confusing company data. Suspended, archived, denied, and missing-membership paths explain what happened and provide the available route back.
2. **Manage people:** show members and pending invitations as distinguishable views; make invitation the primary action where authorised; each row exposes its current role/state and only its relevant reissue, revoke, disable, reactivate, promote, or demote action. Protected Admin constraints are explained at the decision point.
3. **Manage Legal Entities and Sites:** show a compact Legal Entity collection and each Entity's Site count; enter an Entity detail to see its Sites. Add a Legal Entity from the collection, add a Site within its parent Entity, and keep default/active state on the relevant row. Rare or risky changes should not be rendered as a wall of open controls.
4. **Set company identity:** separate display name, logo, and colour from legal identity. Keep a realistic preview next to the form on wide screens and after the controls on a phone. Show the saved state in context.

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

1. **Frame and interaction foundation:** shared Operator/Tenant shell, device navigation, design tokens, action pending state, feedback placement. Verify route access and navigation on actual phone/browser conditions before moving on.
2. **Tenant work:** home, people/invitations, Legal Entity/Site collection and detail, branding. Complete each journey with empty, pending, success, failure, and denied states before starting the next.
3. **Operator work:** home and First Admin invitation, Tenant collection/lifecycle, limits/entitlements, Operator access. Verify that invitation wording reflects delayed Tenant creation.
4. **Whole-product qualification:** representative Operator and Tenant journeys at phone, tablet, and desktop; keyboard and touch; Arabic wording; RTL; no normal horizontal scroll; user review of the rendered result. Record screenshots, reviewed commit, and unresolved observations in the Cube 0 qualification record. Existing database assertions remain engineering evidence, not UX acceptance.

## Acceptance gate

The redesign is not accepted merely because a component library, lint, or build passes. On a phone, a new user must identify where they are, reach the primary task, complete or safely cancel it, see a pending response, read the resulting durable state, and recover from a typical error without discovering hidden backend concepts. The same journeys must remain efficient on tablet and desktop. The owner must review the rendered journeys before Cube 0 product acceptance changes from open.

## Claims deliberately excluded

The Claude exploratory drafts proposed AI recommendations, Operator impersonation, branch-user assignment, tax fields, instant list updates without navigation, arbitrary response-time thresholds, fixed card counts, and a universal multi-step wizard. Those are not Cube 0 requirements. A `details` element alone does not prove a hydration defect; its current use is a composition problem to inspect, not an inferred root cause. This direction does not claim user acceptance or physical-device success before testing.
