import { PageHeader, Badge, Disclosure, RecordCard } from '@/components/ui';
import { Panel } from '@/components/ui';
import { ButtonLink } from '@/components/ui';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import Link from 'next/link';
import {redirect} from 'next/navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import {DraftForm} from './DraftForm';
import {selectedWorkspace,listWorkspace,releaseStatus,safeSourceUrl,type SelectedWorkspace,type ListWorkspace} from './dto';
import {operatorPermission} from '@/lib/operator-access';
import {NumericRulesSummary} from './NumericRules';
import {uuid} from '@/app/tenant/[tenantId]/payroll/rules';
export const dynamic='force-dynamic';
type Query={head?:string;after_created?:string;after_id?:string;before?:string};
type Workspace=Partial<SelectedWorkspace & ListWorkspace>;
const date=(v:string)=>new Intl.DateTimeFormat(ARABIC_DISPLAY_LOCALE,{timeZone:'Africa/Cairo',day:'numeric',month:'long',year:'numeric'}).format(new Date(v));
export default async function StatutoryDraftPage({searchParams}:{searchParams:Promise<Query>}){
 const q=await searchParams;const retry='/operator/statutory?'+new URLSearchParams(q).toString();
 const failure=(title:string,detail:string,denied=false)=><main className="app-shell"><Panel ><PageHeader  title={<>{title}</>} /><p role="alert">{detail}</p><ButtonLink variant="solid" href={retry} className={denied?undefined:"primary-button"}>إعادة المحاولة</ButtonLink> · <ButtonLink variant="ghost" href="/operator" className={denied?"primary-button":"secondary-button"}>العودة إلى تشغيل المنصة</ButtonLink></Panel></main>;
 if((q.head&&!uuid(q.head))||(q.after_id&&!uuid(q.after_id))||(q.after_created&&(!Number.isFinite(Date.parse(q.after_created))||q.after_created.length>64))||Boolean(q.after_created)!==Boolean(q.after_id)||(q.before&&!/^[1-9]\d{0,8}$/.test(q.before)))return failure('راجع رابط المسودة','تعذر التحقق من اختيار المسودة أو صفحة السجل.');
 const client=await createSupabaseServerClient();if(!client)return failure('تعذر الاتصال','أعد المحاولة لاستعادة المسودات؛ لا تُعرض البيانات المفقودة كقائمة فارغة.');
 const {data:{user}}=await getWorkspaceUser(client);if(!user)redirect('/auth/login?next='+encodeURIComponent(retry));
 const {data:allowed,error:accessError}=await client.rpc('current_operator_can_manage_statutory_rules');if(accessError)return failure('تعذر التحقق من الصلاحية','أعد المحاولة قبل مراجعة القواعد القانونية.');if(!operatorPermission({data:allowed,error:accessError}))return failure('إدارة القواعد القانونية غير متاحة','تحتاج مهمة الامتثال الممنوحة صراحةً؛ راجع مسؤول تشغيل المنصة.',true);
 const {data,error}=await client.rpc('statutory_draft_workspace',{p_head:q.head??null,p_after_created:q.after_created??null,p_after_id:q.after_id??null,p_before_revision:q.before?Number(q.before):null,p_limit:20});if(error)return failure('تعذر تحميل المسودات','تعذر قراءة الحالة الحالية؛ لا يمكن تأكيد حالة المسودة من هنا. أعد التحميل.');
 let w:Workspace;let issued=false;let releaseUnavailable=false;
 if(q.head){const parsed=selectedWorkspace(data,q.head);if(parsed.stale)return failure('تغيرت المسودة أثناء القراءة','أعد تحميل النسخة الحالية قبل متابعة المراجعة.');if(!parsed.value)return failure('تعذر التحقق من المسودة','تعذر قراءة النسخة المطلوبة وسجلها؛ لا يُعرض ذلك كقائمة فارغة.');w=parsed.value;
 const release=await client.rpc('statutory_draft_issuance_status',{p_head:q.head,p_expected:parsed.value.head.revision});
 if(release.error?.code==='42501')return failure('مراجعة الإصدار غير متاحة','تعذر السماح بقراءة حالة الإصدار؛ راجع مسؤول تشغيل المنصة قبل المتابعة.',true);
 if(release.error?.code==='PT409')return failure('تغيرت المسودة أثناء القراءة','أعد تحميل النسخة الحالية قبل متابعة المراجعة.');
 const status=release.error?null:releaseStatus(release.data,parsed.value.head.revision);issued=Boolean(status?.issued_pack);releaseUnavailable=!status;
 }else{const parsed=listWorkspace(data);if(!parsed)return failure('تعذر التحقق من المسودات','تعذر قراءة القائمة الحالية؛ لا تُعرض البيانات غير المتاحة كقائمة فارغة.');w=parsed;}

 return <main className="app-shell statutory-workspace"><header className="topbar"><Link className="brand" href="/operator">تشغيل المنصة</Link><ButtonLink variant="ghost" href="/operator" >العودة إلى المهام</ButtonLink></header>
 <Panel ><p className="eyebrow">الامتثال · الرواتب</p><PageHeader  title={<>القواعد القانونية للرواتب</>} /><p className="intro">احفظ نسخة مؤرخة ومراجعها، وراجع سجل تعديلاتها. المسودات غير مؤهلة لحساب الرواتب أو اعتماد الصرف.</p></Panel>
 {w.head&&w.current?<><Panel className="statutory-summary"><h2>{w.head.version}</h2><Badge as="p" className=" is-inactive">{releaseUnavailable?'حالة الإصدار غير مؤكدة':issued?'صدرت للضريبة والتأمين فقط؛ غير مؤهلة ماليًا':'مسودة غير مؤهلة'}</Badge>{releaseUnavailable&&<p role="alert">تعذر قراءة حالة الإصدار الحالية. <ButtonLink variant="solid" href={retry} >إعادة قراءة الحالة</ButtonLink></p>}<p>بداية السريان: {date(w.current.effective_from)}{w.current.effective_until&&<> · تتوقف من: {date(w.current.effective_until)}</>}</p><h3>المراجع المحفوظة</h3><ul>{w.current.source_references.map((s,i)=><li key={i}>{safeSourceUrl(s.url)?<a className="inline-action" href={s.url} target="_blank" rel="noopener noreferrer">{s.title}</a>:<span>{s.title}؛ رابط المرجع غير متاح.</span>}</li>)}</ul><NumericRulesSummary rules={w.current.numeric_rules}/><Link className="inline-action" href="/operator/statutory">العودة إلى المسودات</Link></Panel>
 <Panel className="statutory-task"><DraftForm key={w.head.id} actor={user.id} head={w.head.id} revision={w.head.revision} version={w.head.version} from={w.current.effective_from} until={w.current.effective_until} sources={w.current.source_references} numericRules={w.current.numeric_rules} issued={issued} secondary={releaseUnavailable} next={w.current.numeric_rules&&!issued&&!releaseUnavailable?'/operator/statutory/comparisons?head='+w.head.id:undefined}/></Panel>
 <Panel ><Disclosure summary={<>سجل التعديلات</>}><ul className="member-list">{w.history?.map(v=><RecordCard className="member-card" key={v.revision}><h3>النسخة المحفوظة {v.revision}</h3><p>{date(v.created_at)} · بداية السريان: {date(v.effective_from)} · {v.effective_until?<>تتوقف من: {date(v.effective_until)}</>:<>لا يوجد تاريخ توقف</>}</p><p>سبب الحفظ: {v.reason}</p><NumericRulesSummary rules={v.numeric_rules}/><ul>{v.source_references.map((s,i)=><li key={i}>{safeSourceUrl(s.url)?<a href={s.url} target="_blank" rel="noopener noreferrer">{s.title}</a>:<span>{s.title}؛ رابط المرجع غير متاح.</span>}</li>)}</ul></RecordCard>)}</ul>{w.next_before_revision&&<Link href={'/operator/statutory?'+new URLSearchParams({head:w.head.id,before:String(w.next_before_revision)})}>تعديلات أقدم</Link>}</Disclosure></Panel></>:<>
 <Panel ><h2>المسودات المحفوظة</h2>{w.items?.length?<ul className="member-list">{w.items.map(h=><RecordCard className="member-card" key={h.id}><h3>{h.version}</h3><p>نسخة محفوظة · بداية السريان: {date(h.effective_from)}</p><ButtonLink variant="ghost" href={'/operator/statutory?head='+encodeURIComponent(h.id)} >مراجعة المسودة وسجلها</ButtonLink></RecordCard>)}</ul>:<p>لا توجد مسودات محفوظة في هذه الصفحة. احفظ نسخة ومراجعها لبدء المراجعة.</p>}{w.next&&<Link href={'/operator/statutory?'+new URLSearchParams({after_created:w.next.created,after_id:w.next.id})}>مسودات أقدم</Link>}</Panel>
 <Panel ><DraftForm actor={user.id}/></Panel></>}
 </main>;
}
