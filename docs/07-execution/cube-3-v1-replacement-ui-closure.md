# Cube 3 — approved replacement UI

The HR request detail now offers submitted requests for the same Employee, with paginated discovery. The selected replacement is read through the existing authorized detail RPC and must match the original Employee, Employment and Employer. HR reviews its dates, quantity, reason and day-level pay/balance effect before providing a correction reason.

The action calls the qualified `leave_correct_approved_request`; it supplies both request versions, the original approved preview, the replacement preview and an exact-intent operation key. Correction reverses the original consumption and approves the replacement atomically. The original remains visible as superseded. Stale versions, insufficient balance, mapping problems and classified Attendance conflicts remain enforced by the backend. A pending cancellation or unavailable cancellation history hides the correction form until resolved.

HR and the Employee's own request details expose reciprocal original/replacement history links and the correction reason/time. A superseded or cancelled request shows no active consumption; historical ledger evidence remains retained.

## Focused qualification

- Actual dedicated local Auth → browser → Server Action → RPC → database journey: stale replacement rejected, original unchanged, reason and operation key retained. After reload/review, correction persisted with one correction and the exact original consumption reversal.
- Reciprocal links qualified in both HR and authenticated Employee views. Phone/tablet/desktop widths 390/820/1280 had no horizontal overflow; phone and desktop screenshots inspected.
- Selected paid replacement confirmed in the browser as zero unpaid days and one day of tracked balance consumption before confirmation. The summary sums eligible units, preserving half-day fractions.
- Typecheck, lint, production build and independent review passed. Gemini review was unavailable with server capacity errors; a fresh read-only Codex reviewer identified the missing pay-effect summary and passed its correction. Detailed gate evidence stays outside the repository in the existing Cube 3 run directory.

## Closure boundary

This closes the missing approved replacement interface without adding a joint Leave/Attendance correction engine. Existing classified Attendance conflict protection is preserved.

Cube 3 remains open while the annual entitlement calculation policy in `cube-3-legal-calculation-evidence.md` is unaccepted/unimplemented. Manual HR-entered balances do not qualify that mandatory automatic calculation. No deployment or remote SQL is part of this delivery.
