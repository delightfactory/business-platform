# Cube 4 operational earning date partitions — QA146

Status: installed in the two dedicated local QA databases; full Cube4 goal remains ACTIVE and incomplete.

## Delivered boundary

Actual employee statutory source projection now carries source-bound earning month/year partitions. Dated salary-distribution parts retain exact rational values and indexes into their original source parts. Each saved earning line is conserved and validated once; month fragments have no independently rounded amount. Two half-cent fragments therefore cannot become two cents through separate rounding.

Manual daily payable totals and approved one-period amounts retain an explicit unknown date attribution. Calendar dates are operational evidence only: legal earning attribution, legal duration, insurance obligation ownership and financial qualification remain unresolved. Public net and finalization are not enabled by this change. No frontend change was required.

## Verification and installation

Qualification: `cube4-earning-date-partitions-qualification-v2.json` PASS. Upgrade reused 20 unchanged successful pure checks and resumed only the six affected operational checks. The second dedicated database ran its first full 26 checks. Both qualifications used rollback transactions on ledger145. The initial FAIL artifact is retained: two approximate numeric-division test comparisons were corrected to exact cross-multiplication; implementation was unchanged.

Independent read-only Codex review: `reviews/cube4-earning-date-partitions-review.json` PASS, exact three file hashes, no material findings. This was a separate review context using the same provider, not a legal review; the reviewer did not execute tests. Installer: `cube4-earning-date-partitions-local-install.json` PASS, both dedicated databases145→146 with prior inputs, packs, candidates, runs and comparisons unchanged. The database named fresh was not a new full migration replay.

Migration SHA256: `9d212b5582247ef3a50c85c818c45b961821cb9b61714ff0ba898611cf096157`.

No repeated unchanged arithmetic/frontend/browser suites, publication or production mutation. This does not close the integrated financial-review journey or qualify a statutory model.

## Next route condition

Continue stage2 actual source-bound financial review composition, including explicit handling of missing legal duration/year attribution and enabled Time/Leave coverage. Insurance run ownership remains awaiting an explicit owner answer. Official numerical comparison evidence remains unavailable. Preserve both gates without inventing facts or expanding specialist screens. See [completion route](cube-4-completion-route.md).
