export type ClassificationReview = {
  expected_fact_id: string | null;
  expected_fact_version: number | null;
  expected_interpretation_id: string | null;
  expected_interpretation_version: number | null;
  input_fingerprint: string;
  context_hash: string;
  plan_hash: string;
  classification: {
    kind: 'absence' | 'leave_covered';
    absence_units: number;
    leave_units: number;
    approval_eligible: true;
    observations: { worked_minutes?: number | null };
    diagnostics: string[];
  };
};

export type ClassificationActionState = { message: string; needsReview: boolean };

export function readClassificationReview(value: unknown): ClassificationReview | null {
  if (!object(value) || !object(value.classification)) return null;
  const classification = value.classification;
  if (!['absence', 'leave_covered'].includes(String(classification.kind)) || classification.approval_eligible !== true
    || typeof classification.absence_units !== 'number' || typeof classification.leave_units !== 'number'
    || !object(classification.observations) || !Array.isArray(classification.diagnostics)
    || !classification.diagnostics.every((item) => typeof item === 'string')) return null;
  for (const prefix of ['expected_fact', 'expected_interpretation']) {
    const id = value[`${prefix}_id`], version = value[`${prefix}_version`];
    if (id === null && version === null) continue;
    if (typeof id !== 'string' || !uuid(id) || !Number.isInteger(version) || Number(version) <= 0) return null;
  }
  if (![value.input_fingerprint, value.context_hash].every((hash) => typeof hash === 'string' && /^[a-f0-9]{32}$/.test(hash))
    || typeof value.plan_hash !== 'string' || !/^[a-f0-9]{64}$/.test(value.plan_hash)) return null;
  return value as ClassificationReview;
}

export function uuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function object(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
