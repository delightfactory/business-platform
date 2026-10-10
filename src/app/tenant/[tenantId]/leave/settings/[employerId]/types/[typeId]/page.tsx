import { Badge, Disclosure, EmptyState, Message, PageHeader, Panel, RecordCard } from '@/components/ui';
import { SettingsLink as Link } from '../../../SettingsLink';
import { notFound, redirect } from 'next/navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { GATE_TEXT, loadSettingsAccess } from '../../../access-gate';
import { StatusCard } from '../../../StatusCard';
import {
  balanceModeLabel,
  dayCountBasisLabel,
  effectiveRangeText,
  halfDayLabel,
  isUuid,
  noticeForState,
  payEffectLabel,
  readConfiguration,
  versionText,
  type ReviseTypeState,
} from '../../../rules';
import styles from '../../../settings.module.css';
import { ReviseTypeForm } from './ReviseTypeForm';
import { TypeActivationForm } from './TypeActivationForm';
import { SettingsTask } from '../../../SettingsTask';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; employerId: string; typeId: string }>;
type Query = Promise<{ state?: string | string[] }>;

export default async function LeaveTypeDetailPage({ params, searchParams }: {
  params: Params;
  searchParams: Query;
}) {
  const { tenantId, employerId, typeId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId) || !isUuid(employerId) || !isUuid(typeId)) notFound();
  const basePath = `/tenant/${tenantId}/leave/settings/${employerId}`;
  const path = `${basePath}/types/${typeId}`;
  const card = (title: string, detail: string, retry = false) => (
    <StatusCard tenantId={tenantId} title={title} detail={detail}
      retryPath={retry ? path : undefined} backPath={basePath} backLabel="العودة إلى إعدادات الجهة" />
  );

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    const text = GATE_TEXT['no-client'];
    return card(text.title, text.detail, text.retry);
  }
  const { data: { user } } = await getWorkspaceUser(supabase);
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
        : 'لم نتمكن من تحميل الإعدادات والتحقق من نوع الإجازة المطلوب. أعد المحاولة أو عُد إلى إعدادات الجهة.',
      !denied);
  }
  const configuration = readConfiguration(configResult.data);
  if (!configuration) {
    return card('تعذر تحميل إعدادات الجهة',
      'لم تصل إعدادات يمكن الاعتماد عليها. أعد المحاولة أو عُد إلى إعدادات الجهة.', true);
  }
  const leaveType = configuration?.types.find((entry) => entry.id === typeId) ?? null;
  if (!leaveType) {
    return card('هذا النوع لم يعد متاحًا',
      'لم نعثر على نوع الإجازة المطلوب ضمن إعدادات هذه الجهة. عُدّلت الصفحة بأحدث الإعدادات؛ راجع قائمة الأنواع ثم اختر ما تريد.',
      true);
  }

  const state = typeof query.state === 'string' ? query.state : '';
  const notice = noticeForState(state);
  const versions = leaveType.versions;
  const latest = versions[0] ?? null;
  const initialRevise: ReviseTypeState | null = latest ? {
    effectiveFrom: '',
    payEffect: latest.pay_effect,
    balanceMode: latest.balance_mode,
    dayCountBasis: latest.day_count_basis,
    halfDay: latest.half_day_allowed,
    source: '',
    reason: '',
    error: '',
    attempt: 0,
  } : null;
  const targetActive = !leaveType.is_active;
  const initialKey = crypto.randomUUID();

  return <PageFrame footer="الموارد البشرية">
    {notice?.tone === 'success' && <FeedbackToast key={state} message={notice.message} />}
    <Link className="back-link" href={basePath}>العودة إلى إعدادات الجهة</Link>
    <PageHeader title={<>{leaveType.name}</>} eyebrow="أنواع الإجازة" description={<>{versions.length === 0 ? 'لا توجد إصدارات بعد' : effectiveRangeText(latest?.effective_from ?? '', latest?.effective_until ?? null)}. يحتفظ كل تعديل بالإعدادات السابقة وتاريخ سريانها.</>} />
<Badge tone={leaveType.is_active ? 'ok' : 'neutral'}>{leaveType.is_active ? 'مفعّل' : 'موقوف'}</Badge><Disclosure summary="الرمز المرجعي"><bdi>{leaveType.code}</bdi></Disclosure>

    <div className={styles.notices}>
      {notice && notice.tone !== 'success' && <Message
        tone={notice.tone === 'error' ? 'bad' : 'info'}
        role={notice.tone === 'error' ? 'alert' : 'status'}>
        {notice.message}
      </Message>}
      {!canEdit && !employer.is_active && <Message tone="info"  role="status">
        هذه الجهة موقوفة: يمكنك مراجعة الإعدادات المحفوظة دون حفظ إصدار جديد أو تغيير التفعيل.
      </Message>}
      {!canEdit && employer.is_active && !access.canManage && <Message tone="info"  role="status">
        عرض فقط: يمكنك مراجعة إعدادات النوع دون تعديلها.
      </Message>}
      {!canEdit && employer.is_active && access.canManage && !access.newWorkEnabled && <Message tone="info"  role="status">
        خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا يمكن حفظ إصدار جديد أو تغيير التفعيل. تبقى الإعدادات المحفوظة قابلة للمراجعة.
      </Message>}
    </div>

    <Panel  aria-labelledby="type-versions-title">
      <div className={styles.panelHeading}>
        <div>
          <h2 id="type-versions-title">سجل إعدادات نوع الإجازة</h2>
          <p>الإعدادات الحالية والسابقة، من الأحدث إلى الأقدم.</p>
        </div>
      </div>
      {versions.length === 0
        ? <div ><EmptyState title={<>لا توجد إصدارات لهذا النوع</>} description={<>أعِد فتح صفحة الإعدادات؛ إن استمر عدم وجود إصدار فراجع إدارة الموارد البشرية.</>} /></div>
        : <ul className="record-list">{versions.map((version) => <RecordCard  key={version.id}>
          <div className="record-main">
            <div className="record-title-row">
              <h3>{versionText(version.version)} · {effectiveRangeText(version.effective_from, version.effective_until)}</h3>
            </div>
            <p className="record-meta">الأجر: {payEffectLabel(version.pay_effect)}
              {' · '}خصم الرصيد: {balanceModeLabel(version.balance_mode)}</p>
            <p className="record-meta">الأيام: {dayCountBasisLabel(version.day_count_basis)}
              {' · '}نصف يوم: {halfDayLabel(version.half_day_allowed)}</p>
            <p className="record-meta">المصدر: <bdi>{version.source}</bdi></p>
          </div>
        </RecordCard>)}</ul>}
    </Panel>

    {canEdit && <SettingsTask label="تعديل نوع الإجازة من تاريخ لاحق">
      {initialRevise
        ? <ReviseTypeForm tenantId={tenantId} employerId={employerId} typeId={typeId}
          detailPath={path} initial={initialRevise} />
        : <p className="field-hint">لا يمكن بدء إصدار جديد قبل أن يحمل النوع إصدارًا أوليًا محفوظًا.</p>}
    </SettingsTask>}

    {canEdit && <SettingsTask className={targetActive ? 'task-disclosure' : 'task-disclosure danger-disclosure'}
      label={targetActive ? 'تفعيل النوع' : 'إيقاف استخدام النوع'}>
      <TypeActivationForm tenantId={tenantId} employerId={employerId} typeId={typeId}
        targetActive={targetActive} initialKey={initialKey} detailPath={path} />
    </SettingsTask>}
  </PageFrame>;
}
