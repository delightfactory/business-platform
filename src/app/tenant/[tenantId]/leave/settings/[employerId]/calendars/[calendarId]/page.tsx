import { SettingsLink as Link } from '../../../SettingsLink';
import { notFound, redirect } from 'next/navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { GATE_TEXT, loadSettingsAccess } from '../../../access-gate';
import { StatusCard } from '../../../StatusCard';
import {
  calendarCoverageText,
  effectiveRangeText,
  isUuid,
  noticeForState,
  readConfiguration,
  restDaysText,
  versionText,
  type ReviseCalendarState,
} from '../../../rules';
import styles from '../../../settings.module.css';
import { ReviseCalendarForm } from './ReviseCalendarForm';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; employerId: string; calendarId: string }>;
type Query = Promise<{ state?: string | string[] }>;

export default async function CalendarDetailPage({ params, searchParams }: {
  params: Params;
  searchParams: Query;
}) {
  const { tenantId, employerId, calendarId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId) || !isUuid(employerId) || !isUuid(calendarId)) notFound();
  const basePath = `/tenant/${tenantId}/leave/settings/${employerId}`;
  const path = `${basePath}/calendars/${calendarId}`;
  const card = (title: string, detail: string, retry = false) => (
    <StatusCard tenantId={tenantId} title={title} detail={detail}
      retryPath={retry ? path : undefined} backPath={basePath} backLabel="العودة إلى إعدادات الجهة" />
  );

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    const text = GATE_TEXT['no-client'];
    return card(text.title, text.detail, text.retry);
  }
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(path)}`);

  const gate = await loadSettingsAccess(supabase, tenantId, employerId);
  if (gate.kind !== 'ok') {
    const text = GATE_TEXT[gate.kind];
    return card(text.title, text.detail, text.retry);
  }
  const { access, employer, canEdit } = gate;

  const configResult = await supabase.rpc('leave_configuration_snapshot', {
    p_tenant: tenantId, p_employer: employerId,
  });
  const configuration = configResult.error ? null : readConfiguration(configResult.data);
  const calendar = configuration?.calendars.find((entry) => entry.id === calendarId) ?? null;
  if (!configuration || !calendar) {
    return card('هذا التقويم لم يعد متاحًا',
      'لم نعثر على التقويم المطلوب ضمن إعدادات هذه الجهة. عُدّلت الصفحة بأحدث الإعدادات؛ راجع قائمة التقويمات ثم اختر ما تريد.',
      !configResult.error || configResult.error.code !== '42501');
  }

  const state = typeof query.state === 'string' ? query.state : '';
  const notice = noticeForState(state);
  const versions = calendar.versions;
  const latest = versions[0] ?? null;
  const initial: ReviseCalendarState | null = latest ? {
    effectiveFrom: '',
    effectiveUntil: latest.effective_until ?? '',
    restDays: latest.rest_weekdays,
    holidays: latest.holidays,
    source: '',
    reason: '',
    error: '',
    attempt: 0,
  } : null;

  return <PageFrame footer="الموارد البشرية">
    {notice?.tone === 'success' && <FeedbackToast key={state} message={notice.message} />}
    <Link className="back-link" href={basePath}>العودة إلى إعدادات الجهة</Link>
    <header className="workspace-page-heading"><div>
      <p className="eyebrow">تقويمات الإجازات</p>
      <h1>{calendar.name}</h1>
      <p>{calendarCoverageText(calendar)}.
        يحتفظ كل تعديل بالإعدادات السابقة وتاريخ سريانها.</p>
      <details><summary>الرمز المرجعي</summary><bdi>{calendar.code}</bdi></details>
    </div></header>

    <div className={styles.notices}>
      {notice && notice.tone !== 'success' && <p
        className={notice.tone === 'error' ? 'form-message form-error' : 'form-message'}
        role={notice.tone === 'error' ? 'alert' : 'status'}>
        {notice.message}
      </p>}
      {!canEdit && !employer.is_active && <p className="form-message" role="status">
        هذه الجهة موقوفة: يمكنك مراجعة الإصدارات المحفوظة دون حفظ إصدار جديد.
      </p>}
      {!canEdit && employer.is_active && !access.canManage && <p className="form-message" role="status">
        عرض فقط: يمكنك مراجعة إصدارات التقويم دون تعديلها.
      </p>}
      {!canEdit && employer.is_active && access.canManage && !access.newWorkEnabled && <p className="form-message" role="status">
        خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا يمكن حفظ إصدار جديد. تبقى الإصدارات المحفوظة قابلة للمراجعة.
      </p>}
    </div>

    <section className="workspace-records-panel" aria-labelledby="calendar-versions-title">
      <div className={styles.panelHeading}>
        <div>
          <h2 id="calendar-versions-title">إصدارات التقويم</h2>
          <p>من الأحدث إلى الأقدم. كل إصدار يحمل تواريخ سريانه وأيام راحته وعطلاته ومنطقته الزمنية ومصدره.</p>
        </div>
      </div>
      {versions.length === 0
        ? <div className="empty-state"><h2>لا توجد إصدارات لهذا التقويم</h2>
          <p>أعِد فتح صفحة الإعدادات؛ إن استمر عدم وجود إصدار فراجع إدارة الموارد البشرية.</p></div>
        : <ul className="record-list">{versions.map((version) => <li className="record-card" key={version.id}>
          <div className="record-main">
            <div className="record-title-row">
              <h3>{versionText(version.version)} · {effectiveRangeText(version.effective_from, version.effective_until)}</h3>
            </div>
            <p className="record-meta">أيام الراحة الأسبوعية: {restDaysText(version.rest_weekdays)}
              {' · '}العطلات: {version.holidays.length}</p>
            <p className="record-meta">المنطقة الزمنية: <bdi>{version.timezone}</bdi>
              {' · '}المصدر: <bdi>{version.source}</bdi></p>
            {version.holidays.length > 0 && <details className={styles.versionHolidays}>
              <summary>عرض عطلات هذا الإصدار ({version.holidays.length})</summary>
              <ul className={styles.versionHolidayList}>
                {version.holidays.map((holiday, index) => <li key={`${holiday.date}-${index}`}>
                  <bdi>{holiday.date}</bdi> · <bdi>{holiday.name}</bdi>
                </li>)}
              </ul>
            </details>}
          </div>
        </li>)}</ul>}
    </section>

    {canEdit && initial && <details className="task-disclosure">
      <summary className="secondary-button">إصدار جديد من تاريخ لاحق</summary>
      <ReviseCalendarForm tenantId={tenantId} employerId={employerId} calendarId={calendarId}
        detailPath={path} initial={initial} />
    </details>}
    {canEdit && !initial && <p className="field-hint">
      لا يمكن بدء إصدار جديد قبل أن يحمل التقويم إصدارًا أوليًا محفوظًا.
    </p>}
  </PageFrame>;
}
