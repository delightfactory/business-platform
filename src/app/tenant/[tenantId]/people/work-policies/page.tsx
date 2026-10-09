import { Badge, ButtonLink, Card, Disclosure, EmptyState, PageHeader, Panel } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { saveWorkPolicyAction, setWorkPolicyActiveAction } from '../work-policy-actions';
import { WorkPolicyEditor } from './WorkPolicyEditor';
import { PolicyTask } from './PolicyTask';
import styles from '../people-management.module.css';
import { isUuid } from '../../leave/rules';

export const dynamic = 'force-dynamic';
type Policy = { id: string; code: string; is_active: boolean; head_version: number; name: string; schedule_kind: 'fixed' | 'flexible'; timezone_name: string; work_days: number[]; shift_start: string | null; shift_end: string | null; ends_next_day: boolean; break_minutes: number; fixed_break_start: string | null; fixed_break_end: string | null; flexible_halfday_break_minutes: number | null; required_minutes: number | null; earliest_punch: string | null; latest_punch: string | null; attribution_before_minutes: number; attribution_after_minutes: number; overtime_enabled: boolean; overtime_minimum_minutes: number; overtime_rounding_minutes: number; auto_approve_clean: boolean };
export default async function WorkPoliciesPage({ params, searchParams }: { params: Promise<{ tenantId: string }>; searchParams: Promise<{ state?: string; returnToRequest?: string }> }) {
 const { tenantId } = await params; const query = await searchParams; const supabase = await createSupabaseServerClient();
 const returnToRequest = isUuid(query.returnToRequest) ? query.returnToRequest : undefined;
 if (!supabase) return <PageFrame><Panel ><h1>تعذر فتح سياسات العمل</h1><p>تعذر الاتصال بالخدمة. أعد المحاولة لاحقًا.</p><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</ButtonLink></Panel></PageFrame>;
 const { data: { user } } = await supabase.auth.getUser(); if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people/work-policies`)}`);
 const { data, error } = await supabase.rpc('time_work_policy_catalog', { p_tenant_id: tenantId });
 if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <PageFrame><Panel ><h1>سياسات العمل غير متاحة</h1><p>تأكد من إتاحة وحدة الحضور وصلاحية العرض.</p><Link href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</Link></Panel></PageFrame>;
 const result = data as { items: Policy[]; can_manage: boolean };
 return <PageFrame>
  <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</ButtonLink>
  {returnToRequest && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/leave/requests/${returnToRequest}`}>العودة إلى طلب الإجازة</ButtonLink>}
  {query.state && <FeedbackToast key={query.state} message={stateMessage(query.state)} />}
  <PageHeader title={<>قوالب سياسات العمل</>} eyebrow={<>إعدادات الحضور</>} description={<>قوالب تحدد مواعيد الوردية أو مدة العمل المرنة، ويمكن إسنادها من ملف الموظف.</>} />
  {result.can_manage && <PolicyTask className="workspace-records-panel work-policy-create-panel" label="إنشاء قالب دوام"><div className="work-policy-panel-heading"><p>حدد نوع الجدول وأيامه ومواعيده قبل إتاحته للتعيين.</p></div>
   <WorkPolicyEditor tenantId={tenantId} action={saveWorkPolicyAction} returnToRequest={returnToRequest} />
  </PolicyTask>}
  <Panel className={styles.policyCatalog}><h2>القوالب المسجلة</h2>{result.items.length ? <div className={styles.policyGrid}>{result.items.map((policy)=><Card className={styles.policyCard} key={policy.id}>
   <div className="workspace-record-heading"><h3>{policy.name}</h3><Badge className={`entity-status ${policy.is_active?'is-active':'is-inactive'}`}>{policy.is_active?'متاح للتعيين':'موقوف'}</Badge></div>
   <p>الرمز: <bdi>{policy.code}</bdi> · الإصدار {policy.head_version} · {policy.schedule_kind==='fixed'?'وردية ثابتة':'ساعات مرنة'}</p>
   <p>{policy.schedule_kind==='fixed'?`${policy.shift_start} – ${policy.shift_end}${policy.ends_next_day?' (اليوم التالي)':''}`:`${policy.required_minutes} دقيقة متوقعة`} · {policy.timezone_name}</p>
   <Disclosure summary="نصف يوم الإجازة والإضافي والاعتماد">   <p>{policy.schedule_kind === 'fixed' ? policy.break_minutes === 0 ? 'نصف يوم الإجازة: وردية بلا استراحة' : policy.fixed_break_start && policy.fixed_break_end ? `استراحة نصف اليوم: ${policy.fixed_break_start.slice(0, 5)} – ${policy.fixed_break_end.slice(0, 5)}` : 'إعداد نصف يوم الإجازة غير مكتمل' : policy.flexible_halfday_break_minutes != null ? `استراحة العمل المتبقي مع نصف يوم إجازة: ${policy.flexible_halfday_break_minutes} دقيقة` : 'إعداد نصف يوم الإجازة غير مكتمل'}</p>
   <p>{policy.overtime_enabled ? `مرشح الإضافي مفعّل · حد ${policy.overtime_minimum_minutes} د · تقريب ${policy.overtime_rounding_minutes} د` : 'مرشح العمل الإضافي غير مفعّل'}</p>
   <p>{policy.auto_approve_clean ? 'الاعتماد التلقائي مفعّل للأيام المكتملة بلا استثناء بعد إغلاق نافذة التسجيل' : 'الاعتماد التلقائي غير مفعّل'}</p>
</Disclosure>
 {result.can_manage && <><PolicyTask className="work-policy-revision" label="تعديل القالب من تاريخ جديد">
      <p className="field-hint">تُحفظ التغييرات بإعدادات جديدة، وتبقى الإعدادات السابقة محفوظة.</p>
      <WorkPolicyEditor tenantId={tenantId} action={saveWorkPolicyAction} policy={policy} returnToRequest={returnToRequest} />
     </PolicyTask>
    <OfflineForm action={setWorkPolicyActiveAction}><input type="hidden" name="tenantId" value={tenantId}/><input type="hidden" name="policyId" value={policy.id}/><input type="hidden" name="active" value={String(!policy.is_active)}/><OfflineSubmitButton className="secondary-button" label={policy.is_active?'إيقاف التعيين الجديد':'إعادة إتاحة القالب'} pendingLabel="جارٍ تحديث إتاحة القالب…" /></OfflineForm></>}
  </Card>)}</div>:<EmptyState title="لم تُسجّل قوالب دوام بعد" description="تظهر القوالب المحفوظة هنا لتعيينها من ملفات الموظفين." />}</Panel>
 </PageFrame>;
}
function stateMessage(state:string){return ({'mapping-invalid':'راجع إعداد نصف اليوم: أوقات الاستراحة يجب أن تقع داخل الوردية وتساوي مدتها، واستراحة الدوام المرن بين صفر و360 دقيقة.',saved:'تم حفظ إصدار القالب.',activated:'تمت إتاحة القالب للتعيين.',deactivated:'أوقف القالب عن التعيينات الجديدة.',invalid:'تحقق من بيانات القالب.',forbidden:'لا تملك صلاحية إدارة سياسات الحضور.',setup:'إعداد الاتصال غير مكتمل.',failed:'تعذر حفظ التغيير؛ لم يُعتمد دون تسجيل تدقيق.'} as Record<string,string>)[state]??'تعذر إتمام الإجراء.'}
