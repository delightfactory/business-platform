import { Badge, ButtonLink, DataTable, Disclosure, EmptyState, Message, Panel } from '@/components/ui';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import { isCivilDate } from '@/lib/attendance-calendar';
import { displayDate } from '../../payroll/rules';

export const activityKinds = ['attendance', 'leave', 'payroll', 'advances'] as const;
export type ActivityKind = typeof activityKinds[number];
export type ActivityItem = {
  id: string; employment_id?: string; employer_id: string; date: string; end_date?: string | null; state: string;
  type_name?: string; total_units?: number | string; principal?: number | string; outstanding?: number | string;
  output_id?: string; period_id?: string; net?: number | string; superseded?: boolean; employment_ids?: string[];
  first_in?: string | null; last_out?: string | null; worked_minutes?: number | null;
};
export type ActivityPage = { kind: ActivityKind; employee_id: string; items: ActivityItem[]; has_more: boolean; next_after: string | null };
export type ActivityResult = { page: ActivityPage | null; forbidden: boolean };
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const activityLabels: Record<ActivityKind, string> = { attendance: 'الحضور', leave: 'الإجازات', payroll: 'الرواتب', advances: 'السلف' };

export function readActivity(data: unknown, employeeId: string, kind: ActivityKind): ActivityPage | null {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return null;
  const page = data as Record<string, unknown>;
  if (page.kind !== kind || page.employee_id !== employeeId || !Array.isArray(page.items) || page.items.length > 20
    || typeof page.has_more !== 'boolean' || !(page.next_after === null || typeof page.next_after === 'string' && uuid.test(page.next_after))) return null;
  for (const item of page.items) {
    if (!item || typeof item !== 'object' || typeof item.id !== 'string' || !uuid.test(item.id)
      || typeof item.employer_id !== 'string' || !uuid.test(item.employer_id) || typeof item.date !== 'string'
      || typeof item.state !== 'string') return null;
  }
  if (page.has_more && !page.next_after) return null;
  return page as unknown as ActivityPage;
}

export function EmployeeActivity({ tenantId, employeeId, kind, result, after }: {
  tenantId: string; employeeId: string; kind: ActivityKind; result: ActivityResult; after?: string;
}) {
  const profile = `/tenant/${tenantId}/people/${employeeId}`;
  const currentHref = `${profile}?${new URLSearchParams({ tab: kind, ...(after ? { activityAfter: after } : {}) })}`;
  const title = kind === 'payroll' ? 'مسيرات الرواتب المحفوظة' : activityLabels[kind];
  if (!result.page) return <Panel><h2>{title}</h2><Message tone={result.forbidden ? 'info' : 'warn'}>
    {result.forbidden ? `عرض ${activityLabels[kind]} يحتاج إلى صلاحية هذه الخدمة. اطلبها من مدير الشركة عند الحاجة.` : 'تعذر تحميل السجل. أعد المحاولة؛ لا نعُد السجل فارغًا قبل التحقق.'}
  </Message>{!result.forbidden && <ButtonLink href={currentHref} variant="ghost">إعادة المحاولة</ButtonLink>}</Panel>;
  const page = result.page;
  return <Panel><div className="workspace-page-heading"><div><h2>{title}</h2><p className="record-meta">سجلات هذا الموظف، من الأحدث إلى الأقدم.{kind === 'attendance' && ' الأوقات بتوقيت القاهرة.'}</p></div></div>
    {!page.items.length ? <EmptyState title="لا توجد سجلات في هذا العرض" description={after ? 'عُد إلى بداية السجل لعرض أحدث النتائج.' : kind === 'payroll' ? 'تظهر هنا مسيرات الموظف بعد حفظها نهائيًا.' : 'تظهر السجلات هنا بعد تسجيلها في الخدمة.'} />
      : <div className="workspace-table-wrap"><DataTable className="workspace-record-table"><caption className="ui-sr">{title}</caption><thead><tr><th scope="col">التاريخ</th><th scope="col">التفاصيل</th><th scope="col">الحالة</th><th scope="col">السجل</th></tr></thead><tbody>{page.items.map(item => <tr key={item.id}>
        <th scope="row"><bdi>{activityDate(item.date)}</bdi>{item.end_date && item.end_date !== item.date && <> – <bdi>{activityDate(item.end_date)}</bdi></>}</th>
        <td>{kind === 'leave' ? <>{item.type_name ?? 'إجازة'}{item.total_units !== undefined && <> · {number(item.total_units)} يوم</>}</> : kind === 'advances' ? <>المبلغ {money(item.principal)} · المتبقي {money(item.outstanding)}</> : kind === 'payroll' ? <>صافي الموظف {money(item.net)}</> : <>{item.first_in ? `دخول ${time(item.first_in)}` : 'لم يُسجل دخول'}{item.last_out && <> · خروج {time(item.last_out)}</>}{item.worked_minutes !== null && item.worked_minutes !== undefined && <> · {number(item.worked_minutes)} دقيقة</>}</>}</td>
        <td><Badge tone={['approved', 'final', 'closed', 'paid'].includes(item.state) ? 'ok' : 'neutral'}>{activityState(item.state)}</Badge></td>
        <td>{kind==='payroll'&&item.employment_ids&&item.employment_ids.length>1?<Disclosure summary="عرض أجزاء الراتب"><p>يتضمن هذا المسير أكثر من فترة عمل للموظف.</p>{item.employment_ids.map((employment,index)=><ButtonLink key={employment} variant="ghost" href={activityHref(tenantId,kind,item,currentHref,employment)}>عرض الجزء {index+1}</ButtonLink>)}</Disclosure>:<ButtonLink variant="ghost" href={activityHref(tenantId, kind, item, currentHref)}>{kind === 'payroll' ? 'عرض راتب الموظف' : 'فتح السجل'}</ButtonLink>}</td>
      </tr>)}</tbody></DataTable></div>}
    <nav className="workspace-form-actions" aria-label={`صفحات ${activityLabels[kind]}`}>
      {after && <ButtonLink variant="ghost" href={`${profile}?tab=${kind}`}>أحدث السجلات</ButtonLink>}
      {page.has_more && page.next_after && <ButtonLink variant="ghost" href={`${profile}?${new URLSearchParams({ tab: kind, activityAfter: page.next_after })}`}>سجلات أقدم</ButtonLink>}
    </nav>
  </Panel>;
}

