import { ButtonLink } from '@/components/ui';

export function CompanyTaskLinks({ tenantId, current, lifecycle, commercial }: {
  tenantId: string; current: 'lifecycle' | 'commercial' | 'entitlements'; lifecycle: boolean; commercial: boolean;
}) {
  const destinations = [
    { key: 'lifecycle', allowed: lifecycle, label: 'حالة الشركة', href: `/operator/tenants/${tenantId}` },
    { key: 'commercial', allowed: commercial, label: 'حدود الاستخدام', href: `/operator/commercial/${tenantId}` },
    { key: 'entitlements', allowed: commercial, label: 'إتاحة الوحدات', href: `/operator/entitlements/${tenantId}` },
  ].filter(item => item.allowed === true && item.key !== current);
  if (destinations.length === 0) return null;
  return <div className="operator-company-context">
    <nav aria-label="مهام هذه الشركة">{destinations.map(item => <ButtonLink variant="ghost" key={item.key} className="secondary-button" href={item.href}>{item.label}</ButtonLink>)}</nav>
    <p className="field-hint">هذه مهام الشركة نفسها. احفظ أي تعديل لم ترسله قبل الانتقال.</p>
  </div>;
}
