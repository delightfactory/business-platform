import { redirect } from 'next/navigation';
import { Banner, ButtonLink, PageHeader } from '@/components/ui';
import { readOperatorAuthority } from '@/lib/operator-authority';
import { getWorkspaceClient } from '@/lib/workspace-access';
import { onboardingSnapshot, operatorUuid } from '@/lib/operator-read';
import { OnboardingResult } from '../../onboarding/OnboardingResult';
import { CompanySetup } from './CompanySetup';
import './setup.css';
export const dynamic = 'force-dynamic';
export default async function NewCompanyPage({ searchParams }: { searchParams: Promise<{ mode?: string; key?: string }> }) {
  const query = await searchParams; const authority = await readOperatorAuthority();
  if (authority.session === 'signed-out') redirect('/auth/login?next=%2Foperator%2Fcompanies%2Fnew');
  if (!authority.active || !authority.onboard || !authority.userId) return <main className="app-shell"><Banner>{authority.partial ? 'تعذر التحقق من صلاحية إنشاء الشركات. أعد المحاولة.' : 'إنشاء الشركات غير متاح لهذا الحساب.'}</Banner></main>;
  const mode = query.mode === 'existing' || (query.key && query.mode !== 'invite') ? 'existing' : 'invite';
  if (query.key !== undefined && !operatorUuid(query.key)) return <main className="app-shell"><Banner tone="warn">مرجع المحاولة غير صالح. ارجع إلى صفحة المحاولة الأصلية لمراجعة نتيجتها.</Banner></main>;
  const client = await getWorkspaceClient();
  const result = mode === 'existing' && query.key && client ? await client.rpc('tenant_onboarding_result', { p_idempotency_key: query.key }).then(value => value, () => ({ data: null, error: true })) : null;
  const unavailable = result && (result.error || (result.data !== null && !onboardingSnapshot(result.data)));
  return <main className="app-shell operator-setup-page"><ButtonLink variant="ghost" href={authority.commercial || authority.lifecycle ? '/operator/companies' : '/operator/invitations'}>العودة</ButtonLink>
    <PageHeader title={result?.data && !unavailable ? 'نتيجة إنشاء الشركة' : 'شركة جديدة'} description={result?.data && !unavailable ? 'راجع النتيجة وتابع إعداد خدمات الشركة.' : 'حدد طريقة انضمام المسؤول، ثم أدخل بيانات الشركة.'} />
    {unavailable ? <Banner tone="warn" action={<ButtonLink variant="ghost" href={`/operator/companies/new?mode=existing&key=${encodeURIComponent(query.key!)}`}>إعادة قراءة النتيجة</ButtonLink>}>تعذر التحقق من نتيجة المحاولة. لا تبدأ طلبًا جديدًا قبل مراجعتها.</Banner>
      : result?.data ? <OnboardingResult result={result.data} canManageServices={authority.commercial} />
      : <>{query.key && mode === 'existing' && <Banner>لم ترجع القراءة نتيجة محفوظة لهذا الحساب. لا يؤكد ذلك غياب محاولة من حساب آخر؛ يُستخدم المرجع نفسه عند الإرسال.</Banner>}
        <CompanySetup actorId={authority.userId} requestKey={query.key ?? crypto.randomUUID()} initialMode={mode} canManageServices={authority.commercial} /></>}
  </main>;
}
