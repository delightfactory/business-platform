'use client';

import { useActionState, useId, useState } from 'react';
import { Badge, Button, Disclosure, Field, Input, Message, Select } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { employeeAdjustmentAction } from './adjustment-actions';
import { type InputRecord, type InputState } from '../../payroll/inputs/rules';

export type AdjustmentComponent = { id: string; name: string; classification: 'earning' | 'deduction' };
export type AdjustmentPeriod = { id: string; starts_on: string; ends_on: string };
type Scope = { tenant: string; employee: string; employer: string; employment: string; period: AdjustmentPeriod; returnTo?:string|null };
const initial: InputState = { error: '', saved: false, head: '', revision: 0, attempt: '', signature: '', status: 'draft' };

export function EmployeeAdjustmentForm({ scope, components, record, canManage, canApprove, locked }: {
  scope: Scope; components: AdjustmentComponent[]; record?: InputRecord; canManage: boolean; canApprove: boolean; locked: boolean;
}) {
  const id = useId();
  const [state, action, pending] = useActionState(employeeAdjustmentAction.bind(null, scope.tenant, scope.employee), {
    ...initial, head: record?.id ?? '', revision: record?.revision ?? 0, status: record?.status ?? 'draft', adjustment_data: record?.data,
  });
  const savedComponent = components.find(component => component.id === record?.data.component_id);
  const [classification, setClassification] = useState<'earning' | 'deduction'>(savedComponent?.classification ?? 'earning');
  const choices = components.filter(component => component.classification === classification);
  const [component, setComponent] = useState(String(record?.data.component_id ?? choices[0]?.id ?? ''));
  const [dirty, setDirty] = useState(false);
  const unavailableType=Boolean(record&&!savedComponent);
  const frozen = locked || unavailableType || ['approved', 'applied', 'cancelled'].includes(state.status);
  const editable = canManage && !frozen;
  const active = !locked && !unavailableType && !['applied', 'cancelled'].includes(state.status);
  const until = new Date(`${scope.period.ends_on}T00:00:00Z`); until.setUTCDate(until.getUTCDate() + 1);
  return <OfflineForm action={action} className="auth-form" aria-busy={pending} onChange={()=>setDirty(true)}>
    <input type="hidden" name="return" value={scope.returnTo??''}/>
    <input type="hidden" name="tenant" value={scope.tenant}/><input type="hidden" name="employer" value={scope.employer}/>
    <input type="hidden" name="employment" value={scope.employment}/><input type="hidden" name="period" value={scope.period.id}/>
    <input type="hidden" name="kind" value="adjustment"/><input type="hidden" name="from" value={scope.period.starts_on}/>
    <input type="hidden" name="until" value={until.toISOString().slice(0, 10)}/>
    <input type="hidden" name="deduction_category" value={record?String(record.data.deduction_category??''):(classification === 'deduction' ? 'employer_penalty' : '')}/>
    <input type="hidden" name="consent_reference" value={String(record?.data.consent_reference ?? '')}/>
    {!record && <Field id={`${id}-type`} label="ماذا تريد إضافته؟"><Select id={`${id}-type`} value={classification} disabled={!editable || pending} onChange={event => {
      const next = event.target.value as 'earning' | 'deduction'; setClassification(next);
      setComponent(components.find(item => item.classification === next)?.id ?? '');
    }}><option value="earning">مكافأة</option><option value="deduction">جزاء مالي</option></Select></Field>}
    {!record && choices.length > 1 && editable ? <Field id={`${id}-component`} label={classification === 'earning' ? 'نوع المكافأة' : 'نوع الجزاء'} required>
      <Select id={`${id}-component`} name="component_id" value={component} required disabled={pending} onChange={event => setComponent(event.target.value)}>{choices.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}</Select>
    </Field> : <><input type="hidden" name="component_id" value={record?String(record.data.component_id):component}/><p className="record-meta">{savedComponent?.name ?? (record?'النوع المحفوظ غير متاح ضمن الأنواع الحالية.':choices[0]?.name ?? (classification === 'earning' ? 'لا يوجد نوع مكافأة جاهز لهذه الفترة.' : 'لا يوجد نوع جزاء جاهز لهذه الفترة.'))}</p></>}
    {unavailableType&&<Message tone="warn">راجع مسؤول إعداد الرواتب للتحقق من النوع الأصلي قبل الحساب. لم يتم استبداله بنوع آخر.</Message>}
    <Field id={`${id}-amount`} label="المبلغ بالجنيه" required><Input id={`${id}-amount`} name="amount" type="number" min="0.01" step="0.01" max="999999999999.99" required readOnly={!editable||pending} defaultValue={String(record?.data.amount ?? '')} placeholder="مثال: 500"/></Field>
    <Field id={`${id}-reason`} label="السبب" required help="اكتب سببًا واضحًا، مثل: مكافأة إنجاز طلبات الشهر، أو جزاء تأخير وفق قرار الشركة."><Input id={`${id}-reason`} name="reason" minLength={3} maxLength={500} required readOnly={!editable||pending} defaultValue={String(record?.data.reason ?? '')} placeholder="مثال: مكافأة إنجاز العمل"/></Field>
    <Disclosure summary="رقم القرار أو ملاحظته">
      <Field id={`${id}-reference`} label="مرجع القرار" help="يمكنك كتابة رقم القرار إن وجد. المرجع الافتراضي للإضافة الجديدة يوضح أنها تمت من ملف الموظف، ولا يدّعي وجود مستند خارجي."><Input id={`${id}-reference`} name="reference" minLength={3} maxLength={160} readOnly={!editable||pending} defaultValue={String(record?record.data.reference??'':'تسجيل من ملف الموظف')} placeholder="مثال: قرار الشركة رقم 15"/></Field>
    </Disclosure>
    {state.error && <Message tone="bad" role="alert">{state.error}</Message>}
    {state.saved && <Message tone="ok" role="status">{state.status === 'approved' ? 'تم الاعتماد. سيُدرج المبلغ عند حساب مسير هذه الفترة. إذا حُسب المسير سابقًا، أعد حسابه قبل اعتماده.' : state.status === 'cancelled' ? 'تم إلغاء الإضافة. أعد حساب المسير إذا كان محسوبًا قبل الإلغاء.' : 'تم الحفظ بانتظار الاعتماد. لن يدخل المبلغ في المسير قبل اعتماده.'}</Message>}
    {state.head && <Badge>{state.status === 'draft' ? 'بانتظار الاعتماد' : state.status === 'approved' ? unavailableType?'معتمد · راجع النوع قبل الحساب':'معتمد · جاهز للحساب' : state.status === 'applied' ? 'أُدرج في مسير مقفل' : 'ملغى'}</Badge>}
    <div className="workspace-form-actions">
      {editable && <Button type="submit" variant={record?'ghost':'solid'} name="operation" value="save" disabled={!component || pending}>{pending ? 'جارٍ التنفيذ…' : state.head ? 'حفظ التعديل' : 'حفظ للمراجعة'}</Button>}
      {active && state.head && state.status === 'draft' && canApprove && <Button type="submit" name="operation" value="approve" aria-describedby={dirty?`${id}-dirty`:undefined} disabled={pending||dirty}>{pending ? 'جارٍ التنفيذ…' : 'اعتماد وإضافة للمسير'}</Button>}
      {active && state.head && canManage && <Button variant="ghost" type="submit" name="operation" value="cancel" aria-describedby={dirty?`${id}-dirty`:undefined} formNoValidate disabled={pending||dirty}>إلغاء الإضافة</Button>}
    </div>
    {state.head&&dirty&&<p id={`${id}-dirty`} className="record-meta">احفظ التعديل أولًا قبل الاعتماد أو الإلغاء.</p>}
    {!state.head && !component && <Message tone="info">اطلب من مدير إعداد الرواتب تجهيز النوع من «تجهيز نوع مكافأة أو جزاء» أدناه.</Message>}
    {state.status === 'draft' && state.head && !canApprove && <p className="record-meta">الخطوة التالية: يعتمد مسؤول المكافآت والجزاءات الإضافة من ملف الموظف.</p>}
  </OfflineForm>;
}

