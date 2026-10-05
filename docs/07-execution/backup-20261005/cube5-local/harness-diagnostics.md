# Preserved test-harness diagnostics

These errors occurred during this qualification and were corrected in the QA harness only. Prior reports and logs remain in previous-runtime/; browser.log is append-only.

1. Initial login submit was followed too quickly by navigation; the target returned to login. Waiting for network idle after actual login resolved it.
2. Actual member-page RPC returned HTTP 500 / `55000` / `tenant_member_limit_unavailable`. The synthetic tenant had no tenant.users limit. setup.sql supplies one limited 10-seat fixture, without production changes.
3. First database facts query: `ERROR: column "created_at" does not exist` on channel_events. Its identifier order was used instead. No mutation occurred.
4. Logout selector: `Element not found: button:has-text("تسجيل الخروج")`. The installed native CLI did not match that selector. Fresh snapshot element refs were used.
5. Narrow-layout logout: `Logout button unavailable`. The menu was collapsed at width390; actor switches now use desktop viewport while journey captures remain at the required viewport.
6. Review verification: `ERROR: column "id" does not exist` on channel_review_decisions. Its key is (tenant_id,event_id). The already accepted actual decision was inspected and retained; it was not submitted again. Exclusion then completed normally.

No tool approval rejection occurred after Ahmed's direct authorization. No permission refusal was bypassed.
