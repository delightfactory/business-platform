# Cube 4 statutory source schema checkpoint

## Current evidence

The official 2026 private-sector XLSX was retrieved from the current HTTPS link on the [ETA forms page](https://www.eta.gov.eg/ar/payroll-forms). Its SHA256 is `632905c5211d3e9b9e878843947b0b6143a59099f4aeaf8bb65fb8e16be1767d`. This supersedes the earlier download-timeout observation; historical failed attempts remain evidence of those attempts only.

Read-only inspection of the worksheet XML found 98 header cells and 98 corresponding field codes in A1:CT2, with no other populated cells and no formulas. This is an input template, not an executable calculation model or a set of golden expected results. The original workbook was preserved.

Evidence: `cube4-official-2026-template-schema-evidence.json` and `cube4-official-workbook-cell-extraction.json` in the isolated run directory.

## Implementation implications

- M1/M2 identify tax treatment (EI060). O1/O2 identify work duration (EI130). Duration must have documented cumulative coverage semantics before annualization; do not derive it from the payroll label or payment date.
- V1/V2 comprehensive wage (EI100) and X1/X2 insured wage (EI110) are separate fields. An operational gross total is not evidence of the insured wage.
- R1/R2 insurance commencement (EI080), T1/T2 employment termination (EI090), and U1/U2 insurance termination (EI095) are distinct dates.
- BW1:CB2 distinguish prior calculated tax and current calculated tax by treatment. Existing opening YTD `tax_withheld` describes money withheld; it cannot silently substitute for prior calculated/due tax.

The [official SDK linked by ETA](https://eta.gov.eg/sites/default/files/2023-05/UPTCP-Taxpayer-SDK-V.5.pdf) contains worked request/response examples. Its 2023 hosting/version context does not qualify those numeric results for 2026. Use it as an integration-format reference only until applicable legal identity is established. No external API submission or taxpayer credential use was performed.

## Next implementation boundary

Complete effective employee statutory context and cumulative YTD inputs with provenance and frozen-version capture. Keep the ordinary payroll form short; additional tax/insurance inputs belong in a clearly named employee section and can be reused across periods. Missing statutory context must remain unknown rather than becoming a zero deduction. Then connect the dated adapter to actual current official representative comparisons before exposing final approval.

This checkpoint qualifies source structure only. It does not qualify statutory arithmetic, insurance applicability, rounding, net payroll, approval, or the complete financial cycle. No database migration, production change, commit, push, or unchanged suite rerun was performed for this inspection.

## Owner availability clarification

The owner confirmed that neither official2026 computed results nor portal access is available currently. This changes source availability, not the Frozen qualification requirement. Independent local integration and synthetic workflow qualification continue; no current legal pack or public finalization readiness is inferred. Evidence: `cube4-official-output-availability.json`.
