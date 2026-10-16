# -*- coding: utf-8 -*-
"""Independent Egyptian 2026 salary-tax / insured-wage calculator (AI-derived, NOT official).

Written blind (Phase 1) from primary sources only; imports nothing from the platform.
Run: python -X utf8 independent-calculator.py  -> writes independent-cases.json

Sources (see review-report.ar.md for citations):
  S1 Law 7/2024 (Official Gazette no.7 bis(a), 12 Feb 2024) p.1 Art.8 table + rounding sentence; p.2 Art.13(1) exemption 20,000.
  S2 ETA Payroll FAQ v4 (March 2026): p.6 Q15 cumulative/360 formula; p.13 Q27 treatment 1; p.17 Q40 max 30 days/month, 360/year;
     p.11 L517 over-withholding becomes credit in annual settlement; p.38 Q35 insurance rates fed per NOSI insurance case.
  S3 NOSI news 30/11/2025: insured wage min 2,700 / max 16,700 from 1 Jan 2026.
"""
import json
from decimal import Decimal as D, ROUND_FLOOR, ROUND_HALF_UP

PERSONAL_EXEMPTION = D("20000")          # S1 Art.13(1)
INS_MIN, INS_MAX = D("2700"), D("16700")   # S3, effective 2026-01-01
YEAR_DAYS = D("360")                       # S2 Q15/Q40
CENT = D("0.01")

# S1 Art.8 columns: (upper bound of annual net income for the column, [(band_upper, rate), ...]).
# Band list starts at 0; a band with rate applied "from 1 EGP" absorbs the lower brackets.
INF = None
COLUMNS = [
    (D("600000"),  [(D("40000"), D("0")), (D("55000"), D("0.10")), (D("70000"), D("0.15")),
                    (D("200000"), D("0.20")), (D("400000"), D("0.225")), (INF, D("0.25"))]),
    (D("700000"),  [(D("55000"), D("0.10")), (D("70000"), D("0.15")), (D("200000"), D("0.20")),
                    (D("400000"), D("0.225")), (INF, D("0.25"))]),
    (D("800000"),  [(D("70000"), D("0.15")), (D("200000"), D("0.20")), (D("400000"), D("0.225")), (INF, D("0.25"))]),
    (D("900000"),  [(D("200000"), D("0.20")), (D("400000"), D("0.225")), (INF, D("0.25"))]),
    (D("1200000"), [(D("400000"), D("0.225")), (INF, D("0.25"))]),
    (INF,          [(D("1200000"), D("0.25")), (INF, D("0.275"))]),
]


def floor10(x):
    """S1: annual net income rounded down to nearest 10 EGP."""
    return (x / 10).to_integral_value(rounding=ROUND_FLOOR) * 10


def pick_column(base):
    for i, (cap, bands) in enumerate(COLUMNS):
        if cap is INF or base <= cap:
            return i + 1, bands


def annual_tax(base):
    col, bands = pick_column(base)
    tax, lower, steps = D("0"), D("0"), []
    for upper, rate in bands:
        top = base if upper is INF else min(base, upper)
        if top > lower:
            part = (top - lower) * rate
            steps.append(f"({top}-{lower})x{rate}={part}")
            tax += part
        lower = upper if upper is not INF else lower
        if upper is INF or base <= upper:
            break
    return col, tax, steps


def tax_case(net_before_exemption, days, prior_due, column_basis="rounded"):
    net, days, prior = D(net_before_exemption), D(days), D(prior_due)
    assert D(1) <= days <= YEAR_DAYS
    annualized = net * YEAR_DAYS / days
    taxable = annualized - PERSONAL_EXEMPTION
    if taxable < 0:
        taxable = D("0")
    rounded = floor10(taxable)
    col_base = rounded if column_basis == "rounded" else taxable
    col, _ = pick_column(col_base)
    bands = COLUMNS[col - 1][1]
    # apply chosen column's bands to the rounded base
    tax, lower, steps = D("0"), D("0"), []
    for upper, rate in bands:
        top = rounded if upper is INF else min(rounded, upper)
        if top > lower:
            part = (top - lower) * rate
            steps.append(f"({top}-{lower})x{rate}={part}")
            tax += part
        if upper is INF or rounded <= upper:
            break
        lower = upper
    period_tax_exact = tax * days / YEAR_DAYS
    period_tax = period_tax_exact.quantize(CENT, ROUND_HALF_UP)
    delta = period_tax - prior
    return {
        "annualized_net_before_exemption": str(annualized),
        "personal_exemption": str(PERSONAL_EXEMPTION),
        "annual_taxable_unrounded": str(taxable),
        "annual_taxable_floor10": str(rounded),
        "column_basis": column_basis,
        "art8_column": col,
        "bands": steps,
        "annual_tax": str(tax),
        "period_tax_exact": str(period_tax_exact),
        "expected_tax_due_cumulative_period": str(period_tax),
        "prior_due": str(prior),
        "expected_tax_delta": str(delta),
    }


