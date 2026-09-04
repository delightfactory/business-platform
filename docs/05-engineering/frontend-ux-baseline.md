# Frontend and UX Baseline

## Purpose

Define the experience and implementation guardrails for the web application so every product surface behaves like a professional application across desktop, laptop, tablet, and mobile without fragmenting into separate UI implementations.

## Product experience objective

Business Platform is delivered as a web application, but the experience must adapt convincingly to the device context:

- on desktop and laptop screens, it should feel like a polished desktop-class business application with efficient information density, clear hierarchy, stable navigation, and productive workflows;
- on mobile screens, it should feel like a purpose-designed mobile application rather than a desktop page squeezed into a narrow viewport;
- tablet and intermediate sizes must receive deliberate layouts rather than accidental breakpoint leftovers.

Responsive behavior is a product requirement, not a cosmetic enhancement applied after desktop implementation.

## Adaptive layout principle

The same capability may use different composition patterns by viewport and interaction mode while preserving the same product semantics.

Examples:

- desktop navigation may use a persistent sidebar while mobile uses a bottom/tab/drawer pattern where appropriate;
- dense desktop tables may become cards, grouped rows, condensed lists, or drill-down views on mobile rather than horizontal overflow by default;
- multi-column forms may collapse into a single-column mobile flow;
- side panels and split views may become full-screen sheets/pages on smaller devices;
- actions may move between toolbars, contextual menus, bottom action areas, or floating controls according to device ergonomics.

The goal is not pixel-identical rendering. The goal is consistent task completion with device-appropriate interaction.

## Design system and reusable primitives

Core visual and interaction primitives must be implemented as reusable, centrally governed components rather than recreated per feature.

At minimum, the shared design system should eventually cover, as required by active scope:

- typography and spacing tokens;
- color and semantic state tokens;
- buttons and action groups;
- inputs, selects, date/time controls, switches, and validation states;
- form field wrappers, labels, help text, errors, and required-state behavior;
- cards, panels, sections, separators, and containers;
- dialogs, sheets, drawers, popovers, menus, and confirmations;
- tables, lists, empty states, loading states, and pagination/infinite-loading patterns;
- alerts, toasts, badges, statuses, and progress indicators;
- navigation primitives;
- responsive application shell;
- accessibility and focus behavior;
- mobile-safe touch targets and desktop keyboard efficiency where relevant.

A component must not be made generic merely because reuse is imaginable. Reusable primitives are justified when they represent a recurring product interaction or visual contract.

## Single-source improvement principle

When a recurring component or interaction is improved, the change should normally propagate from the shared implementation rather than require editing every screen independently.

Feature screens should compose approved primitives and domain-specific components. They should not clone base controls, validation patterns, spacing systems, dialog behavior, or navigation conventions unless a documented exception is required.

## UX flow consistency

User experience is not limited to visual styling. Each workflow must define:

- entry point and user intent;
- primary and secondary actions;
- required information and sensible defaults;
- validation timing and error recovery;
- loading, empty, partial, success, and failure states;
- confirmation behavior for sensitive actions;
- cancellation and back-navigation behavior;
- permission/entitlement-disabled behavior;
- post-action destination or next best action.

Equivalent actions across modules should behave consistently unless domain semantics justify a difference.

## Progressive complexity in the UI

The UI must reflect the platform's progressive-complexity principle:

- disabled capabilities should not create unnecessary navigation clutter or dead-end screens;
- advanced controls should appear only when the tenant configuration, entitlement, role, or workflow requires them;
- small organizations should be able to complete common tasks without navigating enterprise-only concepts;
- powerful enterprise configuration must not degrade the default experience.

## Desktop-class expectations

Desktop/laptop interfaces should prioritize productive business use:

- information density without visual clutter;
- stable page structure and predictable navigation;
- efficient use of width for lists, comparison, review, and data-heavy workflows;
- keyboard and pointer-friendly interaction where materially useful;
- clear master-detail, split-view, table, and bulk-action patterns when appropriate;
- no oversized mobile-first spacing that makes business workflows inefficient on large screens.

The desired experience is application-like rather than a collection of marketing-style web pages.

## Mobile-class expectations

Mobile interfaces must be intentionally composed for touch and narrow viewports:

- readable without zooming;
- no required horizontal page scrolling for normal workflows;
- appropriate touch targets and spacing;
- high-priority actions remain reachable;
- forms are sequenced for mobile completion;
- tables and dense data use mobile-appropriate representations;
- dialogs that are unsuitable on small screens become sheets or full-screen flows where appropriate;
- system keyboard, safe areas, viewport changes, and long content must not break critical actions.

The mobile experience should be judged against the expectations of a professional native-style business application, even when technically delivered through the web.

## Accessibility baseline

Accessibility is part of component correctness.

Where applicable, shared components and workflows must support:

- semantic structure;
- visible focus states;
- keyboard navigation;
- accessible names/labels;
- usable contrast;
- error messaging that is not color-only;
- logical focus movement for dialogs, validation, and navigation;
- screen-size-independent access to critical actions.

Accessibility requirements should be built into shared primitives so feature teams do not repeatedly solve them from scratch.

## Localization and directionality readiness

The design system and layout primitives must avoid assumptions that make future language or directionality support expensive.

Do not hard-code layout logic around left/right when start/end semantics are appropriate. Text expansion, number/date formats, and potential RTL requirements must be considered in reusable component design when the supported product languages require them.

This principle does not require building unused localization infrastructure before the active release needs it.

## Performance and perceived quality

Professional UX includes perceived responsiveness:

- avoid unnecessary layout shifts;
- use deliberate loading/skeleton states where latency is material;
- preserve user context during mutations and navigation where practical;
- avoid full-page refresh behavior for ordinary in-app interactions unless justified;
- large lists/forms should not become sluggish because reusable abstractions are inefficient.

## Responsive verification

Frontend work is incomplete until materially affected workflows are verified at representative viewport classes.

At minimum, responsive verification should cover:

1. mobile narrow viewport;
2. tablet/intermediate viewport where layout materially changes;
3. laptop/desktop viewport;
4. large desktop where excessive stretching or density problems may appear, when relevant.

Exact test viewport values may be standardized with the frontend stack later. The requirement is behavioral coverage across layout classes, not allegiance to arbitrary device models.

## UX acceptance evidence

For material user-facing changes, review evidence should show the resulting experience rather than rely only on implementation tests. Depending on change risk, this may include screenshots, visual regression checks, interaction recordings, automated browser tests, or documented manual acceptance on representative viewports.

Critical user flows must verify both successful completion and relevant failure/validation states.

## Anti-patterns

The following are not acceptable default practices:

- desktop-first screens that merely shrink until they technically fit;
- horizontal scrolling as the normal mobile solution for core workflows;
- one-off buttons/forms/dialogs that duplicate shared patterns;
- page-specific spacing/color/type systems;
- hiding actions on smaller screens without an alternative access path;
- relying on hover-only interactions for essential functionality;
- visual consistency without workflow consistency;
- generic component abstraction before a real recurring interaction exists;
- declaring a frontend feature Done without responsive and interaction-state verification.

## Governance rule

Material changes to shared design tokens, application shell behavior, core navigation, foundational interaction patterns, or reusable component contracts must be reviewed as shared frontend architecture because they affect multiple domains.

Ordinary domain-screen composition using existing approved primitives remains a normal implementation detail and must not require unnecessary governance overhead.
