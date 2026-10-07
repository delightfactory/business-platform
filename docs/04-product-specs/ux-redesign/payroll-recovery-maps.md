# R7 — Financial recovery subjourneys (Proposed)

Read with the coverage contract and action source. These diagrams separate confirmed outcome, pending identity, reconciliation and deliberate resubmission. They do not enumerate every validation/role/operation combination; those remain mandatory before Frozen. Access and actor checks remain server-authoritative at every action. Unclassified failure does not mean uncommitted.

## Payments: prepare, submit, recover and cancel

```mermaid
flowchart TD
 A["Scope + allocations / remaining / compensate"] --> B["Prepare valid intent and attempt"]
 B -->|prepare failed| FAIL["No new submission; preserve any prior recoverPending uncertainty"]
 B -->|prepared| S["Submit exact prepared request"]
 S -->|confirmed success| OK["Confirmed receipt; refresh authoritative state"]
 S -->|classified validation or authorization error| V["Source-specific failure; preserve any prior pending uncertainty"]
 S -->|stale or excess needsRefresh| F["Read fresh scope before reviewing a new intent"]
 S -->|unclassified or response lost| P["recoverPending: retain signature and values; no altered request"]
 P --> C{"Explicit choice"}
 C -->|recover| R["Resubmit prepared request with same attempt; may commit it for first time"]
 C -->|cancel request| X["Cancel exact request per contract"]
 R -->|committed| OK
 R -->|unknown| HOLD["Still pending; no new submission"]
 X -->|request_committed| RET["Original payment already recorded; recover its receipt"]
 RET --> R
 X -->|confirmed cancellation| CLOSED["Review source outcome before deliberate new request"]
 X -->|unknown| HOLD
 P -->|values changed| BLOCK["Reject changed signature until original outcome resolved"]
```

## Advances: scoped persistent journal and resolve

```mermaid
flowchart TD
 A["One of ten AdvanceOperation commands"] --> J{"Scoped journal valid and no unresolved attempt?"}
 J -->|corrupt / actor mismatch / unresolved| BLOCK["Block new intent; investigate or resolve original"]
 J -->|safe| W["navigator.locks + localStorage journal before command"]
 W -->|storage or lock unavailable| NS["No command sent"]
 W -->|saved| C["payroll_advance_command exact journal"]
 C -->|committed| OK["Remove confirmed journal; authoritative receipt"]
 C -->|unknown| P["Original journal retained; inputs blocked"]
 P -->|explicit resolve| R["payroll_resolve_advance_attempt"]
 R -->|committed| OK
 R -->|closed_without_commit| CLOSED["Keep original values; deliberate new intent after review"]
 R -->|unknown / failed read| P
```

Ten commands: save, approve, activate, cancel, settle, compensate, termination, defer, correct_deduction, correct_disbursement. Resolution is not a generic eleventh financial action. Source journal includes actor/tenant/employer/intent; no observed time expiry. Privacy/retention policy remains a review gate.

## Deduction disposition: unresolved is a distinct state

```mermaid
flowchart TD
 A["carry / external_settlement / retract with required confirmation"] --> VAL{"Local values and confirmation valid?"}
 VAL -->|no| N["Known not_committed from local validation; no command sent"]
 VAL -->|yes| C["Send actual disposition action"]
 C -->|committed| OK["Confirmed disposition"]
 C -->|server error or missing client/session| P["unresolved; retain context and recover before another request"]
 P -->|explicit recover| R["payroll_deduction_reconcile"]
 R -->|committed| OK
 R -->|not_committed| N
 R -->|unresolved| HOLD["Still unresolved; no speculative retry"]
```

## Corrections: preview, scope, pending signature and finalization

```mermaid
flowchart TD
 A["Source-specific correction kind and scope"] --> P["Preview proposal and affected outputs"]
 P -->|invalid or stale| V["Correct values or refresh preview; no save assumed"]
 P -->|valid hash| S["Save proposal with reviewed previewHash"]
 S -->|confirmed saved| C["Authoritative case state and command gates"]
 S -->|failure or unknown| U["Pending identity and signature; no value changes"]
 C -->|authorized approval/release or command| CMD["Exact source command with reason and version"]
 C -->|not authorized| DEN["Read-only or authorized owner"]
 CMD -->|confirmed outcome and finalization appropriate| F["Finalize with case ID, expected version and confirmation"]
 CMD -->|failure or unknown| U
 F -->|committed| OK["Correction output and settlement responsibility"]
 F -->|failure or unknown| U
 U -->|explicit recovery| R["Correct reconcile or finalization_reconcile for operation"]
 R -->|committed| OK
 R -->|closed_uncommitted| CLOSED["Signature and previewHash cleared; fresh preview before new save"]
 R -->|unknown| HOLD["Keep original pending context"]
 U -->|signature changed| BLOCK["Reject until original outcome resolved"]
 OK --> REF["Revalidate People / runs / payments; this alone is not business closure"]
 OK --> SET["Settlement via its own authorized action and receipt"]
 SET -->|failure or unknown| U
```

Inputs valid kind×command combinations, all correction kinds/commands, private export/print authorization, first/subsequent page export and complete-report revision checks remain separate case registries. Unclassified overtime is X4, a non-blocking warning rather than an invented financial blocker. No chart arrow is automatic replay or permission to omit a confirmation.