def insured_wage(wage):
    w = D(wage)
    return str(min(max(w, INS_MIN), INS_MAX))


INS_UNRESOLVED = {
    "status": "unresolved",
    "reason": ("Contribution rates depend on the NOSI insurance case/category (FAQ v4 p.38 Q35); "
               "Law 148/2019 PDF text extraction was unreadable in this session so Art.19 rates were NOT verified; "
               "UHI (Law 2/2018) is a separate regime and governorate-rollout dependent. No universal 11%/18.75% applied."),
    "expected_employee_insurance": None,
    "expected_employer_insurance": None,
    "expected_deductible_insurance": None,
}

TY = "2026-01-01..2026-12-31 (calendar tax year 2026)"
CASES = [
    dict(case_id="EG2026-01", scenario="low", net="30000", days=360, prior="0",
         period=("2026-01-01", "2026-12-31"), note="full-year cumulative at December pay; below 40,000 zero band"),
    dict(case_id="EG2026-02", scenario="medium", net="180000", days=360, prior="0",
         period=("2026-01-01", "2026-12-31"), note="column 1"),
    dict(case_id="EG2026-03", scenario="high", net="1400000", days=360, prior="0",
         period=("2026-01-01", "2026-12-31"), note="column 6 (>1,200,000): 25% from 1 EGP, 27.5% above"),
    dict(case_id="EG2026-04", scenario="mid_year", net="15000", days=30, prior="0",
         period=("2026-06-01", "2026-06-30"), note="hired 2026-06-01; FAQ Q39/Q40: duration from hire date, 30-day month"),
    dict(case_id="EG2026-05", scenario="cumulative", net="90000", days=180, prior="5000",
         period=("2026-01-01", "2026-06-30"), prior_withheld="4800",
         note="June pay; prior_due=5000 is tax DUE on Jan-May filings (synthetic, uneven earnings); "
              "prior_withheld=4800 is informational and NOT used in delta (remittance gap is separate)"),
    dict(case_id="EG2026-06", scenario="insurance_min", net="15000", days=30, prior="0",
         period=("2026-01-01", "2026-01-31"), insurance_month="2026-01",
         ins_inputs=["2699.99", "2700", "2700.01"], note="insured wage threshold sides at min 2,700"),
    dict(case_id="EG2026-07", scenario="insurance_max", net="30000", days=30, prior="0",
         period=("2026-01-01", "2026-01-31"), insurance_month="2026-01",
         ins_inputs=["16699.99", "16700", "16700.01", "30000"],
         note="insured wage threshold sides at max 16,700; period tax has repeating decimal -> rounding"),
    dict(case_id="EG2026-08", scenario="component_mix", net="180000", days=360, prior="0",
         period=("2026-01-01", "2026-12-31"),
         components={"basic_taxable": "120000", "allowances_taxable": "60000",
                     "employer_paid_employee_insurance_share_benefit": "0",
                     "excluded_by_operator_classification": "10000"},
         note="net_before_exemption = 120000+60000 = 180000; 10000 item excluded ONLY under the stated assumption "
              "that its exemption classification is valid (classification itself not verified here). FAQ p.19 Q: "
              "employer-borne employee insurance share must be ADDED as a benefit; set 0 here."),
    dict(case_id="EG2026-09", scenario="correction", net="90000", days=180, prior="10000",
         period=("2026-01-01", "2026-06-30"), note="positive and negative delta variants below"),
    dict(case_id="EG2026-10", scenario="rounding", net="600009.99", days=360, prior="0",
         period=("2026-01-01", "2026-12-31"),
         note="input is BEFORE exemption -> taxable 580009.99 -> 580000 (column 1); threshold variants below"),
]


