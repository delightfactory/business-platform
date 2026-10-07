# D16 temporal/fence contract: correction delta

**Verdict:** Yes, it's ready for a bounded private helper that holds only the temporal and fence logic. It is not ready to wire into callers. SQL identity, caller, cleanup and concurrency qualification stay OPEN, and Concept C stays NOT VISUALLY VERIFIED.

## Four conditions to settle before freezing the helper

1. **Floor value.** The pruner should advance the floor to the highest issue timestamp it actually pruned, never to the current time. Rows are pruned only after their admission expiry, so the floor stays at least 24h behind now. A fresh ID is never wrongly rejected unless the clock moves backward, and that case already fails closed.
2. **Lock order.**
   - Prepare and the pruner take the actor lock, then the attempt lock, then the floor row last, always in that order.
   - The pruner must also take the attempt lock before deleting rows. Otherwise it races with an execute or close that holds only the attempt lock.
   - The single global floor row is a contention hotspot. Accept that and document it.
3. **Rollback availability.** If the database clock moves backward, earlier IDs look future-dated and are denied. That fails closed, but users lose access to those operations until the clock catches up. Record this as an accepted availability cost.
4. **Reserved prefix collision.** Before reserving the `leave-attempt:` prefix, check existing data for legacy keys that already start with it. Also check that legacy paths reject new keys using it, including the dynamic half-day clones. A data collision would break the fence silently.

## Smaller notes

- **Clock primitive:** Pin down how UUIDv7 IDs are generated. A built-in UUIDv7 generator needs a recent PostgreSQL version; otherwise state the fallback. Either way, take the timestamp from `clock_timestamp()` after the locks are held.
- **Erasure scope:** The "live rows only" scope is right, and no backup or audit claims are made.
- **Open items:** The 13 public-event paths and the dynamic clones are still unverified. Don't call them done.