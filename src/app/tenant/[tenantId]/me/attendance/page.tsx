import { Panel } from '@/components/ui';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient, getWorkspaceUser, readWorkspaceRpc } from '@/lib/workspace-access';
import { channelReasonLabel, readMobileSnapshot } from '@/lib/attendance-channel';
import { MobilePunch } from './MobilePunch';
import { AttendanceHistory } from './AttendanceHistory';
import { ButtonLink, PageHeader } from '@/components/ui';
import styles from './attendance.module.css';
export const dynamic='force-dynamic';
export default async function MyAttendance({params}:{params:Promise<{tenantId:string}>}) {
  const {tenantId}=await params;if(!/^[0-9a-f-]{36}$/i.test(tenantId)) notFound();
  const db=await getWorkspaceClient();
  if(!db) return <PageFrame><Panel className="workspace-records-panel"><PageHeader  title={<>حضوري</>} /><p>تعذر الاتصال. أعد تحميل الصفحة عند عودة الاتصال.</p><ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة العمل</ButtonLink></Panel></PageFrame>;
  const {data:{user}}=await getWorkspaceUser(db);if(!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/me/attendance`)}`);
  let response;
  try {
    response=await readWorkspaceRpc(db,'attendance_mobile_snapshot',tenantId,'p_tenant');
  } catch {
    response={data:null,error:{code:'READ_UNAVAILABLE'}};
  }
  const {data,error}=response;
  const snapshot=!error?readMobileSnapshot(data):null;
  return <PageFrame><PageHeader title="حضوري" description="سجّل يومك وراجع نتيجة كل محاولة." eyebrow="يومي" action={<ButtonLink variant="ghost" href={`/tenant/${tenantId}/me`} icon="arrowRight">العودة إلى يومي</ButtonLink>} />
    {snapshot ? <div className={styles.layout}><MobilePunch tenantId={tenantId} snapshot={snapshot}/><section className={`ui-card ${styles.panel}`}><h2>سجل المحاولات</h2><p className="field-hint">آخر 20 محاولة. لتصحيح سجل الحضور تواصل مع الموارد البشرية.</p><AttendanceHistory history={snapshot.history}/></section></div> : <section className="ui-card channel-read-state"><h2>{error?.code==='42501'?'التسجيل غير متاح لحسابك':'تعذر تحميل الحضور'}</h2><p>{error?.code==='42501'?channelReasonLabel('permission'):'لم تُحمّل حالة حضورك. أعد المحاولة عند عودة الاتصال.'}</p>{error?.code!=='42501' && <ButtonLink href={`/tenant/${tenantId}/me/attendance`}>إعادة تحميل الصفحة</ButtonLink>}</section>}
  </PageFrame>;
}
