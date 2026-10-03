export type ManualData = Record<string, string | number | boolean>;
export type ManualSubmission = {data: ManualData; error?: string};

// Keep historical JSON intact for state transitions; the RPC still verifies CAS and authority.
export function manualSubmission(values: Record<string, string>, saved: ManualData | undefined, operation: string): ManualSubmission {
  const source = values.source || 'manual';
  const data: ManualData = {
    source,
    units: source === 'time' ? '0' : values.units,
    reference: values.reference || '',
    reason: values.reason || '',
    ...(source === 'manual' ? {basis: 'approved_payable_total'} : {}),
  };
  if (operation === 'save') return {data};
  if (!saved) return {data, error: 'أعد فتح السجل المحفوظ قبل الاعتماد أو الإلغاء.'};
  if (operation === 'cancel') return {data: saved};
  const unchanged = ['source', 'units', 'reference', 'reason'].every(key => {
    const expected = key === 'source' ? String(saved.source || 'manual') : String(saved[key] ?? '');
    return String(data[key] ?? '') === expected;
  });
  return unchanged
    ? {data: saved}
    : {data, error: 'احفظ تعديل مصدر الأيام والقيم قبل اعتماد المدخل.'};
}
