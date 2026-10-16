# Supplement: one phone attendance source per branch

## Verdict

This is now the top-ranked finding, above everything in my original report. Delight's form was most likely rejected because that branch already has a phone source, not because of anything the user typed. This is a demonstrated likely cause; no production exception has been tied to the owner's attempt.

The schema allows only one phone source per branch:
- `channel_sources` has a unique index `channel_mobile_site_idx` on `(tenant_id, site_id) WHERE kind='mobile'` (`20261004142814_cube5_attendance_channels.sql:12`).
- The index filters on kind only. Whether a source is enabled is stored separately, per version (`channel_source_versions.enabled`), so a stopped phone source still occupies the branch.

## How it fails today (from source and `attendance-duplicate-valid-local.jpg`)

1. **The create page can't tell the branch is taken.** `attendance_channel_options` (`channel_closure.sql:151-158`) returns only active sites, at most 20, with no sign of an existing source. The page offers "create" for a branch that can't accept one.
2. **The database rejects it with an untranslated error.** The duplicate passes every check in `attendance_channel_save_source`, including the advisory lock (`:205-209`), then fails at the INSERT (`:211`) with a uniqueness error (code `23505`) that isn't caught. `actions.ts:32` turns it into "check fields/period/site", shown as an info/status message (`ChannelForms.tsx:22`). The screenshot shows exactly this with all values valid. Every suggested fix (fields, period, site) is wrong, and retrying can never work.
3. **No route from creating to managing.** Once the duplicate is rejected, the page offers no way to the existing source.

## Correction to my original report

- **Original F1 was too narrow.** It listed name length, reason, inactive site and entitlement. The likelier and more serious cause is a lifecycle mismatch: the user goes to "add" for something that already exists for that branch.
- **Original F2/F3 drop below this.** Form length and units add friction, but they don't block the task.
- **Original task flow A step 1 is amended:** pick branch → **look up the existing phone source** → manage it, or create one only if the branch is free.

## A. Smallest safe repair now (display and action messages only)

No schema, RPC, contract or rules change.

1. **Recognise the duplicate in `actions.ts`.** Only for create on the save operation (no `source` id), treat a `23505` error that names `channel_mobile_site_idx` as a known case. Other `23505` errors keep the generic message.
   - Message: "This branch already has phone attendance. Each branch can have only one phone attendance source, and a stopped one still counts. Open the existing source to review it, enable it or change its settings."
   - Link to the sources list (`/attendance/sources`). The action has no existing-source id unless it does an extra authorised read, which is out of scope here.
   - Don't suggest changing the name, retrying or deleting the original.
2. **Use the right tone.** Failures get `tone="bad" role="alert"`, success gets a success tone, and an unknown result gets a distinct warning that keeps the existing "verify before resubmitting" guard. Keep inputs as entered, and no automatic retries.
3. **Mirror existing database limits on the client.** Name `minLength={2}`, plus trimmed-length checks on submit for name (2–100) and reason (3–500).
4. **Don't change anything else.** No automatic enabling or updating of the existing source, and no change to the reason, geofence, retention, entitlement or concurrency guards. Delight still has to open the existing source and save a new version, with a reason, through the current edit form.

**Acceptance:**
- A valid duplicate on Cairo (QA) shows a red alert with the "already has phone attendance" message and a link that works.
- No record is created and the inputs stay as entered.
- A 1-character name is blocked on the client.
- External sources behave as before.

## B. Coherent redesign (needs a reviewed spec before restructuring routes or tasks)

Model phone attendance as **one configurable facility per branch**. External sources keep their separate multi-source and mapping capabilities.

- **Entry:** "Phone attendance" per branch → the system looks up the existing source → either "manage existing" (enable or stop, new version with reason, history) or "set up" if the branch is free.
- **Fixed identity:** name, kind and branch stay immutable after creation. Version history stays append-only, and the reason stays required for every version.
- **The lookup has to be authoritative.** It needs a new authorised RPC, or an extension of an existing one, that returns per branch "phone source: none / exists (id, current version's enabled state)".
  - It can't infer that a branch is free from the first 20 options or from any paged list.
  - It is advisory only. The unique index plus the advisory lock stay the final authority, so the A1 mapping is still needed for races.
  - It respects `channel_operator_can`: a user without manage rights sees "exists, view only" or nothing, per the spec.
- **Wording to fix together:** "add attendance source" is misleading when there is one phone source per branch. The add choice should offer phone setup only for free branches, while external stays freely addable.
- **Specs to record in issue #47 before coding:**
  - the lookup RPC contract;
  - whether a stopped source should show as "stopped, re-enable" (re-enabling is still an explicit, reasoned version and never automatic);
  - how the "who can record next" readiness ties in;
  - whether site options should mark taken branches.

## What I could and couldn't confirm

- **Confirmed by reading:** the index (`:12`), where the uncaught INSERT fails (`closure.sql:211`), how the action maps errors (`actions.ts:32`), and that the options RPC has no source awareness (`:151-158`).
- **Viewed:** the duplicate screenshot. It matches the earlier failure image: same generic blue message, valid inputs.
- **Not verified:**
  - that the production error text names `channel_mobile_site_idx`;
  - whether the sources list supports filtering by branch or links directly to the existing source;
  - whether Delight's existing source is currently enabled;
  - the owner's exact attempt time.

**Visual: NOT VISUALLY VERIFIED** beyond the viewed images. No route is certified.