function activityHref(tenantId: string, kind: ActivityKind, item: ActivityItem, returnTo: string, selectedEmployment?:string) {
  const base = `/tenant/${tenantId}`;
  if (kind === 'attendance') return `${base}/attendance/${item.id}?${new URLSearchParams({ return: returnTo })}`;
  if (kind === 'leave') return `${base}/leave/requests/${item.id}?${new URLSearchParams({ return: returnTo })}`;
  if (kind === 'advances') return `${base}/payroll/advances?${new URLSearchParams({ employer: item.employer_id, advance: item.id, return: returnTo })}`;
  return `${base}/payroll/output?${new URLSearchParams({ employer: item.employer_id, output: item.output_id ?? item.id, ...(item.period_id ? { period: item.period_id } : {}), ...(selectedEmployment?{employment:selectedEmployment}:item.employment_ids?.length === 1 ? { employment: item.employment_ids[0] } : {}), return: returnTo })}`;
}
function number(value: unknown) { const amount = typeof value === 'string' && value.trim() !== '' ? Number(value) : value; return typeof amount === 'number' && Number.isFinite(amount) ? new Intl.NumberFormat(ARABIC_DISPLAY_LOCALE, { maximumFractionDigits: 2 }).format(amount) : 'غير متاح'; }
function activityDate(value: string) { return isCivilDate(value) ? displayDate(value) : 'غير متاح'; }
function time(value: string) { const instant = new Date(value); return Number.isFinite(instant.getTime()) ? new Intl.DateTimeFormat(ARABIC_DISPLAY_LOCALE, { timeZone: 'Africa/Cairo', hour: '2-digit', minute: '2-digit' }).format(instant) : 'غير متاح'; }
function money(value: unknown) { const amount = typeof value === 'string' && value.trim() !== '' ? Number(value) : value; return typeof amount === 'number' && Number.isFinite(amount) ? `${number(amount)} جنيه` : 'غير متاح'; }
function activityState(state: string) { return ({ open: 'قيد المتابعة', ready: 'جاهز للمراجعة', needs_review: 'يحتاج مراجعة', approved: 'معتمد', submitted: 'بانتظار القرار', withdrawn: 'مسحوب', rejected: 'مرفوض', cancelled: 'ملغى', draft: 'مسودة', final: 'محفوظ نهائيًا', superseded: 'استُبدل بمسير أحدث', active: 'جارٍ السداد', paid: 'مصروف', closed: 'اكتمل السداد', settled: 'اكتمل السداد', record_corrected: 'صُحح سجل الصرف', requested: 'طلب جديد', disbursed: 'مصروف' } as Record<string, string>)[state] ?? 'راجع تفاصيل السجل'; }
