import Link from 'next/link';
import styles from '../attendance-channels.module.css';
import { PageFrame } from '@/components/context-navigation';
import { formatChannelInstant } from '@/lib/attendance-channel';
import { channelOffset, channelHref, ChannelPager, channelSession, ChannelUnavailable, type Source } from './shared';
export const dynamic='force-dynamic';
export default async function SourcesPage({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<{offset?:string}>}) {
 const {tenantId}=await params,query=await searchParams,offset=channelOffset(query.offset),session=await channelSession(tenantId);
 const retryHref=channelHref(`/tenant/${tenantId}/attendance/sources`,{offset});
 if(!session) return <ChannelUnavailable tenantId={tenantId} retryHref={retryHref}/>;
 const {data,error}=await session.db.rpc('attendance_channel_sources',{p_tenant:tenantId,p_limit:20,p_offset:offset});if(error) return <ChannelUnavailable tenantId={tenantId} retryHref={retryHref}/>;
 const items=(data?.items??[]) as Source[];const attention=(s:Source)=>Number(s.unmapped_count??0)+Number(s.retry_count??0)+Number(s.review_count??0);
 items.sort((a,b)=>attention(b)-attention(a));
 return <PageFrame><div className="channel-page"><header className="workspace-page-heading"><div><h1>قنوات الحضور</h1><p>افتح القناة لاستكمال الربط أو مراجعة الحركات، أو أضف قناة جديدة.</p></div>{session.access.can_manage && <Link className="primary-button" href={`/tenant/${tenantId}/attendance/sources/new`}>إضافة قناة</Link>}</header>
 {!session.access.capture_enabled && <p className="form-message">خدمة الحضور غير مفعلة. السجل متاح، وتحتاج الإجراءات الجديدة تفعيل الخدمة.</p>}
 <section className="workspace-records-panel"><h2>القنوات وحالة المعالجة</h2>{!items.length?<p>لا توجد قنوات. أضف قناة بعد اعتماد موقعها وسياسة الخصوصية.</p>:<ul className={`record-list ${styles.catalog}`}>{items.map(s=><li className="record-card" key={s.id}><div className="record-main"><h3>{s.name} <span className="entity-status">{!s.enabled?'موقوفة':attention(s)?'تحتاج متابعة':'مفعّلة'}</span></h3><p>{s.kind==='mobile'?'حضور الهاتف':'مصدر خارجي'} · {s.site_name??'الموقع يُحدد بالربط'}</p><p>تحتاج ربطًا: {s.unmapped_count??0} · تحتاج معالجة: {s.retry_count??0} · مراجعة الموقع: {s.review_count??0}</p>{s.last_success && <p>آخر تسجيل ناجح: {formatChannelInstant(s.last_success,'UTC')} (UTC)</p>}{s.last_failure && <p>آخر تعثر: {formatChannelInstant(s.last_failure,'UTC')} (UTC)</p>}<p className="field-hint">{attention(s)?'افتح السجل لاستكمال الربط أو المعالجة أو المراجعة.':'افتح السجل لمراجعة الحركات والإعدادات.'}</p></div><Link className="secondary-button" href={`/tenant/${tenantId}/attendance/sources/${s.id}`}>فتح القناة</Link></li>)}</ul>}<ChannelPager href={`/tenant/${tenantId}/attendance/sources`} offset={offset} more={data?.has_more===true}/></section>
 <p className="field-hint">الأولوية للحركات التي تحتاج متابعة ضمن هذه الصفحة. القنوات الخارجية لا تعني اعتماد موصل لأي جهاز بعينه.</p></div></PageFrame>;
}
