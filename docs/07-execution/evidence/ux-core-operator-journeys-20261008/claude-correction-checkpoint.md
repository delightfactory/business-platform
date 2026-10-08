# Correction checkpoint (no reads, edits or acceptance claims)

## 1. Onboarding: confirmed, and my contract is corrected

- **Error or malformed read:** never show a creation form. The only action is to re-read with the same key.
- **Null read with a key:** keep the original same-key form, with explicit current-account wording, for example "لا توجد نتيجة محفوظة لهذا الطلب في حسابك الحالي".
  - No automatic new key.
  - No assurance about any other account.
  - No "not committed" claim.
- **Unsafe receipt:** the action validates the receipt with the pure parser. A malformed receipt never redirects to success.
- **Retracted:** a returned `unknown` code alone does not freeze the shared `OperatorActionForm`, and does not cover thrown transport failures. So it cannot claim recovery with the exact same payload.

**What onboarding needs instead:** an onboarding-specific reviewed client contract, in the same pattern as `DraftForm`/`IssuanceForm`. Leave `OperatorActionForm` and the native/JS contracts unchanged. The client contract would:
- capture the key and a payload signature at submit;
- freeze the fields on `unknown` or a throw;
- offer only same-key, same-payload recovery.

**Gap:** a reload before any `?key` exists still produces a new key. Persisting the key across reloads would be a new URL or storage behaviour.

**Owner decision needed:** anything beyond same-actor, same-key replay. That means persisting the key across reloads, offering a fresh-key path from an ambiguous state, or any cross-account wording. Onboarding "unknown" stays **OPEN** until same-actor intent evidence (same actor, key and signature leading to a replayed snapshot) is captured at runtime.

## 2. Issuance readiness: correction accepted

- `ready:true` together with `issued_pack` is source-valid. The issued state takes priority, and I withdraw that integrity rejection.
- The form is offered only when `ready===true`, `blockers` is empty and `issued_pack` is null.
- `ready:true` with non-empty blockers fails closed to "not ready". It is not labelled corrupt.
- Unknown blocker or coverage codes from the `20261003048000` patches, including labour-deduction-adapter blockers, are tolerated and shown with the existing generic text.
- Copy always keeps `tax_insurance` scope and `financially_qualified=false`. It never implies financial or legal qualification.

## 3. Draft receipt: correction accepted

- Compare the receipt with the request captured at submit (`head` and `expected`, from the `previous` state used for that attempt), never with a refreshed current revision.
- **Editing an existing head:** `receipt.head` must equal the captured head, and `receipt.revision` must be greater than the captured `expected`.
- **New draft:** any uuid head with a positive revision.
- No global newest-revision check. A historical replayed result is valid.
- The existing `setDirty(false)`, the success acknowledgement and the `pendingRequest` release on a non-uncertain result stay unchanged.

## 4. Numeric rules guard: correction accepted

The guard covers every field the summary and editor consume:
- `tax`: `treatment`, `exemption`, `column_basis`, and `columns[]` with `through` and `bands[]` (`upper`, `rate`).
- `insurance`: `category`, `minimum`, `maximum`, and `branches[]` (`branch`, `employee`, `employer`, `deductible`).
- `base_taxable`, and the optional `earning_partition_rounding` and `labour_deduction_adapter` strings.

Rules for the guard:
- Unknown fields are tolerated.
- An unknown enum value renders as safe raw text.
- No arithmetic or policy checks.
- A malformed shape gives a visible integrity state for that revision. It never seeds the editor and never drops history rows.

## 5. Labour comparison variant: confirmed, and it blocks freezing the history DTO

- The history DTO becomes a discriminated union, using the discriminator defined in the patched comparator. Codex must identify that field from `20261003048000` before this part of B1 is frozen.
  - **Tax/insurance variant:** rendered as now.
  - **Labour variant:** a neutral generic row showing name, scenario code, matched or not, revision (current or older), origin, safe source link and the raw labelled values.
  - **Unrecognised variant:** stays a visible row reading "تعذر عرض هذه الحالة". It never turns the whole page corrupt and is never hidden.
- **Routine:** this neutral display of existing persisted data.
- **Owner or legal decision needed:** labour-specific labels, explanations of legal meaning, adding a labour case to `ComparisonForm`, or any statement about how labour cases count toward qualification. The backend blockers stay authoritative.

## Unchanged

- B1/B2 scope, with the §5 comparison-history item gated on Codex's source review.
- No new RPC, migration, policy, authority or storage.
- No numerical simplicity claims and no visual acceptance.
- Full R3 and R0–R8 stay open. Payroll A/B is pending, and D16 is deferred.
