import { PageHeader } from '@/components/ui';
import { Panel, Badge, Button, ButtonLink } from '@/components/ui';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { FeedbackToast } from '@/components/feedback-toast';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser, readWorkspaceRpc } from '@/lib/workspace-access';
import { readToday, TodaySections } from './today';

export const dynamic = 'force-dynamic';

export default async function TenantPage({ params, searchParams }: {
  params: Promise<{ tenantId: string }>;
  searchParams: Promise<{ state?: string }>;
}) {
  const { tenantId } = await params;
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <TenantStatus title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد المحاولة." />;

  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect('/auth/login?state=no-session');

  const { data: accessStatus, error: accessStatusError } = await supabase.rpc('tenant_lifecycle_status', { p_tenant_id: tenantId });
  if (accessStatusError || !accessStatus || typeof accessStatus !== 'object' || Array.isArray(accessStatus)) {
    return <TenantStatus title="المساحة غير متاحة" detail="لا يملك هذا الحساب عضوية نشطة في هذه الشركة، أو أن الشركة غير متاحة." showSwitch />;
  }
  const status = accessStatus as Record<string, unknown>;
  if (status.lifecycle_state === 'suspended') {
    return <TenantStatus title="الشركة معلّقة" detail={`مساحة ${String(status.tenant_name ?? 'الشركة')} معلّقة حاليًا. لا تتاح بيانات العمل حتى استعادة تشغيل الشركة. تواصل مع دعم المنصة إذا كنت تحتاج إلى استعادة الوصول.`} showSwitch />;
  }
  if (status.lifecycle_state === 'archived') {
    return <TenantStatus title="المساحة غير متاحة" detail="هذه الشركة غير متاحة حاليًا." showSwitch />;
  }
  if (status.lifecycle_state !== 'active') {
    return <TenantStatus title="المساحة غير متاحة" detail="تعذر التحقق من حالة الشركة." showSwitch />;
  }

  const { data: adminData, error: adminError } = await supabase.rpc('tenant_admin_snapshot', { p_tenant_id: tenantId });
  if (adminError) {
    const { data: memberData, error: memberError } = await supabase.rpc('tenant_membership_snapshot', { p_tenant_id: tenantId });
    if (memberError || !memberData || typeof memberData !== 'object' || Array.isArray(memberData)) {
      return <TenantStatus title="المساحة غير متاحة" detail="لا يملك هذا الحساب عضوية نشطة في هذه الشركة، أو أن الشركة غير متاحة." showSwitch />;
    }
    const member = memberData as Record<string, unknown>;
    const today = await readToday(supabase, tenantId);
    return (
      <main className="app-shell">
        {query.state === 'admin-demoted' && <FeedbackToast key={crypto.randomUUID()} message="تم خفض دورك إلى عضو. بقيت عضويتك فعالة ويمكنك متابعة استخدام مساحة الشركة." />}
        <Panel  aria-labelledby="tenant-title">
          <p className="eyebrow">{String(member.tenant_name ?? 'الشركة')}</p><PageHeader id="tenant-title" title={<>اليوم</>} />
          <p className="intro">ابدأ مهمتك من هنا، وتابع نتيجتها في صفحتها المختصة.</p>
          <TodaySections model={today} />
          <dl className="snapshot-grid"><div><dt>الحساب</dt><dd><bdi>{String(member.member_email ?? user.email ?? '')}</bdi></dd></div>
            <div><dt>الدور</dt><dd>عضو</dd></div></dl>
        </Panel>
        <footer className="footer">منصة الأعمال · مساحة الشركة</footer>
      </main>
    );
  }
  const data = adminData;
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return <TenantStatus title="المساحة غير متاحة" detail="لا يملك هذا الحساب صلاحية مسؤول لهذه الشركة أو أن الشركة غير متاحة." showSwitch />;
  }

  const snapshot = data as Record<string, unknown>;
  const today = await readToday(supabase, tenantId);
  const { data: brandingData } = await readWorkspaceRpc(supabase, 'tenant_branding_snapshot', tenantId, 'p_tenant_id');
  const branding = brandingData && typeof brandingData === 'object' && !Array.isArray(brandingData)
    ? brandingData as Record<string, unknown> : null;
  const entity = objectValue(snapshot.default_legal_entity);
  const site = objectValue(snapshot.default_site);

  return (
    <main className="app-shell">
      <div className="tenant-home" aria-labelledby="tenant-title">
        <header className="tenant-home-heading">
          <p className="eyebrow"><bdi>{String(branding?.tenant_name ?? snapshot.tenant_name ?? 'الشركة')}</bdi></p>
          <div className="tenant-home-title"><PageHeader id="tenant-title" title={<>اليوم</>} />
            <Badge className="is-active">{lifecycleText(snapshot.lifecycle_state)}</Badge></div>
          <p>ابدأ مهمتك من هنا، وتابع نتيجتها في صفحتها المختصة.</p>
        </header>
        <TodaySections model={today} />
        <section className="tenant-home-summary" aria-labelledby="tenant-summary-title">
          <h2 id="tenant-summary-title">لمحة عن إعداد الشركة</h2>
          <dl className="snapshot-grid">
            <div><dt>المستخدمون</dt><dd>{usageText(snapshot.seat_limit_mode, snapshot.seat_limit, snapshot.seat_usage, 'مستخدمين')}</dd></div>
            <div><dt>الفروع</dt><dd>{usageText(snapshot.site_limit_mode, snapshot.site_limit, snapshot.site_usage, 'فروع')}</dd></div>
            <div><dt>الجهة الأساسية</dt><dd>{String(entity?.name ?? 'غير متاح')}</dd></div>
            <div><dt>الفرع الأساسي</dt><dd>{String(site?.name ?? 'غير متاح')}</dd></div>
          </dl>
        </section>
        <section className="tenant-home-tasks" aria-labelledby="tenant-tasks-title">
          <h2 id="tenant-tasks-title">إدارة الشركة</h2>
          <ul className="tenant-task-list">
            <TenantTaskLink href={`/tenant/${tenantId}/users`} title="المستخدمون والدعوات" detail="ادعُ الفريق وراجع صلاحياته وحالة الدعوات." />
            <TenantTaskLink href={`/tenant/${tenantId}/entities-sites`} title="الجهات والفروع" detail="أضف الفروع أو حدّث بيانات الجهات المرتبطة بالشركة." />
            <TenantTaskLink href={`/tenant/${tenantId}/branding`} title="هوية الشركة" detail="اضبط الاسم الظاهر والشعار واللون المستخدم داخل المساحة." />
          </ul>
        </section>
      </div>
      <footer className="footer">منصة الأعمال · مساحة الشركة</footer>
    </main>
  );
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

