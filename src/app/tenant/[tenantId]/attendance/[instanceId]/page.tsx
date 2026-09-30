import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { SubmitButton } from '@/components/submit-button';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { approveAttendanceAbsenceAction, approveAttendanceAction, correctPunchAction, recordPunchAction } from '../actions';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string; instanceId: string }>;
type Punch = { id: string; direction: string; happened_at: string; original_direction: string; original_at: string; corrected: boolean; excluded: boolean };
type Interpretation = { id: string; state: string; first_in: string | null; last_out: string | null; worked_minutes: number | null; gross_worked_minutes: number | null; late_minutes: number | null; early_leave_minutes: number | null; scheduled_break_minutes: number | null; exception_code: string | null };
type Fact = { id: string; interpretation_id: string; version: number; corrects_fact_id: string | null; reason: string | null; fact: Record<string, unknown> };

export default async function AttendanceInstancePage({ params, searchParams }: { params: Params; searchParams: Promise<{ state?: string }> }) {
  const { tenantId, instanceId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId) || !isUuid(instanceId)) notFound();
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <PageFrame><Status title="الاتصال غير متاح" text="تعذر الاتصال بخدمة الحسابات." /></PageFrame>;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/attendance/${instanceId}`)}`);
  const { data, error } = await supabase.rpc('attendance_instance_detail', { p_tenant_id: tenantId, p_instance_id: instanceId });
  if (error || !isObject(data) || !isObject(data.instance) || !isObject(data.permissions)) return <PageFrame><Status title="السجل غير متاح" text="لا تملك صلاحية عرض هذا السجل أو أنه غير موجود." /></PageFrame>;
  const instance = data.instance;
  const permissions = data.permissions;
  const entitlementEnabled = permissions.entitlement_enabled === true;
  const punches = Array.isArray(data.punches) ? data.punches as Punch[] : [];
  const interpretations = isObject(data.interpretation) ? data.interpretation as Interpretation : null;
  const facts = Array.isArray(data.facts) ? data.facts as Fact[] : [];
  const currentFact = facts[0] ?? null;
  const zone = typeof instance.timezone_name === 'string' ? instance.timezone_name : 'Africa/Cairo';
  const employeeName = String(instance.employee_name ?? 'الموظف');
  const state = feedback(query.state);
  const expectedStart = typeof instance.expected_start === 'string' ? instance.expected_start : null;
  const expectedEnd = typeof instance.expected_end === 'string' ? instance.expected_end : null;

  return <PageFrame footer="الحضور وسجل العمل">
    <FeedbackToast key={crypto.randomUUID()} message={state && !state.error ? state.text : null} />
    <section className="work-card task-page attendance-detail" aria-labelledby="attendance-record-title">
      <Link className="back-link" href={`/tenant/${tenantId}/attendance?date=${encodeURIComponent(String(instance.operational_date))}`}>العودة إلى اليوم</Link>
      {state?.error && <p className="form-message form-error" role="alert">{state.text}</p>}
      <p className="eyebrow">سجل يوم العمل · {String(instance.operational_date)}</p>
      <div className="record-title-row"><h1 id="attendance-record-title">{employeeName}</h1><span className={`entity-status ${instance.status === 'approved' ? 'is-active' : 'is-inactive'}`}>{statusLabel(String(instance.status))}</span></div>
      {!entitlementEnabled && <p className="form-message">وحدة الحضور غير مفعلة حاليًا. السجل السابق متاح للقراءة فقط.</p>}
      <p className="record-meta">رقم الموظف: <bdi>{String(instance.employee_code)}</bdi> · {String(instance.policy_name)} · {timezoneLabel(zone)}</p>
      {instance.schedule_kind === 'flexible'
        ? <p className="attendance-expected">يوم عمل مرن · المطلوب {String(instance.required_minutes ?? '—')} دقيقة · نافذة التسجيل {formatOptionalInstant(instance.attribution_start, zone)} – {formatOptionalInstant(instance.attribution_end, zone)}</p>
        : expectedStart && expectedEnd ? <p className="attendance-expected">الوقت المتوقع: {formatInstant(expectedStart, zone)} – {formatInstant(expectedEnd, zone)}</p> : <p className="form-message form-error">وقت العمل المحلي غير واضح بسبب تغيير التوقيت. لا يمكن اعتماد اليوم قبل المراجعة.</p>}
    </section>

    <section className="work-card task-page" aria-labelledby="punches-title">
      <div className="record-title-row"><h2 id="punches-title">تسجيلات الحضور</h2><span className="record-meta">{punches.length} تسجيل</span></div>
      {punches.length === 0 ? <div className="empty-state"><p>لم يُسجّل حضور أو انصراف لهذا اليوم بعد.</p></div> : <ul className="record-list attendance-punch-list">{punches.map((punch) => <li className="record-card" key={punch.id}>
        <div className="record-main"><h3>{directionLabel(punch.direction)} · {formatInstant(punch.happened_at, zone)}</h3>
          {(punch.corrected || punch.excluded) && <p className="record-meta">الدليل الأصلي محفوظ: {directionLabel(punch.original_direction)} · {formatInstant(punch.original_at, zone)}{punch.excluded ? ' · مستبعد بسبب تصحيح مسجل' : ''}</p>}
        </div>
        {permissions.can_correct === true && <details className="task-disclosure"><summary className="secondary-button">تصحيح هذا التسجيل</summary>
          <form action={correctPunchAction} className="attendance-form">
            <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="instanceId" value={instanceId} /><input type="hidden" name="punchId" value={punch.id} />
            <input type="hidden" name="action" value="replace" />
            <label>نوع التسجيل<select name="direction" defaultValue={punch.direction}><option value="in">دخول</option><option value="out">خروج</option></select></label>
            <label>الوقت الصحيح <input name="localTime" type="datetime-local" required defaultValue={toLocalInput(punch.happened_at, zone)} /></label>
            <label className="attendance-full-field">سبب التصحيح <input name="reason" minLength={3} maxLength={500} required /></label>
            <SubmitButton className="primary-button" pendingLabel="جارٍ الحفظ..." label="حفظ التصحيح" />
          </form>
          {!punch.excluded && <form action={correctPunchAction} className="attendance-form attendance-exclude-form">
            <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="instanceId" value={instanceId} /><input type="hidden" name="punchId" value={punch.id} /><input type="hidden" name="action" value="exclude" />
            <label className="attendance-full-field">سبب الاستبعاد <input name="reason" minLength={3} maxLength={500} required /></label>
            <SubmitButton className="secondary-button" pendingLabel="جارٍ الحفظ..." label="استبعاد مع حفظ الدليل" />
          </form>}
        </details>}
      </li>)}</ul>}

      {(permissions.can_manage === true || permissions.can_correct === true) && <details className="task-disclosure attendance-add-punch"><summary className="primary-button">تسجيل دخول أو خروج</summary>
        <form action={recordPunchAction} className="attendance-form">
          <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="instanceId" value={instanceId} /><input type="hidden" name="requestKey" value={crypto.randomUUID()} />
          <label>نوع التسجيل<select name="direction" defaultValue="in"><option value="in">دخول</option><option value="out">خروج</option></select></label>
          <label>الوقت المحلي <input name="localTime" type="datetime-local" required defaultValue={defaultLocalInput(expectedStart, zone)} /></label>
          {(permissions.can_manage !== true || instance.status !== "open") && <label className="attendance-full-field">سبب إضافة التسجيل للمراجعة <input name="reason" minLength={3} maxLength={500} required /></label>}<p className="field-hint attendance-full-field">يُحفظ الوقت كحدث مستقل وفق {timezoneLabel(zone)}. إذا كان التوقيت المحلي ملتبسًا سيطلب النظام وقتًا آخر.</p>
          <SubmitButton className="primary-button" pendingLabel="جارٍ الحفظ..." label="حفظ التسجيل" />
        </form>
      </details>}
    </section>

    <section className="work-card task-page" aria-labelledby="interpretation-title">
      <h2 id="interpretation-title">نتيجة المراجعة</h2>
      {!interpretations ? <p className="field-hint">ستظهر النتيجة بعد تسجيل دخول أو خروج أو إجراء تصحيح.</p> : <>
        <p className={`form-message ${((interpretations.state === 'needs_review' && instance.status !== 'approved') || (currentFact?.fact.outcome === 'absence' && instance.status === 'needs_review') || (interpretations.exception_code === 'short_workday' && instance.status !== 'approved')) ? 'form-error' : ''}`} role="status">{currentFact?.fact.outcome === 'absence' && instance.status === 'approved' ? 'اعتمد المراجع هذا اليوم كيوم غياب مع حفظ السبب.' : currentFact?.fact.outcome === 'absence' && instance.status === 'needs_review' ? 'أضيف تسجيل بعد اعتماد الغياب؛ راجع اليوم واعتمد نتيجة جديدة بسبب.' : currentFact?.fact.interpretation_exception === 'short_workday' && instance.status === 'approved' ? 'صافي المدة أقل من المطلوب، وقد اعتمدها المراجع مع حفظ السبب.' : interpretationLabel(interpretations)}</p>
        {interpretations.state === 'ready' && instance.schedule_kind === 'flexible' && <p className="record-meta">صافي العمل: {interpretations.worked_minutes ?? '—'} من {String(instance.required_minutes ?? '—')} دقيقة مطلوبة</p>}
        {interpretations.state === 'ready' && instance.schedule_kind !== 'flexible' && <div className="attendance-metrics" aria-label="ملخص اليوم">
          <p>الدخول: {interpretations.first_in ? formatInstant(interpretations.first_in, zone) : '—'} · الخروج: {interpretations.last_out ? formatInstant(interpretations.last_out, zone) : '—'}</p>
          <p>التأخر بعد السماح: {interpretations.late_minutes ?? 0} دقيقة · المغادرة المبكرة بعد السماح: {interpretations.early_leave_minutes ?? 0} دقيقة</p>
          <p>المدة بين التسجيلين: {interpretations.gross_worked_minutes ?? '—'} دقيقة · الاستراحة المقررة: {interpretations.scheduled_break_minutes ?? '—'} دقيقة · صافي المدة المحتسبة: {interpretations.worked_minutes ?? '—'} دقيقة</p>
        </div>}
        {interpretations?.exception_code === 'absence_candidate' && instance.status !== 'approved' && currentFact?.fact.outcome !== 'absence' && <div className="attendance-absence-review">
          <p className="form-message form-error">انتهت نافذة الحضور بلا تسجيلات. راجع السجل قبل إثبات الغياب.</p>
          {permissions.can_approve === true && entitlementEnabled && <form action={approveAttendanceAbsenceAction} className="attendance-form attendance-approve-form">
            <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="instanceId" value={instanceId} />
            <label className="attendance-full-field">سبب إثبات الغياب <input name="reason" minLength={3} maxLength={500} required /></label>
            <SubmitButton className="primary-button" pendingLabel="جارٍ الاعتماد..." label="اعتماد يوم غياب" />
          </form>}
        </div>}
      </>}
      {permissions.can_approve === true && interpretations?.state === 'ready' && (!currentFact || currentFact.interpretation_id !== interpretations.id) && <form action={approveAttendanceAction} className="attendance-form attendance-approve-form">
        <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="instanceId" value={instanceId} /><input type="hidden" name="correctsFactId" value={currentFact?.id ?? ''} />
        {(currentFact || interpretations.exception_code === 'short_workday') && <label className="attendance-full-field">{interpretations.exception_code === 'short_workday' ? 'سبب اعتماد مدة أقل من المطلوب' : 'سبب إعادة الاعتماد'} <input name="reason" minLength={3} maxLength={500} required /></label>}
        <SubmitButton className="primary-button" pendingLabel="جارٍ الاعتماد..." label={currentFact ? 'اعتماد التصحيح كنسخة جديدة' : 'اعتماد نتيجة اليوم'} />
      </form>}
      {facts.length > 0 && <div className="attendance-fact-history"><h3>سجل الاعتماد</h3><ol>{facts.map((fact) => <li key={fact.id}><strong>النسخة {fact.version}</strong> · {fact.fact.outcome === 'absence' ? 'اعتماد يوم غياب' : fact.corrects_fact_id ? 'تصحيح لنسخة سابقة' : 'اعتماد'}{fact.reason ? ` · السبب: ${fact.reason}` : ''}</li>)}</ol></div>}
    </section>
  </PageFrame>;
}

