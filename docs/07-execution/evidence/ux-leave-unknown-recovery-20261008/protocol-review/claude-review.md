# D16 review: leave-attempt server recovery proposal

**Verdict: conditionally sound, not yet ready for SQL.** The design can make late calls safe, but only if the item below is settled. Otherwise the reserved-key prefix and the revoked grants can be bypassed.

## Does it safely fence late calls?

**Late executes on the same attempt: yes.** This holds if the state check runs after the same-attempt row lock is taken, and if the commit and the state change happen in one transaction. Then "open" means "never committed", so discover can settle any lost response without guessing from silence or timeouts.

**Legacy calls with the reserved key: only partly.** Three gaps remain:
- **Prefix matching is weak.** Keys must be normalised first (case, whitespace, Unicode). Legacy functions should also reject any key that exists in the attempt registry, not just keys with the `leave-attempt:` prefix.
- **Revoking EXECUTE doesn't stop the owner.** Every existing SECURITY DEFINER function with the same owner can still call the private originals. We need a list of all their callers, revokes for each signature/overload, and default privileges fixed so new functions don't grant PUBLIC.
- **Paths that build keys internally are a hole.** Half-day dynamic rewrites, cross-stream replay and correct each need the namespace check on the final key, not only on the key the client sent.

**A fresh non-reserved legacy key for the same intent is not fenced.** That allows a duplicate request. Whether to retire own-operation legacy paths for new clients is an owner cutover decision.

## Security decisions to settle before writing SQL

1. **Prepare deduplication.** Use a unique key on tenant + actor + form UUID. Same UUID with the same canonical payload returns the existing attempt. A different payload is a conflict, never an overwrite. This covers a lost prepare response.
2. **Identity check.** Pass the expected identity as an explicit parameter to the private original function, checked at its locked point. Don't use transaction-local settings. Drop the post-result check unless full rollback is proven.
3. **Lock order.** List the lock order of every legacy and HR function (approve, decide, reject, cancel). Any function that locks the request row before the employee row can deadlock. Use transaction-scoped locks and a lock timeout. A server abort means no commit and the attempt stays open. A client timeout means unknown.
4. **Authority changes.** Check current authority at execute. Prepare-time permission gives nothing. A later denial never clears an earlier uncertain result.
5. **Retention limit.** Attempts that are prepared but never executed hold the HR payload with no end date. The SQL needs a server-enforced close path for them. The actual lifetime is not invented here.
6. **Receipt access.** Define the minimal receipt fields and who may read them after registry retirement. Readers must be the same actor and tenant-scoped.
7. **Required tests.** Real SQL tests for concurrency, identity, bypass and retention. Mocks are not proof.

## Owner product choices (not security)

- **Who can read old receipts.** Whether an employee whose role or employment changed can still see a receipt for their own committed action.
- **Lifetime and cleanup.** How long an open attempt lives, what terminal data is kept, and how often cleanup runs (privacy governance).
- **Lost form context.** The form isn't kept in the browser and the server payload is erased when an attempt closes. So after a closed attempt or a lost tab, the employee has to re-enter the form. Decide whether to accept that or keep the payload until the employee acknowledges.
- **Legacy cutover timing.**

## Safer employee journey (one primary action per state)

| State | Primary action | Message / continuation |
|---|---|---|
| Draft | "Send" | — |
| Sending or unknown | "Check status" | Plain Arabic RTL text: "we're confirming" (no success shown) |
| Committed | "View request" | Cancellation shown as "awaiting HR decision" |
| Closed without commit | "Start again" | States clearly that nothing was sent |
| Denied | — | Gives the reason, keeps earlier uncertainty visible, and offers no retry that hides it |

No HR or foreign data appears, amounts follow existing authority rules, and pagination is limited to the employee's own records.

Concept C (Cairo 40/44, radius 8) is retained. Both are **NOT VISUALLY VERIFIED** because there is no rendered proof.