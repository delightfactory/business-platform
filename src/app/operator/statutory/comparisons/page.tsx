import { PageHeader } from '@/components/ui';
import { Panel } from '@/components/ui';
import { ButtonLink } from '@/components/ui';
import Link from 'next/link';
import {redirect} from 'next/navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import {uuid} from '@/app/tenant/[tenantId]/payroll/rules';
import {ComparisonForm} from './ComparisonForm';
import {ComparisonHistoryRow} from './ComparisonHistory';
import {selectedWorkspace,comparisonHistory,releaseStatus} from '../dto';
import {IssuanceStatus} from './IssuanceStatus';
export const dynamic='force-dynamic';
export default async function ComparisonPage({searchParams}:{searchParams:Promise<{head?:string;before?:string}>}){
 const q=await searchParams;const url='/operator/statutory/comparisons?'+new URLSearchParams(q);const failure=(detail:string)=><main className="app-shell"><Panel ><PageHeader  title={<>تعذر فتح مقارنة القواعد</>} /><p role="alert">{detail}</p><Link href={url}>إعادة المحاولة</Link> · <Link href="/operator/statutory">العودة إلى المسودات</Link></Panel></main>;
 if(!q.head||!uuid(q.head)||(q.before&&!/^[1-9][0-9]{0,14}$/.test(q.before)))return failure('راجع اختيار المسودة أو صفحة المقارنات.');
 const client=await createSupabaseServerClient();if(!client)return failure('تعذر الاتصال. أعد المحاولة بنفس الاختيار.');const {data:{user}}=await getWorkspaceUser(client);if(!user)redirect('/auth/login?next='+encodeURIComponent(url));
 const [workspace,history]=await Promise.all([client.rpc('statutory_draft_workspace',{p_head:q.head,p_limit:20}),client.rpc('statutory_draft_comparison_history',{p_head:q.head,p_before:q.before?Number(q.before):null,p_limit:20})]);
 if(workspace.error?.code==='42501'||history.error?.code==='42501')return failure('تحتاج مهمة إدارة القواعد القانونية الممنوحة صراحةً. راجع مسؤول تشغيل المنصة.');
 if(workspace.error||history.error||!workspace.data?.head||!history.data)return failure('تعذر تحميل المسودة أو المقارنات. لا تُعرض نتيجة التحميل كقائمة فارغة.');
 const parsed=selectedWorkspace(workspace.data,q.head),h=comparisonHistory(history.data);
 if(parsed.stale)return failure('تغيرت المسودة أثناء القراءة. أعد تحميل النسخة الحالية قبل مراجعة المقارنات.');
 if(!parsed.value||!h)return failure('تعذر التحقق من بيانات المسودة أو سجل المقارنات. لا تُعرض البيانات غير المتاحة كقائمة فارغة.');
 const w=parsed.value;
 if(h.current_revision!==w.head.revision||h.rows.some(row=>row.revision>w.head.revision))return failure('تغيرت نسخة القواعد أثناء القراءة. أعد تحميل الحالة الحالية.');
 const release=await client.rpc('statutory_draft_issuance_status',{p_head:q.head,p_expected:w.head.revision});
 if(release.error)return failure(release.error.code==='42501'?'تحتاج مهمة مراجعة القواعد القانونية.':release.error.code==='PT409'?'تغيرت القواعد أو أدلتها أثناء القراءة. أعد تحميل النسخة الحالية.':'تعذر التحقق من حالة التأهيل. أعد تحميل النسخة الحالية؛ لا يمكن اعتبارها جاهزة.');
 const status=releaseStatus(release.data,w.head.revision);if(!status)return failure('تعذر التحقق من حالة الإصدار. أعد تحميل النسخة الحالية؛ لا يمكن اعتبارها جاهزة.');
 return <main className="app-shell"><Panel ><ButtonLink variant="ghost" href={'/operator/statutory?head='+q.head} >العودة إلى المسودة</ButtonLink><p className="eyebrow">الامتثال · مراجعة القواعد</p><PageHeader  title={<>مقارنة الحساب بالنتائج المرجعية</>} /><h2>{w.head.version}</h2><p>المقارنات مرتبطة بنسخة القواعد وقت حفظها. تغيير القواعد يستلزم مقارنات جديدة؛ الحالات الاصطناعية لا تؤهل قواعد الصرف.</p></Panel>
 <IssuanceStatus status={status} head={q.head} actor={user.id}/>
 <Panel ><h2>نتائج المقارنات المحفوظة</h2>{h.rows.length?<ul className="member-list">{h.rows.map(row=><ComparisonHistoryRow key={row.id} row={row} currentRevision={w.head.revision}/>)}</ul>:<p>لا توجد مقارنات محفوظة في هذه الصفحة. أدخل حالة من المصدر المرجعي أو حالة اصطناعية للمراجعة المحلية.</p>}{h.next&&<Link href={'/operator/statutory/comparisons?'+new URLSearchParams({head:q.head,before:String(h.next)})}>مقارنات أقدم</Link>}</Panel>
 <Panel >{status.issued_pack?<><h2>أدلة هذه النسخة ثابتة</h2><Link href={'/operator/statutory?head='+q.head}>مراجعة المسودة لإنشاء نسخة جديدة عند الحاجة</Link></>:w.current.numeric_rules?<ComparisonForm head={w.head.id} revision={w.head.revision} actor={user.id} sources={w.current.source_references} secondary={status.ready}/>:<><h2>أدخل القواعد الرقمية أولًا</h2><Link href={'/operator/statutory?head='+q.head}>مراجعة بيانات المسودة</Link></>}</Panel></main>;
}
