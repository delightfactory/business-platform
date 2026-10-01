import { SettingsLink as Link } from './SettingsLink';
import { PageFrame } from '@/components/context-navigation';

export function StatusCard({ tenantId, title, detail, retryPath, backPath, backLabel }: {
  tenantId: string;
  title: string;
  detail: string;
  retryPath?: string;
  backPath?: string;
  backLabel?: string;
}) {
  return <PageFrame footer="الموارد البشرية">
    <section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p>
      {retryPath && <Link className="secondary-button" href={retryPath}>إعادة المحاولة</Link>}
      <Link className="secondary-button" href={backPath ?? `/tenant/${tenantId}`}>{backLabel ?? 'العودة إلى مساحة الشركة'}</Link>
    </section>
  </PageFrame>;
}
