'use client';
import { useActionState, useEffect, useRef, useState } from 'react';
import { calendarAction, generateAction } from './actions';
import { type CalendarFields, type CalendarState, type CalendarPreview, displayDate } from './rules';
import styles from './payroll.module.css';
export function CalendarForm({ tenant, employer, start, last, defaults }: { tenant: string; employer: string; start: string; last: string | null; defaults?: {cutoff_day: number|null; payment_day: number; payment_month: string; timezone: string} }) {
 const initial: CalendarState = { start, cutoff: defaults?.cutoff_day?.toString() ?? 'last_day', payment: String(defaults?.payment_day ?? 1), month: defaults?.payment_month ?? 'following', timezone: defaults?.timezone ?? 'Africa/Cairo', reason: '', error: '', preview: null, attemptKey: '', saved: false };
 const [fields, setFields] = useState<CalendarFields>(initial);
 const updateField = (field: keyof CalendarFields, value: string) => setFields(current => ({ ...current, [field]: value }));
 const [state, action, pending] = useActionState(calendarAction, initial);
 const [changedPreview, setChangedPreview] = useState<CalendarPreview | null>(null);
 const feedback = useRef<HTMLParagraphElement>(null);
 useEffect(() => { if (state.error || state.saved) feedback.current?.focus(); }, [state]);
 const preview = state.preview && state.preview !== changedPreview;
 return <form action={action} className={styles.form} onReset={event => event.preventDefault()} onChange={() => setChangedPreview(state.preview)}>
  <input type="hidden" name="tenant" value={tenant} /><input type="hidden" name="employer" value={employer} />
  <h2>{defaults ? 'تغيير الدورة للفترات القادمة' : 'إعداد دورة الرواتب'}</h2>
  {last && <p>آخر فترة محفوظة تنتهي في {displayDate(last)}. تبدأ النسخة الجديدة في اليوم التالي؛ الفترات السابقة محفوظة.</p>}
  <div className={styles.fields}>
   <label htmlFor="payroll-start">بداية أول فترة<input id="payroll-start" name="start" type="date" required value={fields.start} onChange={event => updateField('start', event.currentTarget.value)} disabled={pending} readOnly={Boolean(last)} /></label>
   <label htmlFor="payroll-cutoff">يوم نهاية الفترة<select id="payroll-cutoff" name="cutoff" value={fields.cutoff} onChange={event => updateField('cutoff', event.currentTarget.value)} disabled={pending}><option value="last_day">آخر يوم من الشهر</option>{Array.from({length:31},(_,i)=><option key={i+1} value={i+1}>{i+1}</option>)}</select></label>
   <label htmlFor="payroll-payment">يوم الصرف المقرر<input id="payroll-payment" name="payment" type="number" min="1" max="31" required value={fields.payment} onChange={event => updateField('payment', event.currentTarget.value)} disabled={pending} /></label>
   <label htmlFor="payroll-month">شهر الصرف<select id="payroll-month" name="month" value={fields.month} onChange={event => updateField('month', event.currentTarget.value)} disabled={pending}><option value="ending">شهر نهاية الفترة</option><option value="following">الشهر التالي</option></select></label>
   <label htmlFor="payroll-timezone">المنطقة الزمنية<input id="payroll-timezone" name="timezone" required maxLength={100} value={fields.timezone} onChange={event => updateField('timezone', event.currentTarget.value)} disabled={pending} dir="ltr" /></label>
   <label htmlFor="payroll-reason">سبب الإعداد أو التغيير<input id="payroll-reason" name="reason" required minLength={3} maxLength={500} value={fields.reason} onChange={event => updateField('reason', event.currentTarget.value)} disabled={pending} /></label>
  </div>
  <p className="muted">في الشهر الأقصر يُستخدم آخر يوم متاح. الدورة من 25 إلى 24 تستخدم نهاية يوم 24؛ ومن 26 إلى 25 تستخدم نهاية يوم 25. موعد الصرف موعد مقرر فقط ولا ينتقل تلقائيًا بسبب عطلة.</p>
  {preview && <section className={styles.preview} aria-label="معاينة الفترة"><h3>{state.preview?.is_transition ? 'الفترة الانتقالية للمراجعة' : 'معاينة أول فترة'}</h3><DateSummary preview={state.preview!} /><p>راجع هذه التواريخ قبل الحفظ. لن تتغير حدود الفترات المحفوظة.</p></section>}
  {(state.error || state.saved) && <p ref={feedback} tabIndex={-1} role={state.error ? 'alert' : 'status'}>{state.error || 'تم حفظ الدورة والفترة الأولى. راجع التواريخ والجاهزية في قائمة الفترات.'}</p>}
  <div className={styles.actions}><button className={`primary-button ${styles.primary}`} name="operation" value={preview ? 'save' : 'preview'} disabled={pending}>{pending ? 'جارٍ التحقق…' : preview ? 'حفظ الدورة والفترة' : 'معاينة التواريخ'}</button>{state.preview && <button className="secondary-button" name="operation" value="cancel" formNoValidate disabled={pending}>إلغاء المعاينة</button>}</div>
 </form>;
}
export function DateSummary({preview}: {preview: CalendarPreview}) {
 return <dl className={styles.dates}><div><dt>بداية الفترة</dt><dd>{displayDate(preview.starts_on)}</dd></div><div><dt>نهاية الفترة</dt><dd>{displayDate(preview.ends_on)}</dd></div><div><dt>الصرف المقرر</dt><dd>{displayDate(preview.payment_on)}</dd></div><div><dt>المنطقة الزمنية</dt><dd><bdi>{preview.timezone}</bdi></dd></div></dl>;
}
export function GenerateForm({tenant,employer,revision,preview}: {tenant: string; employer: string; revision: number; preview: CalendarPreview}) {
 const [state,action,pending] = useActionState(generateAction,{error:'',saved:false,attemptKey:crypto.randomUUID()});
 return <form action={action}><input type="hidden" name="tenant" value={tenant}/><input type="hidden" name="employer" value={employer}/><input type="hidden" name="revision" value={revision}/><input type="hidden" name="reviewed" value={JSON.stringify(preview)}/><h2>الفترة التالية للمراجعة</h2><DateSummary preview={preview}/>{state.error && <p role="alert">{state.error}</p>}{state.saved && <p role="status">تم حفظ الفترة التالية.</p>}<button className={`primary-button ${styles.primary}`} disabled={pending}>{pending?'جارٍ الحفظ…':'توليد الفترة بهذه التواريخ'}</button></form>;
}
