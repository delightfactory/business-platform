import { SettingsLink as Link } from '../../../SettingsLink';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { GATE_TEXT, editBlockedText, loadSettingsAccess } from '../../../access-gate';
import { StatusCard } from '../../../StatusCard';
import { isUuid } from '../../../rules';
import { CreateCalendarForm } from './CreateCalendarForm';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; employerId: string }>;

export default async function NewCalendarPage({ params }: { params: Params }) {
  const { tenantId, employerId } = await params;
  if (!isUuid(tenantId) || !isUuid(employerId)) notFound();
  const basePath = `/tenant/${tenantId}/leave/settings/${employerId}`;
  const path = `${basePath}/calendars/new`;
  const backCard = (title: string, detail: string, retry = false) => (
    <StatusCard tenantId={tenantId} title={title} detail={detail}
      retryPath={retry ? path : undefined} backPath={basePath} backLabel="العودة إلى إعدادات الجهة" />
  );

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    const text = GATE_TEXT['no-client'];
    return backCard(text.title, text.detail, text.retry);
  }
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(path)}`);

  const gate = await loadSettingsAccess(supabase, tenantId, employerId);
  if (gate.kind !== 'ok') {
    const text = GATE_TEXT[gate.kind];
    return backCard(text.title, text.detail, text.retry);
  }
  if (!gate.canEdit) {
    const blocked = editBlockedText(gate, 'إضافة تقويم');
    return backCard(blocked.title, blocked.detail);
  }

  const initialCode = `cal-${crypto.randomUUID().replaceAll('-', '')}`;

  return <PageFrame footer="الموارد البشرية">
    <div className="workspace-form-page">
      <Link className="back-link" href={basePath}>العودة إلى إعدادات الجهة</Link>
      <header className="workspace-page-heading"><div>
        <p className="eyebrow">تقويمات الإجازات</p>
        <h1>إضافة تقويم إجازات</h1>
        <p>حدد اسم التقويم وأيام الراحة والعطلات وتاريخ بدء تطبيقه.</p>
      </div></header>
      <section className="workspace-form-panel" aria-label="بيانات تقويم الإجازات">
        <CreateCalendarForm tenantId={tenantId} employerId={employerId}
          initialCode={initialCode} />
      </section>
    </div>
  </PageFrame>;
}
