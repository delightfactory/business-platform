# Employee inclusion review

Official Claude Opus5.5Medium, session0da8e673-7976-4f59-a6de-e06d19d24b13; initial oneUXcaptionfinding fixed, oneboundedre-reviewPASS; readOnlyViolationfalse both.

**Verdict: PASS.** The blocking finding is fixed in the three final files you embedded. I didn't run anything, and the ended-employment caption is checked in code only, as you said. Commit still waits on the final amended build passing.

**The original blocker is resolved.** The page now passes `active` from `employee.employment?.status`, which is the same employment row `people_payroll_inclusion` reads. The captions now cover every reason the switch can be unavailable:
- **Locked:** the closed-payroll message and corrections link appear, and take priority.
- **Not locked and inactive:** "انتهت علاقة العمل؛ لا يمكن تغيير إدراجها من هنا". It no longer blames permissions.
- **Not locked and active:** the user is missing a permission, and the caption names all three it needs (`people.view`, `people.manage`, `employment.manage`). That matches what the database actually checks, so no permission is added.

**The other changes check out:**
- **Ended during an edit:** the `people_employment_not_active` message check comes before the general 23514 case, so the user gets their own message and a refresh link. A closed-payroll 23514 still shows the corrections message.
- **Read-only excluded text:** it no longer tells the user to click when they can't.
- **Switch label:** the text is now visible next to the switch. Screen readers still get the name from `aria-label`, so nothing is announced twice.
- **Saved message:** it now links straight to the payroll runs page for that employer, which gives the next step.
- **Page load:** the inclusion read is now inside the existing `Promise.all`, so it no longer adds a sequential request. When the read fails, the page still says the state is unknown.
- **Unchanged:** request reuse on retry, the in-flight guard, recovery for uncertain/stale/offline, response validation, and the database layer (your 70 passing assertions).

**Optional, not blocking:**
- "راجع سجل التوظيف" is plain text. It could link to `?tab=employment`.
- If `employer_id` were ever empty, the saved link would end in `?employer=`. That's unlikely because an employment always has an employer.

**Visual coverage:** the earlier phone and desktop screenshots still cover the layout of the included, manageable state. The new visible label, the ended-employment caption, and the saved link were **NOT VISUALLY VERIFIED**.