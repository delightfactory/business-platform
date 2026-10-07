# R2-AUTH-CORE review record

Source snapshot: b180a4e1a9c8f2f142bd5ae9f1e142daffd06e9f. Proposed only; no provider or browser acceptance.

- Author: official Claude Code 2.1.292, direct Pro, actual claude-opus-5-5 / medium; same session33d9d8e5-a9a8-48f2-a8f1-139ad493302e. Seven read-only turns, success, no permission denials or read-only changes.
- Codex independently checked source paths, branches, current UI text and recovery routes, reconciled41/12/8 case counts and role/storage/header assumptions, and preserved the raw contribution.
- Independent reviewer applied docs-guard/test-guard. It required correcting the canonical expired recovery assertions and adding resolvable source aliases. Both were applied. Selected60 source checks do not cover all61 scenario records, all19 items, rendered controls, proxy integration or real provider outcomes.
- [Selected check results](auth-core-source-checks.json):60 passed/0 failed. Real action/allowlist/helper/callback source and NextRequest/NextResponse; stub SDK, redirect sentinel and request cookie context. Expected current defects remain defects despite passing reproduction checks.
- Targeted ESLint for the three audit/characterization CommonJS scripts passed. The explicit no-require-imports exception applies only to those CommonJS CLI files, with stated runtime reasons; no global lint/provider setting changed.
- Source fingerprint audit passed; full/stage semantic freeze gates remain blocked as expected. No original project worktree or current task was reset, cleaned or stopped.

The mandatory user-journey requirement is recorded in project AGENTS.md and CLAUDE.md; the existing `@AGENTS.md` Claude import is retained. Every future brief/review must address it explicitly. Core Auth providers/session behavior require separate qualification before being declared improved or closed.
