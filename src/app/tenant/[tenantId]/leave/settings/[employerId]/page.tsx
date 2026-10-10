import { Badge, EmptyState, HelpNote, Message, PageHeader, Panel, RecordCard } from '@/components/ui';
import { notFound, redirect } from 'next/navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { GATE_TEXT, loadSettingsAccess } from '../access-gate';
import { SettingsLink as Link } from '../SettingsLink';
import { StatusCard } from '../StatusCard';
import {
  balanceModeLabel,
  dayCountBasisLabel,
  effectiveRangeText,
  halfDayLabel,
  isUuid,
  noticeForState,
  payEffectLabel,
  periodRangeText,
  readConfiguration,
  restDaysText,
  versionText,
} from '../rules';
import styles from '../settings.module.css';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; employerId: string }>;
type Query = Promise<{ state?: string | string[] }>;

export default async function LeaveSettingsOverviewPage({ params, searchParams }: {
  params: Params;
  searchParams: Query;
}) {
  const { tenantId, employerId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId) || !isUuid(employerId)) notFound();
  const basePath = `/tenant/${tenantId}/leave/settings/${employerId}`;
  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    const text = GATE_TEXT['no-client'];
    return <StatusCard tenantId={tenantId} title={text.title} detail={text.detail} retryPath={basePath}
      backPath={`/tenant/${tenantId}/leave/settings`} backLabel="اختيار جهة أخرى" />;
  }
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(basePath)}`);

  const gate = await loadSettingsAccess(supabase, tenantId, employerId);
  if (gate.kind !== 'ok') {
    const text = GATE_TEXT[gate.kind];
    return <StatusCard tenantId={tenantId} title={text.title} detail={text.detail}
      retryPath={text.retry ? basePath : undefined}
      backPath={`/tenant/${tenantId}/leave/settings`} backLabel="اختيار جهة أخرى" />;
  }
  const { access, employer, canEdit } = gate;

  const configResult = await supabase.rpc('leave_configuration_snapshot', {
    p_tenant: tenantId, p_employer: employerId,
  });
  const configuration = configResult.error ? null : readConfiguration(configResult.data);
  if (!configuration) {
    const forbidden = configResult.error?.code === '42501';
    return <StatusCard tenantId={tenantId}
      title={forbidden ? 'عرض إعدادات هذه الجهة غير متاح' : 'تعذر تحميل إعدادات الإجازات'}
      detail={forbidden
        ? 'لا يملك حسابك صلاحية عرض إعدادات الإجازات لهذه الجهة. راجع إدارة الموارد البشرية.'
        : 'حدث خطأ أثناء تحميل الإعدادات. أعد المحاولة.'}
      retryPath={forbidden ? undefined : basePath}
      backPath={`/tenant/${tenantId}/leave/settings`} backLabel="اختيار جهة أخرى" />;
  }
  const state = typeof query.state === 'string' ? query.state : '';
  const notice = noticeForState(state);
  const calendarName = new Map(configuration.calendars.map((calendar) => [calendar.id, calendar.name]));
  const nextSetup = !configuration.calendars.length
    ? { path: 'calendars/new', label: 'تحديد أيام الراحة والعطلات', detail: 'ابدأ بتقويم الشركة، ثم حدد سنة الرصيد وأنواع الإجازات.' }
    : !configuration.yearPeriods.length
      ? { path: 'year-periods/new', label: 'تحديد سنة رصيد الإجازات', detail: 'التقويم محفوظ. حدد بداية سنة الرصيد ونهايتها.' }
      : !configuration.types.length
        ? { path: 'types/new', label: 'إضافة أول نوع إجازة', detail: 'حدد نوع الإجازة وأثره على الأجر ورصيد الموظف.' }
        : null;

  return <PageFrame footer="الموارد البشرية">
    {notice?.tone === 'success' && <FeedbackToast key={state} message={notice.message} />}
    <Link className="back-link" href={`/tenant/${tenantId}/leave/settings`}>اختيار جهة أخرى</Link>
    <PageHeader title={<>إعدادات الإجازات</>} eyebrow={<>الموارد البشرية</>} description={<>التقويمات وسنوات الإجازة وأنواع الإجازة الخاصة بـ«<bdi>{employer.display_name}</bdi>».
        راجع الإعدادات الحالية أو أضف تغييرًا بتاريخ تطبيق واضح. يبقى سجل الإعدادات السابقة محفوظًا.</>} />

    <div className={styles.notices}>
      {notice && notice.tone !== 'success' && <Message
        tone={notice.tone === 'error' ? 'bad' : 'info'}
        role={notice.tone === 'error' ? 'alert' : 'status'}>
        {notice.message}
      </Message>}
      {!access.canManage && <Message tone="info"  role="status">
        عرض فقط: يمكنك مراجعة إعدادات هذه الجهة دون تعديلها.
      </Message>}
      {access.canManage && !access.newWorkEnabled && <Message tone="info"  role="status">
        خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا يمكن إنشاء إعدادات جديدة أو إصدارات لاحقة.
        تبقى الإعدادات المحفوظة قابلة للمراجعة كما هي.
      </Message>}
      {!employer.is_active && <Message tone="info"  role="status">
        هذه الجهة موقوفة: يمكنك مراجعة إعداداتها السابقة وسجلها دون إنشاء جديد.
      </Message>}
    </div>

    {canEdit && nextSetup && <Panel aria-labelledby="leave-next-setup">
      <h2 id="leave-next-setup">الخطوة التالية</h2>
      <p>{nextSetup.detail}</p>
      <Link className="primary-button" href={`${basePath}/${nextSetup.path}`}>{nextSetup.label}</Link>
    </Panel>}

    <Panel  aria-labelledby="leave-calendars-title">
      <div className={styles.panelHeading}>
        <div>
          <h2 id="leave-calendars-title">تقويمات الإجازات</h2>
          <HelpNote label="عن تقويم الإجازات"><p>حدد أيام الراحة والعطلات وتاريخ العمل بالتقويم. تُحسب إجازات أيام العمل وفقًا لهذا التقويم.</p></HelpNote>
        </div>
        {canEdit && <Link className="secondary-button" href={`${basePath}/calendars/new`}>إضافة تقويم</Link>}
      </div>
      {configuration.calendars.length === 0
        ? <div ><EmptyState title={<>لا توجد تقويمات لهذه الجهة بعد</>} description={<>{canEdit ? 'أنشئ أول تقويم لتحديد أيام الراحة والعطلات قبل تعريف سنوات الإجازة.'
            : 'لم تُنشأ تقويمات لهذه الجهة حتى الآن.'}</>} /></div>
        : <ul className="record-list">{configuration.calendars.map((calendar) => {
          const latest = calendar.versions[0] ?? null;
          return <RecordCard  key={calendar.id}>
            <div className="record-main">
              <div className="record-title-row"><h3>{calendar.name}</h3></div>
              <p className="record-meta">
                {latest ? <>{versionText(latest.version)} · {effectiveRangeText(latest.effective_from, latest.effective_until)}</>
                  : ' · لا توجد إصدارات'}</p>
              {latest && <p className="record-meta">أيام الراحة: {restDaysText(latest.rest_weekdays)}
                {' · '}العطلات: {latest.holidays.length}</p>}
              {latest && <p className="record-meta">المصدر: <bdi>{latest.source}</bdi>
                {' · '}المنطقة الزمنية: <bdi>{latest.timezone}</bdi></p>}
            </div>
            <Link className="secondary-button" href={`${basePath}/calendars/${calendar.id}`}>التفاصيل والإصدارات</Link>
          </RecordCard>;
        })}</ul>}
    </Panel>

    <Panel  aria-labelledby="leave-years-title">
      <div className={styles.panelHeading}>
        <div>
          <h2 id="leave-years-title">سنوات الإجازة</h2>
          <HelpNote label="عن سنة الرصيد"><p>حدد بداية سنة الرصيد ونهايتها والتقويم المستخدم. يمكن أن تبدأ السنة في أي شهر تختاره الشركة.</p></HelpNote>
        </div>
        {canEdit && <Link className="secondary-button" href={`${basePath}/year-periods/new`}>إضافة سنة إجازة</Link>}
      </div>
      {configuration.yearPeriods.length === 0
        ? <div ><EmptyState title={<>لا توجد سنوات إجازة لهذه الجهة بعد</>} description={<>{canEdit ? 'أنشئ تقويمًا ثم أضف فترة سنة الإجازة بتواريخ بدايتها ونهايتها وتصنيفها.'
            : 'لم تُنشأ سنوات إجازة لهذه الجهة حتى الآن.'}</>} /></div>
        : <ul className="record-list">{configuration.yearPeriods.map((period) => <RecordCard  key={period.id}>
          <div className="record-main">
            <div className="record-title-row"><h3>{period.label}</h3></div>
            <p className="record-meta">{periodRangeText(period.starts_on, period.ends_on)}
              {' · '}التقويم: <bdi>{calendarName.get(period.calendar_id) ?? period.calendar_id}</bdi></p>
          </div>
        </RecordCard>)}</ul>}
    </Panel>

    <Panel  aria-labelledby="leave-types-title">
      <div className={styles.panelHeading}>
        <div>
          <h2 id="leave-types-title">أنواع الإجازة</h2>
          <HelpNote label="عن أنواع الإجازات"><p>لكل نوع إعدادات للأجر والرصيد وطريقة حساب الأيام والسماح بنصف يوم. تظهر هذه الاختيارات عند إعداد النوع.</p></HelpNote>
        </div>
        {canEdit && <Link className="secondary-button" href={`${basePath}/types/new`}>إضافة نوع إجازة</Link>}
      </div>
      {configuration.types.length === 0
        ? <div ><EmptyState title={<>لا توجد أنواع إجازة لهذه الجهة بعد</>} description={<>{canEdit ? 'أنشئ أول نوع إجازة وحدد إعداداته الأربعة وتاريخ سريانه.'
            : 'لم تُنشأ أنواع إجازة لهذه الجهة حتى الآن.'}</>} /></div>
        : <ul className="record-list">{configuration.types.map((type) => {
          const latest = type.versions[0] ?? null;
          return <RecordCard  key={type.id}>
            <div className="record-main">
              <div className="record-title-row"><h3>{type.name}</h3>
                <Badge className={`entity-status ${type.is_active ? 'is-active' : 'is-inactive'}`}>
                  {type.is_active ? 'مفعّل' : 'موقوف'}</Badge></div>
              <p className="record-meta">
                {latest ? <>{versionText(latest.version)} · {effectiveRangeText(latest.effective_from, latest.effective_until)}</>
                  : ' · لا توجد إصدارات'}</p>
              {latest && <p className="record-meta">الأجر: {payEffectLabel(latest.pay_effect)}
                {' · '}خصم الرصيد: {balanceModeLabel(latest.balance_mode)}</p>}
              {latest && <p className="record-meta">الأيام: {dayCountBasisLabel(latest.day_count_basis)}
                {' · '}نصف يوم: {halfDayLabel(latest.half_day_allowed)}</p>}
              {latest && <p className="record-meta">المصدر: <bdi>{latest.source}</bdi></p>}
            </div>
            <Link className="secondary-button" href={`${basePath}/types/${type.id}`}>التفاصيل والإصدارات</Link>
          </RecordCard>;
        })}</ul>}
    </Panel>

    <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
  </PageFrame>;
}
