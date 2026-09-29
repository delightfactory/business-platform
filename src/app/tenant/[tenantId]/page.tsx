import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function TenantPage({ params }: { params: Promise<{ tenantId: string }> }) {
  const { tenantId } = await params;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <TenantStatus title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد المحاولة." />;

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');

  const { data, error } = await supabase.rpc('tenant_admin_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) {
    return <TenantStatus title="المساحة غير متاحة" detail="لا يملك هذا الحساب صلاحية مسؤول لهذه الشركة أو أن الشركة غير متاحة." />;
  }

  const snapshot = data as Record<string, unknown>;
  const entity = objectValue(snapshot.default_legal_entity);
  const site = objectValue(snapshot.default_site);

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </header>
      <section className="work-card" aria-labelledby="tenant-title">
        <p className="eyebrow">مساحة مسؤول الشركة</p>
        <h1 id="tenant-title">{String(snapshot.tenant_name ?? 'الشركة')}</h1>
        <p className="intro">حالة الشركة: {String(snapshot.lifecycle_state ?? 'غير متاح')}</p>
        <dl className="snapshot-grid">
          <div><dt>الكيان القانوني الافتراضي</dt><dd>{String(entity?.name ?? 'غير متاح')}</dd></div>
          <div><dt>الموقع الافتراضي</dt><dd>{String(site?.name ?? 'غير متاح')}</dd></div>
          <div><dt>المستخدمون</dt><dd>{limitText(snapshot.seat_limit_mode, snapshot.seat_limit)} · {String(snapshot.seat_usage ?? 0)} مستخدم</dd></div>
          <div><dt>المواقع</dt><dd>{limitText(snapshot.site_limit_mode, snapshot.site_limit)} · {String(snapshot.site_usage ?? 0)} موقع</dd></div>
        </dl>
        <p className="field-hint">هذه مساحة تأسيسية لمسؤول الشركة. إدارة المستخدمين والعمليات ستضاف في مراحل لاحقة.</p>
      </section>
      <footer className="footer">منصة الأعمال · مساحة الشركة</footer>
    </main>
  );
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

function limitText(mode: unknown, value: unknown) {
  return mode === 'unlimited' ? 'غير محدود' : String(value ?? 'غير متاح');
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
