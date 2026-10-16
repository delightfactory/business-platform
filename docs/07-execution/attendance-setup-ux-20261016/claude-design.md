I've read the three skills, the new-source page, `SourceForm`, `actions.ts`, the save, options and validate SQL, and the settings audit. I couldn't write the plan file because no write tool is available here, so the contract is below.

# Attendance source setup: UX contract and problems with the proposal

**Verdict:** The approach is sound. Implement it with the 8 fixes below; items 1–3 are blockers.

## Problems with the proposal

1. **The disable form would break.** `SourceForm` with `disableOnly` (`ChannelForms.tsx:29`) sends every stored config value back as a hidden field, including `retention_seconds`. If `mutateChannel` only reads an amount and a unit, stopping a source fails. `actions.ts` must accept `retention_amount` + `retention_unit`, or fall back to `retention_seconds` when both are missing. It should do the conversion itself on the server and not trust a seconds value computed in the browser.
2. **The read needs a `has_more` flag.** Without it you can't honestly say "first 20 results". You also can't safely skip the site choice when the company has only one active site, as the audit recommends. Fetch `limit+1` rows and return `{items, has_more}`.
3. **Showing edits in raw seconds keeps today's confusion.** Show stored values in the largest unit that divides them exactly (86400 → 1 day, 5400 → 90 minutes). Use seconds only when nothing larger divides exactly. This is exact and never rounds. Amounts are whole numbers only. Limits per unit:

   | Unit | Allowed amount |
   |---|---|
   | Days | 1–30 |
   | Hours | 1–720 |
   | Minutes | 1–43200 |
   | Seconds | 60–2592000 |

   The server rejects anything that doesn't convert to 60..2592000.
4. **The duplicate-site error still leads to a generic list.** When saving hits a 23505 on `channel_mobile_site_idx` (`actions.ts:35`), the server action should rerun the new lookup for that site and return the existing source's id. The recovery link then opens `/sources/{id}` directly. If the lookup fails, keep today's link to the list.
5. **Search results are unescaped and can arrive out of order.** The existing options RPC passes `%` and `_` straight into ILIKE; escape them in the new RPC. On the client, number each request and ignore any reply that isn't the latest. Keep the selected site in the list even when a new search doesn't return it, the same way line 28 does today. Save the selected site together with its existing-source result, so a later search can't change what the form shows.
6. **A failed lookup must not block creation.** If the lookup fails, say the check couldn't be completed and offer a retry. Still allow creating, because database uniqueness is the final guard. If permission was removed, the action returns "denied": disable the form and show the existing message about missing permission.
7. **Mobile sources need a site on the server too.** Today only the browser requires it, and the database accepts a mobile source with no site, which the unique index doesn't catch. `mutateChannel` should reject `kind=mobile` without a site, using a field-specific message.
8. **The suggested name must not overwrite typing.** Fill in `حضور الهاتف — {اسم الموقع}` only while the name is empty or still equals the previous suggestion. Name, type and site become fixed after creation, so the hint says so.

## Contract

**Actor:** someone for whom `channel_operator_can(tenant,true)` is true.
**Job:** set up phone attendance for a site, or open the existing setup.
**Start:** Time → Attendance sources → Add.
**Done:** the saved source page opens with its current state shown.

**New-form order:**
1. **Type.** External sources keep their separate path: site optional, no duplicate check, the existing "no device connection" hint.
2. **Site,** with inline search and the existing source's status shown when the site is chosen.
3. **Name.**
4. **Location policy:** geofence required or not, then retention amount + unit. The unit defaults to days and the amount is blank. With geofence: map, then precision settings, then the failure result.
5. **Whether to accept new records,** as an explicit choice placed just before the reason.
6. **Reason,** then the submit button.

**When the chosen site already has a phone source (active or stopped):**
- Hide sections 3–6.
- Show: «لهذا الموقع وسيلة حضور من الهاتف باسم "{name}" — {مفعّلة/موقوفة}. عدّل إعداداتها أو فعّلها من صفحتها؛ لا يلزم إنشاء وسيلة ثانية.»
- The primary action is a link, «فتح إعداد الوسيلة».
- The secondary action is «اختيار موقع آخر». Hidden draft values stay in the form and come back if the user picks another site.
- Nothing is copied into the edit page or changed automatically.

**Site search states:**

| State | Copy / behavior |
|---|---|
| Loading | «جارٍ البحث…» with `aria-busy`. The current selection stays. |
| Empty | «لا يوجد موقع نشط بهذا الاسم.» |
| More results | «تظهر أول 20 نتيجة؛ اكتب جزءًا أدق من الاسم.» Only when `has_more` is true. |
| Error | «تعذر التحقق من وجود وسيلة لهذا الموقع. يمكنك إعادة المحاولة؛ الحفظ يمنع التكرار.» |
| Denied | The form is disabled. |

The `?q=` parameter still fills the search box, so existing deep links keep working. The page no longer submits a separate GET form.

**Edit form:**
- Type, site and name are fixed.
- Every existing policy value is shown, with retention in its exact unit.
- Location fields appear only when geofence is "مطلوب".
- The reason stays required.
- Saving creates a new version, as today.

**Saving:**
- Save calls still go one at a time, and entered values are kept on failure.
- Keep the separate outcomes: success, specific failure, and uncertain result (check before retrying).
- After creating, open the source page.

**Retention field help:** «مدة حفظ دليل الموقع قبل أن يصبح قابلًا للحذف، من دقيقة إلى 30 يومًا. يبقى سجل الحضور محفوظًا.» No example values and no defaults.

**Unchanged:** permissions, the transaction lock, the unique index, `validate_channel_config`, the required reason, the GPS precision settings with no defaults, and mapping and review.

## RPC (the migration file is currently empty)

`attendance_channel_mobile_site_lookup(p_tenant, p_search text, p_limit int ≤20)`:
- `SECURITY DEFINER`, `search_path=''`, guarded by `channel_operator_can(p_tenant,true)`.
- Validates the length and limit the same way `attendance_channel_options` does.
- Returns active sites matching an escaped ILIKE, ordered by `display_name,id`.
- Each site is joined to its `channel_sources` row where `kind='mobile'`, plus the latest version's `enabled`.
- Returns `{items:[{id,display_name,source:{id,name,enabled}|null}],has_more}`.
- Revoke from public, anon and service_role; grant to authenticated.

The new page uses it for sites. `attendance_channel_options` stays for employee and mapping lists.

## Evidence needed

Before and after measurements:
- The number of required inputs reached before learning a site is already taken. Today it's up to 14; the target is 2.
- Whether the draft survives a site search. Today it's lost; the target is that it's kept.

Scenarios to run:
- A site with an active source, and a site with a stopped source.
- Two sessions creating a source for the same site at once.
- A new site with geofence on: entering retention as days, and as 90 minutes.
- Editing a source with retention stored as 86400 and as 3601.
- Stopping a source with the reason form.
- A lookup error, and a user whose permission was removed.
- Phone width at 360px and desktop width, using keyboard only.

Rendered screenshots and an independent review are still required. None of this has been verified yet: I didn't run anything or look at rendered screens.