import { Button, ButtonLink, KeyValueStrip } from '@/components/ui';
import { CopyAdminLink } from './CopyAdminLink';

export function OnboardingResult({ result, canManageServices = false }: { result: Record<string, unknown>; canManageServices?: boolean }) {
  const tenantId = String(result.tenant_id), tenantName = String(result.tenant_name);
  return <div className="operator-setup-result" role="status"><h2>أُنشئت <bdi>{tenantName}</bdi></h2>
    <KeyValueStrip items={[
      { label: 'الاسم القانوني', value: <bdi>{String(result.legal_entity_name)}</bdi> },
      { label: 'الفرع الأول', value: <bdi>{String(result.site_name)}</bdi> },
      { label: 'المستخدمون عند الإنشاء', value: `${String(result.seat_usage)} من ${limitText(result.seat_limit_mode, result.seat_limit)}` },
      { label: 'الفروع عند الإنشاء', value: `${String(result.site_usage)} من ${limitText(result.site_limit_mode, result.site_limit)}` },
    ]} />
    {canManageServices ? <ButtonLink href={`/operator/companies/${tenantId}/services`}>اختيار خدمات الشركة</ButtonLink>
      : <p>تفعيل الخدمات يحتاج مشغّلًا بصلاحية خدمات الشركات.</p>}
    <div className="operator-setup-secondary"><CopyAdminLink href={`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}`)}`} />
    {/* A new task after a confirmed receipt needs a fresh server-rendered form, even at the same URL. */}
    <form method="get" action="/operator/companies/new"><input type="hidden" name="mode" value="existing" /><Button variant="ghost" type="submit">شركة أخرى</Button></form></div>
  </div>;
}

function limitText(mode: unknown, value: unknown) { return mode === 'unlimited' ? 'غير محدود' : String(value); }
