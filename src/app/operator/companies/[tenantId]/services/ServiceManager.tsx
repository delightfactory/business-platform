'use client';

import { useRef, useState, useSyncExternalStore, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import { Banner, Badge, Button, Disclosure, FactList, IconButton, Input, SegmentedControl, Sheet, Switch, Textarea, Toast } from '@/components/ui';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { operatorServiceLabels } from '@/lib/operator-labels';
import { confirmationChanges, expectedServices, serviceDayLabel, serviceOrder, type ServiceChange, type ServiceDecision, type ServiceKey, type ServicePlanEntry, type ServiceSnapshot } from '@/lib/operator-services';
import { readServicesAction, setServicesAction } from './actions';

const subscribe = () => () => {};
type Dialog = { kind: 'plan'; plan: ServicePlanEntry[] } | { kind: 'duration'; key: ServiceKey; original: ServiceChange[] } | null;
const dependent = (key: ServiceKey) => key !== 'hr.people' && key !== 'hr.attendance';
const denialImpact: Partial<Record<ServiceKey, string>> = {
  'hr.payroll': 'تبقى المسيرات والبيانات المحفوظة؛ لا تُنشأ مسيرات جديدة.',
  'hr.leave': 'تتوقف الطلبات الجديدة؛ يبقى سجل الإجازات محفوظًا.',
  'hr.employee_finance': 'تُمنع سلف جديدة؛ تبقى تسوية الأرصدة القائمة لصاحب الصلاحية.',
};

export function ServiceManager({ initial }: { initial: ServiceSnapshot }) {
  const [snapshot, setSnapshot] = useState(initial);
  const [dialog, setDialog] = useState<Dialog>(null);
  const [pending, setPending] = useState<string | null>(null);
  const [uncertain, setUncertain] = useState(false);
  const [message, setMessage] = useState('');
  const [toast, setToast] = useState('');
  const [note, setNote] = useState('');
  const [mode, setMode] = useState('indefinite');
  const [day, setDay] = useState('');
  const [stopDay, setStopDay] = useState('');
  const inFlight = useRef(false);
  const openingDuration = useRef(false);
  const router = useRouter();
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const ready = useSyncExternalStore(subscribe, () => true, () => false);
  const locked = !ready || offline || uncertain || pending !== null;
  const rows = serviceOrder.map(key => snapshot.entitlements.find(row => row.capability_key === key)!);
  function closeDialog() { if (!inFlight.current) { setDialog(null); setMessage(''); setNote(''); } }

  function acceptSnapshot(next: ServiceSnapshot) {
    setSnapshot(next);
    if (next.lifecycle_state !== initial.lifecycle_state || next.display_name !== initial.display_name) router.refresh();
  }
  function openDuration(key: ServiceKey, original: ServiceChange[] = [], source = snapshot) {
    const row = source.entitlements.find(item => item.capability_key === key)!;
    setMode(row.valid_until_last_day || row.resume_kind === 'expired' || row.resume_kind === 'unknown' ? 'last_day' : 'indefinite');
    setDay(row.is_granted ? row.valid_until_last_day ?? '' : '');
    setStopDay(''); setDialog({ kind: 'duration', key, original });
  }
  async function send(changes: ServiceChange[], submittedNote = note) {
    if (inFlight.current || uncertain || !ready || blockOfflineSubmission()) return;
    inFlight.current = true; setPending(changes.length === 1 ? changes[0].capability_key : 'plan');
    setMessage(''); setToast('');
    try {
      const result = await setServicesAction(snapshot.tenant_id, changes, expectedServices(snapshot), submittedNote);
      if (result.outcome === 'unknown') {
        setUncertain(true); setDialog(null); setMessage('لم تتأكد نتيجة الطلب. أعد قراءة الحالة قبل أي تغيير جديد.'); return;
      }
      if (result.outcome === 'error') { setMessage(result.message); return; }
      acceptSnapshot(result.snapshot);
      if (result.outcome === 'plan_required') {
        setDialog({ kind: 'plan', plan: result.plan }); return;
      }
      if (result.outcome === 'duration_required') {
        openDuration(result.capability_key, changes, result.snapshot); setMessage('اختر مدة واضحة قبل متابعة تفعيل الخدمات.'); return;
      }
      setDialog(null); setNote('');
      if (result.outcome === 'changed') setToast('حُفظت تغييرات خدمات الشركة.');
      else if (result.outcome === 'stale') setMessage('تغيّرت خدمات الشركة منذ فتح الصفحة. راجع الحالة الحالية ثم أعد الاختيار.');
      else setMessage('الحالة الحالية تطابق ما طلبته؛ لم يُسجَّل تغيير جديد.');
    } catch {
      setUncertain(true); setDialog(null); setMessage('لم تتأكد نتيجة الطلب. أعد قراءة الحالة قبل أي تغيير جديد.');
    } finally { inFlight.current = false; setPending(null); }
  }
  async function reread() {
    if (inFlight.current || !ready || blockOfflineSubmission()) return;
    inFlight.current = true; setPending('read');
    try {
      const result = await readServicesAction(snapshot.tenant_id);
      if (!('snapshot' in result)) { setMessage('تعذر قراءة الحالة الحالية. تحقق من الاتصال والصلاحية ثم أعد القراءة.'); return; }
      acceptSnapshot(result.snapshot); setUncertain(false); setDialog(null);
      setMessage('هذه الحالة الحالية للشركة؛ اختر من جديد إن لزم.');
    } catch { setMessage('تعذر قراءة الحالة الحالية. حاول بعد التحقق من الاتصال.'); }
    finally { inFlight.current = false; setPending(null); }
  }
  function durationSubmit(event: FormEvent<HTMLFormElement>, deny = false) {
    event.preventDefault();
    if (dialog?.kind !== 'duration') return;
    const submittedDay = String(new FormData(event.currentTarget).get('lastDay') ?? '');
    if (deny) setStopDay(submittedDay); else if (mode === 'last_day') setDay(submittedDay);
    const selected: ServiceChange = { capability_key: dialog.key, is_granted: !deny,
      duration: deny || mode === 'last_day' ? 'last_day' : 'indefinite',
      ...(deny || mode === 'last_day' ? { last_day: submittedDay } : {}),
    };
    void send([...(deny ? [] : dialog.original.filter(row => row.capability_key !== dialog.key)), selected]);
  }
  const durationRow = dialog?.kind === 'duration' ? rows.find(row => row.capability_key === dialog.key)! : null;
  const additional = dialog?.kind === 'duration' ? dialog.original.filter(row => row.capability_key !== dialog.key) : [];
  const parentDay = snapshot.entitlements.find(row => row.capability_key === 'hr.people')?.valid_until_last_day;
  const prerequisite = dialog?.kind === 'plan' ? dialog.plan.find(row => row.capability_key === 'hr.people') : undefined;
  const requestedDependent = dialog?.kind === 'plan' ? dialog.plan.find(row => dependent(row.capability_key) && row.is_granted) : undefined;
  const planTitle = prerequisite?.is_granted === false ? 'إيقاف الموارد البشرية يوقف خدمات مرتبطة'
    : prerequisite?.derived && requestedDependent ? `تفعيل ${operatorServiceLabels[requestedDependent.capability_key]} يتطلب الموارد البشرية`
    : prerequisite ? 'تعديل مدة الموارد البشرية يحدّث الخدمات المرتبطة' : 'راجع مدة الخدمة';

  return <section className="operator-service-section" aria-labelledby="services-heading">
    <div className="operator-section-heading"><div><h2 id="services-heading">خدمات الشركة</h2>
      <p>{rows.filter(row => row.evaluator_enabled).length} مفعّلة من {rows.length}</p></div>
      <Button variant="ghost" disabled={!ready || offline || pending !== null} onClick={() => void reread()}>إعادة قراءة الحالة</Button></div>
    <noscript><Banner>تحتاج المفاتيح إلى JavaScript. يمكنك قراءة حالة الخدمات هنا.</Banner></noscript>
    {offline && <OfflineSubmissionNotice id="services-offline" purpose={uncertain ? 'recovery' : 'submission'} />}
    {message && !dialog && <Banner tone={uncertain ? 'warn' : 'info'} role="status">{message}</Banner>}
    {pending && <p role="status" className="field-hint">{pending === 'read' ? 'جارٍ قراءة الحالة…' : 'جارٍ الحفظ…'}</p>}
    <div className="operator-service-list">{rows.map(row => {
      const key = row.capability_key;
      const blocked = row.status === 'conflict' || row.status === 'future_conflict';
      const granted = row.status === 'effective' && row.is_granted === true;
      const needsDuration = !granted && (row.resume_kind === 'expired' || row.resume_kind === 'unknown');
      return <article key={key} className="operator-service-row" aria-labelledby={`${key}-title`}>
        <div className="operator-service-info"><div className="operator-service-title"><h3 id={`${key}-title`}>{operatorServiceLabels[key]}</h3>
          <Badge tone={blocked ? 'warn' : granted ? 'ok' : 'neutral'}>{blocked ? 'تحتاج مراجعة فنية' : granted ? 'مفعّلة' : 'غير مفعّلة'}</Badge></div>
          {dependent(key) && <p className="field-hint">تعتمد على الموارد البشرية.</p>}
          <p id={`${key}-description`} className="field-hint">{serviceDescription(row, snapshot)}</p>
          {granted && !row.evaluator_enabled && <p className="field-hint">الخدمة ممنوحة، وتحتاج تفعيل الموارد البشرية لتصبح قابلة للاستخدام.</p>}
          {key === 'hr.employee_finance' && <p className="field-hint">إيقافها لا يمنع تسوية الأرصدة القائمة لصاحب الصلاحية.</p>}
        </div>
        {!blocked && <div className="operator-service-controls">{needsDuration
          ? <Button variant="ghost" disabled={locked} onClick={() => { setNote(''); openDuration(key); }}>{row.resume_kind === 'expired' ? 'تجديد…' : 'اختيار المدة…'}</Button>
          : <Switch label={operatorServiceLabels[key]} checked={granted} pending={pending === key} disabled={locked}
            aria-describedby={`${key}-description`} onCheckedChange={value => { setNote(''); void send([{ capability_key: key, is_granted: value, duration: value ? 'resume' : 'indefinite' }], ''); }} />}
          {!needsDuration && <DropdownMenu.Root dir="rtl"><DropdownMenu.Trigger asChild><IconButton icon="more" disabled={locked} aria-label={`خيارات ${operatorServiceLabels[key]}`} /></DropdownMenu.Trigger>
            <DropdownMenu.Portal><DropdownMenu.Content className="operator-service-menu" align="end" sideOffset={6} onCloseAutoFocus={event => { if (openingDuration.current) { event.preventDefault(); openingDuration.current = false; } }}>
              <DropdownMenu.Item onSelect={() => { openingDuration.current = true; setNote(''); openDuration(key); }}>تعديل المدة</DropdownMenu.Item>
            </DropdownMenu.Content></DropdownMenu.Portal></DropdownMenu.Root>}
        </div>}
      </article>;
    })}</div>
    <Sheet open={dialog?.kind === 'plan'} onOpenChange={open => { if (!open) closeDialog(); }}
      title={planTitle} description="لن يُحفظ أي تغيير قبل تأكيد هذه الخطة.">
      {dialog?.kind === 'plan' && <>
        <FactList items={dialog.plan.map(row => ({ text: `${operatorServiceLabels[row.capability_key]}: ${snapshot.entitlements.find(item => item.capability_key === row.capability_key)?.is_granted ? 'مفعّلة' : 'غير مفعّلة'} ← ${row.is_granted ? 'تفعيل' : 'إيقاف'} · ${row.last_day ? `حتى ${serviceDayLabel(row.last_day)}` : 'بلا تاريخ انتهاء'}` }))} />
        {dialog.plan.filter(row => !row.is_granted && denialImpact[row.capability_key]).map(row => <p className="field-hint" key={row.capability_key}>{operatorServiceLabels[row.capability_key]}: {denialImpact[row.capability_key]}</p>)}
        {message && <Banner role="status">{message}</Banner>}
        <Disclosure summary="إضافة ملاحظة (اختياري)"><label htmlFor="service-plan-note">الملاحظة</label><Textarea id="service-plan-note" value={note} maxLength={500} disabled={locked} onChange={event => setNote(event.target.value)} /></Disclosure>
        <div className="operator-form-actions"><Button disabled={locked} pending={pending === 'plan'} onClick={() => void send(confirmationChanges(dialog.plan))}>تأكيد التغييرات ({dialog.plan.length})</Button>
          <Button variant="ghost" disabled={pending !== null} onClick={closeDialog}>إلغاء</Button></div>
      </>}
    </Sheet>
    <Sheet open={dialog?.kind === 'duration'} onOpenChange={open => { if (!open) closeDialog(); }}
      title={durationRow ? `مدة ${operatorServiceLabels[durationRow.capability_key]}` : 'مدة الخدمة'} description="اختر مدة التفعيل بوضوح. إيقاف الخدمة مؤقتًا متاح ضمن الخيارات المتقدمة.">
      {durationRow && <>
        {message && <Banner role="status">{message}</Banner>}
        {additional.length > 0 && <FactList items={additional.map(row => ({ text: `${row.is_granted ? 'سيتفعّل' : 'سيتوقف'} معها: ${operatorServiceLabels[row.capability_key]}.` }))} />}
        {dependent(durationRow.capability_key) && parentDay && <p className="field-hint">مدة الخدمة لا تتجاوز {serviceDayLabel(parentDay)}، ضمن مدة الموارد البشرية؛ أي تعديل مرتبط سيُعرض للموافقة.</p>}
        <form onSubmit={event => durationSubmit(event)}><fieldset disabled={locked} className="operator-duration-fields">
          <legend className="ui-sr">مدة التفعيل</legend><SegmentedControl label="مدة التفعيل" value={mode} onChange={setMode}
            options={[{ value: 'indefinite', label: 'بلا تاريخ انتهاء' }, { value: 'last_day', label: 'حتى تاريخ' }]} />
          {mode === 'last_day' && <><label htmlFor="service-last-day">آخر يوم سريان بتوقيت القاهرة</label><Input id="service-last-day" name="lastDay" type="date" required max={dependent(durationRow.capability_key) ? parentDay ?? undefined : undefined} value={day} onChange={event => setDay(event.target.value)} /></>}
          <Disclosure summary="إضافة ملاحظة (اختياري)"><label htmlFor="service-duration-note">الملاحظة</label><Textarea id="service-duration-note" value={note} maxLength={500} onChange={event => setNote(event.target.value)} /></Disclosure>
          <div className="operator-form-actions"><Button type="submit" pending={pending !== null}>تأكيد التفعيل{additional.length ? ` (${additional.length + 1})` : ''}</Button><Button variant="ghost" onClick={closeDialog}>إلغاء</Button></div>
        </fieldset></form>
        <Disclosure summary="خيارات متقدمة"><form onSubmit={event => durationSubmit(event, true)}><fieldset disabled={locked} className="operator-duration-fields">
          <legend>إيقاف حتى تاريخ</legend><label htmlFor="service-stop-day">آخر يوم إيقاف بتوقيت القاهرة</label><Input id="service-stop-day" name="lastDay" type="date" required value={stopDay} onChange={event => setStopDay(event.target.value)} />
          <Button type="submit" variant="ghost">إيقاف حتى التاريخ</Button>
        </fieldset></form></Disclosure>
      </>}
    </Sheet>
    {toast && <Toast key={toast} message={toast} />}
  </section>;
}

function serviceDescription(row: ServiceDecision, snapshot: ServiceSnapshot) {
  if (row.status === 'conflict' || row.status === 'future_conflict') return 'لم يتغير شيء. توجد إعدادات تحتاج مراجعة فنية قبل التعديل.';
  if (row.is_granted) return row.valid_until_last_day ? `مفعّلة حتى ${serviceDayLabel(row.valid_until_last_day)}.` : 'مفعّلة بلا تاريخ انتهاء.';
  const denial = row.status === 'effective' && row.valid_until_last_day ? `موقوفة حتى ${serviceDayLabel(row.valid_until_last_day)}؛ لا تُفعّل تلقائيًا بعدها. ` : '';
  if (row.resume_kind === 'unknown') return `${denial}تعذر التأكد من مدة سابقة؛ اختر المدة قبل التفعيل.`;
  if (row.resume_kind === 'expired') return `${denial}انتهت مدة التفعيل السابقة${row.resume_last_day ? ` في ${serviceDayLabel(row.resume_last_day)}` : ''}؛ اختر مدة جديدة للتجديد.`;
  if (row.resume_last_day) return `${denial}عند التفعيل تستمر حتى ${serviceDayLabel(row.resume_last_day)}.`;
  const parent = snapshot.entitlements.find(item => item.capability_key === 'hr.people');
  if (dependent(row.capability_key) && parent?.is_granted && parent.valid_until_last_day) return `${denial}عند التفعيل تستمر حتى ${serviceDayLabel(parent.valid_until_last_day)}، ضمن مدة الموارد البشرية.`;
  return `${denial}عند التفعيل تكون بلا تاريخ انتهاء.`;
}
