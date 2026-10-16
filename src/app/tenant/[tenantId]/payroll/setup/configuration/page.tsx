import type { ReactNode } from 'react';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { Badge, Button, ButtonLink, EmptyState, Field, Input, Message, PageHeader, Panel, RecordCard } from '@/components/ui';
import { getWorkspaceClient, getWorkspaceUser } from '@/lib/workspace-access';
import { generateElementCode } from '@/lib/element-code';
import { InputForm } from '../../inputs/InputForm';
import type { InputRecord } from '../../inputs/rules';
import { displayDate, uuid } from '../../rules';
import { validatePayrollPeriod } from '../../period-scope';
import styles from '../../payroll.module.css';

export const dynamic='force-dynamic';
function ConfigurationFrame({children}:{children:ReactNode}) {
  return <PageFrame><div dir="rtl" className={styles.workspace}>{children}</div></PageFrame>;
}
type Query=Record<string,string|undefined>;
type Workspace={access:Record<string,boolean>;employer_name:string;components:InputRecord[];has_more:boolean;policy:InputRecord|null;selected:InputRecord|null;component_open_ended_min:string|null;policy_open_ended_min:string|null};

export default async function ConfigurationPage({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<Record<string,string|string[]|undefined>>}) {
  const {tenantId}=await params;if(!uuid(tenantId))notFound();
  const raw=await searchParams;
  const query:Query=Object.fromEntries(Object.entries(raw).filter((entry):entry is [string,string]=>typeof entry[1]==='string'));
  const path=`/tenant/${tenantId}/payroll/setup/configuration`;
  const current=`${path}?${new URLSearchParams(query as Record<string,string>)}`;
  const failure=(message:string)=><ConfigurationFrame><PageHeader title="إعداد بنود وسياسة الرواتب"/><Message tone="bad" role="alert">{message}</Message><ButtonLink variant="ghost" href={current}>إعادة المحاولة</ButtonLink><ButtonLink variant="ghost" href={path}>فتح الإعداد من البداية</ButtonLink></ConfigurationFrame>;
  const client=await getWorkspaceClient();if(!client)return failure('تعذر الاتصال. أعد المحاولة بنفس اختياراتك.');
  const {data:{user}}=await getWorkspaceUser(client);if(!user)redirect(`/auth/login?next=${encodeURIComponent(current)}`);
  if(['employer','head','after'].some(key=>raw[key]!==undefined&&(typeof raw[key]!=='string'||!uuid(query[key]??'')))
    || (query.kind&&!['component','policy'].includes(query.kind)) || (query.tab&&!['components','policy'].includes(query.tab)) || (query.view&&query.view!=='record')
    || (query.config_q?.length??0)>120 || (query.employer_q?.length??0)>120
    || (query.after_name?.length??0)>160 || (query.after_id&&!uuid(query.after_id)))return failure('راجع رابط الجهة أو البند ثم افتح الإعداد من البداية.');
  const employers=await client.rpc('payroll_input_employers',{p_tenant:tenantId,p_query:query.employer_q??'',p_after_name:query.after_name??null,p_after_id:query.after_id??null});
  if(employers.error||!employers.data)return failure('تعذر تحميل جهات العمل أو لم تعد لديك صلاحية. راجع مسؤول الشركة أو أعد المحاولة.');
  const employer=query.choose_employer==='1'?'':query.employer??employers.data.unique_employer??'';
  if(!employer)return <ConfigurationFrame><PageHeader title="اختر جهة العمل" description="بنود الراتب تخص الجهة؛ سياسة احتساب الفترة تخص الشركة كلها."/>
    <Panel><form method="get" action={path} className={styles.configurationSearch}><input type="hidden" name="choose_employer" value="1"/><Field id="configuration-employer-search" label="ابحث عن جهة العمل"><Input id="configuration-employer-search" name="employer_q" defaultValue={query.employer_q??''} maxLength={120} placeholder="مثال: شركة النور"/></Field><Button variant="ghost" type="submit">بحث</Button></form>
      {!employers.data.items.length?<EmptyState title="لا توجد جهة مطابقة" description="جرّب اسمًا آخر أو راجع جهات العمل مع مسؤول الشركة."/>:<ul className="record-list">{employers.data.items.map((item:{id:string;name:string})=><RecordCard key={item.id}><h2>{item.name}</h2><ButtonLink variant="ghost" href={`${path}?${new URLSearchParams({employer:item.id})}`}>فتح إعداد الجهة</ButtonLink></RecordCard>)}</ul>}
      {employers.data.items.length===30&&<ButtonLink variant="ghost" href={`${path}?${new URLSearchParams({choose_employer:'1',employer_q:query.employer_q??'',after_name:employers.data.items[29].name,after_id:employers.data.items[29].id})}`}>جهات إضافية</ButtonLink>}
    </Panel></ConfigurationFrame>;
  const result=await client.rpc('payroll_configuration_workspace',{p_tenant:tenantId,p_employer:employer,p_after:query.after??null,p_head:query.head??null,p_query:query.config_q??'',p_limit:30});
  if(result.error||!result.data)return failure(result.error?.code==='42501'?'هذا الحساب لا يملك صلاحية مراجعة إعدادات الرواتب لهذه الجهة. تواصل مع مسؤول الشركة.':result.error?.code==='P0002'?'البند المطلوب لا يخص هذه الجهة أو لم يعد متاحًا. افتح الإعداد من البداية.':'تعذر تحميل إعدادات الجهة. بقيت اختياراتك في الرابط.');
  const work=result.data as Workspace;
  const returnContext:Record<string,string>={};
  if(uuid(query.return_period??'')) {
    const periods=await client.rpc('payroll_input_periods',{p_tenant:tenantId,p_employer:employer});
    if(!periods.error&&Array.isArray(periods.data)&&await validatePayrollPeriod(client,tenantId,employer,query.return_period!,periods.data,'input')==='valid')returnContext.return_period=query.return_period!;
  }
  if(returnContext.return_period) {
    if(query.return_q&&(query.return_q.length<=120))returnContext.return_q=query.return_q;
    for(const key of ['review_view','review_q','review_after','review_employee']) {
      const value=query[key];if(value&&(key==='review_view'?value==='all'||value==='attention':key==='review_q'?value.length<=120:uuid(value)))returnContext[key]=value;
    }
  }
  const href=(extra:Record<string,string>={})=>`${path}?${new URLSearchParams(Object.fromEntries(Object.entries({employer,...returnContext,...(query.config_q?{config_q:query.config_q}:{}),...extra}).filter(([,value])=>value!=='')))}`;
  const policyTab=query.tab==='policy'||query.kind==='policy'||work.selected?.kind==='policy';
  if(work.selected&&query.kind&&work.selected.kind!==query.kind)return failure('نوع البند في الرابط لا يطابق السجل. افتح الإعداد من البداية.');
  const record=work.selected?.kind==='component'?work.selected:undefined;
  const editor=!policyTab&&(query.kind==='component'||Boolean(record));
  const canEdit=work.access.enabled&&work.access['payroll_config.manage']===true;
  const editingRecord=canEdit&&query.view!=='record';
  const setup=`/tenant/${tenantId}/payroll/setup?${new URLSearchParams({employer})}`;
  const back=href(policyTab?{tab:'policy'}:{after:query.after??''});
  const periodReturn=returnContext.return_period?`/tenant/${tenantId}/payroll/inputs?${new URLSearchParams({employer,period:returnContext.return_period,...(returnContext.return_q?{q:returnContext.return_q}:{}),...Object.fromEntries(Object.entries(returnContext).filter(([key])=>key.startsWith('review_')))})}`:null;
  return <ConfigurationFrame>
    <PageHeader title={editor?(record?(editingRecord?'إصدار جديد لبند الراتب':'تفاصيل بند الراتب'):'إضافة بند راتب'):'إعداد بنود وسياسة الرواتب'} description={work.employer_name}/>
    <nav className={styles.reviewNavigation} aria-label="العودة من إعداد الرواتب"><ButtonLink variant="ghost" href={setup}>إعداد رواتب الجهة</ButtonLink>{periodReturn&&<ButtonLink variant="ghost" href={periodReturn}>العودة إلى بيانات الفترة</ButtonLink>}{employers.data.unique_employer!==employer&&<ButtonLink variant="ghost" href={`${path}?choose_employer=1`}>تغيير جهة العمل</ButtonLink>}</nav>
    {!work.access['payroll_config.manage']&&<Message tone="info">عرض فقط. تعديل الإعدادات من اختصاص مدير إعداد الرواتب.</Message>}
    {!work.access.enabled&&<Message tone="info">خدمة الرواتب موقوفة. الإعدادات المحفوظة متاحة للمراجعة؛ تواصل مع مسؤول الشركة لتفعيل الخدمة قبل التعديل.</Message>}
    {!editor&&<nav className={styles.configurationTabs} aria-label="إعدادات الرواتب"><ButtonLink variant="ghost" href={href()} aria-current={!policyTab?'page':undefined}>بنود رواتب الجهة</ButtonLink><ButtonLink variant="ghost" href={href({tab:'policy'})} aria-current={policyTab?'page':undefined}>سياسة احتساب الفترة للشركة</ButtonLink></nav>}
    {editor?<Panel>
      {record&&<p>الإصدار المحفوظ {record.revision} يبدأ {displayDate(record.effective_from)}{record.effective_until?` وينتهي قبل ${displayDate(record.effective_until)}`:''}. {editingRecord?'التعديل يُحفظ كإصدار جديد بتاريخ أحدث؛ يبقى التاريخ السابق محفوظًا.':''}</p>}
      {record&&query.view==='record'&&canEdit&&<ButtonLink href={href({kind:'component',head:record.id})}>إنشاء إصدار جديد</ButtonLink>}
      <InputForm key={`${employer}:${record?.id??'new'}:${editingRecord?'editor':`record:${record?.revision??0}`}`} tenant={tenantId} employer={employer} period={null} configuration={{openEndedMinimum:work.component_open_ended_min}} kind="component" record={record} employees={[]} components={[]} canSave={editingRecord} canApprove={false} suggestedCode={record?'':generateElementCode('PAY')} back={back}/>
    </Panel>:policyTab?<Panel>
      <h2>سياسة الشركة كلها</h2><p>تحدد طريقة احتساب الجزء من فترة الراتب لكل جهات الشركة، مرة واحدة. ليست إعدادًا لفترة بعينها.</p>
      {work.policy?<><Badge tone="neutral">محفوظة</Badge><dl><dt>طريقة الاحتساب</dt><dd>{work.policy.data.mode==='fixed_30_day'?'على أساس 30 يومًا':work.policy.data.mode==='calendar_days'?'بحسب أيام التقويم':'القيمة المحفوظة تحتاج مراجعة'}</dd><dt>يسري من</dt><dd>{displayDate(work.policy.effective_from)}</dd>{work.policy.effective_until&&<><dt>تنتهي قبل</dt><dd>{displayDate(work.policy.effective_until)} — بعد هذا التاريخ لا تكتمل مراجعة الرواتب لعدم تغطية السياسة.</dd></>}<dt>سبب التحديد</dt><dd>{String(work.policy.data.reason??'غير متاح')}</dd></dl><p>السياسة محددة بالفعل؛ لا يمكن تغييرها من هذه الصفحة. يبقى القرار المحفوظ قابلًا للمراجعة.</p></>:canEdit?<InputForm tenant={tenantId} employer={employer} period={null} configuration={{openEndedMinimum:work.policy_open_ended_min}} kind="policy" employees={[]} components={[]} canSave canApprove={false} suggestedCode="" back={href({tab:'policy'})}/>:<EmptyState title="لم تُحدد سياسة الشركة" description="اطلب من مدير إعداد الرواتب تحديد السياسة بعد مراجعتها."/>}
    </Panel>:<Panel>
      <div className={styles.configurationToolbar}><h2>بنود راتب {work.employer_name}</h2>{canEdit&&<ButtonLink href={href({kind:'component'})}>إضافة بند راتب</ButtonLink>}</div>
      <form method="get" action={path} className={styles.configurationSearch}><input type="hidden" name="employer" value={employer}/>{Object.entries(returnContext).map(([key,value])=><input key={key} type="hidden" name={key} value={value}/>)}<Field id="configuration-search" label="ابحث باسم البند أو رمزه"><Input id="configuration-search" name="config_q" defaultValue={query.config_q??''} maxLength={120} placeholder="مثال: بدل انتقال"/></Field><Button type="submit" variant="ghost">بحث</Button></form>
      {!work.components.length?<EmptyState title={query.config_q?'لا توجد بنود مطابقة':'لا توجد بنود رواتب لهذه الجهة'} description={query.config_q?'جرّب اسمًا أو رمزًا آخر.':canEdit?'أضف أول بند راتب.':'اطلب من مدير إعداد الرواتب إضافة البنود.'}/>:<ul className="record-list">{work.components.map(item=><RecordCard key={item.id}><div><h3>{String(item.data.name??'بند راتب')}</h3><p><bdi>{String(item.data.key??'')}</bdi> · {item.data.active===true?'مفعّل':'غير مفعّل'}</p><p>محفوظ — يسري من {displayDate(item.effective_from)}{item.effective_until?` إلى ما قبل ${displayDate(item.effective_until)}`:''}</p></div><ButtonLink variant="ghost" href={href({kind:'component',head:item.id,after:query.after??''})}>{canEdit?'عرض وتعديل':'عرض التفاصيل'}</ButtonLink></RecordCard>)}</ul>}
      {(query.after||work.has_more)&&<nav className={styles.reviewNavigation} aria-label="صفحات بنود الراتب">{query.after&&<ButtonLink variant="ghost" href={href()}>أول صفحة</ButtonLink>}{work.has_more&&work.components.length>0&&<ButtonLink variant="ghost" href={href({after:work.components.at(-1)!.id})}>بنود إضافية</ButtonLink>}</nav>}
    </Panel>}
  </ConfigurationFrame>;
}
