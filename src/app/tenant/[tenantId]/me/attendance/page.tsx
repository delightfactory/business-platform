import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { channelReasonLabel, channelStateLabel, formatChannelInstant, type MobileSnapshot } from '@/lib/attendance-channel';
import { MobilePunch } from './MobilePunch';
export const dynamic='force-dynamic';
export default async function MyAttendance({params}:{params:Promise<{tenantId:string}>}) {
  const {tenantId}=await params;if(!/^[0-9a-f-]{36}$/i.test(tenantId)) notFound();
  const db=await createSupabaseServerClient();
  if(!db) return <PageFrame><section className="workspace-records-panel"><h1>حضوري</h1><p>تعذر الاتصال. أعد تحميل الصفحة عند عودة الاتصال.</p><Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة العمل</Link></section></PageFrame>;
  const {data:{user}}=await db.auth.getUser();if(!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/me/attendance`)}`);
  const {data,error}=await db.rpc('attendance_mobile_snapshot',{p_tenant:tenantId});
  const snapshot=!error && data?data as MobileSnapshot:null;
  return <PageFrame footer="الحضور الشخصي"><div className="channel-page"><header className="workspace-page-heading"><div><h1>حضوري</h1><p>سجّل الحضور أو الانصراف وراجع نتيجة محاولاتك.</p></div></header>
    {snapshot?<div className="channel-mobile-layout"><MobilePunch tenantId={tenantId} snapshot={snapshot}/><section className="workspace-records-panel"><h2>آخر المحاولات</h2>{snapshot.history.length===0?<p>لا توجد محاولات سابقة.</p>:<ul className="record-list">{snapshot.history.map(item=><li className="record-card" key={item.id}><div className="record-main"><h3>{item.direction==='in'?'حضور':'انصراف'} <span className="entity-status">{item.state==='accepted' && item.review_required?'مسجلة وتحتاج مراجعة':channelStateLabel(item.state)}</span></h3><p>{item.site_name??'موقع الحدث غير متاح'}</p><p><time dateTime={item.happened_at}>{formatChannelInstant(item.happened_at,item.timezone_name)}</time>{item.timezone_is_fallback && ' (UTC)'}</p>{item.reason && <p>{channelReasonLabel(item.reason)}</p>}{item.review_decision && <div className="form-message"><strong>{item.review_decision.decision==='exclude'?'استُبعدت الحركة بقرار مراجعة لاحق':'قُبلت الحركة بعد مراجعة الموقع'}</strong><p>المراجع: {item.review_decision.actor_label}</p><p>{item.review_decision.reason}</p><p>{formatChannelInstant(item.review_decision.created_at,item.review_decision.timezone_name)}{item.review_decision.timezone_name==='UTC'?' (UTC)':''}</p></div>}</div></li>)}</ul>}<p className="field-hint">آخر ٢٠ محاولة. تواصل مع الموارد البشرية إذا احتاج سجل الحضور تصحيحًا.</p></section></div>:<section className="workspace-records-panel"><h2>{error?.code==='42501'?'التسجيل غير متاح لحسابك':'تعذر تحميل الحضور'}</h2><p>{error?.code==='42501'?channelReasonLabel('permission'):'لم تُحمّل حالة حضورك. أعد المحاولة عند عودة الاتصال.'}</p>{error?.code!=='42501' && <Link className="secondary-button" href={`/tenant/${tenantId}/me/attendance`}>إعادة تحميل الصفحة</Link>}</section>}
    <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة العمل</Link></div></PageFrame>;
}
