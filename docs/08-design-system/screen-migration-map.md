# Screen Migration Map

Every route at revision `504f904`, its target archetype, and what changes. Archetypes are defined in [`experience-patterns.ar.md`](experience-patterns.ar.md). Phases are defined in the [execution plan](../07-execution/design-system-v2-execution-plan.md).

Rules that apply to every row:

- keep the route path, the data loading, the Server Actions and every access check;
- keep the existing Arabic copy unless a row or `foundations.ar.md` says otherwise;
- replace `PageFrame`, `auth-card`, `work-card`, `auth-form`, `record-card`, `entity-status`, `*-button` classes with system components;
- replace every `?state=` message with `ActionResult` or a flash message;
- replace every `<details>` with `DropdownMenu`, `ConfirmDialog` or `Drawer`;
- add `loading.tsx` with the matching skeleton.

## Tenant workspace

| Route | Archetype | Phase | Changes |
| --- | --- | --- | --- |
| `/tenant/select` | Focused choice | 5 | Centered card, one row per tenant with logo tile, name and status. Sole tenant keeps the current auto-entry behavior. |
| `/tenant/[tenantId]` (layout) | — | 1 | `AppShell mode="tenant"`, `data-brand` from `primary_color_key`, logo in workspace switcher. Remove inline `--color-brand`. |
| `/tenant/[tenantId]` | Dashboard | 5 | Greeting and date; usage `StatCard`s for seats and sites from the existing snapshot with `Meter`; setup checklist derived from existing snapshots; remove the task links that duplicate navigation. Member (non-admin) view: greeting and their account facts in a `Card`. The attention list appears only for items available from existing RPCs; otherwise omitted until Phase 7. |
| `/tenant/[tenantId]/people` | List | 2 | `PageHeader` with primary «إضافة موظف» and secondary «استيراد». `DataTable`: employee (avatar, name, code), employer, site, start date, status. Instant search on `q`. Offset pagination with `hasMore` (no total until Phase 7). Remove header links to organization and work policies (now in navigation). |
| `/tenant/[tenantId]/people/new` | Form (steps) | 4 | Steps: البيانات الأساسية, العمل والفرع, الأجر, المراجعة. One Server Action submit at the end, same fields. `Combobox` for employer, site, department, job; `DateField`; `MoneyInput`. |
| `/tenant/[tenantId]/people/import` | Import | 4 | Steps layout around the existing import flow; errors in a compact table; rejected rows listed with reasons. No change to parsing or validation. |
| `/tenant/[tenantId]/people/[employeeId]` | Record | 3 | `RecordHeader` (name, status, code, job, site). `TabsNav` by `?tab=`: نظرة عامة, العمل والدوام, الأجر, حساب الدخول. Each existing panel (work assignment, lifecycle, compensation, user link) becomes a `Card` with `DescriptionList` and an edit `Drawer` or `ConfirmDialog`. Lifecycle actions move to the header menu. Amount masked with `SensitiveValue`. Remove the «الخطوة التالية» panel. |
| `/tenant/[tenantId]/people/organization` | List with tabs | 2 | `TabsNav`: الأقسام, الوظائف. `DataTable` per tab; create through a `Drawer` using the existing catalog form fields. Navigation label «الهيكل التنظيمي». |
| `/tenant/[tenantId]/people/organization/[kind]/[recordId]` | Record | 3 | `RecordHeader`, `DescriptionList`, edit in `Drawer`. |
| `/tenant/[tenantId]/people/work-policies` | List + form | 3 | `DataTable` of policy templates; the editor opens as a page-level `FormLayout` section or `Drawer` depending on field count (more than 6 fields: page). Navigation label «سياسات الدوام». |
| `/tenant/[tenantId]/attendance` | List | 2 | `PageHeader` «الحضور اليومي» with `DateField` as the date control (submits `date`), primary action by permission. `TabsNav` by status only if the list RPC can filter by status; otherwise a single list. `DataTable`: employee, expected, worked or late, status, attention reason as subtitle. Cursor pagination. Entitlement-off state as `Alert tone="info"`. Links to import, unassigned and review move to the page menu and to the tabs. Bulk approval uses the table selection and bulk bar with the existing action. |
| `/tenant/[tenantId]/attendance/review` | Review queue | 2 | `DataTable` compact density, rows needing review first as returned by the RPC; row opens the record. |
| `/tenant/[tenantId]/attendance/unassigned` | List | 2 | `DataTable`, `EmptyState` variants for each existing failure branch. |
| `/tenant/[tenantId]/attendance/[instanceId]` | Record (decision) | 3 | `RecordHeader` (employee, date, status). Facts in `DescriptionList` with formatted times and durations. The reason for attention as `Alert`. Decision actions in a sticky action bar: primary approve, secondary correct; each of the seven existing forms becomes a `Drawer` or `ConfirmDialog` posting the same action. |
| `/tenant/[tenantId]/attendance/import` | Import | 4 | Same treatment as people import. |
| `/tenant/[tenantId]/users` | List with tabs | 2 (list), 3 (actions) | `TabsNav`: الأعضاء, الدعوات with existing counts. Seat usage as `StatCard` with `Meter` instead of the summary strip. `DataTable`: email, role, status, access bundles. Row menu: إدارة الصلاحيات (Drawer with `ChoiceRow` list), ترقية/خفض (ConfirmDialog with impact list), تعطيل العضوية (ConfirmDialog, danger), إعادة التفعيل. Invitations: delivery status as `StatusBadge`; row menu: إعادة إرسال, إلغاء الدعوة (danger). Rename «حزم People» to «صلاحيات الموارد البشرية»; bundle labels stay as defined in code. Offset pagination with total (page count exists). |
| `/tenant/[tenantId]/users/invite` | Drawer | 3 | Becomes a `Drawer` opened from the list's primary action; the route stays as a full-page fallback. |
| `/tenant/[tenantId]/entities-sites` | List | 2 | `DataTable` of legal entities with site count and status; site usage `StatCard` with `Meter`. |
| `/tenant/[tenantId]/entities-sites/new` | Form | 4 | `FormLayout`, single section. |
| `/tenant/[tenantId]/entities-sites/[entityId]` | Record | 3 | `RecordHeader`; entity facts in `Card`; sites as a `DataTable` inside the page; the nine `<details>` blocks become row menus, `Drawer` edits and `ConfirmDialog`s. |
| `/tenant/[tenantId]/entities-sites/[entityId]/sites/new` | Drawer | 4 | `Drawer` from the entity record; route stays as fallback. |
| `/tenant/[tenantId]/branding` | Settings | 4 | Two `FormSection`s: الاسم والشعار, اللون. Color choice as four radio tiles rendering each palette from `brand-palettes.json`. Live preview of a sidebar item and a primary button. |

