import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isDayCountBasis, isObject, isUuid, type RequestDay } from '../form-rules';
import { PendingLink } from '../pending-link';
import { formatDays, formatInstant, stateClass, stateLabel } from '../states';
import { DayBreakdown } from './DayBreakdown';
import { WithdrawRequestForm } from './WithdrawRequestForm';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; requestId: string }>;
type Query = Promise<{ state?: string | string[] }>;

type RequestDetail = {
  id: string;
  leave_type_name: string;
  start_date: string;
  end_date: string;
  total_units: number;
  is_half_day: boolean;
  state: string;
  version: number;
  reason: string;
  submitted_at: string | null;
  request_source: string;
  days: RequestDay[];
};

export default async function MyLeaveRequestPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId, requestId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId) || !isUuid(requestId)) notFound();
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} title="الاتصال غير متاح" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/me/leave/${requestId}`)}`);

  const { data, error } = await supabase.rpc('leave_my_request_detail', { p_tenant: tenantId, p_request: requestId });
  const request = error || !isObject(data) ? null : readRequest(data);
  if (!request) {
    const unavailable = Boolean(error && error.code === 'P0002') || (!error && !isObject(data));
    const forbidden = Boolean(error && error.code === '42501');
    return <Status tenantId={tenantId} retry={!unavailable && !forbidden}
      title={unavailable ? 'الطلب غير متاح' : forbidden ? 'عرض الطلب غير متاح' : 'تعذر تحميل الطلب الآن'}
      detail={unavailable ? 'لم نعثر على هذا الطلب ضمن سجلك، أو أنه لم يعد متاحًا للعرض.'
        : forbidden ? 'ليست لديك صلاحية عرض هذا الطلب. راجع إدارة الموارد البشرية.'
          : 'حدث خطأ أثناء تحميل تفاصيل الطلب. أعد المحاولة.'}
      requestId={requestId} />;
  }

  const feedback = query.state === 'submitted' ? 'تم إرسال طلبك وسينتظر قرار الموارد البشرية.'
    : query.state === 'withdrawn' ? 'تم سحب الطلب وحُفظ السبب في سجل العملية.' : null;

  return <PageFrame footer="الخدمة الذاتية">
    {feedback && <FeedbackToast key={crypto.randomUUID()} message={feedback} />}
    <section className="work-card task-page" aria-labelledby="leave-request-title">
      <PendingLink className="back-link" href={`/tenant/${tenantId}/me/leave`}>العودة إلى إجازاتي</PendingLink>
      <p className="eyebrow">طلب إجازة</p>
      <div className="record-title-row"><h1 id="leave-request-title">{request.leave_type_name}</h1>
        <span className={`entity-status ${stateClass(request.state)}`}>{stateLabel(request.state)}</span></div>
      <p className="record-meta">{request.submitted_at
        ? <>أُرسل في <bdi>{formatInstant(request.submitted_at)}</bdi> · </>
        : 'لم يُرسل بعد · '}الطلب المعلّق لا يحجز رصيدًا قبل الاعتماد.</p>

      <dl className="snapshot-grid">
        <div><dt>الحالة</dt><dd>{stateLabel(request.state)}</dd></div>
        <div><dt>إجمالي أيام الإجازة المحتسبة</dt><dd>{formatDays(request.total_units)} يوم{request.is_half_day ? ' · نصف يوم' : ''}</dd></div>
        <div><dt>تاريخ البداية</dt><dd><bdi>{request.start_date}</bdi></dd></div>
        <div><dt>تاريخ النهاية</dt><dd><bdi>{request.end_date}</bdi></dd></div>
        <div><dt>السبب</dt><dd>{request.reason || 'غير مسجل'}</dd></div>
        <div><dt>طريقة التسجيل</dt><dd>{request.request_source === 'hr' ? 'إدارة الموارد البشرية' : 'خدمة الموظف'}</dd></div>
      </dl>

      {request.state !== 'submitted' && <p className="form-message" role="status">
        هذا الطلب {stateLabel(request.state)}؛ لا يمكن سحبه من هذا الحساب.</p>}

      {request.days.length > 0 && <details className="task-disclosure">
        <summary className="secondary-button">تفاصيل أيام الطلب</summary>
        <DayBreakdown days={request.days} />
      </details>}
    </section>

    {request.state === 'submitted' && <section className="work-card task-page" aria-labelledby="withdraw-title">
      <h2 id="withdraw-title">سحب الطلب</h2>
      <p className="field-hint">يمكنك سحب طلبك ما دام بانتظار قرار الموارد البشرية. بعد السحب تصبح حالته «مسحوبًا» نهائيًا،
        ويُحفظ سببك في سجل العملية مع هويتك ووقتها. لن يُخصم أي رصيد لأن الطلب لم يُعتمد بعد.</p>
      <WithdrawRequestForm tenantId={tenantId} requestId={requestId} expectedVersion={request.version}
        idempotencyKey={crypto.randomUUID()} />
    </section>}
  </PageFrame>;
}

function readRequest(data: Record<string, unknown>): RequestDetail | null {
  if (!isUuid(data.id) || typeof data.leave_type_name !== 'string' || typeof data.start_date !== 'string'
    || typeof data.end_date !== 'string' || typeof data.total_units !== 'number'
    || typeof data.is_half_day !== 'boolean' || typeof data.state !== 'string'
    || typeof data.version !== 'number' || typeof data.request_source !== 'string'
    || !(data.submitted_at === null || typeof data.submitted_at === 'string')
    || !(data.reason === null || typeof data.reason === 'string')
    || !Array.isArray(data.days)) return null;
  const days: RequestDay[] = [];
  for (const day of data.days) {
    if (!isObject(day) || typeof day.date !== 'string' || typeof day.units !== 'number'
      || typeof day.eligible !== 'boolean' || typeof day.is_weekly_rest !== 'boolean'
      || !isDayCountBasis(day.day_count_basis)
      || !(day.holiday_name === null || typeof day.holiday_name === 'string')) return null;
    days.push({
      date: day.date,
      units: day.units,
      eligible: day.eligible,
      is_weekly_rest: day.is_weekly_rest,
      holiday_name: day.holiday_name,
      day_count_basis: day.day_count_basis,
    });
  }
  return {
    id: data.id,
    leave_type_name: data.leave_type_name,
    start_date: data.start_date,
    end_date: data.end_date,
    total_units: data.total_units,
    is_half_day: data.is_half_day,
    state: data.state,
    version: data.version,
    reason: data.reason ?? '',
    submitted_at: data.submitted_at,
    request_source: data.request_source,
    days,
  };
}

function Status({ tenantId, requestId, title, detail, retry = false }: {
  tenantId: string; requestId?: string; title: string; detail: string; retry?: boolean;
}) {
  return <PageFrame footer="الخدمة الذاتية">
    <section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p>
      {retry && <Link className="secondary-button" href={`/tenant/${tenantId}/me/leave/${requestId}`}>إعادة المحاولة</Link>}
      <Link className="secondary-button" href={`/tenant/${tenantId}/me/leave`}>العودة إلى إجازاتي</Link>
      <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
    </section>
  </PageFrame>;
}
