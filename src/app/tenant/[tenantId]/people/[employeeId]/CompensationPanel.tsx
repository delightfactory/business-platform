'use client';

import { useActionState, useState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { cancelCompensationChangeAction, changeCompensationAction, type CompensationFormState } from '../compensation-actions';

type CompensationVersion = {
  id: string; amount: number | string; currency: string; valid_from: string; valid_until: string | null;
  status: 'current' | 'past' | 'scheduled';
};
export type CompensationHistory = { items: CompensationVersion[]; truncated: boolean; pay_basis: 'monthly' | 'daily' };
export type CompensationOptions = {
  pay_basis: 'monthly' | 'daily'; employment_status: string; employment_start: string;
  has_current: boolean; current_valid_from: string | null; effective_date_min: string | null;
  effective_date_default: string | null;
  pending: { id: string; valid_from: string } | null;
};

export function CompensationPanel({ tenantId, employeeId, employmentId, canView, canManage, history, historyError,
  options, optionsError, today }: {
  tenantId: string; employeeId: string; employmentId: string | null; canView: boolean; canManage: boolean;
  history: CompensationHistory | null; historyError: boolean; options: CompensationOptions | null;
  optionsError: boolean; today: string;
}) {
  const initial: CompensationFormState = {
    tenantId, employmentId: employmentId ?? '', employeeId, amount: '',
    effectiveDate: options?.effective_date_default ?? today, error: '', attempt: 0,
  };
  const [formState, formAction] = useActionState(changeCompensationAction, initial);
  const [effectiveDateChoice, setEffectiveDateChoice] = useState(formState.effectiveDate);
  const pending = options ? options.pending : history?.items.find((version) => version.status === 'scheduled') ?? null;
  const canChange = canManage && employmentId !== null && options !== null && !optionsError
    && options.employment_status === 'active' && options.has_current && !pending;

  return <section className="workspace-records-panel assignment-history-panel" aria-labelledby="compensation-heading">
    <h2 id="compensation-heading">الأجر الأساسي</h2>
    {(options || history) && <p className="record-meta">{(options?.pay_basis ?? history?.pay_basis) === 'daily' ? 'أجر يومي' : 'راتب شهري'} · الجنيه المصري</p>}
    {historyError && <p className="form-message error-message" role="alert">تعذر تحميل سجل الأجر. تحقق من صلاحية عرض بيانات الأجر ثم حدّث الصفحة.</p>}
    {canView && !historyError && history?.items.length ? <ol className="assignment-history-list">
      {history.items.map((version) => <li key={version.id} className="assignment-history-item">
        <div className="assignment-history-heading">
          <strong>{version.status === 'scheduled' ? 'تغيير مقرر' : version.status === 'current' ? 'الأجر الحالي' : 'أجر سابق'}</strong>
          <span className={`entity-status ${version.status === 'past' ? 'is-inactive' : 'is-active'}`}>
            {version.status === 'scheduled' ? 'يبدأ لاحقًا' : version.status === 'current' ? 'سارٍ الآن' : 'انتهى'}</span>
        </div>
        <dl className="snapshot-grid">
          <div><dt>القيمة</dt><dd><bdi>{formatAmount(version.amount)}</bdi> جنيه مصري</dd></div>
          <div><dt>يبدأ في</dt><dd><bdi>{version.valid_from}</bdi></dd></div>
          {version.valid_until && <div><dt>ينتهي قبل</dt><dd><bdi>{version.valid_until}</bdi></dd></div>}
        </dl>
        {canManage && version.status === 'scheduled' && pending?.id === version.id && employmentId && <form action={cancelCompensationChangeAction} className="assignment-cancel-form">
          <input type="hidden" name="tenantId" value={tenantId} />
          <input type="hidden" name="employeeId" value={employeeId} />
          <input type="hidden" name="employmentId" value={employmentId} />
          <input type="hidden" name="versionId" value={version.id} />
          <SubmitButton label="إلغاء تغيير الأجر المقرر" pendingLabel="جارٍ الإلغاء…" />
        </form>}
      </li>)}
    </ol> : canView && !historyError ? <p className="empty-state">لا توجد بيانات أجر مسجلة لهذه العلاقة.</p> : null}
    {history?.truncated && <p className="record-meta">يعرض هذا الملف أحدث 100 تغيير في الأجر.</p>}
    {canManage && !employmentId && <p className="form-message">لا توجد علاقة توظيف يمكن تغيير أجرها.</p>}
    {optionsError && canManage && employmentId && <p className="form-message error-message" role="alert">تعذر تحميل حالة الأجر. حدّث الصفحة أو تحقق من صلاحية إدارة الأجر.</p>}
    {canManage && options && options.employment_status !== 'active' && <p className="form-message">لا يمكن تغيير الأجر بعد انتهاء علاقة التوظيف.</p>}
    {canManage && options && !options.has_current && <p className="form-message">لا يوجد أجر سارٍ اليوم لهذه العلاقة. يمكن تغيير الأجر بعد بداية علاقة العمل.</p>}
    {pending && canManage && <p className="form-message">يوجد تغيير مقرر بتاريخ <bdi>{pending.valid_from}</bdi>. ألغِه قبل حفظ تغيير آخر.</p>}
    {canChange && <details className="compensation-change-details">
      <summary>تغيير الأجر الأساسي</summary>
      <form key={formState.attempt} action={formAction} className="compensation-change-form">
        <p className="field-hint">يسري التغيير من التاريخ المحدد؛ وتبقى القيم السابقة محفوظة في سجل الأجر.</p>
        <input type="hidden" name="tenantId" value={tenantId} />
        <input type="hidden" name="employmentId" value={employmentId ?? ''} />
        <input type="hidden" name="employeeId" value={employeeId} />
        <label htmlFor="compensation-amount">{options.pay_basis === 'daily' ? 'الأجر اليومي' : 'الراتب الشهري'} (جنيه مصري)</label>
        <input id="compensation-amount" name="amount" type="number" inputMode="decimal" min="0" max="999999999999.99"
          step="0.01" required defaultValue={formState.amount} />
        <label htmlFor="compensation-effective-date">تاريخ بدء الأجر الجديد</label>
        <input id="compensation-effective-date" name="effectiveDate" type="date" required
          min={options.effective_date_min ?? today} value={effectiveDateChoice}
          onChange={(event) => setEffectiveDateChoice(event.target.value)} />
        {effectiveDateChoice < today && <p className="field-hint">التاريخ السابق متاح داخل فترة الأجر الحالية فقط. فحص الفترات المقفلة وربط طلب التصحيح سيُضافان مع تكامل Payroll.</p>}
        {formState.error && <p className="form-message error-message" role="alert">{formState.error}</p>}
        <p className="field-hint">يوجد تغيير مقرر واحد فقط؛ ألغِه أولًا لتحديد تاريخ أو قيمة أخرى.</p>
        <div className="workspace-form-actions"><SubmitButton label="حفظ تغيير الأجر" pendingLabel="جارٍ حفظ التغيير…" /></div>
      </form>
    </details>}
    {canManage && !canView && employmentId && options?.pending && <form action={cancelCompensationChangeAction} className="assignment-cancel-form">
      <input type="hidden" name="tenantId" value={tenantId} />
      <input type="hidden" name="employeeId" value={employeeId} />
      <input type="hidden" name="employmentId" value={employmentId} />
      <input type="hidden" name="versionId" value={options.pending.id} />
      <SubmitButton label="إلغاء تغيير الأجر المقرر" pendingLabel="جارٍ الإلغاء…" />
    </form>}
  </section>;
}

function formatAmount(value: number | string) {
  return Number(value).toLocaleString('ar-EG', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
