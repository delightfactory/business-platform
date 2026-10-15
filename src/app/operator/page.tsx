import { PageHeader, Panel } from '@/components/ui';
import { Message } from '@/components/ui';
import { Button, ButtonLink } from '@/components/ui';
import Link from 'next/link';
import { readOperatorAuthority } from '@/lib/operator-authority';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';

export const dynamic = 'force-dynamic';

type SearchParams = Promise<{ state?: string }>;

export default async function OperatorPage({ searchParams }: { searchParams: SearchParams }) {
  const query = await searchParams;
  const authority = await readOperatorAuthority();
  if (authority.session === 'unconfigured') return <Status title="إعداد الاتصال غير مكتمل" detail="تعذر الاتصال بالمنصة. اطلب من مسؤول التشغيل مراجعة إعدادات الاتصال." />;
  if (authority.session === 'signed-out') redirect('/auth/login?state=no-session');
  if (authority.session === 'unavailable') return <Status title="تعذر التحقق من الجلسة" detail="حاول تسجيل الدخول مرة أخرى." />;
  if (!authority.active && authority.partial) return <Status title="تعذر التحقق من الصلاحية" detail="تعذر التحقق من صلاحية تشغيل المنصة. حاول لاحقًا." />;
  if (!authority.active) return <Status title="لا توجد صلاحية تشغيل" detail="هذا الحساب لا يملك صلاحية مسؤول تشغيل المنصة النشطة." />;
  const { manage: canManage, onboard: canOnboard, lifecycle: canManageLifecycle, commercial: canManageCommercial,
    statutory: canManageStatutory, partial: partialRead } = authority;

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

        {(canManageLifecycle || canManageCommercial) && <form action="/operator/companies" method="get" role="search" className="workspace-form-panel">
          <label htmlFor="operator-company-search">ابحث عن شركة</label>
          <div className="topbar-actions"><input className="ui-input" id="operator-company-search" name="q" type="search" maxLength={120} placeholder="اسم الشركة" /><Button type="submit" icon="search">بحث</Button></div>
        </form>}

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
              {(canManageLifecycle || canManageCommercial) && <TaskLink href="/operator/companies" title="الشركات" detail="ابحث عن الشركة ثم تابع خدماتها وحدودها وحالتها حسب صلاحيتك." />}
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
