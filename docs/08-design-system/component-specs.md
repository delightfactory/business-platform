# Component Specifications

The owned component layer. Feature screens import from here and nowhere else.

Read with: [`reference/components.css`](reference/components.css) for exact measurements, [`reference/previews/`](reference/previews/) for the rendered result, [`reference/guidelines/`](reference/guidelines/) for usage rules.

## Layout

```text
src/styles/tokens.css          generated from docs/08-design-system/tokens.json and brand-palettes.json
src/app/globals.css            Tailwind import, @theme mapping, base reset only
src/lib/cn.ts                  clsx + tailwind-merge
src/lib/format.ts              dates, times, durations, money, counts (ar-EG-u-nu-latn)
src/lib/status.ts              status dictionary: key -> { label, tone }
src/lib/product.ts             product name and monogram
src/lib/flash.ts               one-time flash message (set on server, read once on client)
src/components/ui/             primitives (one file per component)
src/components/patterns/       composed patterns
src/app/dev/ui/                component gallery (not available in production)
```

## Rules for every component

1. Styled with Tailwind utilities that resolve to tokens. No literal color, no arbitrary pixel value that is not in `tokens.json`, no new global class.
2. Logical properties only (`ms-*`, `me-*`, `ps-*`, `pe-*`, `start-*`, `end-*`, `text-start`). No `left`/`right`.
3. Accepts `className` and merges it with `cn()`. Accepts `ref` as a prop (React 19).
4. Server Component by default. Add `'use client'` only when the component holds state or wraps an interactive Radix primitive.
5. Variants are declared with `cva`. Variant names below are the public API.
6. Every interactive element shows the `focus` ring (2 px solid, 2 px offset) on `:focus-visible`.
7. All motion respects `prefers-reduced-motion`.
8. Radix is imported only inside `src/components/ui`.
9. User-visible strings inside components (close, loading, pagination labels) are Arabic and come from props with Arabic defaults.

## Token mapping

`tokens.css` declares every token under its name in `tokens.json` (`--surface`, `--brand`, `--radius-sm`, `--shadow-md`, `--control-md`, ...), with light values on `:root, [data-theme="light"]` and dark values on `[data-theme="dark"]`. It also emits one `[data-brand="<key>"]` block per palette in `brand-palettes.json`, with a dark variant under `[data-theme="dark"] [data-brand="<key>"]`. `reference/tokens.css` shows the expected output for the base tokens.

`globals.css` maps tokens to Tailwind so utilities read as intent:

- colors: `bg-canvas`, `bg-surface`, `bg-surface-raised`, `text-muted`, `border-subtle`, `bg-brand`, `text-on-brand`, `bg-success-subtle`, `text-success-text`, and so on, one utility per color token;
- radius: `rounded-xs|sm|md|lg|full` resolve to the system values;
- shadow: `shadow-xs|md|lg` resolve to the system values and switch with the theme;
- type: one utility per type style (`text-body`, `text-title-lg`, ...) carrying size, line height and weight;
- spacing: Tailwind's 4 px scale already equals `space-1` to `space-16`; use `p-4`, `gap-6` directly;
- fonts: `font-sans`, `font-mono`;
- dark variant bound to `[data-theme="dark"]`, not to the media query.

Verify the exact `@theme` and custom-variant syntax against the Tailwind 4 documentation for the installed version before writing it.

## Primitives (`src/components/ui`)

### Button — `button.tsx`

| Prop | Values | Default |
| --- | --- | --- |
| `variant` | `primary` `secondary` `ghost` `danger` `danger-ghost` `link` | `secondary` |
| `size` | `sm` (32) `md` (36) `lg` (44) | `md` |
| `iconOnly` | boolean; requires `aria-label` | `false` |
| `loading` | boolean; shows spinner, sets `aria-busy`, blocks clicks | `false` |
| `block` | boolean; full width | `false` |
| `asChild` | boolean; renders the child (for `next/link`) through Radix `Slot` | `false` |

`SubmitButton` (`submit-button.tsx`, client): wraps `Button`, reads `useFormStatus`, takes `label` and `pendingLabel`. Replaces `src/components/submit-button.tsx`.

Acceptance: all six variants and three sizes render as in `previews/Button.html` in both themes; disabled and loading states block interaction; an icon-only button without `aria-label` fails typecheck.

### Icon usage

