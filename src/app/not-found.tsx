import { Panel, PageHeader } from '@/components/ui';
import { ButtonLink } from '@/components/ui';
export default function PageNotFound() {
  return <main className="app-shell">
    <Panel className="auth-card" aria-labelledby="page-not-found-title">
      <PageHeader id="page-not-found-title" title={<>الصفحة غير متاحة على هذا الرابط</>} />
      <p>تحقق من الرابط، أو ارجع للرئيسية للوصول إلى خدماتك المتاحة.</p>
      <ButtonLink variant="solid"  href="/">العودة للرئيسية</ButtonLink>
    </Panel>
  </main>;
}
