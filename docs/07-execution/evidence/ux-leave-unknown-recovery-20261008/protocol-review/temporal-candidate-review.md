# D16 private helper review: verdict on the migration SQL

**Verdict:** I found no must-fix parsing, security, time, entropy or floor bugs. The helper can be frozen as a bounded prerequisite. I'm judging from reading the SQL; the PostgreSQL 17.6 results are yours, and I didn't re-run them.

## What checks out

- **Entropy and layout:** The ID is the 12 timestamp hex digits, then `7`, then hex digits 14–32 of a v4 UUID. That gives 74 random bits from `gen_random_uuid` and keeps a valid variant nibble.
- **Parsing:** Decoding via `bit(48)::bigint` is exact. `uuid::text` is always lowercase, so the version and variant checks are reliable.
- **Time:** In PostgreSQL 17, `extract` returns an exact numeric, so flooring to milliseconds is safe. The 24h boundaries line up: the floor can be advanced to at most now−24h, admission requires issue time > now−24h, and an ID issued at exactly now−24h is expired on both sides.
- **Floor:** The floor row is locked `FOR UPDATE`, `greatest()` keeps it monotonic, and a clock rollback makes advancement raise an error, so it fails closed. A single global floor is safe because every ID at or below it is already 24h expired.

## Should-fix (non-blocking)

1. **Volatility label.** `extract('epoch', timestamptz)` is STABLE, but `attempt_form_is_admissible` is declared IMMUTABLE. Mark it STABLE, or document why IMMUTABLE is safe for epoch. Don't use it in index expressions either way.
2. **Unneeded SECURITY DEFINER.** The two pure helpers, `attempt_form_issued_ms` and `attempt_form_is_admissible`, don't need elevated privileges. Make them SECURITY INVOKER to shrink the privilege surface.
3. **Predicate scope comment.** State that the admissibility predicate is only for first prepare of an ID with no row. Existing unresolved rows are governed by first prepare + 24h. A prepare at hour 23 is valid until hour 47 even though its issue window closed at hour 24. Otherwise a caller might wrongly use the predicate on execute or recovery.
4. **Grants hygiene.** Confirm `USAGE` on schema `leave` isn't granted to `anon` or `authenticated`. Confirm no default privileges later re-grant these objects to them.

Full wiring, the pruner, the 13 public-event paths and half-day clones, the end-to-end journey, and Concept C (NOT VISUALLY VERIFIED) all remain OPEN.