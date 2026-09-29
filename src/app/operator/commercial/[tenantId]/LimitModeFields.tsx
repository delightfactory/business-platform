'use client';

import { useState } from 'react';

export function LimitModeFields({ id, label, mode, value }: {
  id: string; label: string; mode: 'limited' | 'unlimited' | null; value: number | null;
}) {
  const [selectedMode, setSelectedMode] = useState(mode ?? 'limited');
  return <>
    <label htmlFor={`${id}-mode`}>نوع الحد</label>
    <select id={`${id}-mode`} name="mode" value={selectedMode}
      onChange={(event) => setSelectedMode(event.currentTarget.value as 'limited' | 'unlimited')}>
      <option value="limited">عدد محدد</option><option value="unlimited">غير محدود</option>
    </select>
    {selectedMode === 'limited' && <>
      <label htmlFor={`${id}-value`}>{label}</label>
      <input id={`${id}-value`} name="value" type="number" min="1" step="1" defaultValue={value ?? ''} required />
    </>}
    <p className="field-hint">إذا خُفّض الحد عن الاستخدام الحالي، تبقى الموارد الموجودة فعّالة ويُمنع إضافة جديد حتى ينخفض الاستخدام أو يُرفع الحد.</p>
  </>;
}
