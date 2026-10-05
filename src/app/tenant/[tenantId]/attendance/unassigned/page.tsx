import Link from 'next/link';
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { PageFrame } from '@/components/context-navigation';
import { SubmitButton } from '@/components/submit-button';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
type Evidence = { id:string; employee_id:string; source_employee_code:string; source_employee_name:string; site_id:string; source_site_name:string; direction:'in'|'out'; happened_at:string; source_event_key:string; created_at:string; resolved:boolean; work_instance_id:string|null; resolution_reason:string|null; resolved_at:string|null; candidate_work_dates?:string[]; date_resolution_status?:string };
type Search = Promise<{ cursor?:string; result?:string }>;

export default async function UnassignedAttendancePage({ params, searchParams }: { params: Promise<{tenantId:string}>; searchParams:Search }) {
  const {tenantId}=await params; const query=await searchParams; const cursor=query.cursor&&/^[0-9a-f-]{36}$/i.test(query.cursor)?query.cursor:null; const supabase=await createSupabaseServerClient();
  if(!supabase) return <PageFrame><section className="work-card task-page"><h1>تعذر الاتصال</h1></section></PageFrame>;
  const {data:{user}}=await supabase.auth.getUser(); if(!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/attendance/unassigned`)}`);
  const {data:access}=await supabase.rpc('time_attendance_access_snapshot',{p_tenant_id:tenantId});
  const {data,error}=await supabase.rpc('attendance_unassigned_evidence_queue',{p_tenant_id:tenantId,p_after:cursor,p_limit:50});
  if(error||!isObject(data)||!Array.isArray(data.items)) return <PageFrame><section className="work-card task-page"><h1>قائمة التسجيلات بلا تكليف غير متاحة</h1><p>تحقق من صلاحية الحضور ثم أعد المحاولة.</p></section></PageFrame>;
  const rows=data.items as Evidence[]; const hasMore=data.has_more===true; const nextCursor=typeof data.next_cursor==='string'?data.next_cursor:null; const canAttach=access?.entitlement_enabled===true&&(access?.can_manage===true||access?.can_correct===true);
  async function attach(formData:FormData){'use server';const tenant=String(formData.get('tenantId')??'');const evidence=String(formData.get('evidenceId')??'');const reason=String(formData.get('reason')??'').trim();const rawWorkDate=String(formData.get('workDate')??'').trim();const workDate=/^\d{4}-\d{2}-\d{2}$/.test(rawWorkDate)?rawWorkDate:null;const client=await createSupabaseServerClient();if(!client)redirect(`/tenant/${tenant}/attendance/unassigned?result=error`);const {error}=await client.rpc('attach_unassigned_attendance_evidence_for_date',{p_tenant_id:tenant,p_evidence_id:evidence,p_reason:reason,p_work_date:workDate});revalidatePath(`/tenant/${tenant}/attendance/unassigned`);const result=!error?'attached':error.message.includes('attendance_unassigned_work_date_required')?'ambiguous':error.message.includes('attendance_unassigned_assignment_unavailable')?'stale':'error';redirect(`/tenant/${tenant}/attendance/unassigned?result=${result}`);}
  return <PageFrame footer="مراجعة تسجيلات الحضور">
    <section className="work-card task-page attendance-review-page" aria-labelledby="unassigned-title">
      <Link className="back-link" href={`/tenant/${tenantId}/attendance`}>العودة إلى الحضور اليومي</Link>
      <div className="workspace-page-heading"><div><p className="eyebrow">أدلة محفوظة دون ربط تخميني</p><h1 id="unassigned-title">تسجيلات بلا تكليف</h1><p>هذه التسجيلات تخص موظفًا وفرعًا معروفين، لكن لا يوجد تكليف وسياسة دوام نافذان لوقتها. أصلح الفترة في ملف الموظف ثم أعد ربط التسجيل صراحةً.</p></div><Link className="secondary-button" href={`/tenant/${tenantId}/attendance/import`}>استيراد تسجيلات</Link></div>
      {access?.entitlement_enabled!==true&&<p className="form-message">وحدة الحضور غير مفعلة؛ السجل للقراءة فقط.</p>}
      {query.result==='attached'&&<p className="form-message" role="status">تم ربط التسجيل بسجل يوم العمل بعد إعادة التحقق من التكليف.</p>}
      {query.result==='ambiguous'&&<p className="form-message form-error" role="alert">يطابق وقت الحدث أكثر من يوم عمل. اختر تاريخ العمل المقصود من القائمة قبل الربط.</p>}
      {query.result==='stale'&&<p className="form-message form-error" role="alert">تغيرت الأيام المطابقة منذ عرض القائمة. حدّث الصفحة واختر من التواريخ الحالية.</p>}
      {query.result==='error'&&<p className="form-message form-error" role="alert">تعذر ربط التسجيل. أصلح التكليف وسياسة الدوام والفرع الفعال في تاريخ الحدث، ثم أعد المحاولة مع سبب واضح.</p>}
      {rows.length===0?<div className="empty-state"><h2>لا توجد تسجيلات معلقة</h2><p>ستظهر هنا التسجيلات التي لم تجد تكليفًا مطابقًا عند الاستيراد.</p></div>:<ul className="record-list">{rows.map((row)=><li className="record-card" key={row.id}><div className="record-main"><div className="record-title-row"><h2>{row.source_employee_name}</h2><span className={`entity-status ${row.resolved?'is-active':'is-inactive'}`}>{row.resolved?'تم الربط':'بانتظار المعالجة'}</span></div><p className="record-meta">الموظف <bdi>{row.source_employee_code}</bdi> · الفرع {row.source_site_name}</p><p className="record-meta">{row.direction==='in'?'دخول':'خروج'} · <bdi>{new Date(row.happened_at).toLocaleString('ar-EG',{timeZone:'Africa/Cairo'})}</bdi></p><p className="record-meta">معرّف المصدر: <bdi>{row.source_event_key}</bdi></p>{row.resolved&&<p className="record-meta">سجل اليوم: <bdi>{row.work_instance_id}</bdi> · سبب الربط: {row.resolution_reason}</p>}
        {!row.resolved&&<div className="workspace-form-actions"><Link className="secondary-button" href={`/tenant/${tenantId}/people/${row.employee_id}`}>مراجعة تكليف الموظف وسياسة دوامه</Link></div>}
        {!row.resolved&&canAttach&&<form action={attach} className="auth-form attendance-import-confirm-form"><input type="hidden" name="tenantId" value={tenantId}/><input type="hidden" name="evidenceId" value={row.id}/>{(row.candidate_work_dates?.length??0)>1&&<><label>اختر يوم العمل المقصود<select name="workDate" defaultValue="" required><option value="">اختر تاريخًا</option>{row.candidate_work_dates?.map((date)=><option key={date} value={date}>{date}</option>)}</select></label><p className="form-message form-error">يُطابق هذا التسجيل أكثر من يوم عمل؛ لن يُربط حتى تختار يومًا.</p></>}<label>سبب ربط التسجيل بعد مراجعة التكليف<textarea name="reason" minLength={3} maxLength={500} required rows={3} placeholder="اذكر ما تم التحقق منه"/></label><div className="workspace-form-actions"><SubmitButton label="إعادة الفحص وربط التسجيل" pendingLabel="جارٍ التحقق والربط…"/></div></form>}
      </div></li>)}</ul>}
      <div className="attendance-pagination"><span>عدد التسجيلات في هذه الصفحة: {rows.length}{hasMore?'، توجد تسجيلات أخرى':''}</span>{hasMore&&nextCursor&&<Link className="primary-button" href={`/tenant/${tenantId}/attendance/unassigned?cursor=${encodeURIComponent(nextCursor)}`}>التالي</Link>}</div>
    </section>
  </PageFrame>;
}
function isObject(value:unknown):value is Record<string,unknown>{return Boolean(value&&typeof value==='object'&&!Array.isArray(value));}
