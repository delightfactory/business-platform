# Cube 4 calculation feedback checkpoint

Local UI fix, 2026-10-02. This closes the observed missing-success-message defect, not complete Payroll Core or legal qualification.

Successful calculation revalidates the review page. Previously the action component moved between two page locations and was keyed by the changing run revision; remounting discarded its saved-result message. The page now keeps one scope-keyed action wrapper. It retains feedback across that refresh, while its nested command form remains keyed by the authoritative run/revision/status. The parent disables controls throughout submission, including a nested form remount. Saved feedback is shown only for the matching authoritative result. Scope, authority or final-stage changes still remove or reset the wrapper.

Initial, cancelled and stale periods show the next action expanded. Current review periods keep recalculation/cancellation in optional details. Success feedback appears outside those details. No monetary rule or database function changed.

Evidence in the isolated run directory:

- `cube4-run-feedback-ui.json`: actual authenticated recalculation on development runtime3545; exactly one new candidate; old candidate output digests preserved; input-version, payment and final-context counts unchanged; success remains visible at390/820/1280; full reload neither repeats calculation nor claims a new success.
- `reviews/cube4-run-feedback-review.json`: independent read-only PASS against exact hashes of `RunActions.tsx` and `runs/page.tsx`.
- TypeScript and focused two-file ESLint both exited0 in session38700. `git diff --check` exited0. Phone and desktop screenshots were inspected; Arabic feedback is readable and no horizontal page overflow was observed.

Cross-remount recovery after an unknown command result is not qualified by this journey. Complete earning/YTD/insurance composition, verified statutory pack issuance, legal numeric comparison, final approval/lock and distribution remain open. No new commit, push, deployment or production write occurred.