Import icons from `lucide-react` directly. Size by context: 18 px beside text, 16 px in small controls, 22 px in the bottom navigation. Stroke width 1.75. Directional icons (chevrons, arrows used for next/back) flip in RTL with the `rtl:` variant. Fixed assignments: home `Home`, employees `Users`, attendance `Clock`, organization `Layers`, work policies `Calendar`, users and permissions `KeyRound`, entities and sites `Building2`, branding `Palette`, tenants `Building2`, invitations `Mail`, limits `Wallet`, entitlements `Layers`, operators `ShieldCheck`.

### Field family — `field.tsx`, `input.tsx`, `textarea.tsx`, `native-select.tsx`, `combobox.tsx`, `date-field.tsx`, `money-input.tsx`, `search-input.tsx`

- `Field`: `label`, `optional?`, `hint?`, `error?`, `children`. Generates the id with `useId`, wires `htmlFor`, `aria-describedby`, `aria-invalid`. Error replaces hint.
- `Input`, `Textarea`: native elements with system styling. Height `control-md`; 16 px font and `control-lg` below 768 px.
- `NativeSelect`: for 7 options or fewer.
- `Combobox` (client): Radix Popover + `cmdk`. Props: `name`, `options: {value,label,description?}[]`, `defaultValue`, `placeholder`, `emptyText`, `required`. Renders a hidden input so the value posts with the form. Use for sites, departments, jobs, employers, employees.
- `DateField` (client): Radix Popover + `react-day-picker`. Props: `name`, `defaultValue` (ISO `yyyy-mm-dd`), `min`, `max`, `required`. Posts ISO through a hidden input; displays `1 ديسمبر 2026`. Week starts Saturday.
- `MoneyInput`: `inputMode="decimal"`, currency suffix (`ج.م`), posts a plain decimal string.
- `SearchInput` (client): debounced 300 ms, writes the `q` search param with `router.replace`, resets `page`.

Acceptance: a form built from these posts the same field names and value formats the existing Server Actions expect; keyboard-only selection works in `Combobox` and `DateField`; errors are announced.

### Choice — `checkbox.tsx`, `radio-group.tsx`, `switch.tsx`, `choice-row.tsx`

Radix Checkbox, RadioGroup, Switch. `ChoiceRow`: `label`, `description?`, control as child; the whole row is the hit target. `Switch` is for settings that apply on save of that control alone; inside a submitted form use `Checkbox`. All post standard form values (`name`, `value`).

### Badge — `badge.tsx`

`tone`: `neutral` `success` `info` `warning` `danger` `brand`. `dot` (default true). `Badge.Count` for counters. `Tag` for removable filter values.

`StatusBadge`: `domain`, `status`. Looks up `src/lib/status.ts`. Feature code never chooses a tone by hand.

Status dictionary (labels are the existing UI labels; do not rename):

| Domain | Key | Label | Tone |
| --- | --- | --- | --- |
| employee | `active` | نشط | success |
| employee | `scheduled` | يبدأ قريبًا | info |
| employee | `ended` | انتهت خدمته | neutral |
| employee | other | غير نشط | neutral |
| tenant | `active` | نشطة | success |
| tenant | `suspended` | معلّقة | warning |
| tenant | `closing` | قيد الإغلاق | warning |
| tenant | `closed` | مغلقة | neutral |
| membership | `active` | نشط | success |
| membership | `inactive` | غير نشط | neutral |
| invitation | `pending` | بانتظار القبول | info |
| invitation | `accepted` | مقبولة | success |
| invitation | `expired` | منتهية | neutral |
| invitation | `revoked` | ملغاة | neutral |
| delivery | `sending` | جارٍ التحقق من الإرسال | info |
| delivery | `sent` | أُرسلت بالبريد | success |
| delivery | `failed` | تعذر إرسال البريد | danger |
| attendance | `open` | قيد المتابعة | info |
| attendance | `ready` | جاهز للمراجعة | brand |
| attendance | `needs_review` | يحتاج مراجعة | warning |
| attendance | `approved` | معتمد | success |
| record | active / inactive / pending | نشط / غير نشط / قيد الانتظار | success / neutral / info |

Add a row here before introducing a new status in a screen.

### Avatar — `avatar.tsx`

`name` (initials: first letters of the first two words), `size`: `sm` 24, `md` 32, `lg` 56, `shape`: `circle` | `tile`, `src?` for logos. Decorative: `aria-hidden` when the name is printed next to it.

### Alert — `alert.tsx`

`tone`: `neutral` `info` `success` `warning` `danger`. `title?`, `children`, `action?` (one node). `role="alert"` for `danger`, `role="status"` otherwise. No accent border on one side.

### Toast — `toaster.tsx`, `flash-toast.tsx`

`Toaster` (sonner) mounted once in the root layout: bottom, inline-start on desktop; above the bottom navigation on phones; 6 s; pauses on hover and focus; `dir="rtl"`.

