'use client';
import { Badge, Disclosure, Field, Input, Message, Panel, RecordCard } from '@/components/ui';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';

import { useActionState, useState } from 'react';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import { useOfflineSubmission } from '@/components/offline-submission';
import { cancelCompensationChangeAction, changeCompensationAction, type CompensationFormState } from '../compensation-actions';

type CompensationVersion = {
  id: string; amount: number | string; currency: string; valid_from: string; valid_until: string | null;
  status: 'current' | 'past' | 'scheduled' | 'initial_scheduled';
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
  const { blockOfflineSubmission } = useOfflineSubmission();
  const initial: CompensationFormState = {
    tenantId, employmentId: employmentId ?? '', employeeId, amount: '',
    effectiveDate: options?.effective_date_default ?? today, error: '', attempt: 0,
  };
  const [formState, formAction] = useActionState(changeCompensationAction, initial);
  const [effectiveDateChoice, setEffectiveDateChoice] = useState(formState.effectiveDate);
  const pending = options ? options.pending : history?.items.find((version) => version.status === 'scheduled') ?? null;
  const canChange = canManage && employmentId !== null && options !== null && !optionsError
    && options.employment_status === 'active' && options.has_current && !pending;

  return <Panel className="assignment-history-panel" aria-labelledby="compensation-heading">
    <h2 id="compensation-heading">الأجر الأساسي</h2>
    {(options || history) && <p className="record-meta">{(options?.pay_basis ?? history?.pay_basis) === 'daily' ? 'أجر يومي' : 'راتب شهري'} · الجنيه المصري</p>}
    {historyError && <Message tone="bad"  role="alert">تعذر تحميل سجل الأجر. تحقق من صلاحية عرض بيانات الأجر ثم حدّث الصفحة.</Message>}
    {canView && !historyError && history?.items.length ? <ol className="assignment-history-list">
      {history.items.map((version) => <RecordCard key={version.id} className="assignment-history-item">
        <div className="assignment-history-heading">
          <strong>{version.status === 'initial_scheduled' ? 'الأجر عند بدء العمل'
            : version.status === 'scheduled' ? 'تغيير مقرر' : version.status === 'current' ? 'الأجر الحالي' : 'أجر سابق'}</strong>
          <Badge className={`entity-status ${version.status === 'past' ? 'is-inactive' : 'is-active'}`}>
            {version.status === 'initial_scheduled' ? 'يبدأ مع العمل'
              : version.status === 'scheduled' ? 'يبدأ لاحقًا' : version.status === 'current' ? 'سارٍ الآن' : 'انتهى'}</Badge>
        </div>
        <dl className="snapshot-grid">
          <div><dt>القيمة</dt><dd><bdi>{formatAmount(version.amount)}</bdi> جنيه مصري</dd></div>
          <div><dt>يبدأ في</dt><dd><bdi>{version.valid_from}</bdi></dd></div>
          {version.valid_until && <div><dt>ينتهي قبل</dt><dd><bdi>{version.valid_until}</bdi></dd></div>}
        </dl>
        {canManage && version.status === 'scheduled' && pending?.id === version.id && employmentId && <form action={cancelCompensationChangeAction} className="assignment-cancel-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
          <input type="hidden" name="tenantId" value={tenantId} />
          <input type="hidden" name="employeeId" value={employeeId} />
          <input type="hidden" name="employmentId" value={employmentId} />
          <input type="hidden" name="versionId" value={version.id} />
          <OfflineSubmitButton label="إلغاء تغيير الأجر المقرر" pendingLabel="جارٍ الإلغاء…" />
        </form>}
      </RecordCard>)}
    </ol> : canView && !historyError ? <Message tone="neutral" >لا توجد بيانات أجر مسجلة لهذا التوظيف.</Message> : null}
    {history?.truncated && <p className="record-meta">يعرض هذا الملف أحدث 100 تغيير في الأجر.</p>}
    {canManage && !employmentId && <Message tone="info" >لا يوجد توظيف مسجل لتغيير الأجر.</Message>}
    {optionsError && canManage && employmentId && <Message tone="bad"  role="alert">تعذر تحميل حالة الأجر. حدّث الصفحة أو تحقق من صلاحية إدارة الأجر.</Message>}
    {canManage && options && options.employment_status !== 'active' && <Message tone="info" >لا يمكن تغيير الأجر بعد انتهاء التوظيف.</Message>}
    {canManage && options && !options.has_current && <Message tone="info" >لا يوجد أجر سارٍ اليوم. يمكن تغييره بعد بدء التوظيف.</Message>}
    {pending && canManage && <Message tone="info" >يوجد تغيير مقرر بتاريخ <bdi>{pending.valid_from}</bdi>. ألغِه قبل حفظ تغيير آخر.</Message>}
    {canChange && <Disclosure className="compensation-change-details" summary={<>تغيير الأجر الأساسي</>}>
      <form key={formState.attempt} action={formAction} className="compensation-change-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
        <p className="field-hint">يسري التغيير من التاريخ المحدد؛ وتبقى القيم السابقة محفوظة في سجل الأجر.</p>
        <input type="hidden" name="tenantId" value={tenantId} />
        <input type="hidden" name="employmentId" value={employmentId ?? ''} />
        <input type="hidden" name="employeeId" value={employeeId} />
        <Field id="compensation-amount" label={<>{options.pay_basis === 'daily' ? 'الأجر اليومي' : 'الراتب الشهري'} (جنيه مصري)</>} required><Input id="compensation-amount" name="amount" type="number" inputMode="decimal" min="0" max="999999999999.99"
          step="0.01" required defaultValue={formState.amount} /></Field>
        <Field id="compensation-effective-date" label={<>تاريخ بدء الأجر الجديد</>} required><Input id="compensation-effective-date" name="effectiveDate" type="date" required
          min={options.effective_date_min ?? today} value={effectiveDateChoice}
          onChange={(event) => setEffectiveDateChoice(event.target.value)} /></Field>
        {effectiveDateChoice < today && <p className="field-hint">يمكن اختيار تاريخ سابق داخل فترة الأجر الحالية فقط. إذا تأثر مسير مقفل، يحتفظ النظام ببيانات المصدر ويوجّه مسؤول الرواتب لمراجعة مقترح التصحيح المؤرخ ونتيجته.</p>}
        {formState.error && <Message tone="bad"  role="alert">{formState.error}</Message>}
        <p className="field-hint">يوجد تغيير مقرر واحد فقط؛ ألغِه أولًا لتحديد تاريخ أو قيمة أخرى.</p>
        <div className="workspace-form-actions"><OfflineSubmitButton label="حفظ تغيير الأجر" pendingLabel="جارٍ حفظ التغيير…" /></div>
      </form>
    </Disclosure>}
    {canManage && !canView && employmentId && options?.pending && <form action={cancelCompensationChangeAction} className="assignment-cancel-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
      <input type="hidden" name="tenantId" value={tenantId} />
      <input type="hidden" name="employeeId" value={employeeId} />
      <input type="hidden" name="employmentId" value={employmentId} />
      <input type="hidden" name="versionId" value={options.pending.id} />
      <OfflineSubmitButton label="إلغاء تغيير الأجر المقرر" pendingLabel="جارٍ الإلغاء…" />
    </form>}
  </Panel>;
}

function formatAmount(value: number | string) {
  return Number(value).toLocaleString(ARABIC_DISPLAY_LOCALE, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
