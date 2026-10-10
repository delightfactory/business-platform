import { EmptyState, PageHeader, Panel } from '@/components/ui';
import { SettingsLink as Link } from '../../../SettingsLink';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { GATE_TEXT, editBlockedText, loadSettingsAccess } from '../../../access-gate';
import { StatusCard } from '../../../StatusCard';
import { calendarCoverageText, isUuid, readConfiguration } from '../../../rules';
import { CreateYearPeriodForm } from './CreateYearPeriodForm';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; employerId: string }>;

export default async function NewYearPeriodPage({ params }: { params: Params }) {
  const { tenantId, employerId } = await params;
  if (!isUuid(tenantId) || !isUuid(employerId)) notFound();
  const basePath = `/tenant/${tenantId}/leave/settings/${employerId}`;
  const path = `${basePath}/year-periods/new`;
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
  if (!gate.canEdit) {
    const blocked = editBlockedText(gate, 'إضافة سنة إجازة');
    return card(blocked.title, blocked.detail);
  }

  const configResult = await supabase.rpc('leave_configuration_snapshot', {
    p_tenant: tenantId, p_employer: employerId,
  });
  const configuration = configResult.error ? null : readConfiguration(configResult.data);
  if (!configuration) {
    const forbidden = configResult.error?.code === '42501';
    return card(forbidden ? 'عرض إعدادات هذه الجهة غير متاح' : 'تعذر تحميل إعدادات الإجازات',
      forbidden
        ? 'لا يملك حسابك صلاحية عرض إعدادات الإجازات لهذه الجهة. راجع إدارة الموارد البشرية.'
        : 'حدث خطأ أثناء تحميل الإعدادات. أعد المحاولة.',
      !forbidden);
  }

  const calendars = configuration.calendars
    .filter((calendar) => calendar.versions.length > 0)
    .map((calendar) => ({
      id: calendar.id,
      name: calendar.name,
      coverageText: calendarCoverageText(calendar),
    }));
  const hasAnyCalendar = configuration.calendars.length > 0;

  return <PageFrame footer="الموارد البشرية">
    <div className="workspace-form-page">
      <Link className="back-link" href={basePath}>العودة إلى إعدادات الجهة</Link>
      <PageHeader title={<>إضافة فترة إجازات</>} eyebrow={<>سنوات الإجازة</>} description={<>اختر التقويم وحدد بداية سنة الرصيد ونهايتها واسمًا واضحًا لها. يجب أن يغطي التقويم جميع أيام السنة المحددة.</>} />
      {calendars.length === 0
        ? <div ><EmptyState title={<>{hasAnyCalendar ? 'لا توجد تقويمات مغطاة بإصدارات بعد' : 'لا توجد تقويمات لهذه الجهة بعد'}</>} description={<>فترة الإجازة تحتاج تقويمًا يحمل إصدارًا واحدًا على الأقل يحدد تغطيته. أنشئ التقويم أولًا ثم عد إلى هنا.</>} action={<><Link className="secondary-button" href={`${basePath}/calendars/new`}>إضافة تقويم</Link></>} /></div>
        : <Panel  aria-label="بيانات فترة الإجازات">
          <CreateYearPeriodForm tenantId={tenantId} employerId={employerId} calendars={calendars} />
        </Panel>}
    </div>
  </PageFrame>;
}
