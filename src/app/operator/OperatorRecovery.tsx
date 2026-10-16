import { Banner, ButtonLink, PageHeader, Panel } from '@/components/ui';

/** Read-only exits; retry never submits or recreates an operation. */
export function OperatorRecovery({ title, detail, retryHref, backHref = '/operator' }: {
  title: string; detail: string; retryHref?: string; backHref?: string;
}) {
  return <main className="app-shell"><Panel className="auth-card">
    <PageHeader title={title} />
    <Banner tone="warn">{detail}</Banner>
    <div className="workspace-form-actions">
      {retryHref && <ButtonLink variant="solid" href={retryHref}>إعادة المحاولة</ButtonLink>}
      <ButtonLink variant="ghost" href={backHref}>{backHref.startsWith('/operator/companies') ? 'العودة إلى الشركات' : backHref === '/operator/invitations' ? 'العودة إلى الدعوات' : backHref === '/tenant/select' ? 'العودة إلى مساحتي' : 'العودة إلى تشغيل المنصة'}</ButtonLink>
    </div>
  </Panel></main>;
}
