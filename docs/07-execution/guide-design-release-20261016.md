# Approved user-guide design release

The owner approved the isolated three-page Cairo proof and explicitly requested implementation and production publication. This applies the same editorial direction to the complete Arabic guide. Base: `0dc2f15da97b9de84b7997a212222cadd3320c5a`.

## Delivered

- Local Cairo variable font with OFL licence, white/teal cover, restrained vector icons, numbered steps, distinct start/outcome/recovery callouts and responsive controls.
- Full HTML guide keeps all 34 chapters, original text and stable section anchors. The Markdown content is unchanged; exact article-text comparison, stripping markup and the new diagrams, passed.
- Three explanatory diagrams cover CSV preview versus saving, employee attendance, and leave submission versus approval. Each uses the existing granular task filter, not a separate permission system.
- Complete tagged A4 PDF: 42 pages, clickable contents and document outline, running header/page numbers, repeated table headers and controlled page breaks. Major chapter-break selectors follow the existing stable heading anchors and must be updated if those IDs change.
- Search and role-sensitive reading/printing remain available. The cover reflects the selected reading scope. Downloading the full PDF remains a separate, clearly labelled action.

## Verification

- Parser and guide suite: 17 passed. Node syntax checks passed; HTML regeneration is reproducible.
- All original article text preserved exactly after excluding new diagram text and markup. No product/business, invitation, import, authorization or database changes.
- Chromium qualification: Cairo loaded; desktop rendering checked; mobile CSS viewport 390px, document scroll width 390px, TOC jump lands the import heading about 22px from the top. Representative mobile capture includes host viewport padding; DOM dimensions establish no horizontal page overflow.
- Real browser reader scope (`personal=1&topics=payroll-view`): 9 visible chapters, payment task blocks hidden, searching the payment reference yields 0 results, clearing restores 9 chapters. Generated a tagged 11-page filtered print as verification evidence.
- Every page of the full PDF audited: no empty pages and no extracted characters outside the paper boundaries. Representative cover, contents, import, payroll and training pages rendered and inspected.
- Independent official Claude Pro review: actual `claude-opus-5-5`, medium, session `c4fe3165-d5df-4e79-a808-c91d3ed51740`, PASS with no material blockers, read-only violation false. Reviewed source and final representative images; runtime/test results explicitly remained parent evidence. Afterwards removed one inert CSS override and documented the stable print-anchor selectors; these have no visual or behavior effect.
- No local dependency installation/build caches were needed. The production remote build provides the application build gate. Owned local preview binds only to 127.0.0.1:61193 and is stopped after live verification.

## Release boundaries and evidence

Publish only to the existing Vercel project `prj_O5OSEuyyJkJZtVW5sRXm7M4XfPaa`, team `team_AYQTvxuQJ1EepKxDVhzjX1ew`, domain `platform.delight-world.com`. Development branch `codex/operator-company-ux`; no merge to main. Previous deployment `dpl_CGBncuKUazHRTGVpWpfaYdJzzi6X` is the rollback reference.

Compact evidence and full audit/review outputs: `C:/Users/DELL/AppData/Local/ai-dev-workflow/runs/20261016-guide-design-release/`. Preserve final source/assets, representative final renders, PDF audit, review verdict and release identities. Clean obsolete intermediate renders and duplicate verification copies only after exact-path/reparse/consumer/source checks. Production databases, protected backups, old source-only workers and unrelated runs are excluded.

The delivery note records the actual deployed source, live file hashes and final cleanup result after promotion.