## Operator workspace

| Route | Archetype | Phase | Changes |
| --- | --- | --- | --- |
| `/operator` (layout) | — | 1 | `AppShell mode="operator"` with the context bar. |
| `/operator` | Dashboard | 5 | Entry cards replaced by counts and links only for data the page already loads; otherwise a short list of the operator's available areas with icons. |
| `/operator/tenants` | List | 2 | `DataTable`: tenant, lifecycle status, and the columns the current list RPC returns. Search as today, instant. |
| `/operator/tenants/[tenantId]` | Record | 3 | `RecordHeader` with tenant name and lifecycle badge; snapshot facts in `DescriptionList`; lifecycle actions in the header menu with `ConfirmDialog` (danger, impact list). Links to this tenant's limits and entitlements as tabs. |
| `/operator/invitations` | List | 2 (list), 3 (actions) | `DataTable` with lifecycle and delivery `StatusBadge`s; row menu for reissue and revoke. |
| `/operator/invitations/new` | Drawer | 3 | `Drawer` from the list; route stays as fallback. |
| `/operator/onboarding` | Form | 4 | `FormLayout` with sections. |
| `/operator/commercial` | List | 2 | `DataTable`: tenant, seat usage, site usage with `Meter`. |
| `/operator/commercial/[tenantId]` | Settings | 4 | `FormSection` per limit; current usage beside each control. |
| `/operator/entitlements` | List | 2 | `DataTable`: tenant, enabled modules as `Tag`s. |
| `/operator/entitlements/[tenantId]` | Settings | 4 | One `Card` per module with status badge, effective date, and a change action in a `Drawer`. Dependency note (payroll needs HR) as `Alert tone="info"`. |
| `/operator/operators` | List | 2 (list), 3 (actions) | `DataTable`; grant form in a `Drawer`; the three `<details>` become row menu items with `ConfirmDialog`. |

## Authentication and entry

All use one `AuthLayout` pattern (Phase 5): centered card 400 px wide on `canvas`, wordmark above, `control-lg` fields, full-width primary button, no sidebar.

| Route | Changes |
| --- | --- |
| `/` | Remove the «الأساس التقني جاهز» development page. No session: redirect to `/auth/login`. With a session: apply the destination rule the login action already uses in `src/app/auth/actions.ts` (extract it into a shared function without changing it). |
| `/auth/login` | `AuthLayout`; field-level errors; link to forgot password. |
| `/auth/forgot-password`, `/auth/password/update` | `AuthLayout`; the invalid-link branch as `EmptyState kind="unavailable"` with a recovery link. |
| `/auth/invitations/accept`, `/auth/invitations/callback` | `AuthLayout`; multi-branch states as `Steps` where the flow has steps, `Alert` for expired or revoked. |
| `/auth/membership-invitations/accept`, `/auth/membership-invitations/callback` | Same. |
| `/auth/employee-account-activation`, `/auth/employee-account-activation/callback` | Same. |
| `/auth/callback` (route handler) | No change. |

## Shared states (Phase 1)

| File | Content |
| --- | --- |
| `src/app/not-found.tsx` | `EmptyState kind="unavailable"`: «الصفحة غير موجودة», link home. |
| `src/app/error.tsx`, `src/app/tenant/[tenantId]/error.tsx`, `src/app/operator/error.tsx` | `EmptyState kind="error"`: «تعذر تحميل الصفحة. لم يتغير شيء.», retry button calling `reset()`. |
| `loading.tsx` in `tenant/[tenantId]`, `operator`, and each list, record and form segment | `TableSkeleton`, `RecordSkeleton` or `FormSkeleton`. |
| Existing in-page `Unavailable` and `Status` helpers | Replaced by `EmptyState` inside the shell, keeping their text and recovery links. |
