import { ButtonLink, Message, PageHeader, Panel } from '@/components/ui';
import Link from 'next/link';
import { notFound,redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isObject,isUuid } from '../../rules';
import { readBalanceAccess } from '../rules';
import { AnnualForm } from './AnnualForm';
import { annualError,readPolicy,type Rate } from './rules';
export const dynamic='force-dynamic';
export default async function AnnualPage({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {tenantId:tenant}=await params;const query=await searchParams;const employee=query.employee,employer=query.employer,type=query.type,period=query.period;
 if(!isUuid(tenant)||!isUuid(employee)||!isUuid(employer)||!isUuid(type)||!isUuid(period))notFound();
 const back=`/tenant/${tenant}/leave/balances?employee=${employee}&employer=${employer}&kind=annual_grant&period=${period}&type=${type}`;
 const path=`/tenant/${tenant}/leave/balances/annual?employee=${employee}&employer=${employer}&type=${type}&period=${period}`;
 const supabase=await createSupabaseServerClient();if(!supabase)return <PageFrame footer="الموارد البشرية"><Message tone="bad" role="alert">الاتصال غير متاح.</Message></PageFrame>;
 const {data:{user}}=await supabase.auth.getUser();if(!user)redirect(`/auth/login?next=${encodeURIComponent(path)}`);
 const accessResult=await supabase.rpc('leave_access_snapshot',{p_tenant:tenant});const access=accessResult.error?null:readBalanceAccess(accessResult.data);
 if(!access?.canAdjust||!access.newWorkEnabled)return <PageFrame footer="الموارد البشرية"><Message tone="bad" role="alert">حساب استحقاق جديد غير متاح لهذا الحساب أو الشركة حاليًا.</Message><Link href={back}>العودة إلى الأرصدة</Link></PageFrame>;
 const {data,error}=await supabase.rpc('leave_annual_context',{p_tenant:tenant,p_employee:employee,p_employer:employer,p_type:type,p_period:period});const policy=isObject(data)?readPolicy(data.policy):null;
 if(error||!policy||!isObject(data)||!['employee_name','type_name','period_name','service_start','today','ends_on'].every(k=>typeof data[k]==='string'))return <PageFrame footer="الموارد البشرية"><Message tone="bad" role="alert">{annualError(error?.message??'unknown')}</Message><Link href={back}>العودة إلى الأرصدة</Link></PageFrame>;
 const asOf=String(data.today)<String(data.ends_on)?String(data.today):String(data.ends_on);
 const last=isObject(data.last_calculation)&&isObject(data.last_calculation.quote)?data.last_calculation.quote:null;
 const initialRates:Rate[]=last&&Array.isArray(last.rates)?last.rates.filter((r):r is Rate=>isObject(r)&&typeof r.from==='string'&&typeof r.annual_days==='number'&&typeof r.source==='string'):[];
 return <PageFrame footer="الموارد البشرية"><Panel className="task-page"><ButtonLink variant="ghost"  href={back}>العودة إلى أرصدة الموظف</ButtonLink><PageHeader title="حساب الاستحقاق السنوي" eyebrow="أرصدة الإجازات" description={<>{String(data.employee_name)} · {String(data.type_name)} · {String(data.period_name)}</>} />
  <AnnualForm tenant={tenant} employee={employee} employer={employer} type={type} period={period} policy={policy} canManage={isObject(accessResult.data)&&accessResult.data.can_manage===true} asOf={asOf} serviceStart={String(data.service_start)} initialRates={initialRates} initialSource={last&&typeof last.source==='string'?last.source:''}/>
  <ButtonLink variant="ghost"  href={`/tenant/${tenant}/leave/balances?employee=${employee}&employer=${employer}&kind=adjustment&period=${period}&type=${type}#balances-type-title`}>تعديل رصيد هذا النوع يدويًا</ButtonLink>
 </Panel></PageFrame>;
}
