'use client';
import {useActionState,useState} from 'react';
import {useRouter} from 'next/navigation';
import {Button,ButtonLink,Disclosure,Field,Input,Select,Message} from '@/components/ui';
import {useOfflineSubmission} from '@/components/offline-submission';
import {prepareEgyptEmployee,type EgyptState} from './actions';
import {displayDate} from '../../rules';
import styles from '../../payroll.module.css';
type Saved={id:string;revision:number;status:string;effective_from:string;data:Record<string,string|number>};
export type EgyptContext={locked:boolean;stamp:string;starts_on:string;ends_on:string;employment_start:string;pay_basis:string;single_month:boolean;full_month:boolean;suggested_duration:number|null;pack:{version:string;category:string;minimum:number;maximum:number}|null;context:Saved|null;opening:Saved|null;prior_final:boolean;policy_exists:boolean};
export function EgyptForm({tenant,employer,period,employment,facts,advanced,review,profileHref,openingHref,readOnly=false}:{tenant:string;employer:string;period:string;employment:string;facts:EgyptContext;advanced:string;review:string;profileHref?:string;openingHref?:string;readOnly?:boolean}){
 const router=useRouter();
 const current=facts.context?.data;
 const [insured,setInsured]=useState(String(current?.insurance_status??''));
 const [state,action,pending]=useActionState(async(previous:EgyptState,form:FormData)=>{
  const result=await prepareEgyptEmployee(previous,form);
  if(result.saved&&profileHref){
   const destination=new URL(profileHref,window.location.origin);
   if(destination.origin===window.location.origin&&destination.pathname===window.location.pathname&&destination.searchParams.get('tab')==='compensation'){
    destination.searchParams.set('payrollSaved',result.attempt);
    destination.searchParams.set('payrollPeriod',period);
    router.replace(destination.pathname+destination.search,{scroll:false});
   }
  }
  return result;
 },{saved:false,error:'',attempt:'',signature:''});
 const {offline,blockOfflineSubmission}=useOfflineSubmission();
 const needsOpening=!facts.opening&&!facts.prior_final;
 const [prior,setPrior]=useState('');
 const sameScope=current?.calculation_from===facts.starts_on&&current?.calculation_until===facts.ends_on;
 if(state.saved)return <section aria-label="نتيجة تجهيز الموظف"><Message tone="ok" role="status">حُفظت بيانات الموظف. الأرصدة السابقة المحفوظة لم تتغير. راجع نتيجة الحساب قبل الاعتماد.</Message>{profileHref?<Button type="button" onClick={()=>router.refresh()}>عرض البيانات المحفوظة</Button>:<ButtonLink href={review}>حساب ومراجعة الرواتب</ButtonLink>}<ButtonLink variant="ghost" href={profileHref?review:advanced+'&kind=statutory_context&head='+(state.head??'')}>{profileHref?'فتح مسير الفترة':'عرض البيانات المحفوظة وتعديلها'}</ButtonLink></section>;
 if(!facts.single_month||!facts.pack)return <Message tone="warn">{!facts.single_month?'الفترة تشمل أكثر من شهر. افتح بيانات الضريبة والتأمينات لتحديد ما يخص كل شهر.':'الأساس المصري غير جاهز لهذه الفترة. اطلب من إدارة المنصة مراجعة إعدادات الحساب.'} <ButtonLink variant="ghost" href={advanced}>فتح بيانات الضريبة والتأمينات</ButtonLink></Message>;
 const frozen=readOnly||facts.locked||Boolean(facts.context&&['applied','cancelled'].includes(facts.context.status));
 return <form action={action} onSubmit={event=>blockOfflineSubmission(event)} className={styles.form}>
  {Object.entries({tenant,employer,period,employment,stamp:facts.stamp}).map(([k,v])=><input key={k} type="hidden" name={k} value={v}/>)}
  <p>بيانات الموظف للفترة {displayDate(facts.starts_on)} — {displayDate(facts.ends_on)}</p>
  <Disclosure summary="القواعد المستخدمة"><p>الأساس المصري: <bdi>{facts.pack.version}</bdi>. جهة العمل الأصلية والقطاع الخاص العادي خارج التأمين الصحي الشامل. تُستخدم القواعد المنشورة السارية، مع ربط شهر التأمين بالفترة المختارة. عدّل المعاملة والفئة من الخيارات المتقدمة إذا اختلفت حالة الموظف.</p></Disclosure>
  <fieldset disabled={pending||Boolean(frozen)} className={styles.fields}>
   <Field id="egypt-insured" label="حالة تأمين الموظف" required><Select id="egypt-insured" name="insurance_status" value={insured} onChange={e=>setInsured(e.target.value)} required><option value="" disabled>اختر حالة الموظف</option><option value="insured">مشترك في التأمينات</option><option value="not_insured">غير مشترك في التأمينات</option></Select></Field>
   {insured==='insured'&&<>
    <Field id="egypt-wage" label="الأجر المسجل بالتأمينات" help={`قد يختلف عن الراتب الأساسي. الحدود في النسخة الحالية ${facts.pack.minimum} إلى ${facts.pack.maximum} جنيه؛ لا تضع الراتب الأساسي تلقائيًا.`}><Input id="egypt-wage" name="insured_wage" inputMode="decimal" defaultValue={current?.insured_wage??''} required placeholder="مثال: 6000.00"/></Field>
    <Field id="egypt-from" label="بداية اشتراكه بالتأمينات"><Input id="egypt-from" type="date" name="insurance_from" defaultValue={String(current?.insurance_from??'')} required/></Field>
    <Field id="egypt-month" label="تأمينات هذا الشهر" help="اختر حسب حالة اشتراك الموظف. اختيار الاستحقاق يسجل التزام شهر كامل على هذه الفترة؛ النظام يمنع تكراره في فترة أخرى."><Select id="egypt-month" name="insurance_month_disposition" defaultValue={String(current?.insurance_month_disposition??'')} required><option value="" disabled>اختر حسب حالة الاشتراك</option><option value="reviewed_due">تُحتسب على هذه الفترة</option><option value="reviewed_not_due">لا تُستحق عن هذا الشهر</option></Select></Field>
   </>}
   {needsOpening?<Field id="egypt-prior" label="هل توجد للموظف مبالغ أو ضرائب سابقة هذا العام؟" help="يشمل ذلك العمل لدى جهة أخرى. لا تختَر عدم وجود أرصدة إذا كانت غير معلومة."><Select id="egypt-prior" name="no_prior_income" value={prior} onChange={e=>setPrior(e.target.value)} required><option value="" disabled>اختر الحالة</option><option value="true">لا، وهذه أول رواتب له هذا العام</option><option value="false">نعم، أو أحتاج مراجعتها</option></Select></Field>:<Message tone="info">سيحتفظ النظام بالأرصدة والحسابات السابقة المسجلة؛ لن يصفرها.</Message>}
   {prior==='false'&&<Message tone="info">أدخل الأرصدة السابقة مرة واحدة، ثم عُد لهذا الإعداد. <ButtonLink variant="ghost" href={openingHref??advanced+'&kind=opening_ytd'}>تسجيل الأرصدة السابقة</ButtonLink></Message>}
   {facts.pay_basis==='daily'&&<Field id="egypt-days" label="أيام العمل المستحقة في هذه الفترة" help="للأجر اليومي استخدم عدد الأيام المستحقة فعلًا، ويشمل نصف اليوم عند الحاجة؛ لا تكتب عدد أيام التقويم."><Input id="egypt-days" name="tax_duration_days" inputMode="decimal" required defaultValue={sameScope?current?.tax_duration_days??'':''} placeholder="مثال: 12 أو 12.5"/></Field>}
   <Disclosure summary="خيارات متقدمة وتعديل الافتراضات" style={{gridColumn:'1 / -1'}}><div className={styles.fields}>
    <Field id="egypt-tax" label="المعاملة الضريبية" help="01 لجهة العمل الأصلية؛ الحالات الخاصة تحتاج قواعد منشورة مناسبة."><Input id="egypt-tax" name="tax_treatment_code" defaultValue={current?.tax_treatment_code??'01'} maxLength={2} required/></Field>
    <Field id="egypt-category" label="الفئة التأمينية"><Input id="egypt-category" name="insurance_category" defaultValue={current?.insurance_category??facts.pack.category}/></Field>
    {insured==='insured'&&<Field id="egypt-until" label="انتهاء الاشتراك إن وُجد"><Input id="egypt-until" name="insurance_until" type="date" defaultValue={String(current?.insurance_until??'')}/></Field>}
    {facts.pay_basis!=='daily'&&<Field id="egypt-duration" label="مدة احتساب الضريبة بالأيام" help="اقتراح قابل للتعديل: الشهر الكامل 30 يومًا، والفترة الجزئية مدة العمل داخل الشهر بحد أقصى 30. لا تتغير أيام الحضور بهذا الاختيار."><Input id="egypt-duration" name="tax_duration_days" inputMode="decimal" required defaultValue={sameScope?current?.tax_duration_days??facts.suggested_duration??'':facts.suggested_duration??''}/></Field>}
   </div><ButtonLink variant="ghost" href={advanced}>كل المدخلات والتفاصيل الخاصة</ButtonLink></Disclosure>
  </fieldset>
  {!facts.policy_exists&&<Message tone="warn">يلزم تحديد سياسة حساب الجزء من الفترة للشركة مرة واحدة من إعداد البنود والسياسة.</Message>}
  {frozen&&<Message tone="warn">{readOnly?'هذه البيانات للقراءة لأن خدمة الرواتب موقوفة.':'السجل محفوظ بحالة لا تقبل التعديل هنا؛ استخدم مسار التصحيح من المسير.'}</Message>}
  {state.error&&<Message tone="bad" role="alert">{state.error} مدخلاتك ما زالت في النموذج.</Message>}
  {offline&&<Message tone="warn">الاتصال غير متاح. احتفظ بالصفحة وأعد الحفظ بعد عودة الاتصال.</Message>}
  <div className={styles.actions}><Button type="submit" disabled={pending||offline||Boolean(frozen)||prior==='false'}>{pending?'جارٍ حفظ بيانات الموظف…':'حفظ بيانات الموظف'}</Button><ButtonLink variant="ghost" href={review}>{profileHref?'فتح مسير الفترة':'العودة إلى مراجعة الرواتب'}</ButtonLink></div>
 </form>;
}
