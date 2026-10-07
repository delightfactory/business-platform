**Verdict: conditional PASS.** I don't see a blocker in the patch text. I ran no tools and no tests, so everything below comes from reading the diff and the proposal.

**Open redirect.** This looks safe. The branch must start with `/tenant/`, so a `//host` or `/\host` value can't match. The extra character filter blocks `%`, `?`, `#`, backslashes and control or space characters, so encoded tricks, `..` traversal and queries can't get through. In JavaScript, `$` without the `m` flag doesn't accept a trailing newline. The 256-character cap is generous for these fixed shapes.

**Conditions before PASS:**
1. **`uuid` grammar.** Confirm the shared `uuid` source has no top-level `|`. If it does, putting it inside `(?:new|${uuid})` changes how the alternation groups.
2. **Every caller of `safeAuthNext`.** The proposal names the login page and `signInAction`. Any other caller (callback, invitation, logout) also gets these 5 routes. Either list those callers in the D8 decision or accept them explicitly.
3. **Upper-case matches.** Because of the `i` flag, `/TENANT/…/ME/LEAVE/NEW` passes. Next.js routes are case-sensitive, so that lands on a 404 instead of the task. It isn't a security risk, but either remove `i` from this branch or record that it matches existing policy.
4. **Route inventory.** Show that the 5 patterns match the actual route folders exactly, including the leave detail folder name, with no unlisted siblings.

**Wording.** "Same existing page → authoritative denial or task" is honest. Keep saying that the redirect grants nothing, that branding isn't a guard, and that mid-action session expiry is still unresolved.

**Additional targeted tests (minimal set):**
- **Classifier:** trailing slash, upper-case variants, `/me/leave/new/`, `/me/leave/<non-uuid>`, `/me/pay`, `/me/profile`, `/me/leave/<uuid>/x`, `%2F`, an empty query `?`, and a tab or newline inside the path.
- **Login page:** the `next` value survives into the form for each of the 5 routes.
- **`signInAction`:** a successful sign-in redirects to each of the 5. A failed sign-in (invalid credentials, setup or provider error) keeps the same `next`.
- **Authority, as a browser or contract test:**
  - a user from another tenan
  - a revoked member
  - a different user's leave UUID
  - a member who lacks `attendance.self.capture`

  Each must end on the existing denial screen with no data shown.
- **Attendance receipt:** an unknown receipt in same-tab storage is unchanged after the login round trip.
- **Rerun:** the existing tenant, operator, invitation and payroll classifier fixtures, byte for byte.