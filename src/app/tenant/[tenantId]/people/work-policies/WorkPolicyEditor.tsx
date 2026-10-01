'use client';

import { useActionState, useState, type ChangeEvent } from 'react';
import { SubmitButton } from '@/components/submit-button';
import type { WorkPolicySaveState } from '../work-policy-actions';

type ScheduleKind = 'fixed' | 'flexible';
type PolicySeed = {
  id: string;
  code: string;
  name: string;
  schedule_kind: ScheduleKind;
  timezone_name: string;
  work_days: number[];
  shift_start: string | null;
  shift_end: string | null;
  ends_next_day: boolean;
  break_minutes: number;
  fixed_break_start: string | null;
  fixed_break_end: string | null;
  flexible_halfday_break_minutes: number | null;
  required_minutes: number | null;
  earliest_punch: string | null;
  latest_punch: string | null;
  attribution_before_minutes: number;
  attribution_after_minutes: number;
  overtime_enabled: boolean;
  overtime_minimum_minutes: number;
  overtime_rounding_minutes: number;
  auto_approve_clean: boolean;
};

const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

export function WorkPolicyEditor({
  tenantId,
  action,
  policy,
  returnToRequest,
}: {
  tenantId: string;
  action: (previous: WorkPolicySaveState, formData: FormData) => Promise<WorkPolicySaveState>;
  policy?: PolicySeed;
  returnToRequest?: string;
}) {
  const [saveState, saveAction, pending] = useActionState(action, { error: '' });
  const [values, setValues] = useState({
    code: policy?.code ?? '', name: policy?.name ?? '', timezone: policy?.timezone_name ?? 'Africa/Cairo',
    shiftStart: policy?.shift_start?.slice(0, 5) ?? '', shiftEnd: policy?.shift_end?.slice(0, 5) ?? '',
    requiredMinutes: String(policy?.required_minutes ?? ''), earliestPunch: policy?.earliest_punch?.slice(0, 5) ?? '', latestPunch: policy?.latest_punch?.slice(0, 5) ?? '',
    attributionBefore: String(policy?.attribution_before_minutes ?? 120), attributionAfter: String(policy?.attribution_after_minutes ?? 360),
    nextDay: policy?.ends_next_day ?? false, autoApproveClean: policy?.auto_approve_clean ?? false,
  });
  const [workDays, setWorkDays] = useState(policy?.work_days ?? [1, 2, 3, 4, 5]);
  function handleValueChange(event: ChangeEvent<HTMLInputElement>) {
    const { name, type, checked, value } = event.target;
    setValues((current) => ({ ...current, [name]: type === 'checkbox' ? checked : value }));
  }
  const [kind, setKind] = useState<ScheduleKind>(policy?.schedule_kind ?? 'fixed');
  const [breakMinutes, setBreakMinutes] = useState(policy?.break_minutes ?? 0);
  const [mappingEnabled, setMappingEnabled] = useState(Boolean(policy?.fixed_break_start || policy?.flexible_halfday_break_minutes != null || (policy?.schedule_kind === 'fixed' && policy.break_minutes === 0)));
  const [fixedBreakStart, setFixedBreakStart] = useState(policy?.fixed_break_start?.slice(0, 5) ?? '');
  const [fixedBreakEnd, setFixedBreakEnd] = useState(policy?.fixed_break_end?.slice(0, 5) ?? '');
  const [halfdayBreak, setHalfdayBreak] = useState<string>(policy?.flexible_halfday_break_minutes == null ? '' : String(policy.flexible_halfday_break_minutes));
  const [overtimeEnabled, setOvertimeEnabled] = useState(policy?.overtime_enabled ?? false);
  const [overtimeMinimum, setOvertimeMinimum] = useState(policy?.overtime_minimum_minutes ?? 30);
  const [overtimeRounding, setOvertimeRounding] = useState(policy?.overtime_rounding_minutes ?? 15);
  const idPrefix = policy ? `revision-${policy.id}` : 'new-policy';

  return <form action={saveAction} className="work-policy-editor" aria-busy={pending}>
    <fieldset disabled={pending} style={{ display: 'contents' }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    {returnToRequest && <input type="hidden" name="returnToRequest" value={returnToRequest} />}
    {policy && <><input type="hidden" name="templateId" value={policy.id} /><input type="hidden" name="code" value={policy.code} /></>}

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-identity-heading`}>
      <div className="work-policy-section-heading">
        <h3 id={`${idPrefix}-identity-heading`}>بيانات القالب</h3>
        <p>اسم واضح يساعد فريق الموارد البشرية على اختيار الجدول الصحيح.</p>
      </div>
      <div className="work-policy-grid">
        {!policy && <div className="work-policy-field">
          <label htmlFor={`${idPrefix}-code`}>رمز القالب</label>
          <input id={`${idPrefix}-code`} name="code" value={values.code} onChange={handleValueChange} required maxLength={32} autoComplete="off" />
        </div>}
        <div className="work-policy-field">
          <label htmlFor={`${idPrefix}-name`}>اسم القالب</label>
          <input id={`${idPrefix}-name`} name="name" value={values.name} onChange={handleValueChange} required maxLength={100} />
        </div>
        <div className="work-policy-field">
          <label htmlFor={`${idPrefix}-timezone`}>المنطقة الزمنية</label>
          <input id={`${idPrefix}-timezone`} name="timezone" value={values.timezone} onChange={handleValueChange} required />
          <small>مثال: <bdi>Africa/Cairo</bdi></small>
        </div>
      </div>
    </section>

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-schedule-heading`}>
      <div className="work-policy-section-heading">
        <h3 id={`${idPrefix}-schedule-heading`}>نوع الجدول وأيامه</h3>
        <p>اختر نوعًا واحدًا، ثم حدد الأيام التي يسري فيها القالب.</p>
      </div>
      <fieldset className="work-policy-kind-options">
        <legend>نوع الجدول</legend>
        <label className={kind === 'fixed' ? 'is-selected' : ''}>
          <input type="radio" name="kind" value="fixed" checked={kind === 'fixed'} onChange={() => setKind('fixed')} />
          <span><strong>وردية ثابتة</strong><small>بداية ونهاية محددتان</small></span>
        </label>
        <label className={kind === 'flexible' ? 'is-selected' : ''}>
          <input type="radio" name="kind" value="flexible" checked={kind === 'flexible'} onChange={() => setKind('flexible')} />
          <span><strong>ساعات مرنة</strong><small>مدة عمل مطلوبة خلال اليوم</small></span>
        </label>
      </fieldset>
      <fieldset className="work-policy-days">
        <legend>أيام العمل</legend>
        <div className="work-policy-day-grid">
          {days.map((day, index) => <label key={day}>
            <input type="checkbox" name="workDays" value={index + 1} checked={workDays.includes(index + 1)} onChange={(event) => setWorkDays((current) => event.target.checked ? [...current, index + 1] : current.filter((day) => day !== index + 1))} />
            <span>{day}</span>
          </label>)}
        </div>
      </fieldset>
    </section>

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-hours-heading`}>
      <div className="work-policy-section-heading">
        <h3 id={`${idPrefix}-hours-heading`}>{kind === 'fixed' ? 'مواعيد الوردية' : 'مدة العمل المرنة'}</h3>
        <p>{kind === 'fixed' ? 'حدد وقت البداية والنهاية، مع توضيح الاستراحة.' : 'حدد إجمالي دقائق العمل المطلوبة وأوقات استقبال البصمة عند الحاجة.'}</p>
      </div>
      {kind === 'fixed' ? <div className="work-policy-grid">
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-start`}>بداية الوردية</label><input id={`${idPrefix}-start`} name="shiftStart" type="time" required value={values.shiftStart} onChange={handleValueChange} /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-end`}>نهاية الوردية</label><input id={`${idPrefix}-end`} name="shiftEnd" type="time" required value={values.shiftEnd} onChange={handleValueChange} /></div>
        <label className="work-policy-check-option"><input type="checkbox" name="nextDay" checked={values.nextDay} onChange={handleValueChange} /><span>تنتهي الوردية في اليوم التالي</span></label>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-break`}>مدة الاستراحة بالدقائق</label><input id={`${idPrefix}-break`} name="breakMinutes" type="number" min="0" max="360" value={breakMinutes} onChange={(event) => setBreakMinutes(Number(event.target.value))} /></div>
      </div> : <div className="work-policy-grid">
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-required`}>مدة العمل المطلوبة بالدقائق</label><input id={`${idPrefix}-required`} name="requiredMinutes" type="number" min="60" max="960" required value={values.requiredMinutes} onChange={handleValueChange} /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-earliest`}>أبكر وقت لاستقبال البصمة <span>(اختياري)</span></label><input id={`${idPrefix}-earliest`} name="earliestPunch" type="time" value={values.earliestPunch} onChange={handleValueChange} /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-latest`}>آخر وقت لاستقبال البصمة <span>(اختياري)</span></label><input id={`${idPrefix}-latest`} name="latestPunch" type="time" value={values.latestPunch} onChange={handleValueChange} /></div>
      </div>}
    </section>

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-halfday-heading`}>
      <h3 id={`${idPrefix}-halfday-heading`}>نصف يوم الإجازة</h3>
      <label className="work-policy-check-option"><input type="checkbox" name="leaveMappingEnabled" checked={mappingEnabled} onChange={(event) => setMappingEnabled(event.target.checked)} /><span>إعداد احتساب الحضور مع نصف يوم إجازة</span></label>
      <p className="field-hint">{mappingEnabled ? 'تُحفظ هذه الإعدادات مع إصدار الدوام لتحديد أثر نصف اليوم على الحضور.' : 'عند غياب الإعدادات اللازمة، يحتاج نصف يوم الإجازة إلى مراجعة قبل الاعتماد.'}</p>
      {mappingEnabled && (kind === 'fixed' ? breakMinutes > 0 ? <div className="work-policy-grid">
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-break-start`}>بداية الاستراحة</label><input id={`${idPrefix}-break-start`} name="fixedBreakStart" type="time" required value={fixedBreakStart} onChange={(event) => setFixedBreakStart(event.target.value)} /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-break-end`}>نهاية الاستراحة</label><input id={`${idPrefix}-break-end`} name="fixedBreakEnd" type="time" required value={fixedBreakEnd} onChange={(event) => setFixedBreakEnd(event.target.value)} /></div>
        <p className="field-hint">يجب أن تقع الاستراحة داخل الوردية وأن تساوي مدتها المحددة، بما في ذلك الوردية الليلية.</p>
      </div> : <p className="field-hint">الوردية بلا استراحة؛ لا تحتاج إلى تحديد وقت للاستراحة.</p> : <div className="work-policy-field"><label htmlFor={`${idPrefix}-halfday-break`}>استراحة العمل المتبقي مع نصف يوم إجازة (دقيقة)</label><input id={`${idPrefix}-halfday-break`} name="flexibleHalfdayBreak" type="number" min="0" max="360" required value={halfdayBreak} onChange={(event) => setHalfdayBreak(event.target.value)} /><small>أدخل صفرًا إذا لم توجد استراحة في الجزء المتبقي من اليوم.</small></div>)}
    </section>

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-attribution-heading`}>
      <div className="work-policy-section-heading">
        <h3 id={`${idPrefix}-attribution-heading`}>نافذة إسناد البصمة</h3>
        <p>المدة المحيطة بالجدول التي يمكن خلالها ربط البصمة به.</p>
      </div>
      <div className="work-policy-grid work-policy-grid-narrow">
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-before`}>قبل بداية الجدول (دقيقة)</label><input id={`${idPrefix}-before`} name="attributionBefore" type="number" min="0" max="720" value={values.attributionBefore} onChange={handleValueChange} /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-after`}>بعد نهاية الجدول (دقيقة)</label><input id={`${idPrefix}-after`} name="attributionAfter" type="number" min="0" max="720" value={values.attributionAfter} onChange={handleValueChange} /></div>
      </div>
    </section>

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-overtime-heading`}>
      <div className="work-policy-section-heading">
        <h3 id={`${idPrefix}-overtime-heading`}>العمل الإضافي</h3>
        <p>عند التفعيل، تُراجع الدقائق الزائدة عن نهاية الوردية أو مدة العمل المطلوبة يدويًا. يُقرّب المرشح لأسفل حسب الخطوة المحددة، ولا يُعتمد تلقائيًا.</p>
      </div>
      <label className="work-policy-check-option">
        <input type="checkbox" name="overtimeEnabled" checked={overtimeEnabled} onChange={(event) => setOvertimeEnabled(event.target.checked)} />
        <span>احتساب مرشح للعمل الإضافي وفق هذا القالب</span>
      </label>
      {overtimeEnabled ? <div className="work-policy-grid work-policy-grid-narrow">
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-overtime-minimum`}>أقل مدة زائدة لإنشاء مرشح (دقيقة)</label><input id={`${idPrefix}-overtime-minimum`} name="overtimeMinimum" type="number" min="15" max="480" step="1" value={overtimeMinimum} onChange={(event) => setOvertimeMinimum(Number(event.target.value))} required /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-overtime-rounding`}>خطوة التقريب لأسفل (دقيقة)</label><input id={`${idPrefix}-overtime-rounding`} name="overtimeRounding" type="number" min="5" max="60" step="1" value={overtimeRounding} onChange={(event) => setOvertimeRounding(Number(event.target.value))} required /></div>
      </div> : <><input type="hidden" name="overtimeMinimum" value={overtimeMinimum} /><input type="hidden" name="overtimeRounding" value={overtimeRounding} /></>}
      <p className="field-hint">تُحفظ الإعدادات في إصدار القالب. يصنف المراجع الدقائق الإضافية ويعتمدها يدويًا؛ لا يصنف النظام الليل أو الراحة الأسبوعية أو العطلات تلقائيًا.</p>
    </section>

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-approval-heading`}>
      <div className="work-policy-section-heading">
        <h3 id={`${idPrefix}-approval-heading`}>اعتماد الأيام المكتملة</h3>
        <p>لا يعتمد النظام اليوم إلا بعد انتهاء نافذة التسجيل وثبات جميع الأحداث.</p>
      </div>
      <label className="work-policy-check-option">
        <input type="checkbox" name="autoApproveClean" checked={values.autoApproveClean} onChange={handleValueChange} />
        <span>اعتماد اليوم تلقائيًا إذا كان مكتملًا بلا استثناء</span>
      </label>
      <p className="field-hint">لا يشمل الغياب أو التسجيل الناقص أو المدة الأقل من المطلوبة أو أي تعارض. يسري الإعداد على Work Instances الجديدة فقط.</p>
    </section>

    {saveState.error && <p className="form-message form-error" role="alert">{saveState.error}</p>}
    <div className="work-policy-editor-actions">
      <SubmitButton label={policy ? 'حفظ إصدار جديد' : 'إنشاء قالب الدوام'} pendingLabel={policy ? 'جارٍ حفظ الإصدار…' : 'جارٍ إنشاء القالب…'} />
      {policy && <span>سيبقى الإصدار السابق محفوظًا.</span>}
    </div>
    </fieldset>
  </form>;
}
