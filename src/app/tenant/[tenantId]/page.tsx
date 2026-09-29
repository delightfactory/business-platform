import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { TenantNavigation } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function TenantPage({ params, searchParams }: {
  params: Promise<{ tenantId: string }>;
  searchParams: Promise<{ state?: string }>;
}) {
  const { tenantId } = await params;
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <TenantStatus title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد المحاولة." />;

  const { data: { user } } = await supabase.auth.getUser();
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
    return (
      <main className="app-shell">
        {query.state === 'admin-demoted' && <FeedbackToast key={crypto.randomUUID()} message="تم خفض دورك إلى عضو. بقيت عضويتك فعالة ويمكنك متابعة استخدام مساحة الشركة." />}
        <TenantNavigation tenantId={tenantId} tenantName={String(member.tenant_name ?? 'الشركة')} current="home" />
        <section className="work-card" aria-labelledby="tenant-title">
          <p className="eyebrow">مساحة الشركة</p><h1 id="tenant-title">{String(member.tenant_name ?? 'الشركة')}</h1>
          <p className="intro">أنت عضو في هذه الشركة.</p>
          <dl className="snapshot-grid"><div><dt>الحساب</dt><dd><bdi>{String(member.member_email ?? user.email ?? '')}</bdi></dd></div>
            <div><dt>الدور</dt><dd>عضو</dd></div></dl>
        </section>
        <footer className="footer">منصة الأعمال · مساحة الشركة</footer>
      </main>
    );
  }
  const data = adminData;
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return <TenantStatus title="المساحة غير متاحة" detail="لا يملك هذا الحساب صلاحية مسؤول لهذه الشركة أو أن الشركة غير متاحة." showSwitch />;
  }

  const snapshot = data as Record<string, unknown>;
  const { data: brandingData } = await supabase.rpc('tenant_branding_snapshot', { p_tenant_id: tenantId });
  const branding = brandingData && typeof brandingData === 'object' && !Array.isArray(brandingData)
    ? brandingData as Record<string, unknown> : null;
  const entity = objectValue(snapshot.default_legal_entity);
  const site = objectValue(snapshot.default_site);

  return (
    <main className="app-shell">
      <TenantNavigation tenantId={tenantId} tenantName={String(branding?.tenant_name ?? snapshot.tenant_name ?? 'الشركة')} current="home" />
      <div className="tenant-home" aria-labelledby="tenant-title">
        <header className="tenant-home-heading">
          <p className="eyebrow">مساحة الشركة</p>
          <div className="tenant-home-title"><h1 id="tenant-title"><bdi>{String(branding?.tenant_name ?? snapshot.tenant_name ?? 'الشركة')}</bdi></h1>
            <span className="entity-status is-active">{lifecycleText(snapshot.lifecycle_state)}</span></div>
          <p>تابع إعداد الشركة واستخدامها من مكان واحد.</p>
        </header>
        <section className="tenant-home-summary" aria-labelledby="tenant-summary-title">
          <h2 id="tenant-summary-title">لمحة سريعة</h2>
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
          <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
        </nav>
      </header>
      <section className="auth-card" aria-labelledby="tenant-status-title">
        <p className="eyebrow">مساحة الشركة</p>
        <h1 id="tenant-status-title">{title}</h1>
        <p className="intro">{detail}</p>
        {showSwitch && <Link className="secondary-button" href="/tenant/select">اختر شركة أخرى</Link>}
      </section>
      <footer className="footer">منصة الأعمال · مساحة الشركة</footer>
    </main>
  );
}
