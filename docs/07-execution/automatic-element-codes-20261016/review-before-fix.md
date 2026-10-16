# Independent review of automatic element codes: **NOT ACCEPTED, one blocker**

I reviewed this with Claude Opus 5.5 as a read-only review. I made no edits and ran no shell commands. The review covers only the diff, `src/lib/element-code.ts`, the README and the four images.

## Blocker

**B1: the suggested payroll component key breaks the database format rule.** `generateElementCode('PAY')` produces something like `PAY-7KQ…`: uppercase letters with a hyphen. `supabase/migrations/20261002002040_cube4_payroll_inputs.sql:103` rejects any key that doesn't match `^[a-z][a-z0-9_]{1,39}$`. It must start with a lowercase letter and use only lowercase letters, digits and underscores. That is the only definition of the rule I found.

So if the user keeps the suggested key, the save fails, most likely with the general "check the fields" error rather than the new duplicate-key message. That is a dead end at exactly the step this change was meant to remove.

The parent's browser test didn't catch this because it submitted a lowercase key starting with `d…` to test the duplicate case. It never saved the generated key. The new label, "رمز بند الراتب (مقترح، يمكنك تغييره)" (payroll item code — suggested, you can change it), makes the problem worse because it tells the user the suggestion is valid.

**Fix:** give payroll keys their own generator that matches the rule, such as `pay_` followed by lowercase letters and digits. Then save an unedited generated key once in isolated QA. No database change is needed.

## Not run (unverified limits)

- **Leave-type and calendar codes:** I didn't confirm whether the database requires lowercase or another format. The old generator produced lowercase hex; the new one produces uppercase letters. This could be the same failure as B1. It needs one isolated save each with the unedited suggestion.
- **Work-policy codes:** the limit is ≤32 characters and the code is uppercased. The 16-character `dwm-…` fits.
- **Employee and department/job codes:** both allow 1–40 characters, so the 14–16 character suggestions fit.
- **Correction "new employee" path:** I didn't check the `employee_code` limit used when the correction is applied. It probably uses the employee rule, but this is unconfirmed.

## Code safety (apart from B1)

- **Server-only generation:** the generator uses `node:crypto` and is only imported by server pages. Client forms receive the value as a prop and use it once as their starting value, so the code doesn't change while typing or retrying.
- **Existing values preserved:** existing records, saved revisions and saved proposals are not overwritten. The generator only runs when there is no saved record or proposal, and saved values take precedence.
- **Same rules, no new loops:** the same RPCs, permissions and audit run as before, and the database still decides uniqueness. There is no retry loop and no promise that a code is available.
- **Attendance-source duplicate:** the specific "already exists" message only fires for a new mobile source hitting `channel_mobile_site_idx`. The new name (2–100) and reason (3–500) length checks match the database limits in `cube5_attendance_channels.sql:7,15,126`, so existing sources that pass the database check can still be edited or disabled. An unknown outcome is still reported as unknown (warning tone plus the list link).
- **Optional:**
  - JavaScript `trim()` removes more kinds of whitespace than SQL `btrim`, which is a negligible edge case.
  - The code field changed from `dir="auto"` to `dir="ltr"`, so existing Arabic codes in edit forms will display left-to-right.
  - Adding the `server-only` package import to `element-code.ts` would guard against accidental client use.

## Coverage

The inventory of eight create flows matches the diff. Leaving out device, tax, insurance, document, import and request-recovery references is correct. Coverage is incomplete until B1 is fixed and the two not-run saves above pass.

## Simplicity

The change reduces the task as intended: the user no longer has to invent a code, focus moves to the name field, and the help appears only on new records. For payroll components it currently makes things harder, because of B1.

## Failure and recovery

- **Department duplicate (parent's report) and payroll duplicate (screenshot):** entered values stay in place and the error is specific.
- **Mobile source duplicate:** clear message plus a "فتح وسائل تسجيل الحضور" (open attendance sources) link.
- **Weakness:** that link goes to the sources list, not the existing source itself. That's acceptable but not ideal.
- **Payroll with the unedited suggestion:** fails (B1).

## Rendered visual verdict (only what is visible)

- **Department, desktop and mobile:** the help popover is open and covers the code field. On mobile it also covers the name label. **The generated code value is not visible in either image, so it is NOT VISUALLY VERIFIED.** The popover overlap comes from the existing Field component. The tokens and dark theme look consistent with the existing components.
- **Payroll duplicate:** the image is stitched together and cut off on the right, and the key field is truncated. The red error and teal info messages are distinct and readable, and the entered values are retained. **Partially verified.**
- **Source duplicate recovery:** stitched and cut off. The red message text is clipped, but the recovery link is visible. **Partially verified, and the message wording is NOT VISUALLY VERIFIED.**
- This is not a whole-app or Concept C approval.

## Answers

| Question | Verdict |
|---|---|
| Code safe? | Yes for permissions, money and privacy; **no** for payroll key validity (B1). |
| Task coverage? | Incomplete (B1 plus the not-run leave-type and calendar saves). |
| Simplicity? | Improved, except payroll. |
| Failure/recovery? | Adequate, except that payroll's main path fails. |
| Scoped visual? | Partial; the generated default is NOT VISUALLY VERIFIED. |

**Required next steps:**
1. Fix B1.
2. In isolated QA, save each of the eight flows once with the unedited suggestion, at least payroll component, leave type, calendar and the correction "new employee".
3. Re-take the department images with the help popover closed so the generated value shows.