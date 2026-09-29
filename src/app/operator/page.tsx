import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

type SearchParams = Promise<{ state?: string }>;

export default async function OperatorPage({ searchParams }: { searchParams: SearchParams }) {
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة إلى ملف البيئة ثم أعد تشغيل التطبيق." />;
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  if (userError) return <Status title="تعذر التحقق من الجلسة" detail="حاول تسجيل الدخول مرة أخرى." />;
  const { data: operatorStatus, error: statusError } = await supabase.rpc('current_platform_operator_status');
  if (statusError) return <Status title="تعذر التحقق من الصلاحية" detail="تعذر التحقق من صلاحية تشغيل المنصة. حاول لاحقًا." />;
  if (operatorStatus !== 'active') return <Status title="لا توجد صلاحية تشغيل" detail="هذا الحساب لا يملك صلاحية مشغّل المنصة النشطة." />;

  const [{ data: canManage, error: manageError }, { data: canOnboard, error: onboardError }, { data: canManageLifecycle, error: lifecycleError }] = await Promise.all([
    supabase.rpc('current_operator_can_manage_operators'),
    supabase.rpc('current_operator_can_onboard_tenants'),
    supabase.rpc('current_operator_can_manage_tenant_lifecycle'),
  ]);
  if (manageError || onboardError || lifecycleError) return <Status title="تعذر تحميل المهام" detail="حاول مجددًا بعد قليل." />;

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </header>
      <section className="work-card" aria-labelledby="operator-title">
        <p className="eyebrow">مساحة المشغّل</p>
        <h1 id="operator-title">مهام تشغيل المنصة</h1>
        {query.state === 'updated-self' && <p className="form-message" role="status">تم تحديث صلاحياتك. انتقلت إلى المهام التي ما زالت متاحة لحسابك.</p>}
        {query.state === 'revoked-self' && <p className="form-message" role="status">سُحبت صلاحيات المشغّل من حسابك.</p>}
        <div className="operator-task-list">
          {canManage && <Link className="primary-button" href="/operator/operators">إدارة مشغّلي المنصة</Link>}
          {canOnboard && <Link className="secondary-button" href="/operator/onboarding">إعداد شركة</Link>}
          {canOnboard && <Link className="secondary-button" href="/operator/invitations">دعوة مسؤول شركة</Link>}
          {canManageLifecycle && <Link className="secondary-button" href="/operator/tenants">إدارة حالة الشركات</Link>}
          {!canManage && !canOnboard && !canManageLifecycle && <p className="intro">لا توجد مهام تشغيل ممنوحة لهذا الحساب حاليًا.</p>}
        </div>
      </section>
      <footer className="footer">منصة الأعمال · تشغيل المنصة</footer>
    </main>
  );
}

function Status({ title, detail }: { title: string; detail: string }) {
  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></header>
      <section className="auth-card" aria-labelledby="status-title"><p className="eyebrow">مساحة المشغّل</p>
        <h1 id="status-title">{title}</h1><p className="intro">{detail}</p></section>
      <footer className="footer">منصة الأعمال · تشغيل المنصة</footer>
    </main>
  );
}
