## Batch 6 review: **ACCEPTED**, no blockers

**What I checked and what I didn't.** I did a read-only review of the source in `MemberAccessSheet.tsx`, `member-access.module.css`, `page.tsx:96-213` (the role rows and `MemberTasks`), `actions.ts:88-107` (`setTenantMemberPeopleBundlesAction`) and the guide at `ar.md:165-167`. I also looked at two dev screenshots: `editor-phone-dark.png` and `editor-desktop-light.png`. I did not run any browser actions, saves, Esc/reopen tests, tests, lint, the build or the PDF regeneration. Every runtime claim (the FormData check, the unchanged results after saving, the 51px summaries, the 768 fit) comes from the parent's report, not from me. Only 390 dark and 1366 light are visually checked. Tablet, other theme/size pairs, screen reader behaviour and a full UAT are **not verified**.

**Task.** The journey now improves. The row shows the first two task labels at `page.tsx:208`, and the rest sit in a native disclosure at `:209-211`. The admin can now see what a member does without opening the editor; before, the row only showed a count. Saving returns to the same member, filtered (`actions.ts:93`, with `member` and `q` in the URL).

**Capability.** Nothing is lost:
- All 27 checkboxes are still rendered inside closed `<details>` (`MemberAccessSheet.tsx:37-44`). Nothing is filtered or unmounted, so checked boxes in closed groups are still sent on save.
- The original keys (`expectedBundleKey`) are still sent as hidden fields (`:28`).
- The templates are now in a collapsed section but still only add to the current selection (`:30-35`).
- Inactive members keep their "saved permissions" disclosure (`page.tsx:104-106`).

**Simplicity.** One clear primary action: "حفظ الصلاحيات" in the review area that stays visible. Groups with existing tasks open automatically and show a count per group. In the phone image only the self-service group is open (2 of 27 tasks visible); in the desktop image the empty member shows six closed groups, all reading "0 مختارة". The template step is optional, so no one is pushed into using it.

**Recovery and honest states.**
- Reopening resets the selection to the original keys (`changeOpen`, `:17-20`).
- A group's `open` value only depends on `initialKeys`, and the editor is rebuilt when a member's roles change (`page.tsx:111`). So unticking the last task in a group does not close that group.
- The "سيُضاف / سيُزال" review and the sensitive-permission warning still show, and they are announced to screen readers (`:46-52`). Tasks added to a closed group by a template still appear in that review and in the group's count, so nothing is hidden.

**Responsive.** At 390 dark, the review area stays fixed and the list above it scrolls, with no visible overflow. The Next "N" dev badge overlaps the bottom corner, but it only appears in dev. At 1366 light the editor is about 500px wide with comfortable spacing. Both images render RTL correctly and keep email addresses readable inside Arabic text.

**Safeguards unchanged.** The action, RPC call, input validation (allowed keys only, no duplicates, length limits), the conflict check against the original keys, the protected admin role and the financial-authority badge (`page.tsx:107`) are all as before. Nothing touches the schema, tenant isolation or privacy reads.

**Code quality.** The changes are small and match the surrounding style. They reuse the existing `Disclosure`, `Checkbox` and `Sheet` components. `--color-muted` is a defined token (`src/styles/tokens.css`), so using it on lines 20 and 22 alongside `--muted` is fine.

### Optional follow-ups (not blocking)
1. `page.tsx:102` and `:208`: an active member with no tasks shows both "صلاحيات العمل: 0" and "لم تُضف مهام عمل…". You could hide the count line when it is 0, or merge the two lines.
2. `MemberAccessSheet.tsx:38`: "0 مختارة" is acceptable, but "لا مهام مختارة" would read more naturally for empty groups.
3. `MemberAccessSheet.tsx:36`: when nothing is selected, "افتح المجال لتعديل مهامه" could become "افتح مجالًا لإضافة مهام" to point to the next step.
4. Ask the parent to confirm in the final build that the dev badge isn't present and that the 768 sheet still fits.

**UX verdict:** the before/after numbers (labels on the row, 2 of 27 tasks visible instead of 27) are as the parent measured them. Coverage and simplicity both pass on the evidence above.