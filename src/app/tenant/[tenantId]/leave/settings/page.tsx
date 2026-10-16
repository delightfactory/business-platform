import { Badge, Button, EmptyState, Field, HelpNote, Input, Message, PageHeader, Panel, RecordCard } from '@/components/ui';
import { LeaveWorkspaceTabs } from '../LeaveWorkspaceTabs';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { GATE_TEXT } from './access-gate';
import { SettingsLink } from './SettingsLink';
import { StatusCard } from './StatusCard';
import { isUuid, readAccess, readEmployerPage } from './rules';
import styles from './settings.module.css';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ choose_employer?: string | string[]; q?: string | string[]; after_name?: string | string[]; after_id?: string | string[] }>;

const PAGE_LIMIT = 50;

export default async function LeaveSettingsPage({ params, searchParams }: {
  params: Params;
  searchParams: Query;
}) {
  const { tenantId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId)) notFound();
  const path = `/tenant/${tenantId}/leave/settings`;
  const text = (value: string | string[] | undefined) => (typeof value === 'string' ? value : '');
  const chooseEmployer = text(query.choose_employer) === '1';
  const chooserPath = `${path}?choose_employer=1`;
  const q = text(query.q).trim();
  const afterName = text(query.after_name);
  const afterId = text(query.after_id);
  const invalidQuery = q.length > 120 || afterName.length > 160 || (afterName === '' && afterId !== '')
    || (afterName !== '' && afterId === '') || (afterId !== '' && !isUuid(afterId));
  const context = new URLSearchParams();
  if (chooseEmployer) context.set('choose_employer', '1');
  if (!invalidQuery) {
    if (q) context.set('q', q);
    if (afterName && afterId) { context.set('after_name', afterName); context.set('after_id', afterId); }
  }
  const currentHref = `${path}${context.size ? `?${context}` : ''}`;
  const resetHref = chooseEmployer ? chooserPath : path;
  const invalidInput = (detail: string) => (
    <StatusCard tenantId={tenantId} title="معاملات بحث غير صالحة" detail={detail} retryPath={resetHref} />
  );

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    const gateText = GATE_TEXT['no-client'];
    return <StatusCard tenantId={tenantId} title={gateText.title} detail={gateText.detail} retryPath={currentHref} />;
  }
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(currentHref)}`);

  const { data, error } = await supabase.rpc('leave_access_snapshot', { p_tenant: tenantId });
  const access = error ? null : readAccess(data);
  if (!access) {
    const gateText = error?.code === '42501' ? GATE_TEXT.forbidden : GATE_TEXT.error;
    return <StatusCard tenantId={tenantId} title={gateText.title} detail={gateText.detail}
      retryPath={gateText.retry ? currentHref : undefined} />;
  }
  if (!access.canView) {
    const gateText = GATE_TEXT['no-view'];
    return <StatusCard tenantId={tenantId} title={gateText.title} detail={gateText.detail} />;
  }

  if (invalidQuery) {
    return invalidInput('راجع رابط الصفحة أو أعد البحث من البداية.');
  }

  const pageResult = await supabase.rpc('leave_configuration_employers', {
    p_tenant: tenantId,
    p_query: q,
    p_after_name: afterName === '' ? null : afterName,
    p_after_id: afterId === '' ? null : afterId,
    p_limit: PAGE_LIMIT,
  });
  if (pageResult.error) {
    if (pageResult.error.code === '42501') {
      const gateText = GATE_TEXT['no-view'];
      return <StatusCard tenantId={tenantId} title={gateText.title} detail={gateText.detail} />;
    }
    if (pageResult.error.code === '22023') {
      return invalidInput('راجع رابط الصفحة أو أعد البحث من البداية.');
    }
    const gateText = GATE_TEXT.error;
    return <StatusCard tenantId={tenantId} title={gateText.title} detail={gateText.detail} retryPath={currentHref} />;
  }
  const employerPage = readEmployerPage(pageResult.data);
  if (!employerPage) {
    const gateText = GATE_TEXT.error;
    return <StatusCard tenantId={tenantId} title={gateText.title} detail={gateText.detail} retryPath={currentHref} />;
  }

  if (!chooseEmployer && q === '' && afterName === '' && afterId === '' && employerPage.uniqueEmployer) {
    redirect(`${path}/${employerPage.uniqueEmployer}`);
  }

  const firstParams = new URLSearchParams({ choose_employer: '1' });
  if (q) firstParams.set('q', q);
  const firstSearch = firstParams.toString();
  const firstHref = firstSearch ? `${path}?${firstSearch}` : path;
  const nextParams = new URLSearchParams({ choose_employer: '1' });
  if (q) nextParams.set('q', q);
  if (employerPage.hasMore && employerPage.nextAfterName && employerPage.nextAfterId) {
    nextParams.set('after_name', employerPage.nextAfterName);
    nextParams.set('after_id', employerPage.nextAfterId);
  }
  const nextHref = `${path}?${nextParams.toString()}`;
  const onLaterPage = afterName !== '' || afterId !== '';

  return <PageFrame footer="الموارد البشرية">
    <PageHeader title="إعدادات الإجازات" description="أنواع الإجازات والعطلات ورصيد السنة لكل جهة عمل." />
    <LeaveWorkspaceTabs tenantId={tenantId} current="settings" />
    <div className={styles.notices}>
      {!access.canManage && <Message tone="info"  role="status">
        عرض فقط: يمكنك مراجعة إعدادات الإجازات دون تعديلها.
      </Message>}
      {!access.newWorkEnabled && <Message tone="info"  role="status">
        خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا يمكن إنشاء إعدادات جديدة أو إصدارات لاحقة.
        تبقى الإعدادات المحفوظة قابلة للمراجعة.
      </Message>}
    </div>

    <Panel  aria-labelledby="leave-employers-title">
      <div className={styles.panelHeading}>
        <div>
          <h2 id="leave-employers-title">الجهات القانونية</h2>
          <HelpNote label="ما الجهات التي تظهر هنا؟"><p>تظهر الجهات النشطة والموقوفة. يمكنك الاطلاع على سجل الجهة الموقوفة؛ لا تتاح إضافة إعدادات جديدة لها.</p></HelpNote>
        </div>
      </div>
      <div className={styles.panelBody}>
        <form className={styles.filterBar} method="get" action={path}>
          <input type="hidden" name="choose_employer" value="1" />
          <Field id="employer-search" label={<>بحث باسم الجهة</>}><Input id="employer-search" type="search" name="q" defaultValue={q} maxLength={120}
            placeholder="اكتب جزءًا من اسم الشركة…" /></Field>
          <div className={styles.rowActions}>
            <Button variant="ghost"  type="submit">بحث</Button>
            {q !== '' && <SettingsLink className="ui-button ui-button-ghost ui-button-md" href={chooserPath}>مسح البحث</SettingsLink>}
          </div>
        </form>

        {employerPage.items.length === 0
          ? <EmptyState title={q ? 'لا توجد نتائج' : 'لا توجد جهات قانونية بعد'} description={q
              ? <>لا توجد جهات تطابق <bdi>{q}</bdi>. جرّب كلمة أخرى أو امسح البحث.</>
              : 'يضيف مسؤول الشركة الجهة القانونية من إعدادات الجهات والفروع.'} />
          : <ul className="record-list">{employerPage.items.map((employer) => <RecordCard  key={employer.id}>
            <div className="record-main">
              <div className="record-title-row">
                <h3>{employer.display_name}</h3>
                <Badge className={`entity-status ${employer.is_active ? 'is-active' : 'is-inactive'}`}>
                  {employer.is_active ? 'نشطة' : 'موقوفة'}</Badge>
              </div>
              {!employer.is_active && <p className="record-meta">متاحة للاطلاع على إعداداتها السابقة دون تعديل جديد.</p>}
            </div>
            <SettingsLink className="ui-button ui-button-ghost ui-button-md"
              href={`/tenant/${tenantId}/leave/settings/${employer.id}`}>{employer.is_active ? 'فتح إعدادات الجهة' : 'عرض السجل'}</SettingsLink>
          </RecordCard>)}</ul>}

        {(employerPage.hasMore || onLaterPage) && <div className={styles.rowActions}>
          {employerPage.hasMore && employerPage.nextAfterName && employerPage.nextAfterId &&
            <SettingsLink className="ui-button ui-button-ghost ui-button-md" href={nextHref}>الصفحة التالية</SettingsLink>}
          {onLaterPage && <SettingsLink className="ui-button ui-button-ghost ui-button-md" href={firstHref}>النتائج من البداية</SettingsLink>}
        </div>}
      </div>
    </Panel>

    <SettingsLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</SettingsLink>
  </PageFrame>;
}
