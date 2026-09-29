'use client';

import { useState } from 'react';

export function LimitFields({ kind, label }: { kind: 'seats' | 'sites'; label: string }) {
  const [mode, setMode] = useState<'limited' | 'unlimited'>('limited');
  return <fieldset className="limit-fields"><legend>{label}</legend>
    <label htmlFor={`${kind}Mode`}>نوع الحد</label>
    <select id={`${kind}Mode`} name={`${kind}Mode`} value={mode}
      onChange={(event) => setMode(event.currentTarget.value as 'limited' | 'unlimited')}>
      <option value="limited">عدد محدد</option><option value="unlimited">غير محدود</option>
    </select>
    {mode === 'limited' && <>
      <label htmlFor={`${kind}Limit`}>الحد الأقصى {kind === 'seats' ? 'للمستخدمين' : 'للفروع'}</label>
      <input id={`${kind}Limit`} name={`${kind}Limit`} type="number" min="1" step="1" defaultValue="10" required />
    </>}
  </fieldset>;
}
