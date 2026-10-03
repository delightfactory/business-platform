# Cube 4 independent statutory pack binding — bounded local QA150 qualification

Stage2 prerequisite for the Frozen Payroll specification section16: effective-dated versioned rules and exact calculation provenance. The private numeric employee worker previously used one pack for both tax and insurance. It can now accept an explicit tax/earnings pack and a separate explicit insurance pack. This removes a composition constraint when reviewed tax earnings and reviewed insurance obligations require different dated versions. It adds no screen, legal default, automatic pack selection or month ownership rule.

## Source boundary

- Migration `20261003022000_cube4_independent_statutory_pack_binding.sql` adds private five-argument overloads of `calculate_statutory_employee` and `calculate_statutory_employee_with_earnings`: employee, tax pack, facts, insurance pack, insurance context.
- Existing four-argument signatures remain thin compatibility wrappers. There is one numeric validation/calculation body. Tax and taxable earning attribution use the tax pack; insurance uses its own explicitly supplied pack and retains the existing full-month effective coverage validation.
- Insured facts cannot omit a qualifying insurance pack. Explicitly reviewed not-insured facts reject an extra insurance pack or insurance context. The old not-insured API still accepts its tax pack and NULL insurance context.
- The existing `statutory_calculation.pack_id` remains the tax pack; insurance already records its exact `pack_id` and `pack_version`. All four signatures remain private SECURITY INVOKER with empty search_path and API-role EXECUTE revoked.
- Results remain `financially_qualified:false`. Public candidate net and G6 are unchanged. Different-year synthetic facts below are explicit test inputs, not adoption of a live tax attribution or insurance ownership policy.

## Root evidence — dedicated QA149 rollback only

`cube4-independent-statutory-packs-qualification-v2.json` in the run artifacts records PASS15 new binding assertions and PASS38 checks for the changed legacy core. The latter include the existing36 calculation/validation cases plus exact JSON comparison against the original function captured from the installed database for both insured and explicitly not-insured results. Repeating these cases is justified by changing their numeric body/signature dispatch; unrelated attention and payment suites were not repeated.

The new assertions cover independent dated pack provenance and rates, unqualified tax/insurance packs independently rejected, whole-month coverage, missing insurance pack, explicit exclusions, duplicate application, source-derived earnings using the tax pack even when the insurance pack lacks earning rules, same-pack legacy equivalence, and denial to all API roles. A NONLEGAL hand fixture reconciles gross100 minus insurance20 minus tax10 to net70, without claiming legal qualification.

Before/after rollback evidence confirms all44 Payroll tables and the command_receipts view unchanged, migration count149 unchanged, and all Payroll/private and public Payroll function definitions restored. This is not a fresh replay or a full financial lifecycle acceptance.

Source hashes:

- Migration: `e47fd0f00ac1f3705db8451564e4e727b981f76a3222b18c315ee3c65079af31`.
- Test: `267979753243ae4ec8eef32ef3c5350316d62e58962f70cb7f73940ad6c95606`.

The unexecuted initial OpenCode test draft had an incorrect insurance error expectation and passed a prohibited taxable override to the source-derived wrapper; root corrected both before execution. The first actual run then failed a missing synthetic reviewer foreign key before assertions; its FAIL_STOPPED v1 artifact is retained. Adding the isolated reviewer fixture resolved that dependency. No test expectation or source qualification was weakened.

## Remaining integration and next action

Independent exact-source review PASS in OpenCode plan session `ses_effdae8c8ffepoC0YZj1Knn8Zo`, terminal exit0, at the exact hashes above. Artifacts: `opencode-independent-packs-readonly/result.json`. Root then installed those reviewed bytes on both dedicated local QA databases149→150. `cube4-independent-statutory-packs-local-install.json` records matching pre-install definitions, all45 retained-history checks inside each installation transaction before commit, and denial of API-role execution for all four signatures. No production or publication changes. Do not call this a financially usable candidate or a completed Stage2.

The source composition bridge must eventually select qualifying packs for reviewed tax earning spans and reviewed insurance month spans separately. The current automatic source helper still emits NULL legal duration and obligation months. Those unresolved facts cannot be manufactured from operational date partitions. Legal tax duration/year attribution, insurance ownership/consumption, official comparisons, cross-year tax segmentation and public integration remain open. This worker accepts one tax context and one insurance context, whose existing adapter requires one year and pack; it does not implement arbitrary multi-pack groups.

After the bounded source acceptance, return to the integrated review bridge in [completion route](cube-4-completion-route.md), using explicit owned blockers for missing legal facts. No new rule engine, source override screen or repeated legal research/test loop is authorized by this checkpoint.
