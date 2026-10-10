'use client';

import { Panel, PageHeader } from '@/components/ui';
import { Button, ButtonLink } from '@/components/ui';
export default function PageError({ retry }: { retry: () => void }) {
  return <main className="app-shell">
    <Panel className="auth-card" aria-labelledby="page-error-title">
      <PageHeader id="page-error-title" title={<>تعذر عرض الصفحة</>} />
      <p>حاول فتح الصفحة مرة أخرى. إذا كنت قد أرسلت طلبًا ولم تتأكد نتيجته، راجع سجله قبل إرسال طلب آخر.</p>
      <div className="workspace-form-actions">
        <Button variant="solid" type="button"  onClick={retry}>إعادة فتح الصفحة</Button>
        <ButtonLink variant="ghost"  href="/">العودة للرئيسية</ButtonLink>
      </div>
    </Panel>
  </main>;
}
