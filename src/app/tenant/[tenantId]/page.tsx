import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
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

  const { data: adminData, error: adminError } = await supabase.rpc('tenant_admin_snapshot', { p_tenant_id: tenantId });
  if (adminError) {
    const { data: memberData, error: memberError } = await supabase.rpc('tenant_membership_snapshot', { p_tenant_id: tenantId });
    if (memberError || !memberData || typeof memberData !== 'object' || Array.isArray(memberData)) {
      return <TenantStatus title="المساحة غير متاحة" detail="لا يملك هذا الحساب عضوية نشطة في هذه الشركة، أو أن الشركة غير متاحة." />;
    }
    const member = memberData as Record<string, unknown>;
    return (
      <main className="app-shell">
        <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
          <nav className="topbar-actions" aria-label="إجراءات الحساب"><Link className="secondary-button" href="/tenant/select">تبديل الشركة</Link>
            <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></nav>
        </header>
        <section className="work-card" aria-labelledby="tenant-title">
          <p className="eyebrow">مساحة الشركة</p><h1 id="tenant-title">{String(member.tenant_name ?? 'الشركة')}</h1>
          <p className="intro">أنت عضو في هذه الشركة.</p>
          {query.state === 'admin-demoted' && <p className="form-message" role="status">تم خفض دورك إلى عضو. بقيت عضويتك فعالة ويمكنك متابعة استخدام مساحة الشركة.</p>}
          <dl className="snapshot-grid"><div><dt>الحساب</dt><dd><bdi>{String(member.member_email ?? user.email ?? '')}</bdi></dd></div>
            <div><dt>الدور</dt><dd>عضو</dd></div></dl>
        </section>
        <footer className="footer">منصة الأعمال · مساحة الشركة</footer>
      </main>
    );
  }
  const data = adminData;
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return <TenantStatus title="المساحة غير متاحة" detail="لا يملك هذا الحساب صلاحية مسؤول لهذه الشركة أو أن الشركة غير متاحة." />;
  }

  const snapshot = data as Record<string, unknown>;
  const entity = objectValue(snapshot.default_legal_entity);
  const site = objectValue(snapshot.default_site);

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/">منصة الأعمال</Link>
        <nav className="topbar-actions" aria-label="إجراءات الحساب"><Link className="secondary-button" href="/tenant/select">تبديل الشركة</Link>
          <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></nav>
      </header>
      <section className="work-card" aria-labelledby="tenant-title">
        <p className="eyebrow">مساحة مسؤول الشركة</p>
        <h1 id="tenant-title">{String(snapshot.tenant_name ?? 'الشركة')}</h1>
        <p className="intro">حالة الشركة: {lifecycleText(snapshot.lifecycle_state)}</p>
        <dl className="snapshot-grid">
          <div><dt>الكيان القانوني الافتراضي</dt><dd>{String(entity?.name ?? 'غير متاح')}</dd></div>
          <div><dt>الموقع الافتراضي</dt><dd>{String(site?.name ?? 'غير متاح')}</dd></div>
          <div><dt>المستخدمون</dt><dd>{usageText(snapshot.seat_limit_mode, snapshot.seat_limit, snapshot.seat_usage, 'مستخدمين')}</dd></div>
          <div><dt>المواقع</dt><dd>{usageText(snapshot.site_limit_mode, snapshot.site_limit, snapshot.site_usage, 'مواقع')}</dd></div>
        </dl>
        <p className="field-hint">هذه مساحة تأسيسية لمسؤول الشركة.</p>
        <Link className="primary-button" href={`/tenant/${tenantId}/users`}>إدارة مستخدمي الشركة</Link>
      </section>
      <footer className="footer">منصة الأعمال · مساحة الشركة</footer>
    </main>
  );
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
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

function TenantStatus({ title, detail }: { title: string; detail: string }) {
  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </header>
      <section className="auth-card" aria-labelledby="tenant-status-title">
        <p className="eyebrow">مساحة الشركة</p>
        <h1 id="tenant-status-title">{title}</h1>
        <p className="intro">{detail}</p>
      </section>
      <footer className="footer">منصة الأعمال · مساحة الشركة</footer>
    </main>
  );
}
