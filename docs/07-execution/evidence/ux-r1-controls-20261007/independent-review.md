**PASS**

I found nothing that must be fixed. This is a token migration: selectors, layout, sizes and type are unchanged, and the only new declarations are the three focus `outline-offset`s.

**What holds up:**
- The three faint brand-soft focus rings now use `--focus-width`/`--color-focus` with a 2px offset, matching the other field focus rules.
- Field borders that used hardcoded hex now use `--color-control-border`, which fixes the weak border contrast you measured.
- Warning and danger colours stay on their meaning, with no new state mapping.
- Leaving the sidebar's dark colours for later is a sensible deferral.

**Non-blocking notes:**
1. The borders on `.danger-disclosure > summary` and `.attendance-import-ambiguous` were faint and now use the dark status text colour. That makes them noticeably heavier, which is acceptable but worth a visual check against the calm-paper look.
2. Several very light hairlines now use `--color-border`, which may be slightly darker. That's consistent, but row lists may look a bit heavier.
3. Labels in the assignment and compensation forms use `--text-muted`, while labels in the work-policy forms use `--text-secondary`. This copies an existing inconsistency and could be unified in a later batch.
4. A misspelled or undefined variable wouldn't fail the build; the colour would just fall back silently. Your fixture covers the four pages tested; screens outside it, like operator home, branding and mobile nav, still depend on the tokens existing.