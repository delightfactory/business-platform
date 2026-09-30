'use client';

import { useState } from 'react';
import { SubmitButton } from '@/components/submit-button';

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
}: {
  tenantId: string;
  action: (formData: FormData) => void | Promise<void>;
  policy?: PolicySeed;
}) {
  const [kind, setKind] = useState<ScheduleKind>(policy?.schedule_kind ?? 'fixed');
  const idPrefix = policy ? `revision-${policy.id}` : 'new-policy';

  return <form action={action} className="work-policy-editor">
    <input type="hidden" name="tenantId" value={tenantId} />
    {policy && <><input type="hidden" name="templateId" value={policy.id} /><input type="hidden" name="code" value={policy.code} /></>}

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-identity-heading`}>
      <div className="work-policy-section-heading">
        <h3 id={`${idPrefix}-identity-heading`}>بيانات القالب</h3>
        <p>اسم واضح يساعد فريق الموارد البشرية على اختيار الجدول الصحيح.</p>
      </div>
      <div className="work-policy-grid">
        {!policy && <div className="work-policy-field">
          <label htmlFor={`${idPrefix}-code`}>رمز القالب</label>
          <input id={`${idPrefix}-code`} name="code" required maxLength={32} autoComplete="off" />
        </div>}
        <div className="work-policy-field">
          <label htmlFor={`${idPrefix}-name`}>اسم القالب</label>
          <input id={`${idPrefix}-name`} name="name" defaultValue={policy?.name} required maxLength={100} />
        </div>
        <div className="work-policy-field">
          <label htmlFor={`${idPrefix}-timezone`}>المنطقة الزمنية</label>
          <input id={`${idPrefix}-timezone`} name="timezone" defaultValue={policy?.timezone_name ?? 'Africa/Cairo'} required />
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
            <input type="checkbox" name="workDays" value={index + 1} defaultChecked={policy ? policy.work_days.includes(index + 1) : index < 5} />
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
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-start`}>بداية الوردية</label><input id={`${idPrefix}-start`} name="shiftStart" type="time" required defaultValue={policy?.shift_start ?? ''} /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-end`}>نهاية الوردية</label><input id={`${idPrefix}-end`} name="shiftEnd" type="time" required defaultValue={policy?.shift_end ?? ''} /></div>
        <label className="work-policy-check-option"><input type="checkbox" name="nextDay" defaultChecked={policy?.ends_next_day ?? false} /><span>تنتهي الوردية في اليوم التالي</span></label>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-break`}>مدة الاستراحة بالدقائق</label><input id={`${idPrefix}-break`} name="breakMinutes" type="number" min="0" max="360" defaultValue={policy?.break_minutes ?? 0} /></div>
      </div> : <div className="work-policy-grid">
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-required`}>مدة العمل المطلوبة بالدقائق</label><input id={`${idPrefix}-required`} name="requiredMinutes" type="number" min="60" max="960" required defaultValue={policy?.required_minutes ?? ''} /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-earliest`}>أبكر وقت لاستقبال البصمة <span>(اختياري)</span></label><input id={`${idPrefix}-earliest`} name="earliestPunch" type="time" defaultValue={policy?.earliest_punch ?? ''} /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-latest`}>آخر وقت لاستقبال البصمة <span>(اختياري)</span></label><input id={`${idPrefix}-latest`} name="latestPunch" type="time" defaultValue={policy?.latest_punch ?? ''} /></div>
      </div>}
    </section>

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-attribution-heading`}>
      <div className="work-policy-section-heading">
        <h3 id={`${idPrefix}-attribution-heading`}>نافذة إسناد البصمة</h3>
        <p>المدة المحيطة بالجدول التي يمكن خلالها ربط البصمة به.</p>
      </div>
      <div className="work-policy-grid work-policy-grid-narrow">
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-before`}>قبل بداية الجدول (دقيقة)</label><input id={`${idPrefix}-before`} name="attributionBefore" type="number" min="0" max="720" defaultValue={policy?.attribution_before_minutes ?? 120} /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-after`}>بعد نهاية الجدول (دقيقة)</label><input id={`${idPrefix}-after`} name="attributionAfter" type="number" min="0" max="720" defaultValue={policy?.attribution_after_minutes ?? 360} /></div>
      </div>
    </section>

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-overtime-heading`}>
      <div className="work-policy-section-heading">
        <h3 id={`${idPrefix}-overtime-heading`}>العمل الإضافي</h3>
        <p>عند التفعيل، تُراجع الدقائق الزائدة عن نهاية الوردية أو مدة العمل المطلوبة يدويًا. يُقرّب المرشح لأسفل حسب الخطوة المحددة، ولا يُعتمد تلقائيًا.</p>
      </div>
      <label className="work-policy-check-option">
        <input type="checkbox" name="overtimeEnabled" defaultChecked={policy?.overtime_enabled ?? false} />
        <span>احتساب مرشح للعمل الإضافي وفق هذا القالب</span>
      </label>
      <div className="work-policy-grid work-policy-grid-narrow">
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-overtime-minimum`}>أقل مدة زائدة لإنشاء مرشح (دقيقة)</label><input id={`${idPrefix}-overtime-minimum`} name="overtimeMinimum" type="number" min="15" max="480" step="1" defaultValue={policy?.overtime_minimum_minutes ?? 30} required /></div>
        <div className="work-policy-field"><label htmlFor={`${idPrefix}-overtime-rounding`}>خطوة التقريب لأسفل (دقيقة)</label><input id={`${idPrefix}-overtime-rounding`} name="overtimeRounding" type="number" min="5" max="60" step="1" defaultValue={policy?.overtime_rounding_minutes ?? 15} required /></div>
      </div>
      <p className="field-hint">تُحفظ الإعدادات في إصدار القالب. يصنف المراجع الدقائق الإضافية ويعتمدها يدويًا؛ لا يصنف النظام الليل أو الراحة الأسبوعية أو العطلات تلقائيًا.</p>
    </section>

    <section className="work-policy-section" aria-labelledby={`${idPrefix}-approval-heading`}>
      <div className="work-policy-section-heading">
        <h3 id={`${idPrefix}-approval-heading`}>اعتماد الأيام المكتملة</h3>
        <p>لا يعتمد النظام اليوم إلا بعد انتهاء نافذة التسجيل وثبات جميع الأحداث.</p>
      </div>
      <label className="work-policy-check-option">
        <input type="checkbox" name="autoApproveClean" defaultChecked={policy?.auto_approve_clean ?? false} />
        <span>اعتماد اليوم تلقائيًا إذا كان مكتملًا بلا استثناء</span>
      </label>
      <p className="field-hint">لا يشمل الغياب أو التسجيل الناقص أو المدة الأقل من المطلوبة أو أي تعارض. يسري الإعداد على Work Instances الجديدة فقط.</p>
    </section>

    <div className="work-policy-editor-actions">
      <SubmitButton label={policy ? 'حفظ إصدار جديد' : 'إنشاء قالب الدوام'} pendingLabel={policy ? 'جارٍ حفظ الإصدار…' : 'جارٍ إنشاء القالب…'} />
      {policy && <span>سيبقى الإصدار السابق محفوظًا.</span>}
    </div>
  </form>;
}
