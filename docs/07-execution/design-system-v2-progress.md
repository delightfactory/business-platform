# Design System v2 — Progress

Updated in every pull request of the [execution plan](design-system-v2-execution-plan.md). Check an item only when its acceptance in the plan is met and evidence is saved.

Baseline revision: `504f904`.

## Phases

| Phase | Status | Pull request | Evidence |
| --- | --- | --- | --- |
| 0 Foundation | Not started | | |
| 1 Shell and navigation | Not started | | |
| 2 Lists | Not started | | |
| 3 Records and actions | Not started | | |
| 4 Forms and imports | Not started | | |
| 5 Home, entry screens, phone pass, theme | Not started | | |
| 6 Removal and governance | Not started | | |
| 7 Data enablement | Awaiting go-ahead per item | | |

## Phase 0

- [ ] Dependencies added and exact-pinned
- [ ] `tokens:build` script and generated `src/styles/tokens.css`
- [ ] `lint:design` script with baseline
- [ ] `cn`, `format`, `status`, `product`, `flash` libraries; `format` tests
- [ ] Fonts and theme cookie in root layout
- [ ] Button, SubmitButton
- [ ] Field, Input, Textarea, NativeSelect, Combobox, DateField, MoneyInput, SearchInput
- [ ] Checkbox, RadioGroup, Switch, ChoiceRow
- [ ] Badge, StatusBadge, Tag, Avatar
- [ ] Alert, Toaster, FlashToast
- [ ] Dialog, ConfirmDialog, Drawer, DropdownMenu
- [ ] TabsNav, Segmented, Breadcrumbs
- [ ] Card, StatCard, Meter, DescriptionList, SensitiveValue, Timeline
- [ ] EmptyState, Skeleton set, Steps
- [ ] `/dev/ui` gallery; evidence saved

## Phase 1

- [ ] AppShell tenant
- [ ] AppShell operator with context bar
- [ ] Navigation descriptions; visibility parity verified per role
- [ ] Workspace switcher and account menu
- [ ] Phone app bar and bottom navigation; tablet drawer
- [ ] `data-brand` on tenant layout
- [ ] `not-found`, `error`, `loading` files
- [ ] Legacy navigation components deleted; page footers removed

## Phase 2

- [ ] PageHeader, DataTable, FilterChip, pagination, selection
- [ ] `/tenant/[tenantId]/people`
- [ ] `/tenant/[tenantId]/people/organization`
- [ ] `/tenant/[tenantId]/attendance`
- [ ] `/tenant/[tenantId]/attendance/review`
- [ ] `/tenant/[tenantId]/attendance/unassigned`
- [ ] `/tenant/[tenantId]/users` (list)
- [ ] `/tenant/[tenantId]/entities-sites`
- [ ] `/operator/tenants`
- [ ] `/operator/invitations` (list)
- [ ] `/operator/commercial`
- [ ] `/operator/entitlements`
- [ ] `/operator/operators` (list)

## Phase 3

- [ ] RecordHeader
- [ ] `/tenant/[tenantId]/people/[employeeId]`
- [ ] `/tenant/[tenantId]/people/organization/[kind]/[recordId]`
- [ ] `/tenant/[tenantId]/people/work-policies`
- [ ] `/tenant/[tenantId]/attendance/[instanceId]`
- [ ] `/tenant/[tenantId]/users` (actions) and `/users/invite`
- [ ] `/tenant/[tenantId]/entities-sites/[entityId]`
- [ ] `/operator/tenants/[tenantId]`
- [ ] `/operator/invitations` (actions) and `/invitations/new`
- [ ] `/operator/operators` (actions)
- [ ] No `<details>` in `src`
- [ ] No `?state=` result messaging in converted actions

## Phase 4

- [ ] FormLayout, UnsavedChangesGuard
- [ ] `/tenant/[tenantId]/people/new`
- [ ] `/tenant/[tenantId]/people/import`
- [ ] `/tenant/[tenantId]/attendance/import`
- [ ] `/tenant/[tenantId]/entities-sites/new` and `/[entityId]/sites/new`
- [ ] `/tenant/[tenantId]/branding`
- [ ] `/operator/onboarding`
- [ ] `/operator/commercial/[tenantId]`
- [ ] `/operator/entitlements/[tenantId]`

## Phase 5

- [ ] `/tenant/[tenantId]` home
- [ ] `/operator` home
- [ ] `/tenant/select`
- [ ] AuthLayout and all `/auth/*` screens
- [ ] `/` redirect
- [ ] CommandPalette
- [ ] Theme choice in account menu
- [ ] Phone pass of every screen

## Phase 6

- [ ] `workspace.css` deleted; `globals.css` reduced
- [ ] Cairo removed
- [ ] Lint baseline empty
- [ ] Legacy class grep clean
- [ ] Final evidence set

## Phase 7 go-aheads

| Item | Go-ahead (date, by) | Status |
| --- | --- | --- |
| B1 Directory filters, totals, status counts | | |
| B2 Home attention feed | | |
| B3 Record search | | |
| B4 Employee change history | | |
| B5 Attendance totals and status filter | | |

## Backend gaps

Record here each place where a screen fell back to degraded behavior: route, what is missing, which Phase 7 item covers it.

## Open questions

Record here each question that blocked an item: date, file and line, the question, what was skipped.
