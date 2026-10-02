'use server';
import {revalidatePath} from 'next/cache';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid} from '../rules';
import {paymentError,type PaymentState} from './rules';
export async function paymentAction(previous:PaymentState,form:FormData):Promise<PaymentState>{
 const get=(key:string)=>String(form.get(key)??'').trim();
 const tenant=get('tenant'),employer=get('employer'),output=get('output'),operation=get('operation'),original=get('original');
 const selected=form.getAll('employee').map(String),allocations=selected.map(id=>({employment_id:id,amount:get(`amount:${id}`)})).sort((a,b)=>a.employment_id.localeCompare(b.employment_id));
 if(![tenant,employer,output].every(uuid)||!['allocations','remaining','compensate'].includes(operation)||selected.length>100||new Set(selected).size!==selected.length||allocations.some(i=>!uuid(i.employment_id)||!/^\d{1,16}(\.\d{1,2})?$/.test(i.amount))||(original&&!uuid(original)))return {...previous,saved:false,error:paymentError('22023')};
 const expected=Number(get('revision'));if(!Number.isSafeInteger(expected)||expected<0)return {...previous,saved:false,error:paymentError('22023')};
 const args={p_tenant:tenant,p_employer:employer,p_output:output,p_expected:expected,p_operation:operation,p_date:get('date'),p_reference:get('reference'),p_reason:get('reason'),p_allocations:operation==='allocations'?allocations:[],p_original:original||null,p_confirmed:get('confirmed')==='yes'};
 if(previous.recoverPending&&previous.signature){const prior=JSON.parse(previous.signature);args.p_expected=prior.p_expected;if(JSON.stringify(args)!==previous.signature)return {...previous,error:'نتيجة الطلب السابق لم تتأكد. أعد قيمه الأصلية وأعد المحاولة للتحقق منها قبل تسجيل طلب مختلف.',saved:false};}
 const signature=JSON.stringify(args),attempt=previous.signature===signature&&uuid(previous.attempt)?previous.attempt:crypto.randomUUID(),state={...previous,saved:false,error:'',signature,attempt};
 try {
 const client=await createSupabaseServerClient();if(!client)return {...state,error:paymentError(),recoverPending:true,needsRefresh:false};
 const {data:{user}}=await client.auth.getUser();if(!user)return {...state,error:paymentError('42501')};
 const result=await client.rpc('payroll_record_payment',{...args,p_attempt:attempt});if(result.error){
 // A retry failure proves nothing about an earlier response-lost command. Only its recovered receipt resolves that uncertainty.
 const unresolved=previous.recoverPending===true||!['22023','42501','23514','PT409','55P03','40P01','55000'].includes(result.error.code);
 return {...state,error:paymentError(result.error.code,result.error.message),recoverPending:unresolved,needsRefresh:!unresolved&&(result.error.message.includes('payment_stale')||result.error.message.includes('payment_excess'))};
 }
 revalidatePath(`/tenant/${tenant}/payroll/payments`);
 return {saved:true,error:'',revision:result.data.revision,signature:'',attempt:'',amount:result.data.amount,remaining:result.data.remaining,kind:result.data.kind};
 }catch{return {...state,error:paymentError(),recoverPending:true,needsRefresh:false};}
}
