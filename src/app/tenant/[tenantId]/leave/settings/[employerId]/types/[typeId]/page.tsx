import { SettingsLink as Link } from '../../../SettingsLink';
import { notFound, redirect } from 'next/navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
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
  const leaveType = configuration?.types.find((entry) => entry.id === typeId) ?? null;
  if (!configuration || !leaveType) {
    return card('هذا النوع لم يعد متاحًا',
      'لم نعثر على نوع الإجازة المطلوب ضمن إعدادات هذه الجهة. عُدّلت الصفحة بأحدث الإعدادات؛ راجع قائمة الأنواع ثم اختر ما تريد.',
      !configResult.error || configResult.error.code !== '42501');
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
    <header className="workspace-page-heading"><div>
      <p className="eyebrow">أنواع الإجازة</p>
      <div className="record-title-row">
        <h1>{leaveType.name}</h1>
        <span className={`entity-status ${leaveType.is_active ? 'is-active' : 'is-inactive'}`}>
          {leaveType.is_active ? 'مفعّل' : 'موقوف'}</span>
      </div>
      <p>{versions.length === 0 ? 'لا توجد إصدارات بعد' : effectiveRangeText(latest?.effective_from ?? '', latest?.effective_until ?? null)}.
        يحتفظ كل تعديل بالإعدادات السابقة وتاريخ سريانها.</p>
      <details><summary>الرمز المرجعي</summary><bdi>{leaveType.code}</bdi></details>
    </div></header>

    <div className={styles.notices}>
      {notice && notice.tone !== 'success' && <p
        className={notice.tone === 'error' ? 'form-message form-error' : 'form-message'}
        role={notice.tone === 'error' ? 'alert' : 'status'}>
        {notice.message}
      </p>}
      {!canEdit && !employer.is_active && <p className="form-message" role="status">
        هذه الجهة موقوفة: يمكنك مراجعة الإعدادات المحفوظة دون حفظ إصدار جديد أو تغيير التفعيل.
      </p>}
      {!canEdit && employer.is_active && !access.canManage && <p className="form-message" role="status">
        عرض فقط: يمكنك مراجعة إعدادات النوع دون تعديلها.
      </p>}
      {!canEdit && employer.is_active && access.canManage && !access.newWorkEnabled && <p className="form-message" role="status">
        خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا يمكن حفظ إصدار جديد أو تغيير التفعيل. تبقى الإعدادات المحفوظة قابلة للمراجعة.
      </p>}
    </div>

    <section className="workspace-records-panel" aria-labelledby="type-versions-title">
      <div className={styles.panelHeading}>
        <div>
          <h2 id="type-versions-title">إصدارات النوع</h2>
          <p>الإعدادات الحالية والسابقة، من الأحدث إلى الأقدم.</p>
        </div>
      </div>
      {versions.length === 0
        ? <div className="empty-state"><h2>لا توجد إصدارات لهذا النوع</h2>
          <p>أعِد فتح صفحة الإعدادات؛ إن استمر عدم وجود إصدار فراجع إدارة الموارد البشرية.</p></div>
        : <ul className="record-list">{versions.map((version) => <li className="record-card" key={version.id}>
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
        </li>)}</ul>}
    </section>

    {canEdit && <SettingsTask label="إصدار جديد من تاريخ لاحق">
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