/** A one-time company setup, in context, with the existing configuration permission. */
export function AdjustmentTypeForm({ scope, kinds, keySuffix }: { scope: Scope; kinds:('earning'|'deduction')[]; keySuffix:string }) {
  const [state, action, pending] = useActionState(employeeAdjustmentAction.bind(null, scope.tenant, scope.employee), initial);
  const id = useId();
  const [classification, setClassification] = useState(kinds[0]);
  return <OfflineForm action={action} className="auth-form" aria-busy={pending}>
    <input type="hidden" name="return" value={scope.returnTo??''}/><input type="hidden" name="viewPeriod" value={scope.period.id}/>
    <input type="hidden" name="tenant" value={scope.tenant}/><input type="hidden" name="employer" value={scope.employer}/><input type="hidden" name="kind" value="component"/>
    <input type="hidden" name="from" value={scope.period.starts_on}/><input type="hidden" name="key" value={`${classification === 'earning' ? 'employee_reward' : 'employee_penalty'}_${keySuffix}`}/>
    <input type="hidden" name="name" value={classification === 'earning' ? 'مكافأة' : 'جزاء مالي'}/>
    {Object.entries({ calculation: 'fixed', base: '', value: '0', visible: 'true', active: 'true', order: '100', behavior: 'period_input', proration: 'paid_full_period', reason: 'تجهيز نوع من ملف الموظف' }).map(([name, value]) => <input type="hidden" key={name} name={name} value={value}/>)}
    <Field id={`${id}-classification`} label="النوع"><Select id={`${id}-classification`} name="classification" value={classification} disabled={pending || state.saved} onChange={event => setClassification(event.target.value as 'earning'|'deduction')}>{kinds.map(kind=><option key={kind} value={kind}>{kind==='earning'?'مكافأة':'جزاء مالي'}</option>)}</Select></Field>
    <Field id={`${id}-taxable`} label="تدخل في الدخل الخاضع للضريبة؟" help="اختر معاملة هذا النوع حسب سياسة الشركة. يُستخدم هذا الاختيار في حساب الراتب."><Select id={`${id}-taxable`} name="taxable" required defaultValue="" disabled={pending || state.saved}><option value="" disabled>اختر معاملة الشركة</option><option value="true">نعم</option><option value="false">لا</option></Select></Field>
    <Field id={`${id}-social`} label="تدخل في الأجر التأميني؟"><Select id={`${id}-social`} name="social" required defaultValue="" disabled={pending || state.saved}><option value="" disabled>اختر معاملة الشركة</option><option value="true">نعم</option><option value="false">لا</option></Select></Field>
    {state.error && <Message tone="bad" role="alert">{state.error}</Message>}
    {state.saved ? <Message tone="ok">تم تجهيز النوع. <a href={`?tab=adjustments&adjustmentPeriod=${scope.period.id}`}>تحديث الأنواع وإضافة المبلغ</a></Message> : <Button type="submit" name="operation" value="save" disabled={pending}>{pending ? 'جارٍ التجهيز…' : 'تجهيز النوع للشركة'}</Button>}
  </OfflineForm>;
}
