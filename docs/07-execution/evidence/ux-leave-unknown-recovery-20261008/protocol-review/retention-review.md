# D16 retention/fence delta: critique of the UUIDv7 admission-expiry candidate

**Verdict:** The candidate mostly closes the late-prepare resurrection hole for an identical form ID. It isn't ready to freeze because of the five corrections below. It is still not SQL-ready. Concept C is unchanged and NOT VISUALLY VERIFIED.

## Guaranteed vs. mechanics

- **Guaranteed (authority):** The actor, tenant and employee binding, current permission checks, and the per-actor serialization of each prepare. Nothing else is guaranteed.
- **Not guaranteed (cryptographic):** UUIDv7 has no integrity protection. "Can't alter the timestamp while keeping the same ID" is true by definition, but it proves nothing. The server can't tell an ID it issued from one a client made up. "Accepted only during original form admission" really means "during the window encoded in the ID." The candidate already treats a client-made ID as a new operation, so say "nonce-expiry mechanics" in the spec, not "server-issued."
- **Why it closes the hole:** A late prepare with an expired identical ID is denied before any row is created. This only holds if no record of that ID is pruned before its admission expiry plus a skew margin.

## Contradictions and required corrections

1. **Lifetime anchor conflict.** The payload lives 24h from prepare, but the minimal refs may be pruned at issue time + 24h. A prepare made at hour 23 leaves an unresolved payload until about hour 47, after its refs could be gone. **Fix:** set payload expiry to min(prepare + 24h, issue time + 24h), or else prune only at the latest of admission expiry, payload expiry and close, plus a margin. Ask the owner which anchor "24-hour recovery" means.
2. **Future bound.** A client could put a far-future timestamp in the ID and keep it valid indefinitely. **Fix:** reject any timestamp later than server time plus a small skew, and add that skew to the retention period.
3. **Clock source and rollback.**
   - Use the database clock only, never app servers.
   - Read the time after acquiring the attempt mutex, not at transaction start. A call waiting on the mutex could otherwise pass a stale expiry check.
   - If the database clock steps backward after pruning, a pruned ID becomes valid again. **Fix:** keep one durable "pruned-through" watermark row per tenant and actor. Deny any ID whose timestamp is at or before the watermark. This keeps the fence finite.
4. **Legacy bypass.** If the existing v4 endpoints accept any UUID, a v7 ID could reach them and skip the fence. **Fix:** route strictly by UUID version. Legacy paths reject v7 IDs and can never touch reserved attempts. New APIs reject v4 IDs.
5. **Prune vs. prepare race.** Cleanup must take the actor lock and then the attempt lock, in the same order as prepare. Prepare checks expiry and existence under the actor lock, so pruning can't slip between its check and insert.

## Replay and privacy risks

- **Replay:** Within the window, identical replays dedupe and conflicting payloads are denied. After terminal close, return the minimal receipt until pruning, then deny as expired. State that a replay never re-checks the old authorization: execute re-checks current permission.
- **Entropy:** Fill the 74 random bits from a cryptographic random source. Avoid counter-mode rand_a, because the actor binding, not unguessability, is the real protection.
- **Timestamp leak:** The ID reveals when the HR form was opened, in URLs, logs and triage views. Redact or truncate it there.
- **"Erased":** It covers live rows only, not backups, WAL or logs. Document backup retention or scope the claim.

Retired unknown attempts stay denied with own-list/HR triage and no noCommit claim. That and the receipts limited to existing own-authorized refs are acceptable as written.