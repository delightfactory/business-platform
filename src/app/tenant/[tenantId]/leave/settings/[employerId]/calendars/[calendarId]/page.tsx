import { Disclosure, EmptyState, Message, PageHeader, Panel, RecordCard } from '@/components/ui';
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
import { SettingsTask } from '../../../SettingsTask';

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
  if (configResult.error) {
    const denied = configResult.error.code === '42501';
    return card(denied ? 'تعذر عرض إعدادات الجهة' : 'تعذر تحميل إعدادات الجهة',
      denied ? 'لا يمكن عرض هذه الإعدادات بصلاحية الحساب الحالية. عُد إلى إعدادات الجهة للمراجعة.'
        : 'لم نتمكن من تحميل الإعدادات والتحقق من التقويم المطلوب. أعد المحاولة أو عُد إلى إعدادات الجهة.',
      !denied);
  }
  const configuration = readConfiguration(configResult.data);
  if (!configuration) {
    return card('تعذر تحميل إعدادات الجهة',
      'لم تصل إعدادات يمكن الاعتماد عليها. أعد المحاولة أو عُد إلى إعدادات الجهة.', true);
  }
  const calendar = configuration?.calendars.find((entry) => entry.id === calendarId) ?? null;
  if (!calendar) {
    return card('هذا التقويم لم يعد متاحًا',
      'لم نعثر على التقويم المطلوب ضمن إعدادات هذه الجهة. عُدّلت الصفحة بأحدث الإعدادات؛ راجع قائمة التقويمات ثم اختر ما تريد.',
      true);
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
    <PageHeader title={<>{calendar.name}</>} eyebrow="تقويمات الإجازات" description={<>{calendarCoverageText(calendar)}. يحتفظ كل تعديل بالإعدادات السابقة وتاريخ سريانها.</>} />
<Disclosure summary="الرمز المرجعي"><bdi>{calendar.code}</bdi></Disclosure>

    <div className={styles.notices}>
      {notice && notice.tone !== 'success' && <Message
        tone={notice.tone === 'error' ? 'bad' : 'info'}
        role={notice.tone === 'error' ? 'alert' : 'status'}>
        {notice.message}
      </Message>}
      {!canEdit && !employer.is_active && <Message tone="info"  role="status">
        هذه الجهة موقوفة: يمكنك مراجعة الإصدارات المحفوظة دون حفظ إصدار جديد.
      </Message>}
      {!canEdit && employer.is_active && !access.canManage && <Message tone="info"  role="status">
        عرض فقط: يمكنك مراجعة سجل إعدادات التقويم دون تعديلها.
      </Message>}
      {!canEdit && employer.is_active && access.canManage && !access.newWorkEnabled && <Message tone="info"  role="status">
        خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا يمكن حفظ إصدار جديد. تبقى الإصدارات المحفوظة قابلة للمراجعة.
      </Message>}
    </div>

    <Panel  aria-labelledby="calendar-versions-title">
      <div className={styles.panelHeading}>
        <div>
          <h2 id="calendar-versions-title">سجل إعدادات التقويم</h2>
          <p>أحدث الإعدادات أولًا، مع فترة تطبيقها وأيام الراحة والعطلات والتوقيت ومرجعها.</p>
        </div>
      </div>
      {versions.length === 0
        ? <div ><EmptyState title={<>لا توجد إصدارات لهذا التقويم</>} description={<>أعِد فتح صفحة الإعدادات؛ إن استمر عدم وجود إصدار فراجع إدارة الموارد البشرية.</>} /></div>
        : <ul className="record-list">{versions.map((version) => <RecordCard  key={version.id}>
          <div className="record-main">
            <div className="record-title-row">
              <h3>{versionText(version.version)} · {effectiveRangeText(version.effective_from, version.effective_until)}</h3>
            </div>
            <p className="record-meta">أيام الراحة الأسبوعية: {restDaysText(version.rest_weekdays)}
              {' · '}العطلات: {version.holidays.length}</p>
            <p className="record-meta">المنطقة الزمنية: <bdi>{version.timezone}</bdi>
              {' · '}المصدر: <bdi>{version.source}</bdi></p>
            {version.holidays.length > 0 && <Disclosure className={styles.versionHolidays} summary={<>عرض عطلات هذا الإصدار ({version.holidays.length})</>}>
              <ul className={styles.versionHolidayList}>
                {version.holidays.map((holiday, index) => <li key={`${holiday.date}-${index}`}>
                  <bdi>{holiday.date}</bdi> · <bdi>{holiday.name}</bdi>
                </li>)}
              </ul>
            </Disclosure>}
          </div>
        </RecordCard>)}</ul>}
    </Panel>

    {canEdit && initial && <SettingsTask label="تعديل التقويم من تاريخ لاحق">
      <ReviseCalendarForm tenantId={tenantId} employerId={employerId} calendarId={calendarId}
        detailPath={path} initial={initial} />
    </SettingsTask>}
    {canEdit && !initial && <p className="field-hint">
      لا يمكن بدء إصدار جديد قبل أن يحمل التقويم إصدارًا أوليًا محفوظًا.
    </p>}
  </PageFrame>;
}
