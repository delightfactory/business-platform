# Batch 8: shared components and task return context

Accepted by official Claude Opus 5.5 Medium, session d90ca800-ca69-49c3-96ac-8ffcbdb89a15. Read-only review; no read-only violation. This accepts the scoped changes below, not the full platform goal.

## What changed

- SettingsLink consumes exact legacy button classes, preserves custom classes, size and accessible label, and leaves ordinary links ordinary. CSS module names containing a button-like substring no longer trigger a false conversion.
- Leave employer selection keeps its explicit chooser flag, search and valid page cursor through read retries and sign-in. Invalid context resets without losing the chooser flag. Read-only setup progress states a missing setting without instructing the reader to edit it.
- Login returns now recognize the actual known tenant task pages: profile, leave setup, payroll configuration and other existing destinations. The route patterns exclude unknown pages, API/export/preview handlers, external URLs, controls and encoded path traversal. Each destination still authorizes its own data; navigation grants no permission. Operator-company query validation is unchanged.
- The compact attendance calendar has a visible symbol legend, a word and underline marking today, and one fewer duplicate day link. The header still opens today; the review-list link remains distinct. Empty permission-editor wording and login error tone are clearer.

## Evidence

- Four new tests passed: the actual 54 tenant page paths, task queries and malicious-return rejection, real SettingsLink props, and actual chooser retry/signed-out branches.
- The auth source characterization passed 61 cases. Five legitimate task paths moved from rejected to accepted; malicious negative cases remain. Its previously stale fallback fixture now models active operator versus ordinary account explicitly. These are source/provider-boundary checks, not runtime UAT.
- Three existing payroll-auth-return and six operator-recovery tests passed. Scoped ESLint passed. No unrelated financial suite was repeated.
- Qualification build pmTr-tsamMdX4d40CYcEn passed. After review, the parent removed an unnecessary aria-label from the plain legend paragraph, leaving its visible text intact. Final build 3VOK6EPUUdjArWXEc7jn5 passed; no second review loop.
- Actual dev sign-out and sign-in returned the existing admin to choose_employer=1 and the same Arabic search, without the single-employer auto-redirect. The built chooser retained that search too.
- Current built login error rendered as ui-tone-bad with role=alert. CDP measured its capture viewport/content at 390px without horizontal overflow. Calendar today was visible and underlined; its measured phone cell was about 47.8 × 69.4px.
- The built compact legend was also viewed after ordinary browser wheel scrolling. CDP measured 390px at the capture, with pageY 625. The current calendar-built-phone-light image uses final build 3VOK6EPUUdjArWXEc7jn5. Other named images are earlier Batch 8 dev/pmTr renders, before the attribute-only delta; their visual source is unchanged by that delta.
- The guide HTML and 35-page PDF were regenerated. Changed page 17 was rendered and read, with clear Arabic and no clipping.

## Evidence boundaries

Claude read the source and two named dev images, not the parent tests or current built smoke. The child did not see the below-fold legend; the parent verified that later. This is not authentication/authorization UAT for all 54 pages, all six theme-size combinations, or a screen reader certification. Read-only missing-setup copy was checked in source, not with a newly created empty employer.

Several diagnostic images were unusable because the IAB capture surface cropped or tiled them. They are not acceptance evidence. The reliable capture sequence uses CDP metrics immediately before the screenshot; ordinary CDP wheel input can reveal content below the fold without resetting the viewport. Keep only the four named representative images. This was a capture issue, not an app layout repair.

No schema, permission, financial, account or email write was made; no production deployment or paid-plan change. Active external caches, QA databases and recovery journals remain protected. Whole goal remains active for the finite representative coverage and completion audit across the 14 user screen families.
