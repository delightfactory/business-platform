'use client';
import { Button, Input, Message, Panel, Select, Field, Disclosure, KeyValueStrip } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { useActionState, useEffect, useRef, useState } from 'react';
import { calendarAction, generateAction } from './actions';
import { type CalendarFields, type CalendarState, type CalendarPreview, displayDate } from './rules';
import styles from './payroll.module.css';
export function CalendarForm({ tenant, employer, start, last, defaults }: { tenant: string; employer: string; start: string; last: string | null; defaults?: {cutoff_day: number|null; payment_day: number; payment_month: string; timezone: string} }) {
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHintId = useId();
 const initial: CalendarState = { start, cutoff: defaults?.cutoff_day?.toString() ?? 'last_day', payment: String(defaults?.payment_day ?? 1), month: defaults?.payment_month ?? 'following', timezone: defaults?.timezone ?? 'Africa/Cairo', reason: '', error: '', preview: null, attemptKey: '', saved: false };
 const [fields, setFields] = useState<CalendarFields>(initial);
 const updateField = (field: keyof CalendarFields, value: string) => setFields(current => ({ ...current, [field]: value }));
 const [state, action, pending] = useActionState(calendarAction, initial);
 const [changedPreview, setChangedPreview] = useState<CalendarPreview | null>(null);
 const feedback = useRef<HTMLParagraphElement>(null);
 useEffect(() => { if (state.error || state.saved) feedback.current?.focus(); }, [state]);
 const preview = state.preview && state.preview !== changedPreview;
 const showOfflineNotice = offline && !pending;
 return <form action={action} className={styles.form} onReset={event => event.preventDefault()} onChange={() => setChangedPreview(state.preview)} onSubmit={(event) => { blockOfflineSubmission(event); }}>
  <input type="hidden" name="tenant" value={tenant} /><input type="hidden" name="employer" value={employer} />
  <h2>{defaults ? 'تغيير الدورة للفترات القادمة' : 'إعداد دورة الرواتب'}</h2>
  {last && <p>آخر فترة محفوظة تنتهي في {displayDate(last)}. تبدأ النسخة الجديدة في اليوم التالي؛ الفترات السابقة محفوظة.</p>}
  <div className={styles.fields}>
   <Field  id="payroll-start" label={<>بداية أول فترة</>}><Input id="payroll-start" name="start" type="date" required value={fields.start} onChange={event => updateField('start', event.currentTarget.value)} disabled={pending} readOnly={Boolean(last)} /></Field>
   <Field  id="payroll-cutoff" label={<>يوم نهاية الفترة</>}><Select id="payroll-cutoff" name="cutoff" value={fields.cutoff} onChange={event => updateField('cutoff', event.currentTarget.value)} disabled={pending}><option value="last_day">آخر يوم من الشهر</option>{Array.from({length:31},(_,i)=><option key={i+1} value={i+1}>{i+1}</option>)}</Select></Field>
   <Field  id="payroll-payment" label={<>يوم الصرف المقرر</>}><Input id="payroll-payment" name="payment" type="number" min="1" max="31" required value={fields.payment} onChange={event => updateField('payment', event.currentTarget.value)} disabled={pending} /></Field>
   <Field  id="payroll-month" label={<>شهر الصرف</>}><Select id="payroll-month" name="month" value={fields.month} onChange={event => updateField('month', event.currentTarget.value)} disabled={pending}><option value="ending">شهر نهاية الفترة</option><option value="following">الشهر التالي</option></Select></Field>
   <Field  id="payroll-timezone" label={<>المنطقة الزمنية</>}><Input id="payroll-timezone" name="timezone" required maxLength={100} value={fields.timezone} onChange={event => updateField('timezone', event.currentTarget.value)} disabled={pending} dir="ltr" /></Field>
   <Field  id="payroll-reason" label={<>سبب الإعداد أو التغيير</>}><Input id="payroll-reason" name="reason" required minLength={3} maxLength={500} value={fields.reason} onChange={event => updateField('reason', event.currentTarget.value)} disabled={pending} /></Field>
  </div>
  <Disclosure summary="كيف تتحدد التواريخ؟"><p>في الشهر الأقصر يُستخدم آخر يوم متاح. الدورة من 25 إلى 24 تستخدم نهاية يوم 24؛ ومن 26 إلى 25 تستخدم نهاية يوم 25. موعد الصرف موعد مقرر فقط ولا ينتقل تلقائيًا بسبب عطلة.</p></Disclosure>
  {preview && <Panel className={styles.preview} aria-label="معاينة الفترة"><h3>{state.preview?.is_transition ? 'الفترة الانتقالية للمراجعة' : 'معاينة أول فترة'}</h3><DateSummary preview={state.preview!} /><p>راجع هذه التواريخ قبل الحفظ. لن تتغير حدود الفترات المحفوظة.</p></Panel>}
  {(state.error || state.saved) && <Message tone={state.error ? "bad" : "ok"} ref={feedback} tabIndex={-1} role={state.error ? 'alert' : 'status'}>{state.error || 'تم حفظ الدورة والفترة الأولى. راجع التواريخ والجاهزية في قائمة الفترات.'}</Message>}
  <div className={styles.actions}><Button variant="solid" type="submit" className={` ${styles.primary}`} name="operation" value={preview ? 'save' : 'preview'} disabled={offline || (pending)} aria-describedby={showOfflineNotice ? offlineHintId : undefined}>{pending ? 'جارٍ التحقق…' : preview ? 'حفظ الدورة والفترة' : 'معاينة التواريخ'}</Button>{state.preview && <Button variant="ghost" type="submit"  name="operation" value="cancel" formNoValidate disabled={offline || (pending)} aria-describedby={showOfflineNotice ? offlineHintId : undefined}>إلغاء المعاينة</Button>}</div>
 {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}</form>;
}
export function DateSummary({preview}: {preview: CalendarPreview}) {
 return <KeyValueStrip items={[{label:"بداية الفترة",value:displayDate(preview.starts_on)},{label:"نهاية الفترة",value:displayDate(preview.ends_on)},{label:"الصرف المقرر",value:displayDate(preview.payment_on)},{label:"المنطقة الزمنية",value:<bdi>{preview.timezone}</bdi>}]}/>;
}
export function GenerateForm({tenant,employer,revision,preview}: {tenant: string; employer: string; revision: number; preview: CalendarPreview}) {
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHintId = useId();
 const [state,action,pending] = useActionState(generateAction,{error:'',saved:false,attemptKey:crypto.randomUUID()});
 const showOfflineNotice = offline && !pending && !state.saved;
 return <form action={action} onSubmit={(event) => { blockOfflineSubmission(event); }}><input type="hidden" name="tenant" value={tenant}/><input type="hidden" name="employer" value={employer}/><input type="hidden" name="revision" value={revision}/><input type="hidden" name="reviewed" value={JSON.stringify(preview)}/><h2>الفترة التالية للمراجعة</h2><DateSummary preview={preview}/>{state.error && <Message tone="bad" role="alert">{state.error}</Message>}{state.saved && <Message tone="info" role="status">تم حفظ الفترة التالية.</Message>}<Button variant="solid" type="submit" className={` ${styles.primary}`} disabled={offline || (pending)} aria-describedby={showOfflineNotice ? offlineHintId : undefined}>{pending?'جارٍ الحفظ…':'توليد الفترة بهذه التواريخ'}</Button>{showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}</form>;
}
