import { Avatar, Icon, Badge } from '@/components/ui';
import { PageHeader } from '@/components/ui';
import { ButtonLink, Button, Panel } from '@/components/ui';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { SubmitButton } from '@/components/submit-button';

export const dynamic = 'force-dynamic';
type TenantOption = { tenant_id: string; tenant_name: string; lifecycle_state: 'active' | 'suspended' };

export default async function SelectTenantPage() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <main className="app-shell"><Panel className="auth-card"><PageHeader  title={<>تعذر الاتصال بخدمة الحسابات</>} /><p className="intro" role="alert">حاول مرة أخرى لاحقًا. إذا استمرت المشكلة، تواصل مع دعم المنصة.</p><ButtonLink variant="solid" className="link-button" href="/auth/login">العودة إلى تسجيل الدخول</ButtonLink></Panel></main>;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { data, error } = await supabase.rpc('current_tenant_spaces');
  if (error || !Array.isArray(data)) return <main className="app-shell"><Panel className="auth-card"><PageHeader  title={<>تعذر تحميل الشركات</>} /><p className="intro" role="alert">لا يمكن عرض مساحاتك الآن. أعد المحاولة، أو تواصل مع دعم المنصة إذا استمرت المشكلة.</p><form action="/tenant/select" method="get"><Button variant="solid" className="link-button" type="submit">إعادة تحميل الشركات</Button></form><form action={signOutAction}><SubmitButton variant="ghost"  label="تسجيل الخروج" pendingLabel="جارٍ الخروج…" /></form></Panel></main>;
  const options = data as TenantOption[];
  if (options.length === 1 && options[0].lifecycle_state === 'active' && /^[0-9a-f-]{36}$/i.test(options[0].tenant_id)) {
    redirect(`/tenant/${options[0].tenant_id}`);
  }
  return (
    <main className="app-shell">
      <Panel  aria-labelledby="tenant-select-title">
        <p className="eyebrow">مساحاتك</p><PageHeader id="tenant-select-title" title={<>اختر الشركة</>} />
        {options.length === 0 ? <>
          <p className="intro">لا توجد مساحة عمل متاحة لهذا الحساب حاليًا. إذا كنت تتوقع ظهور شركة، تواصل مع دعم المنصة.</p>
          <form action={signOutAction}><SubmitButton variant="ghost"  label="تسجيل الخروج" pendingLabel="جارٍ الخروج…" /></form>
        </> : (
          <ul className="tenant-choice-list company-choice-grid">{options.map((tenant) => <li key={tenant.tenant_id}>
            <ButtonLink variant="ghost" className="tenant-choice-option company-choice" href={`/tenant/${tenant.tenant_id}`}>
              <Avatar name={tenant.tenant_name} size={48} />
              <span className="company-choice-copy"><strong>{tenant.tenant_name}</strong>
                {tenant.lifecycle_state === 'suspended' && <><Badge tone="warn">معلّقة</Badge><small>الاستخدام غير متاح، تواصل مع دعم المنصة</small></>}
              </span><Icon name="arrowLeft" size={18} />
            </ButtonLink>
          </li>)}</ul>
        )}
      </Panel>
    </main>
  );
}
