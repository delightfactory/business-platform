import { ButtonLink, Message, PageHeader, Panel, RecordCard, Select, Textarea, EmptyState, Badge } from '@/components/ui';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import styles from '../attendance-channels.module.css';
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';

export const dynamic = 'force-dynamic';
type Evidence = { id:string; employee_id:string; source_employee_code:string; source_employee_name:string; site_id:string; source_site_name:string; direction:'in'|'out'; happened_at:string; source_event_key:string; created_at:string; resolved:boolean; work_instance_id:string|null; resolution_reason:string|null; resolved_at:string|null; candidate_work_dates?:string[]; date_resolution_status?:string };
type Search = Promise<{ cursor?:string; result?:string }>;

export default async function UnassignedAttendancePage({ params, searchParams }: { params: Promise<{tenantId:string}>; searchParams:Search }) {
  const {tenantId}=await params; const query=await searchParams; const cursor=query.cursor&&/^[0-9a-f-]{36}$/i.test(query.cursor)?query.cursor:null; const supabase=await createSupabaseServerClient();
  const retryHref=`/tenant/${tenantId}/attendance/unassigned${cursor?`?cursor=${encodeURIComponent(cursor)}`:''}`;
  if(!supabase) return <PageFrame><Panel className=" task-page"><PageHeader  title={<>تعذر الاتصال</>} /><ButtonLink  href={retryHref}>إعادة تحميل القائمة</ButtonLink></Panel></PageFrame>;
  const {data:{user}}=await getWorkspaceUser(supabase); if(!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/attendance/unassigned`)}`);
  const {data:access}=await supabase.rpc('time_attendance_access_snapshot',{p_tenant_id:tenantId});
  const {data,error}=await supabase.rpc('attendance_unassigned_evidence_queue',{p_tenant_id:tenantId,p_after:cursor,p_limit:50});
  if(error||!isObject(data)||!Array.isArray(data.items)) return <PageFrame><Panel className=" task-page"><PageHeader  title={<>قائمة التسجيلات بلا بيانات عمل غير متاحة</>} description={<> تحقق من صلاحية الحضور ثم أعد المحاولة. </>} /><ButtonLink  href={retryHref}>إعادة تحميل القائمة</ButtonLink></Panel></PageFrame>;
  const rows=data.items as Evidence[]; const hasMore=data.has_more===true; const nextCursor=typeof data.next_cursor==='string'?data.next_cursor:null; const canAttach=access?.entitlement_enabled===true&&(access?.can_manage===true||access?.can_correct===true);
  async function attach(formData:FormData){'use server';const tenant=String(formData.get('tenantId')??'');const evidence=String(formData.get('evidenceId')??'');const reason=String(formData.get('reason')??'').trim();const rawWorkDate=String(formData.get('workDate')??'').trim();const workDate=/^\d{4}-\d{2}-\d{2}$/.test(rawWorkDate)?rawWorkDate:null;const client=await createSupabaseServerClient();if(!client)redirect(`/tenant/${tenant}/attendance/unassigned?result=error`);const {error}=await client.rpc('attach_unassigned_attendance_evidence_for_date',{p_tenant_id:tenant,p_evidence_id:evidence,p_reason:reason,p_work_date:workDate});revalidatePath(`/tenant/${tenant}/attendance/unassigned`);const result=!error?'attached':error.message.includes('attendance_unassigned_work_date_required')?'ambiguous':error.message.includes('attendance_unassigned_assignment_unavailable')?'stale':'error';redirect(`/tenant/${tenant}/attendance/unassigned?result=${result}`);}
  return <PageFrame footer="مراجعة تسجيلات الحضور">
    <Panel className={` task-page attendance-review-page ${styles.queue}`} aria-labelledby="unassigned-title">
      <ButtonLink icon="arrowRight" variant="ghost"  href={`/tenant/${tenantId}/attendance`}>العودة إلى الحضور اليومي</ButtonLink>
      <div className="workspace-page-heading"><div><p className="eyebrow">أدلة محفوظة دون ربط تخميني</p><PageHeader id="unassigned-title" title={<>تسجيلات بلا بيانات عمل</>} description={<> هذه التسجيلات تخص موظفًا وفرعًا معروفين، لكن لم تكن بيانات العمل وسياسة الدوام سارية وقت التسجيل. أصلح الفترة في ملف الموظف ثم أعد ربط التسجيل صراحةً. </>} /></div><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance/import`}>استيراد تسجيلات</ButtonLink></div>
      <ol className={styles.steps} aria-label="خطوات معالجة التسجيل"><li>راجع بيانات عمل الموظف وسياسة دوامه في تاريخ الحركة.</li><li>اكتب سبب الربط، واختر يوم العمل إذا طُلب منك.</li><li>أعد الفحص والربط، ثم راجع النتيجة المسجلة.</li></ol>
      {access?.entitlement_enabled!==true&&<Message tone="info" >وحدة الحضور غير مفعلة؛ السجل للقراءة فقط.</Message>}
      {query.result==='attached'&&<Message tone="info"  role="status">تم ربط التسجيل بسجل يوم العمل بعد إعادة التحقق من بيانات العمل.</Message>}
      {query.result==='ambiguous'&&<Message tone="bad"  role="alert">يطابق وقت الحدث أكثر من يوم عمل. اختر تاريخ العمل المقصود من القائمة قبل الربط.</Message>}
      {query.result==='stale'&&<Message tone="bad"  role="alert">تغيرت الأيام المطابقة منذ عرض القائمة. حدّث الصفحة واختر من التواريخ الحالية.</Message>}
      {query.result==='error'&&<Message tone="bad"  role="alert">تعذر ربط التسجيل. أصلح بيانات العمل وسياسة الدوام والفرع الفعال في تاريخ الحدث، ثم أعد المحاولة مع سبب واضح.</Message>}
      {rows.length===0?<EmptyState title={<>لا توجد تسجيلات معلقة</>} description={<>ستظهر هنا التسجيلات التي لم تجد بيانات عمل مطابقة عند الاستيراد.</>} />:<ul className="record-list">{rows.map((row)=><RecordCard  key={row.id}><div className="record-main"><div className="record-title-row"><h2>{row.source_employee_name}</h2><Badge tone={row.resolved ? "ok" : "neutral"} >{row.resolved?'تم الربط':'بانتظار المعالجة'}</Badge></div><p className="record-meta">الموظف <bdi>{row.source_employee_code}</bdi> · الفرع {row.source_site_name}</p><p className="record-meta">{row.direction==='in'?'دخول':'خروج'} · <bdi>{new Date(row.happened_at).toLocaleString(ARABIC_DISPLAY_LOCALE,{timeZone:'Africa/Cairo'})}</bdi></p><p className="record-meta">معرّف المصدر: <bdi>{row.source_event_key}</bdi></p>{row.resolved&&<p className="record-meta">سجل اليوم: <bdi>{row.work_instance_id}</bdi> · سبب الربط: {row.resolution_reason}</p>}
        {!row.resolved&&<div className="workspace-form-actions"><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people/${row.employee_id}`}>مراجعة بيانات عمل الموظف وسياسة دوامه</ButtonLink></div>}
        {!row.resolved&&canAttach&&<OfflineForm action={attach} className="auth-form attendance-import-confirm-form"><input type="hidden" name="tenantId" value={tenantId}/><input type="hidden" name="evidenceId" value={row.id}/>{(row.candidate_work_dates?.length??0)>1&&<><label>اختر يوم العمل المقصود<Select name="workDate" defaultValue="" required><option value="">اختر تاريخًا</option>{row.candidate_work_dates?.map((date)=><option key={date} value={date}>{date}</option>)}</Select></label><Message tone="bad" >يُطابق هذا التسجيل أكثر من يوم عمل؛ لن يُربط حتى تختار يومًا.</Message></>}<label>سبب ربط التسجيل بعد مراجعة بيانات العمل<Textarea name="reason" minLength={3} maxLength={500} required rows={3} placeholder="اذكر ما تم التحقق منه"/></label><div className="workspace-form-actions"><OfflineSubmitButton label="إعادة الفحص وربط التسجيل" pendingLabel="جارٍ التحقق والربط…"/></div></OfflineForm>}
      </div></RecordCard>)}</ul>}
      <div className="attendance-pagination"><span>عدد التسجيلات في هذه الصفحة: {rows.length}{hasMore?'، توجد تسجيلات أخرى':''}</span>{hasMore&&nextCursor&&<ButtonLink  href={`/tenant/${tenantId}/attendance/unassigned?cursor=${encodeURIComponent(nextCursor)}`}>التالي</ButtonLink>}</div>
    </Panel>
  </PageFrame>;
}
function isObject(value:unknown):value is Record<string,unknown>{return Boolean(value&&typeof value==='object'&&!Array.isArray(value));}