Success only. Two entry points:

- from a client component after `useActionState` returns success: `toast.success(message)`, optionally with an undo action;
- after a redirect: the Server Action calls `setFlash({ tone, message })` (`src/lib/flash.ts`) which sets a short-lived, non-HttpOnly cookie; `FlashToast` (client, in the root layout) reads it once on navigation, shows it and deletes it.

Flash messages contain no personal data (no email, name or amount).

### Dialog — `dialog.tsx`, `confirm-dialog.tsx`

`Dialog`: Radix Dialog. Width 480 px; bottom sheet below 768 px. Parts: `DialogHeader`, `DialogTitle`, `DialogBody`, `DialogFooter`.

`ConfirmDialog` (client): Radix AlertDialog.

| Prop | Meaning |
| --- | --- |
| `trigger` | the node that opens it |
| `title` | a question naming the action and the record |
| `impact` | `{ icon, text }[]` — what changes now, what stays, whether it can be undone |
| `confirmLabel` | repeats the verb of the title |
| `tone` | `default` or `danger` |
| `action` | the Server Action |
| `fields` | hidden fields to post |
| `typeToConfirm?` | a string the user must type for irreversible bulk or financial actions |

The confirm button is a `SubmitButton` inside a `<form action>`; cancel is `secondary`. Focus returns to the trigger on close.

### Drawer — `drawer.tsx`

Radix Dialog as a side sheet on the inline-end edge, 440 px; full page with a back button below 768 px. Parts: header (title, close), scrollable body, sticky footer. For 2 to 6 fields or a quick look at a record.

### DropdownMenu — `dropdown-menu.tsx`

Radix DropdownMenu. Items take `icon`, `tone="danger"`, `disabled` with `disabledReason`. Separator before destructive items. Items that open a confirmation end with `…`. An item may be a link (`asChild`) or wrap a `ConfirmDialog` trigger.

### Tabs — `tabs-nav.tsx`, `segmented.tsx`

`TabsNav`: link-based. Each tab is a `next/link` with `aria-current="page"`; the active tab comes from the URL (a search param or a sub-route). `count?` per tab. Horizontal scroll on overflow.

`Segmented` (client): switches the presentation of the same data (table/cards, density). Persists the choice when given a `storageKey`.

### Breadcrumbs — `breadcrumbs.tsx`

`items: { label, href? }[]`. The last item is the current page. Separator chevron flips in RTL. Rendered in the top bar by the page through a slot (see `AppShell`).

### Card, StatCard, DescriptionList, Timeline, Meter — `card.tsx`, `stat-card.tsx`, `description-list.tsx`, `timeline.tsx`, `meter.tsx`

- `Card`: `title?`, `action?`, `children`. Border `border-subtle`, radius `md`, no shadow. Never nest cards.
- `StatCard`: `label`, `icon?`, `value`, `of?`, `footer?` or `meter?`.
- `Meter`: `value`, `max`; turns `warning` at 85 % or more.
- `DescriptionList`: `items: { label, value }[]`; empty value renders «غير محدد». `SensitiveValue` (client) masks a value until the user reveals it.
- `Timeline`: `items: { title, meta, current? }[]`, newest first.

### EmptyState, Skeleton — `empty-state.tsx`, `skeleton.tsx`

`EmptyState`: `kind`: `first-use` `no-results` `error` `unavailable`; `icon`, `title`, `text`, `actions?`. `Skeleton`: block with pulse; `TableSkeleton`, `RecordSkeleton`, `FormSkeleton` compose it for `loading.tsx` files.

### Steps — `steps.tsx`

`items: { label }[]`, `current` index. Completed steps show a check.

## Patterns (`src/components/patterns`)

### AppShell — `app-shell/`

Replaces `src/components/context-navigation*.tsx`. Server component that loads the navigation description and renders client parts.

- `mode`: `tenant` | `operator`.
- Sidebar (≥ 1024 px): workspace switcher (logo or monogram, tenant name, opens tenant list and account menu), command trigger (from Phase 5), navigation groups with icons and counters, user bar with account menu (theme choice, sign out).
- 768 to 1023 px: sidebar becomes a drawer opened from the top bar.
- Below 768 px: app bar (logo, page title, actions) and bottom navigation with icon and label: home, the first two destinations the user can access, and «المزيد» which opens the full navigation sheet.
- Top bar: breadcrumbs slot, help, notifications placeholder is omitted until a notification feature exists.
- Operator mode: `operator-bg` sidebar and a persistent context bar «وضع المشغّل: تعمل بصلاحيات المنصة على كل الشركات.»
- Content area: max width `content-max`, padding `space-8` desktop, `space-4` phone. No text footer.

