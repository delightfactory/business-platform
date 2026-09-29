import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
type TenantOption = { tenant_id: string; tenant_name: string };

export default async function SelectTenantPage() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <main className="app-shell"><section className="auth-card"><h1>إعداد الاتصال غير مكتمل</h1><p className="intro">تعذر الاتصال بخدمة الحسابات.</p></section></main>;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { data } = await supabase.rpc('current_tenant_memberships');
  const options = Array.isArray(data) ? data as TenantOption[] : [];
  if (options.length === 1 && /^[0-9a-f-]{36}$/i.test(options[0].tenant_id)) redirect(`/tenant/${options[0].tenant_id}`);
  return (
    <main className="app-shell">
      <section className="work-card" aria-labelledby="tenant-select-title">
        <p className="eyebrow">مساحاتك</p><h1 id="tenant-select-title">اختر الشركة</h1>
        {options.length === 0 ? <p className="intro">لا توجد لديك عضوية نشطة في شركة حاليًا.</p> : (
          <ul className="tenant-choice-list">{options.map((tenant) => <li key={tenant.tenant_id}>
            <Link className="secondary-button" href={`/tenant/${tenant.tenant_id}`}>{tenant.tenant_name}</Link>
          </li>)}</ul>
        )}
      </section>
    </main>
  );
}
