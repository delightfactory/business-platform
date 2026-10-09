'use client';
import { Button, ButtonLink, Field, Input, Message, Select } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useActionState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { saveOrgCatalogAction, type OrgCatalogFormState, type OrgCatalogKind } from './actions';

export type OrgCatalogOption = {
  id: string; name: string; parent_id?: string | null; is_active: boolean; effectively_active: boolean;
};
export type OrgCatalogRecord = {
  id: string; code: string; name: string; is_active: boolean;
  parent_id?: string | null; department_id?: string | null; parent_name?: string | null; department_name?: string | null;
};

export function OrgCatalogForm({ tenantId, kind, record, options, optionsTruncated }:
  { tenantId: string; kind: OrgCatalogKind; record: OrgCatalogRecord | null; options: OrgCatalogOption[]; optionsTruncated: boolean }) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHint0 = useId();
  const isNew = record === null;
  const relationId = kind === 'departments' ? record?.parent_id ?? '' : record?.department_id ?? '';
  const initial: OrgCatalogFormState = {
    tenantId, kind, recordId: record?.id ?? 'new', code: record?.code ?? '', name: record?.name ?? '',
    relationId, isActive: record?.is_active ?? true, error: '', attempt: 0,
  };
  const [state, action, actionPending] = useActionState(saveOrgCatalogAction, initial);
  const choices = kind === 'departments' && record
    ? excludeDescendants(options, record.id)
    : options;
  const relationName = kind === 'departments' ? 'القسم الأعلى (اختياري)' : 'القسم (اختياري)';
  const missingCurrent = state.relationId && !choices.some((option) => option.id === state.relationId);
  const showOffline0 = offline && !actionPending;
  return <form key={state.attempt} action={action} className="auth-form compact-form org-catalog-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="kind" value={kind} />
    <input type="hidden" name="recordId" value={record?.id ?? 'new'} />
    <Field id="org-catalog-code" label={<>الرمز</>} required><Input id="org-catalog-code" name="code" required maxLength={40} autoFocus defaultValue={state.code} dir="auto" /></Field>
    <Field id="org-catalog-name" label={<>{kind === 'departments' ? 'اسم القسم' : 'اسم الوظيفة'}</>} required><Input id="org-catalog-name" name="name" required maxLength={160} defaultValue={state.name} /></Field>
    <Field id="org-catalog-relation" label={<>{relationName}</>}><Select id="org-catalog-relation" name="relationId" defaultValue={state.relationId}>
      <option value="">دون تحديد</option>
      {missingCurrent && <option value={state.relationId}>{kind==='departments' ? record?.parent_name : record?.department_name ?? 'الارتباط الحالي محفوظ'}</option>}
      {choices.map((option) => <option key={option.id} value={option.id}
        disabled={!option.effectively_active && option.id !== state.relationId}>
        {option.name}{option.effectively_active ? '' : ' · غير نشط'}
      </option>)}
    </Select></Field>
    {kind === 'departments' && <p className="field-hint">اختر قسمًا أعلى في التسلسل. يمنع النظام أي تغيير يكوّن حلقة.</p>}
    {(optionsTruncated || missingCurrent) && <Message tone="info"  role="status">
      {missingCurrent ? 'تعذر عرض قائمة الأقسام كاملة؛ سيبقى الارتباط الحالي محفوظًا إذا لم تغيّره.'
        : 'تُعرض أول 1000 قيمة نشطة في هذه القائمة.'}
    </Message>}
    <Field id="org-catalog-active" label={<>الحالة</>}><Select id="org-catalog-active" name="isActive" defaultValue={String(state.isActive)}>
      <option value="true">نشط</option><option value="false">غير نشط</option>
    </Select></Field>
    {!isNew && <p className="field-hint">تعطيل السجل يحفظ تاريخه وروابط بيانات العمل السابقة، ويمنع اختياره في تغييرات جديدة في بيانات العمل.</p>}
    {state.error && <Message tone="bad"  role="alert">{state.error}</Message>}
    <div className="workspace-form-actions org-catalog-actions">
      <SubmitButton label={isNew ? 'إضافة السجل' : 'حفظ التغييرات'} pendingLabel="جارٍ الحفظ…"  ariaDescribedBy={showOffline0 ? offlineHint0 : undefined} disabled={offline}/>
      {!isNew && state.isActive && <Button variant="ghost"  type="submit" name="intent" value="disable" aria-describedby={showOffline0 ? offlineHint0 : undefined} disabled={offline}>
        تعطيل السجل
      </Button>}
      {!isNew && !state.isActive && <Button variant="ghost"  type="submit" name="intent" value="reactivate" aria-describedby={showOffline0 ? offlineHint0 : undefined} disabled={offline}>
        إعادة تفعيل السجل
      </Button>}
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people/organization?kind=${kind}`}>إلغاء</ButtonLink>
    </div>
  {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>;
}

function excludeDescendants(options: OrgCatalogOption[], recordId: string) {
  const blocked = new Set([recordId]);
  let changed = true;
  while (changed) {
    changed = false;
    for (const option of options) {
      if (option.parent_id && blocked.has(option.parent_id) && !blocked.has(option.id)) {
        blocked.add(option.id);
        changed = true;
      }
    }
  }
  return options.filter((option) => !blocked.has(option.id));
}
