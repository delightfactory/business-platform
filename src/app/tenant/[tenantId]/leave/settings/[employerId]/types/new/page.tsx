import { SettingsLink as Link } from '../../../SettingsLink';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { GATE_TEXT, editBlockedText, loadSettingsAccess } from '../../../access-gate';
import { StatusCard } from '../../../StatusCard';
import { isUuid } from '../../../rules';
import { CreateTypeForm } from './CreateTypeForm';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; employerId: string }>;

export default async function NewLeaveTypePage({ params }: { params: Params }) {
  const { tenantId, employerId } = await params;
  if (!isUuid(tenantId) || !isUuid(employerId)) notFound();
  const basePath = `/tenant/${tenantId}/leave/settings/${employerId}`;
  const path = `${basePath}/types/new`;
  const card = (title: string, detail: string, retry = false) => (
    <StatusCard tenantId={tenantId} title={title} detail={detail}
      retryPath={retry ? path : undefined} backPath={basePath} backLabel="العودة إلى إعدادات الجهة" />
  );

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    const text = GATE_TEXT['no-client'];
    return card(text.title, text.detail, text.retry);
  }
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(path)}`);

  const gate = await loadSettingsAccess(supabase, tenantId, employerId);
  if (gate.kind !== 'ok') {
    const text = GATE_TEXT[gate.kind];
    return card(text.title, text.detail, text.retry);
  }
  if (!gate.canEdit) {
    const blocked = editBlockedText(gate, 'إضافة نوع إجازة');
    return card(blocked.title, blocked.detail);
  }

  const initialCode = `typ-${crypto.randomUUID().replaceAll('-', '')}`;

  return <PageFrame footer="الموارد البشرية">
    <div className="workspace-form-page">
      <Link className="back-link" href={basePath}>العودة إلى إعدادات الجهة</Link>
      <header className="workspace-page-heading"><div>
        <p className="eyebrow">أنواع الإجازة</p>
        <h1>إضافة نوع إجازة</h1>
        <p>حدد نوع الإجازة وطريقة احتسابها وأثرها على الرصيد والأجر.</p>
      </div></header>
      <section className="workspace-form-panel" aria-label="بيانات نوع الإجازة">
        <CreateTypeForm tenantId={tenantId} employerId={employerId}
          initialCode={initialCode} />
      </section>
    </div>
  </PageFrame>;
}
