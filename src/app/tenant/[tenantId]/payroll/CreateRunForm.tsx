'use client';

import { useId, useState, useSyncExternalStore } from 'react';
import { useRouter } from 'next/navigation';
import { Button, ButtonLink, Disclosure, Field, Input, Message, Select } from '@/components/ui';
import { createRun, previewFirstRun, type CreateRunRequest, type FirstRunFields, type RunCreation } from './create-run-actions';
import { displayDate, uuid, type CalendarPreview } from './rules';
import { useOfflineSubmission, OfflineSubmissionNotice } from '@/components/offline-submission';
import styles from './payroll.module.css';

const event = 'payroll-create-run-changed';
export type SavedRunPeriod = { id: string; starts_on: string; ends_on: string; payment_on: string };
function read(key: string) { try { return localStorage.getItem(key) ?? ''; } catch { return ''; } }
function subscribe(listener: () => void) { window.addEventListener(event, listener); window.addEventListener('storage', listener); return () => { window.removeEventListener(event, listener); window.removeEventListener('storage', listener); }; }

export function CreateRunForm({ actor, tenant, employer, revision, next, today, saved = [], canManage = true }: { actor: string; tenant: string; employer: string; revision: number; next?: CalendarPreview; today: string; saved?: SavedRunPeriod[]; canManage?: boolean }) {
 const router = useRouter(), { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineNotice=useId();
 const key = `payroll-create:v1:${JSON.stringify([actor, tenant, employer])}`;
 const stored = useSyncExternalStore(subscribe, () => read(key), () => '');
 const [fields, setFields] = useState<FirstRunFields>({ start: `${today.slice(0, 7)}-01`, cutoff: 'last_day', payment: '1', month: 'following' });
 const preferred = saved.find(period => period.starts_on <= today && period.ends_on >= today)
  ?? [...saved].filter(period => period.ends_on < today).sort((a, b) => b.ends_on.localeCompare(a.ends_on))[0]
  ?? [...saved].sort((a, b) => a.starts_on.localeCompare(b.starts_on))[0];
 const [selection, setSelection] = useState(preferred?.id ?? (next ? 'next' : 'first'));
 const existing = saved.find(period => period.id === selection);
 const [preview, setPreview] = useState<CalendarPreview | undefined>(next), [busy, setBusy] = useState(false), [error, setError] = useState('');
 const dates = existing ?? preview;
 const back = `/tenant/${tenant}/payroll?${new URLSearchParams({ employer })}`;
 const change = (name: keyof FirstRunFields, value: string) => { setFields(current => ({ ...current, [name]: value })); setPreview(undefined); };
 function persist(request: CreateRunRequest | null) { if (request) localStorage.setItem(key, JSON.stringify(request)); else localStorage.removeItem(key); window.dispatchEvent(new Event(event)); }
 async function complete(request: CreateRunRequest) {
  const result = await createRun(request);
  if (result.period) { persist(null); router.replace(`/tenant/${tenant}/payroll/runs?${new URLSearchParams({ employer, period: result.period, created: '1', view: 'all' })}`); router.refresh(); }
  // Only the receipt-aware rejection proves the original attempt is settled.
  // Permission loss, identity conflict and network failures keep its journal.
  else { if (result.settled) persist(null); setError(result.error ?? 'لم تتأكد النتيجة. استكمل الطلب المحفوظ نفسه.'); }
 }
 async function submit(recover = false) {
  if (blockOfflineSubmission()) return;
  if (!navigator.locks) { setError('استخدم متصفحًا حديثًا لاستكمال الطلب بأمان.'); return; }
  await navigator.locks.request(key, { ifAvailable: true }, async lock => {
   if (!lock) { setError('الطلب مفتوح في صفحة أخرى. انتظر نتيجته.'); return; }
   setBusy(true); setError('');
   try {
    const current = read(key);
    if (recover || current) {
     let request: CreateRunRequest;
     try { request = JSON.parse(current); } catch { setError('تعذر قراءة الطلب المحفوظ. اطلب مساعدة الدعم قبل إنشاء مسير جديد.'); return; }
     if (request.actor !== actor || request.tenant !== tenant || request.employer !== employer || !uuid(request.attempt ?? '')) { setError('الطلب المحفوظ لا يطابق هذه الشركة. اطلب مساعدة الدعم.'); return; }
     await complete(request); return;
    }
    if (!existing && selection !== 'first' && selection !== 'next') { setError('لم تعد الفترة المختارة متاحة. حدّث القائمة واختر الفترة من جديد.'); return; }
    if (!existing && !preview) { const result = await previewFirstRun(tenant, employer, fields); setPreview(result.preview); setError(result.error ?? ''); return; }
    const creation: RunCreation = existing ? { mode: 'existing', period: existing.id } : selection === 'next' && preview ? { mode: 'next', revision, reviewed: preview } : { mode: 'first', revision: preview!.revision ?? revision, reviewed: preview!, start: fields.start, cutoff: fields.cutoff === 'last_day' ? null : Number(fields.cutoff), payment: Number(fields.payment), month: fields.month, timezone: 'Africa/Cairo' };
    const request: CreateRunRequest = { actor, tenant, employer, creation, attempt: crypto.randomUUID(), calendarAttempt: crypto.randomUUID(), runAttempt: crypto.randomUUID() };
    try { persist(request); } catch { setError('تعذر حفظ الطلب على هذا الجهاز؛ لم يُرسل. فعّل تخزين الموقع ثم أعد المحاولة.'); return; }
    await complete(request);
   } catch { setError('لم تصل النتيجة. استكمل الطلب المحفوظ؛ لن ننشئ نسخة ثانية منه.'); }
   finally { setBusy(false); }
  });
 }
 return <section className={styles.createWorkspace} aria-label="إنشاء مسير الرواتب">
  <div className={styles.formHeading}><h2>مسير جديد</h2><ButtonLink variant="ghost" href={back}>العودة إلى المسيرات</ButtonLink></div>
  {stored ? <div className={styles.guidance}><h3>{busy ? 'جارٍ حساب المسير…' : 'يوجد طلب لم تتأكد نتيجته'}</h3>{!busy && <p>استكمل الطلب نفسه. إذا كان قد حُفظ، سنفتح مسيره؛ وإذا لم يصل، سنتممه مرة واحدة.</p>}<Button disabled={busy || offline} onClick={() => void submit(true)}>{busy ? 'جارٍ استكمال الطلب…' : 'استكمال الطلب السابق'}</Button></div> : <form className={styles.form} onSubmit={e => { e.preventDefault(); void submit(); }}>
   {saved.length > 0 && <Field id="new-run-period" label="فترة الرواتب"><Select id="new-run-period" value={selection} disabled={busy} onChange={event => { const value = event.target.value; setSelection(value); setPreview(value === 'next' ? next : undefined); setError(''); }}>{saved.map(period => <option key={period.id} value={period.id}>{displayDate(period.starts_on)} — {displayDate(period.ends_on)}</option>)}{canManage && next && <option value="next">الفترة التالية · {displayDate(next.starts_on)} — {displayDate(next.ends_on)}</option>}</Select></Field>}
   {selection === 'first' && canManage && <div className={styles.fields}><Field id="new-run-start" label="بداية الفترة"><Input id="new-run-start" type="date" value={fields.start} onChange={e => change('start', e.target.value)} required disabled={busy}/></Field><Field id="new-run-cutoff" label="نهاية كل فترة"><Select id="new-run-cutoff" value={fields.cutoff} onChange={e => change('cutoff', e.target.value)} disabled={busy}><option value="last_day">آخر يوم من الشهر</option>{Array.from({ length: 31 }, (_, i) => <option key={i + 1} value={i + 1}>يوم {i + 1} من الشهر</option>)}</Select></Field><Disclosure summary="تغيير موعد الصرف"><div className={styles.fields}><Field id="new-run-payment" label="يوم الصرف"><Input id="new-run-payment" type="number" min="1" max="31" value={fields.payment} onChange={e => change('payment', e.target.value)} disabled={busy} required/></Field><Field id="new-run-month" label="شهر الصرف"><Select id="new-run-month" value={fields.month} onChange={e => change('month', e.target.value)} disabled={busy}><option value="following">الشهر التالي</option><option value="ending">شهر نهاية الفترة</option></Select></Field></div></Disclosure></div>}
   {dates && <dl className={styles.figureStrip}><div><dt>من</dt><dd>{displayDate(dates.starts_on)}</dd></div><div><dt>إلى</dt><dd>{displayDate(dates.ends_on)}</dd></div><div><dt>الصرف المقرر</dt><dd>{displayDate(dates.payment_on)}</dd></div></dl>}
   {selection === 'next' && <p className="field-hint">تبدأ الفترة بعد آخر فترة محفوظة، وفق مواعيد الشركة.</p>}
   <Button type="submit" disabled={busy || offline}>{busy ? 'جارٍ التجهيز…' : existing ? 'حساب المسير' : preview ? 'إنشاء وحساب' : 'مراجعة الفترة'}</Button>
  </form>}
  {error && <Message tone="bad" role="alert">{error}</Message>}{offline && <OfflineSubmissionNotice id={offlineNotice} purpose="recovery"/>}
 </section>;
}