function statusLabel(status: string) { return ({ open: 'قيد المتابعة', ready: 'جاهز للاعتماد', needs_review: 'يحتاج مراجعة', approved: 'معتمد' } as Record<string, string>)[status] ?? status; }
function directionLabel(direction: string) { return direction === 'in' ? 'دخول' : 'خروج'; }
function interpretationLabel(value: Interpretation) { if (value.state === 'ready') return value.exception_code === 'short_workday' ? 'صافي المدة أقل من المطلوب. راجع التسجيلات أو اعتمدها بسبب.' : 'تسجيلات الدخول والخروج متوافقة، والنتيجة جاهزة للاعتماد.'; if (value.state === 'needs_review') return value.exception_code === 'absence_candidate' ? 'يوم بلا تسجيلات؛ يحتاج إلى مراجعة واعتماد الغياب بسبب.' : value.exception_code === 'missing_punch' ? 'ينقص تسجيل دخول أو خروج. أضف التسجيل الصحيح أو راجع السجل.' : value.exception_code === 'ambiguous_local_time' ? 'التوقيت المحلي غير واضح. راجع توقيت سياسة الدوام.' : 'تحتاج التسجيلات إلى مراجعة. صحّح التعارض مع حفظ الدليل الأصلي.'; return 'السجل مفتوح لاستقبال تسجيلات الحضور والانصراف.'; }
function feedback(state?: string) { const map: Record<string, { text: string; error?: boolean }> = { 'punch-recorded': { text: 'تم تسجيل الحضور أو الانصراف.' }, 'punch-corrected': { text: 'تم حفظ التصحيح والدليل الأصلي.' }, 'fact-approved': { text: 'تم اعتماد النتيجة وحفظ نسختها.' }, 'absence-approved': { text: 'تم اعتماد يوم الغياب وحفظ السبب.' }, forbidden: { text: 'هذه العملية غير متاحة لصلاحيتك.', error: true }, time: { text: 'الوقت المحلي ملتبس أو غير صالح. اختر وقتًا واضحًا.', error: true }, 'time-future': { text: 'لا يمكن تسجيل وقت لم يقع بعد.', error: true }, 'not-ready': { text: 'لا يمكن اعتماد السجل قبل اكتمال المراجعة.', error: true }, stale: { text: 'تغيرت النتيجة منذ فتح الصفحة. حدّثها قبل الاعتماد.', error: true }, conflict: { text: 'استُخدم مفتاح الإرسال نفسه لبيانات مختلفة. حدّث الصفحة وحاول مجددًا.', error: true }, input: { text: 'تحقق من الحقول المطلوبة.', error: true }, setup: { text: 'الاتصال غير متاح.', error: true }, failed: { text: 'تعذر حفظ التغيير. لم يُعتمد السجل.', error: true } }; return state ? map[state] ?? { text: 'لم تكتمل العملية.', error: true } : null; }
function toLocalInput(value: string, zone: string) { const d = new Date(value); const parts = new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(d); const p = Object.fromEntries(parts.map((x) => [x.type, x.value])); return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`; }
function defaultLocalInput(value: string | null, zone: string) { return value ? toLocalInput(value, zone) : ''; }
function timezoneLabel(zone: string) { if (zone === 'Africa/Cairo') return 'توقيت القاهرة'; try { return new Intl.DateTimeFormat('ar-EG', { timeZone: zone, timeZoneName: 'long' }).formatToParts(new Date()).find((part) => part.type === 'timeZoneName')?.value ?? 'توقيت سياسة الدوام'; } catch { return 'توقيت سياسة الدوام'; } }
function formatInstant(value: string, zone: string) { return new Intl.DateTimeFormat('ar-EG', { dateStyle: 'short', timeStyle: 'short', timeZone: zone }).format(new Date(value)); }
function formatOptionalInstant(value: unknown, zone: string) { return typeof value === 'string' ? formatInstant(value, zone) : 'غير محدد'; }
function isObject(value: unknown): value is Record<string, unknown> { return Boolean(value && typeof value === 'object' && !Array.isArray(value)); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function Status({ title, text }: { title: string; text: string }) { return <section className="work-card task-page"><h1>{title}</h1><p>{text}</p></section>; }
