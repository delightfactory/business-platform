import { Badge, ButtonLink, KeyValueStrip, Message, PageHeader, Panel } from '@/components/ui';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { OrgCatalogForm, type OrgCatalogOption, type OrgCatalogRecord } from '../../OrgCatalogForm';
import type { OrgCatalogKind } from '../../actions';

export const dynamic = 'force-dynamic';
type RouteParams = Promise<{ tenantId: string; kind: string; recordId: string }>;
type Access = { can_manage_org?: boolean };
type OptionsResult = { items: OrgCatalogOption[]; truncated: boolean };

export default async function OrgCatalogRecordPage({ params }: { params: RouteParams }) {
  const { tenantId, kind: rawKind, recordId } = await params;
  if (!isUuid(tenantId) || !['departments','jobs'].includes(rawKind)) {
    return <Unavailable tenantId={tenantId} title="السجل غير متاح" detail="تحقق من الرابط ثم عد إلى دليل الأقسام والوظائف." />;
  }
  const kind = rawKind as OrgCatalogKind;
  const isNew = recordId === 'new';
  if (!isNew && !isUuid(recordId)) return <Unavailable tenantId={tenantId} title="السجل غير متاح" detail="لم نعثر على السجل المطلوب." />;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Unavailable tenantId={tenantId} title="الاتصال غير متاح" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people/organization/${kind}/${recordId}`)}`);
  const accessResult = await supabase.rpc('people_access_snapshot', { p_tenant_id: tenantId });
  if (accessResult.error || !accessResult.data) return <Unavailable tenantId={tenantId} title="السجل غير متاح" detail="تحقق من صلاحيتك في هذه الشركة ثم أعد المحاولة." />;
  const canManage = (accessResult.data as Access).can_manage_org === true;
  if (isNew && !canManage) return <Unavailable tenantId={tenantId} title="لا يمكن إضافة سجل" detail="تحتاج إلى صلاحية إدارة الأقسام والوظائف." />;
  const [recordResult, optionsResult] = await Promise.all([
    isNew ? Promise.resolve({ data: null, error: null }) :
      supabase.rpc('people_org_catalog_record', { p_tenant_id: tenantId, p_kind: kind, p_record_id: recordId }),
    supabase.rpc('people_org_catalog_options', { p_tenant_id: tenantId, p_kind: 'departments' }),
  ]);
  if (optionsResult.error || !optionsResult.data || (recordResult && recordResult.error)) {
    return <Unavailable tenantId={tenantId} title="تعذر فتح النموذج" detail="تحقق من الاتصال والصلاحية، ثم أعد المحاولة." />;
  }
  const record = recordResult.data as unknown as OrgCatalogRecord | null;
  if (!isNew && !record) return <Unavailable tenantId={tenantId} title="لم نعثر على السجل" detail="قد يكون السجل قد تغيّر. ارجع إلى القائمة وحدّثها." />;
  const optionsData = optionsResult.data as unknown as OptionsResult;
  const options = Array.isArray(optionsData.items) ? optionsData.items : [];
  const title = kind === 'departments' ? 'القسم' : 'الوظيفة';
  const description = kind === 'departments'
    ? isNew ? 'أنشئ قسمًا وحدد موقعه في تسلسل الأقسام.' : canManage ? 'حدّث بيانات القسم وعلاقته بالقسم الأعلى.' : 'بيانات القسم وعلاقته بالقسم الأعلى.'
    : isNew ? 'أضف وظيفة وحدد القسم المرتبطة به.' : canManage ? 'حدّث بيانات الوظيفة والقسم المرتبط بها.' : 'بيانات الوظيفة والقسم المرتبط بها.';
  const relationName = kind === 'departments' ? record?.parent_name : record?.department_name;
  const currentRelation = kind === 'departments' ? record?.parent_id : record?.department_id;
  const currentMissing = Boolean(currentRelation && !options.some((item) => item.id === currentRelation));

  return <PageFrame footer="الموارد البشرية"><div className="workspace-form-page org-catalog-page">
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people/organization?kind=${kind}`}>العودة إلى {kind==='departments'?'الأقسام':'الوظائف'}</ButtonLink>
    <PageHeader title={<>{isNew ? `إضافة ${title}` : canManage ? `تعديل ${title}` : `تفاصيل ${title}`}</>} eyebrow={<>الأقسام والوظائف</>} description={<>{description}</>} />
    <Panel  aria-label={isNew?`إضافة ${title}`:`بيانات ${title}`}>
      {canManage ? <OrgCatalogForm tenantId={tenantId} kind={kind} record={record} options={options}
        optionsTruncated={optionsData.truncated===true} />
        : <div><h2>{record?.name}</h2><KeyValueStrip items={[{ label: 'الرمز', value: <bdi>{record?.code}</bdi> }, { label: 'الحالة', value: <Badge tone={record?.is_active ? 'ok' : 'neutral'}>{record?.is_active ? 'نشط' : 'غير نشط'}</Badge> }, ...(relationName ? [{ label: kind === 'departments' ? 'القسم الأعلى' : 'القسم', value: relationName }] : [])]} /><ButtonLink variant="ghost" href={`/tenant/${tenantId}/people/organization?kind=${kind}`}>العودة إلى القائمة</ButtonLink></div>}
      {currentMissing && <Message tone="info"  role="status">تعذر تحميل {kind==='departments'?'القسم الأعلى':'القسم'} الحالي ضمن قائمة الاختيارات؛ سيبقى محفوظًا ما لم تغيّره.</Message>}
    </Panel>
  </div></PageFrame>;
}

function isUuid(value:string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function Unavailable({tenantId,title,detail}:{tenantId:string;title:string;detail:string}) {
  return <PageFrame><Panel ><h1>{title}</h1><p className="intro">{detail}</p>
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people/organization`}>العودة إلى الأقسام والوظائف</ButtonLink>
  </Panel></PageFrame>;
}
