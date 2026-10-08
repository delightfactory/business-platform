import Link from 'next/link';
import { PageFrame } from '@/components/context-navigation';
import { SourceForm } from '../ChannelForms';
import { channelSession, channelHref, ChannelUnavailable, type Options } from '../shared';
export const dynamic='force-dynamic';
export default async function NewSource({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<{q?:string}>}) {
 const {tenantId}=await params,{q=''}=await searchParams,session=await channelSession(tenantId);const retryHref=channelHref(`/tenant/${tenantId}/attendance/sources/new`,{q});if(!session || !session.access.can_manage) return <ChannelUnavailable tenantId={tenantId} retryHref={retryHref}/>;
 const {data,error}=await session.db.rpc('attendance_channel_options',{p_tenant:tenantId,p_search:q.slice(0,100),p_limit:20});if(error) return <ChannelUnavailable tenantId={tenantId} retryHref={retryHref}/>;
 return <PageFrame><div className="channel-page"><Link className="secondary-button" href={`/tenant/${tenantId}/attendance/sources`}>العودة إلى القنوات</Link><header className="workspace-page-heading"><h1>إضافة قناة حضور</h1></header><section className="workspace-form-panel"><p className="field-hint">قبل الإنشاء، تأكد من اعتماد موقع العمل وسياسة التحقق والاحتفاظ بدليل الموقع. إنشاء قناة خارجية لا يشغّل موصل جهاز تلقائيًا.</p><form method="get" className="channel-search"><label htmlFor="site-search">البحث عن موقع</label><input id="site-search" name="q" defaultValue={q} maxLength={100}/><button className="secondary-button">البحث عن الموقع</button></form><p className="field-hint">تظهر أول ٢٠ نتيجة. ابحث بالاسم إذا لم تجد الموقع.</p><SourceForm tenantId={tenantId} options={data as Options}/></section></div></PageFrame>;
}
