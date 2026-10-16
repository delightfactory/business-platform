import { ButtonLink, PageHeader } from '@/components/ui';
import { PageFrame } from '@/components/context-navigation';
import { SourceForm } from '../ChannelForms';
import { channelSession, channelHref, ChannelUnavailable, type SourceSites } from '../shared';
export const dynamic='force-dynamic';
export default async function NewSource({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<{q?:string|string[]}>}) {
 const {tenantId}=await params,query=await searchParams,q=typeof query.q==='string'?query.q:'',session=await channelSession(tenantId);const retryHref=channelHref(`/tenant/${tenantId}/attendance/sources/new`,{q});if(!session || !session.access.can_manage) return <ChannelUnavailable tenantId={tenantId} retryHref={retryHref}/>;
 const {data,error}=await session.db.rpc('attendance_channel_mobile_site_lookup',{p_tenant:tenantId,p_search:q.slice(0,100),p_limit:20});if(error) return <ChannelUnavailable tenantId={tenantId} retryHref={retryHref}/>;
 return <PageFrame><div className="channel-page"><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance/sources`}>العودة إلى وسائل تسجيل الحضور</ButtonLink><div className="workspace-page-heading"><PageHeader  title={<>إضافة وسيلة تسجيل حضور</>} /></div><section className="workspace-form-panel"><SourceForm tenantId={tenantId} options={{employees:[],sites:[]}} siteOptions={data as SourceSites} initialSearch={q}/></section></div></PageFrame>;
}
