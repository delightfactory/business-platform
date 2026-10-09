import { PageHeader, Panel } from '@/components/ui';
import { Message } from '@/components/ui';
import { Button, ButtonLink } from '@/components/ui';
import Link from 'next/link';
import { operatorPermission } from '@/lib/operator-access';
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

  const [{ data: manage, error: manageError }, { data: onboard, error: onboardError }, { data: lifecycle, error: lifecycleError }, { data: commercial, error: commercialError }, { data: statutory, error: statutoryError }] = await Promise.all([
    supabase.rpc('current_operator_can_manage_operators').then(result => result, (error: unknown) => ({ data: null, error })),
    supabase.rpc('current_operator_can_onboard_tenants').then(result => result, (error: unknown) => ({ data: null, error })),
    supabase.rpc('current_operator_can_manage_tenant_lifecycle').then(result => result, (error: unknown) => ({ data: null, error })),
    supabase.rpc('current_operator_can_manage_commercial_access').then(result => result, (error: unknown) => ({ data: null, error })),
    supabase.rpc('current_operator_can_manage_statutory_rules').then(result => result, (error: unknown) => ({ data: null, error })),
  ]);
  const partialRead = Boolean(manageError || onboardError || lifecycleError || commercialError || statutoryError);
  const canManage = operatorPermission({ data: manage, error: manageError });
  const canOnboard = operatorPermission({ data: onboard, error: onboardError });
  const canManageLifecycle = operatorPermission({ data: lifecycle, error: lifecycleError });
  const canManageCommercial = operatorPermission({ data: commercial, error: commercialError });
  const canManageStatutory = operatorPermission({ data: statutory, error: statutoryError });

  return (
    <main className="app-shell">
      {(query.state === 'updated-self' || query.state === 'revoked-self') && <Message tone="info"  role="status">المهام المتاحة لصلاحياتك الحالية معروضة أدناه؛ الرابط وحده لا يؤكد تغيير الصلاحيات.</Message>}
      {partialRead && <Message tone="info"  role="alert">تعذر التحقق من بعض المهام. يمكنك متابعة المهام المؤكدة أدناه. <ButtonLink variant="ghost" href="/operator" >إعادة قراءة المهام</ButtonLink></Message>}
      <div className="operator-home" aria-labelledby="operator-title">
        <header className="operator-home-heading">
          <p className="eyebrow">مساحة التشغيل</p>
          <PageHeader id="operator-title" title={<>تشغيل المنصة</>} />
          <p>اختر المهمة التي تريد إنجازها. تظهر هنا الأعمال المسموحة لحسابك فقط.</p>
        </header>

        {canOnboard && <section className="operator-featured-task" aria-labelledby="new-company-title">
          <div>
            <p className="eyebrow">بدء العمل</p>
            <h2 id="new-company-title">شركة جديدة</h2>
            <p>أرسل دعوة للمسؤول الأول لتُنشأ الشركة بفرعها وحدود استخدامها عند قبولها.</p>
          </div>
          <ButtonLink variant="solid"  href="/operator/invitations/new">دعوة مسؤول الشركة <span aria-hidden="true">←</span></ButtonLink>
        </section>}

        <div className="operator-home-grid">
          {(canOnboard || canManageLifecycle || canManageCommercial) && <section className="operator-work-group" aria-labelledby="company-operations-title">
            <div className="operator-group-heading"><p className="eyebrow">الشركات</p><h2 id="company-operations-title">إدارة الشركات</h2></div>
            <ul className="operator-work-list">
              {canOnboard && <TaskLink href="/operator/onboarding" title="إعداد شركة بحساب موجود" detail="أنشئ شركة لمسؤول لديه حساب مؤكد بالفعل." />}
              {canManageLifecycle && <TaskLink href="/operator/tenants" title="حالة الشركات" detail="علّق الوصول أو استعده مع تسجيل السبب." />}
              {canManageCommercial && <TaskLink href="/operator/commercial" title="حدود الاستخدام" detail="راجع عدد المستخدمين والفروع واضبط الحدود." />}
              {canManageCommercial && <TaskLink href="/operator/entitlements" title="إتاحة الوحدات" detail="راجع الوحدات المتاحة لكل شركة وغيّرها." />}
            </ul>
          </section>}
          {canManage && <section className="operator-work-group" aria-labelledby="access-operations-title">
            <div className="operator-group-heading"><p className="eyebrow">الفريق</p><h2 id="access-operations-title">صلاحيات التشغيل</h2></div>
            <ul className="operator-work-list"><TaskLink href="/operator/operators" title="مشغّلو المنصة" detail="امنح مهام التشغيل أو عدّلها أو ألغها." /></ul>
          </section>}
        </div>
        {canManageStatutory && <section className="operator-work-group" aria-labelledby="statutory-authority-title"><h2 id="statutory-authority-title">القواعد القانونية للرواتب</h2><ul className="operator-work-list"><TaskLink href="/operator/statutory" title="مسودات القواعد ومراجعها" detail="احفظ النسخ المؤرخة وراجع سجل تعديلاتها؛ الحفظ لا يعتمدها لحساب الرواتب." /></ul></section>}
        {!partialRead && !canManage && !canOnboard && !canManageLifecycle && !canManageCommercial && !canManageStatutory &&
          <p className="empty-state">لا توجد مهام تشغيل ممنوحة لحسابك حاليًا. تواصل مع مسؤول تشغيل المنصة إذا كنت تحتاج مهمة محددة.</p>}
      </div>

    </main>
  );
}

function TaskLink({ href, title, detail }: { href: string; title: string; detail: string }) {
  return <li><Link className="operator-work-link" href={href}>
    <span><strong>{title}</strong><small>{detail}</small></span><span className="operator-work-arrow" aria-hidden="true">←</span>
  </Link></li>;
}

function Status({ title, detail }: { title: string; detail: string }) {
  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><Button variant="ghost"  type="submit">تسجيل الخروج</Button></form></header>
      <Panel className="auth-card" aria-labelledby="status-title"><p className="eyebrow">مساحة المشغّل</p>
        <PageHeader id="status-title" title={<>{title}</>} /><p className="intro">{detail}</p></Panel>

    </main>
  );
}
