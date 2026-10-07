import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { SubmitButton } from '@/components/submit-button';

export const dynamic = 'force-dynamic';
type TenantOption = { tenant_id: string; tenant_name: string; lifecycle_state: 'active' | 'suspended' };

export default async function SelectTenantPage() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <main className="app-shell"><section className="auth-card"><h1>إعداد الاتصال غير مكتمل</h1><p className="intro" role="alert">تعذر الاتصال بخدمة الحسابات. تواصل مع دعم المنصة إذا استمرت المشكلة.</p><Link className="primary-button link-button" href="/auth/login">العودة إلى تسجيل الدخول</Link></section></main>;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { data, error } = await supabase.rpc('current_tenant_spaces');
  if (error || !Array.isArray(data)) return <main className="app-shell"><section className="auth-card"><h1>تعذر تحميل الشركات</h1><p className="intro" role="alert">لا يمكن عرض مساحاتك الآن. أعد المحاولة، أو تواصل مع دعم المنصة إذا استمرت المشكلة.</p><form action="/tenant/select" method="get"><button className="primary-button link-button" type="submit">إعادة تحميل الشركات</button></form><form action={signOutAction}><SubmitButton className="secondary-button" label="تسجيل الخروج" pendingLabel="جارٍ الخروج…" /></form></section></main>;
  const options = data as TenantOption[];
  if (options.length === 1 && options[0].lifecycle_state === 'active' && /^[0-9a-f-]{36}$/i.test(options[0].tenant_id)) {
    redirect(`/tenant/${options[0].tenant_id}`);
  }
  return (
    <main className="app-shell">
      <section className="work-card" aria-labelledby="tenant-select-title">
        <p className="eyebrow">مساحاتك</p><h1 id="tenant-select-title">اختر الشركة</h1>
        {options.length === 0 ? <>
          <p className="intro">لا توجد مساحة عمل متاحة لهذا الحساب حاليًا. إذا كنت تتوقع ظهور شركة، تواصل مع دعم المنصة.</p>
          <form action={signOutAction}><SubmitButton className="secondary-button" label="تسجيل الخروج" pendingLabel="جارٍ الخروج…" /></form>
        </> : (
          <ul className="tenant-choice-list">{options.map((tenant) => <li key={tenant.tenant_id}>
            <Link className="secondary-button tenant-choice-option" href={`/tenant/${tenant.tenant_id}`}>
              <span>{tenant.tenant_name}</span>
              {tenant.lifecycle_state === 'suspended' && <span className="field-hint">معلّقة · الاستخدام غير متاح، تواصل مع دعم المنصة</span>}
            </Link>
          </li>)}</ul>
        )}
      </section>
    </main>
  );
}
