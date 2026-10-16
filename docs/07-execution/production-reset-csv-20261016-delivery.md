# Delivery identity and cleanup

- Released application source: `8954ba646a4a9a402749727410cbafdf758d126c`, pushed to `codex/operator-company-ux`; no merge to main.
- Production deployment: `dpl_CGBncuKUazHRTGVpWpfaYdJzzi6X`, `business-platform-production-h3ymcjth4.vercel.app`, project `prj_O5OSEuyyJkJZtVW5sRXm7M4XfPaa`.
- Staged deployment was READY and returned the Arabic UTF-8-BOM CSV through authenticated Vercel curl before promotion. Verified the custom domain resolves to that exact deployment after promotion.
- Live `https://platform.delight-world.com/templates/workforce-import.csv` (222 bytes) and `/user-guide.pdf` match the checked-in files by SHA-256. Browser confirmed the updated import chapter; representative screenshot retained outside OneDrive at `C:/Users/DELL/AppData/Local/ai-dev-workflow/runs/20261016-production-reset/arabic-import-guide-live.png`.
- Owner Edge session was expired at verification. New-company defaults were independently source-reviewed; no new production company/import was created after reset. Owner should log in again to conduct their requested clean operational test.
- Production-dependency audit (`npm audit --omit=dev`): zero reported vulnerabilities at this check. Deployment install's warnings include development dependencies; no automatic package upgrades were performed.
- Owned local preview stopped. Validated source-clean, no Node consumer, exact absolute paths, no reparse points, and no tracked files in cleanup targets. Removed this run's unused integration `node_modules` and `.next`, plus temporary API-key/environment copies. Verified local reclaimed file bytes: **855,298,690** (~816 MiB). Git source remained clean. No global cache, Docker/database, cloud/OneDrive deletion or quota claim.
- Exclusions retained: protected backups and manifest, maintenance scripts/journals/results, representative verification evidence, source-only CSV worker and patch (uncommitted source), local QA database/containers, all unrelated projects.

This companion note is documentation only and does not require another application deployment. See `production-reset-csv-20261016.md` for reset scope, backup hashes and test boundaries.
