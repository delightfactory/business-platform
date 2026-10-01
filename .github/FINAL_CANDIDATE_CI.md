# Final-candidate CI

Hosted CI runs only on `pull_request: ready_for_review` targeting `main`.
Opening a PR (including a non-draft PR), pushing, synchronizing, reopening,
labeling, and merging do not request CI. Keep work in draft until the exact
candidate is reviewed and frozen. Existing lint, typecheck and build coverage
and the check name `Lint, typecheck, and build` are retained.

## Invoke once for the final version

1. Record the PR number, current `head.sha` and `base.sha`:
   `gh api repos/delightfactory/business-platform/pulls/NUMBER --jq '{head: .head.sha, base: .base.sha, draft, state}'`.
2. Finish all commits and review. If the PR is already ready, convert it to draft
   with `gh pr ready NUMBER --undo --repo delightfactory/business-platform`.
3. Mark that frozen candidate ready:
   `gh pr ready NUMBER --repo delightfactory/business-platform`.
4. Inspect the new CI run and both candidate guards in its logs/summary. Require
   the existing check to finish with `success` for this candidate. Use
   `gh run view RUN_ID --repo delightfactory/business-platform --json event,headSha,conclusion,jobs`
   and the PR's checks tab. Record the run ID, candidate head, base and tested
   merge snapshot from the guard summary; do not infer tested checkout identity
   from a green badge or the run's `headSha` alone.
5. Immediately before an authorized merge, re-fetch the PR and the target branch.
   The PR must still be open, ready and mergeable, and its head and current target
   SHA must equal the validated head/base. The PR checks must still refer to the
   recorded candidate. Stop if any identity changed. The eventual merge operator
   must use expected-head protection (`--match-head-commit HEAD_SHA` with
   `gh pr merge`) and recheck the base; this document does not authorize merging.

## Exact identity and changes

`pull_request` runs are eligible for native PR status evaluation. Checkout is
pinned to the event's `github.sha`, the synthetic PR merge snapshot. The guard
reads raw commit parent headers (valid even at a depth-one shallow boundary),
verifies the two parents are the recorded target base and candidate head, and
queries GitHub before and after validation to reject a moved head/base,
retargeted PR, closed PR or draft PR. Native job check identity is managed by
GitHub; we do not publish success to another SHA or manufacture a status.
The tested synthetic merge SHA differs from the PR head and from a later squash
or rebase merge commit.

A newer commit or target-base change invalidates prior acceptance even if an
old run still displays green. Return to draft, finish the changes, and mark
ready again for a fresh candidate run. Do not rerun an old event as evidence for
a new candidate. Re-requesting the same frozen candidate cancels an older
in-progress run for the PR. A push alone does not cancel a run; the guard rejects
drift at the end, and the reviewer must also reject drift after it completes.
There is no atomic base lock in this workflow, so integration must be serialized
while making the final base check and merge.

On 2026-10-01, `main` was unprotected and effective branch rules/rulesets were
empty. This change does not establish or alter enforcement. The reviewer must
explicitly require this exact-candidate evidence; absent/stale checks are never
approval. If protections are later added, preserve all existing required checks
and verify their names/app identity and merge-queue needs before integration.

`workflow_dispatch` is deliberately not a PR gate: its job checks do not satisfy
native required PR checks, and manual dispatch additionally depends on workflow
availability on the default branch. No skip-ci or path-filter workaround is used.

## Local verification and cost

Run `node --test .github/scripts/final-candidate.test.mjs` and validate the YAML
with `actionlint` before publishing. These tests include a real depth-one Git merge checkout and verify the candidate guard;
they do not execute application lint/typecheck/build. Hosted validation is one
deliberate candidate run, repeated only after candidate changes or a justified
retry. Ordinary development events request zero runs under this workflow.
No account billing or billed-minute saving is inferred.

References: [PR check eligibility and stale checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks),
[PR event and dispatch semantics](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows).
