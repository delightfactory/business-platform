# ADR-010 — Frontend Design System Foundation

## Status

**Proposed**

## Context

The product experience baseline requires desktop-class business workflows, native-style mobile composition, reusable components, accessibility, and centralized improvements. A purely page-by-page styling approach would create drift and make later UX improvements expensive.

The project also wants to avoid adopting a closed theme/component suite that dictates product identity or makes responsive composition difficult.

## Decision

Use the following UI foundation:

- Tailwind CSS 4.x as the styling/token implementation layer;
- CSS variables/design tokens as the canonical visual values for color, spacing, radius, typography, elevation, motion, density, and related shared concepts;
- an internally owned component layer as the normal feature-level import surface;
- shadcn/ui as an open-code starting/distribution model for selected components;
- Radix Primitives where appropriate for accessible low-level behavior and focus/keyboard semantics.

Feature code should normally import project-owned components rather than raw third-party primitives.

## Required architecture rules

1. Do not duplicate foundational controls such as Button, Input, Select, Dialog, Drawer/Sheet, Form feedback, Tabs, Menu, Badge, Empty state, Loading state, and similar recurring patterns inside feature folders.
2. Third-party primitive dependencies are wrapped/owned at the Design System layer unless there is a documented exception.
3. Base-component improvements must propagate centrally.
4. Responsive behavior is semantic: a desktop Table may become cards/list/drill-down on mobile without changing business meaning.
5. Tokens/components must be compatible with RTL/LTR layout direction; product-language choice is a separate decision.
6. Accessibility, keyboard, focus, and touch behavior remain part of component acceptance.
7. shadcn components are added selectively when required; do not bulk-import an unused component catalogue.
8. The Design System must not become a separate product/framework before repeated patterns justify abstractions.

## Component ownership model

Suggested logical layers:

```text
Design tokens
  -> low-level accessible primitives
  -> owned UI components
  -> composed application patterns
  -> domain/feature screens
```

Examples of composed application patterns that may emerge after repeated use:

- responsive record list/table;
- entity form shell;
- filter/search bar;
- review/approval panel;
- sensitive-action confirmation;
- status timeline;
- application page header;
- desktop sidebar/mobile navigation pattern.

Do not generalize a pattern until at least concrete product flows demonstrate it.

## Consequences

- visual and interaction changes can be applied from a central source;
- responsive/mobile behavior can diverge in composition without duplicating business logic;
- accessibility primitives reduce common low-level implementation risk;
- open-code components remain fully customizable for the product's visual identity;
- the team must actively maintain its owned component layer instead of treating third-party defaults as finished UX.

## Rejected alternatives

### Page-local Tailwind only

Rejected because it leads to repeated styles/components and product drift.

### Closed/pre-styled enterprise component suite as the product design system

Rejected for now because it creates more visual/behavioral lock-in than the product currently needs.

### Build every accessible primitive from scratch

Rejected as unnecessary risk and effort when mature headless primitives exist.
