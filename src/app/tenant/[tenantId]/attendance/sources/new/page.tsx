import { Button, ButtonLink, Input, PageHeader, Field } from '@/components/ui';
import { PageFrame } from '@/components/context-navigation';
import { SourceForm } from '../ChannelForms';
import { channelSession, channelHref, ChannelUnavailable, type Options } from '../shared';
export const dynamic='force-dynamic';
export default async function NewSource({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<{q?:string}>}) {
 const {tenantId}=await params,{q=''}=await searchParams,session=await channelSession(tenantId);const retryHref=channelHref(`/tenant/${tenantId}/attendance/sources/new`,{q});if(!session || !session.access.can_manage) return <ChannelUnavailable tenantId={tenantId} retryHref={retryHref}/>;
 const {data,error}=await session.db.rpc('attendance_channel_options',{p_tenant:tenantId,p_search:q.slice(0,100),p_limit:20});if(error) return <ChannelUnavailable tenantId={tenantId} retryHref={retryHref}/>;
 return <PageFrame><div className="channel-page"><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance/sources`}>العودة إلى القنوات</ButtonLink><div className="workspace-page-heading"><PageHeader  title={<>إضافة قناة حضور</>} /></div><section className="workspace-form-panel"><p className="field-hint">قبل الإنشاء، تأكد من اعتماد موقع العمل وسياسة التحقق والاحتفاظ بدليل الموقع. إنشاء قناة خارجية لا يشغّل موصل جهاز تلقائيًا.</p><form method="get" className="channel-search"><Field id="site-search" label={<>البحث عن موقع</>}><Input id="site-search" name="q" defaultValue={q} maxLength={100}/></Field><Button variant="ghost" type="submit" >البحث عن الموقع</Button></form><p className="field-hint">تظهر أول 20 نتيجة. ابحث بالاسم إذا لم تجد الموقع.</p><SourceForm tenantId={tenantId} options={data as Options}/></section></div></PageFrame>;
}