def build():
    out = []
    for c in CASES:
        t = tax_case(c["net"], c["days"], c["prior"])
        rec = {
            "case_id": c["case_id"], "scenario": c["scenario"],
            "evidence_origin": "ai_independently_derived_from_primary_sources",
            "official": False,
            "tax_treatment": "ETA payroll treatment 1 (FAQ v4 p.13 Q27): permanent/temporary employee, original employer, resident, no disability/chronic/SCZone/foreign special rules",
            "tax_year": TY,
            "tax_period_from": c["period"][0], "tax_period_until": c["period"][1],
            "tax_duration_days": c["days"],
            "tax_net_before_personal_exemption": c["net"],
            "prior_tax_due": c["prior"],
            "prior_tax_withheld": c.get("prior_withheld"),
            "assumption_note": c["note"],
            "tax": t,
            "expected_tax_due": t["expected_tax_due_cumulative_period"],
            "expected_tax_delta": t["expected_tax_delta"],
            "insurance": dict(INS_UNRESOLVED),
        }
        if "components" in c:
            rec["components"] = c["components"]
        if "ins_inputs" in c:
            rec["insurance_month"] = c["insurance_month"]
            rec["insurance"]["insured_months"] = 1
            rec["insurance"]["insured_wage_clamp_2026"] = {w: insured_wage(w) for w in c["ins_inputs"]}
            rec["insurance"]["insured_wage_status"] = "resolved (NOSI 30/11/2025)"
        out.append(rec)

    by = {r["case_id"]: r for r in out}
    # correction variants (EG2026-09)
    orig = tax_case("96000", 180, "10000")
    neg = tax_case("90000", 180, "12000")
    by["EG2026-09"]["variants"] = {
        "original_filing_net_96000": orig,
        "corrected_net_90000": by["EG2026-09"]["tax"],
        "correction_effect_on_period_due": str(D(by["EG2026-09"]["expected_tax_delta"]) - D(orig["expected_tax_delta"])),
        "negative_delta_prior_due_12000": neg,
        "negative_delta_handling": "credit settled via annual settlement (FAQ v4 p.11 ~L517); not a refund computed here",
    }
    # rounding / column threshold variants (EG2026-10)
    by["EG2026-10"]["variants"] = {
        "taxable_exactly_600000 (net 620000)": tax_case("620000", 360, "0"),
        "taxable_600009.99_rounded_basis (net 620009.99)": tax_case("620009.99", 360, "0", "rounded"),
        "taxable_600009.99_UNROUNDED_basis (net 620009.99)": tax_case("620009.99", 360, "0", "unrounded"),
        "taxable_600010 (net 620010)": tax_case("620010", 360, "0"),
        "taxable_1200000 (net 1220000)": tax_case("1220000", 360, "0"),
        "taxable_1200010 (net 1220010)": tax_case("1220010", 360, "0"),
        "column_basis_status": ("UNRESOLVED interpretation for 600000<x<600010: Law 7/2024 says annual net is floored to 10 'when computing tax'; "
                                "primary text does not state whether column selection uses floored or unfloored base. Primary expected uses floored base."),
    }
    return out


if __name__ == "__main__":
    cases = build()
    doc = {
        "evidence_origin": "ai_independently_derived_from_primary_sources",
        "official": False,
        "reviewer_model": "claude-opus-5-5", "model_effort": "medium (as appointed)",
        "review_date": "2026-10-16",
        "scope": "Egyptian salary tax 2026, ETA treatment 1, resident private-sector employee; insured-wage bounds 2026. "
                 "Insurance contribution amounts UNRESOLVED (category-dependent). Not labour-law pay, not bank execution.",
        "global_assumptions": [
            "Annualize: cumulative net x 360 / cumulative days (FAQ v4 p.6 Q15).",
            "Full annual personal exemption 20,000 deducted from the annualized net (Law 7/2024 Art.13(1)); floor to 10 EGP after exemption.",
            "Column chosen on floored annual taxable base (see EG2026-10 unresolved note).",
            "Annual tax kept exact; period tax = annual x days/360 rounded HALF_UP to 0.01 EGP (assumption: no primary piaster-rounding rule found).",
            "Tax delta = period cumulative tax - prior tax DUE (not prior withheld).",
            "Inputs are synthetic; no real persons/companies.",
        ],
        "cases": cases,
    }
    with open("independent-cases.json", "w", encoding="utf-8") as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=2)
    for c in cases:
        print(c["case_id"], c["scenario"], "col", c["tax"]["art8_column"], "annual", c["tax"]["annual_tax"],
              "due", c["expected_tax_due"], "delta", c["expected_tax_delta"])
    for k, v in cases[9]["variants"].items():
        if isinstance(v, dict):
            print("  ", k, "col", v["art8_column"], "annual", v["annual_tax"])
    v = cases[8]["variants"]
    print("  corr orig due", v["original_filing_net_96000"]["expected_tax_due_cumulative_period"], "effect", v["correction_effect_on_period_due"],
          "neg delta", v["negative_delta_prior_due_12000"]["expected_tax_delta"])