function TenantTaskLink({ href, title, detail }: { href: string; title: string; detail: string }) {
  return <li><Link href={href} className="tenant-task-link"><span><strong>{title}</strong><small>{detail}</small></span><span aria-hidden="true">←</span></Link></li>;
}

function lifecycleText(value: unknown) {
  const labels: Record<string, string> = {
    active: 'نشطة',
    suspended: 'معلّقة',
    closing: 'قيد الإغلاق',
    closed: 'مغلقة',
  };
  return typeof value === 'string' ? labels[value] ?? 'غير متاحة' : 'غير متاحة';
}

function usageText(mode: unknown, limit: unknown, usage: unknown, noun: string) {
  const used = String(usage ?? 0);
  if (mode === 'unlimited') return `${used} ${noun} · بلا حد أقصى`;
  if (mode !== 'limited' || limit === null || limit === undefined) return 'الحد غير متاح';
  return `${used} من ${String(limit)} ${noun}`;
}

function TenantStatus({ title, detail, showSwitch = false }: { title: string; detail: string; showSwitch?: boolean }) {
  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/">منصة الأعمال</Link>
        <nav className="topbar-actions" aria-label="إجراءات الحساب">
          <form action={signOutAction}><Button variant="ghost"  type="submit">تسجيل الخروج</Button></form>
        </nav>
      </header>
      <Panel className="auth-card" aria-labelledby="tenant-status-title">
        <p className="eyebrow">مساحة الشركة</p>
        <PageHeader id="tenant-status-title" title={<>{title}</>} />
        <p className="intro">{detail}</p>
        {showSwitch && <ButtonLink variant="ghost"  href="/tenant/select">اختر شركة أخرى</ButtonLink>}
      </Panel>
      <footer className="footer">منصة الأعمال · مساحة الشركة</footer>
    </main>
  );
}