Navigation description, one per domain, in code (`src/app/tenant/[tenantId]/navigation.ts` and `src/app/operator/navigation.ts`):

```ts
type NavItem = { id: string; label: string; icon: LucideIcon; href: string; visible: boolean; count?: number };
type NavGroup = { id: string; label?: string; items: NavItem[] };
```

`visible` is computed from the same access snapshots the current navigation uses. Do not add, remove or relax any access check. Target tenant navigation:

```text
الرئيسية
الموارد البشرية        الموظفون · الحضور · الهيكل التنظيمي · سياسات الدوام
إدارة الشركة           المستخدمون والصلاحيات · الجهات والفروع · هوية الشركة
```

Target operator navigation:

```text
الرئيسية
الشركات                الشركات · دعوات الشركات · إعداد شركة
الاشتراكات             حدود الاشتراك · الوحدات المتاحة
المنصة                 المشغّلون
```

A group with no visible item is not rendered.

### PageHeader, RecordHeader — `page-header.tsx`, `record-header.tsx`

`PageHeader`: `title`, `count?`, `description?`, `primaryAction?`, `secondaryActions?` (max two), `menu?`. On phones only the primary action stays visible.

`RecordHeader`: `name`, `avatar`, `status`, `facts: ReactNode[]` (code, role, site, since), `actions`, `menu`.

### DataTable — `data-table/`

Server-rendered table with client islands for search, filters, selection and density.

```ts
type Column<Row> = {
  id: string; header: string; cell: (row: Row) => ReactNode;
  align?: 'start' | 'end'; sortable?: boolean; width?: string; hideBelow?: 'md' | 'lg';
};
type DataTableProps<Row> = {
  columns: Column<Row>[]; rows: Row[]; rowKey: (row: Row) => string;
  rowHref?: (row: Row) => string;           // whole row opens the record
  rowMenu?: (row: Row) => ReactNode;        // DropdownMenu
  mobileRow: (row: Row) => { title: ReactNode; subtitle?: ReactNode; badge?: ReactNode };
  toolbar?: ReactNode;                      // SearchInput, FilterChip..., actions
  pagination: OffsetPagination | CursorPagination;
  selection?: { name: string; bulkActions: ReactNode };
  empty: ReactNode;                         // EmptyState for the current condition
};
type OffsetPagination = { kind: 'offset'; page: number; pageSize: number; total?: number; hasMore?: boolean; hrefFor: (page: number) => string };
type CursorPagination = { kind: 'cursor'; count: number; nextHref?: string; firstHref?: string };
```

- Below 768 px the same data renders as a list of `mobileRow` items. No horizontal page scroll.
- Footer text: with `total`, «عرض 1 إلى 25 من 128» and page numbers. Without `total`, «عرض 1 إلى 25» with previous and next only. Never «الصفحة 1» alone.
- `FilterChip` (client): `param`, `label`, `options`; writes the search param; active state shows the chosen value and a clear button. Render a filter only when the backing RPC supports that filter.
- Density: `Segmented` with `storageKey="table-density"`.
- Selection: checkbox column; when one or more rows are selected, a floating bulk bar shows the count and `bulkActions`.
- Sorting: only on columns the RPC can sort.

### FormLayout — `form-layout.tsx`

`FormSection`: `title`, `description?`, fields in a two-column grid (`FormGrid`, `span={2}` for wide fields); one column below 768 px. `FormActionBar`: sticky at the bottom of the content area; primary at the end, cancel as `ghost`, optional save status at the start. `UnsavedChangesGuard` (client) confirms before leaving a dirty form.

Server Actions used with these forms return:

```ts
type ActionResult =
  | { ok: true; message?: string }
  | { ok: false; formError?: string; fieldErrors?: Record<string, string>; values?: Record<string, string> };
```

`fieldErrors` keys are field names. On failure the form keeps the entered values and focuses the first invalid field. The business validation inside each action does not change; only the shape of what it returns to the UI.

### CommandPalette — `command-palette.tsx` (Phase 5)

`cmdk` in a Radix Dialog, opened by Ctrl K / ⌘ K and by the sidebar trigger. Sources: navigation destinations and page actions the user can access. Record search is added only when a search RPC exists (Phase 7).

## Gallery — `src/app/dev/ui`

One page per component group, rendering every variant and state with a theme toggle and a brand switch. Returns `notFound()` when `NODE_ENV === 'production'`. It needs no session and no database. It is the surface for visual verification of Phase 0.
