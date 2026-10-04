'use server';
import {revalidatePath} from 'next/cache';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid} from '../rules';
import {openingCoverageFields} from '../inputs/rules';
import {correctionError,correctionKinds,type CorrectionKind,type CorrectionState} from './rules';
export async function correctionAction(previous:CorrectionState,form:FormData):Promise<CorrectionState>{
 if(String(form.get('operation')??'')==='preview')previous={...previous,previewHash:undefined,affected:undefined};
 const get=(key:string)=>String(form.get(key)??'').trim();
 const tenant=get('tenant'),employer=get('employer'),output=get('output'),caseId=get('case'),operation=get('operation'),revision=Number(get('revision'));
 if(![tenant,employer,output].every(uuid)||(caseId&&!uuid(caseId))||!Number.isSafeInteger(revision)||revision<0)return {...previous,saved:false,error:correctionError('22023')};
 let rpc:string,args:Record<string,unknown>,state:CorrectionState={...previous,saved:false};let submitted=false;
 try{
 if(operation==='preview'||operation==='save'){
  const fields:Record<string,unknown>={};for(const key of JSON.parse(get('field_keys')))fields[key]=get(`field:${key}`)||null;
  if(get('kind')==='input_revision'){
   const data:Record<string,unknown>={};for(const key of JSON.parse(get('data_keys')))data[key]=['active','visible','taxable','social'].includes(key)?get(`data:${key}`)==='true':get(`data:${key}`);
   for(const key of ['tax_due','tax_net_income',...openingCoverageFields])if(data[key]==='')delete data[key];
   for(const key of ['insurance_category','insured_wage','insurance_from','insurance_until'])if(data.insurance_status==='not_insured'||data[key]==='')delete data[key];
   fields.data=data;fields.cancelled=get('field:cancelled')==='true';
  }
  if(['employment','new_employment'].includes(get('kind')))fields.payroll_eligible=get('field:payroll_eligible')==='true';
  const selected:unknown=get('kind')==='source_change'?JSON.parse(get('source_changes')):null;
  if(get('kind')==='source_change'&&(!Array.isArray(selected)||selected.length<1||selected.length>32||selected.some(x=>!x||typeof x!=='object'||!uuid(x.id)||typeof x.expected_hash!=='string'||!/^[0-9a-f]{64}$/.test(x.expected_hash))))return {...previous,saved:false,error:'اختر التغييرات المسجلة ثم أعد المعاينة. الحقول محفوظة.'};
  const unchanged:unknown=JSON.parse(get('unchanged_changes')||'[]');
  if(!Array.isArray(unchanged)||unchanged.length>31)return {...previous,saved:false,error:correctionError('22023')};
  const changes=Array.isArray(selected)?selected.map(x=>({type:'source_change',source_id:x.id,expected_hash:x.expected_hash,fields:{}})):[{type:get('kind'),source_id:get('source')||null,expected_hash:get('source_hash')||null,fields},...unchanged];
  const rows=form.getAll('row_employment').map((employment,index)=>{
   const value=(key:string)=>String(form.getAll(key)[index]??'').trim();
   return {output_id:value('row_output'),...(String(employment).startsWith('new:')?{employment_ref:String(employment)}:{employment_id:String(employment)}),amount:value('row_amount'),basis:value('row_basis'),component_id:value('row_component')||null,target_period:value('row_target')||null,reference:value('row_reference'),source:value('row_source')};
  });
  rpc='payroll_correction_proposal';args={p_tenant:tenant,p_employer:employer,p_output:output,p_case:caseId||null,p_expected:revision,p_changes:changes,p_rows:rows,p_target:get('target')||null,p_reason:get('reason'),p_reference:get('reference'),p_preview_hash:operation==='save'?previous.previewHash??'':null,p_operation:operation};
 }else if(operation==='settlement'){
  rpc='payroll_correction_settlement';args={p_tenant:tenant,p_employer:employer,p_case:caseId,p_expected:revision,p_employment:get('employment'),p_direction:get('direction'),p_amount:get('amount'),p_date:get('date'),p_reference:get('reference'),p_reason:get('reason')};
 }else if(operation==='approve_candidate'||operation==='release_candidate'){
  rpc='payroll_candidate_approval';args={p_tenant:tenant,p_employer:employer,p_period:get('period'),p_run:get('run'),p_candidate:get('candidate'),p_expected:revision,p_operation:operation==='approve_candidate'?'approve':'release',p_reason:get('reason')};
 }else{
  rpc='payroll_correction_command';args={p_tenant:tenant,p_employer:employer,p_case:caseId,p_expected:revision,p_operation:operation,p_reason:get('reason')};
 }
 if(previous.recoverPending&&previous.signature){const original=JSON.parse(previous.signature);args.p_expected=original.args.p_expected;}
 const signature=JSON.stringify({rpc,args});
 if(previous.recoverPending&&previous.signature&&signature!==previous.signature)return {...previous,saved:false,error:'لم تتأكد نتيجة الطلب السابق. أعد قيمه الأصلية للتحقق من نتيجته قبل تغيير المقترح أو مبلغ التسوية.'};
 const clientAttempt=get('__attempt');if(clientAttempt&&!uuid(clientAttempt))return {...previous,saved:false,error:correctionError('22023')};
 const attempt=clientAttempt||(signature===previous.signature&&uuid(previous.attempt)?previous.attempt:crypto.randomUUID());state={...previous,saved:false,closedUncommitted:false,error:'',signature,attempt};
 const submittedKind=get('kind').replace(/_split$/,'');
 const kind=Object.hasOwn(correctionKinds,submittedKind)?submittedKind as CorrectionKind:undefined;
 const client=await createSupabaseServerClient();if(!client)return {...state,recoverPending:operation!=='preview',error:correctionError()};
 const {data:{user}}=await client.auth.getUser();if(!user||get('__actor')&&get('__actor')!==user.id)return {...state,error:correctionError('42501')};
 submitted=true;
 if(get('__reconcile')==='true'){
  const reconciled=await client.rpc('payroll_correction_reconcile',{p_tenant:tenant,p_employer:employer,p_output:output,p_rpc:rpc,p_args:args,p_attempt:attempt});
  if(reconciled.error)return {...state,recoverPending:true,error:correctionError(reconciled.error.code,reconciled.error.message)};
  if(reconciled.data.outcome==='closed_uncommitted')return {...state,saved:false,recoverPending:false,closedUncommitted:true,signature:'',attempt:'',previewHash:undefined,error:''};
  if(reconciled.data.outcome!=='committed')return {...state,recoverPending:true,error:correctionError()};
  const receipt=reconciled.data.result;
  revalidatePath(`/tenant/${tenant}/payroll/corrections`);revalidatePath(`/tenant/${tenant}/payroll/runs`);revalidatePath(`/tenant/${tenant}/payroll/payments`);revalidatePath(`/tenant/${tenant}/people`);
  return {saved:true,recoverPending:false,error:'',signature:'',attempt:'',kind,caseId:receipt.case_id??caseId,revision:receipt.revision,status:receipt.status,route:receipt.route,affected:receipt.affected_outputs};
 }
 const result=await client.rpc(rpc,{...args,p_attempt:attempt});
 if(result.error)return {...state,previewHash:undefined,recoverPending:operation!=='preview',error:correctionError(result.error.code,result.error.message)};
 if(operation!=='preview'){revalidatePath(`/tenant/${tenant}/payroll/corrections`);revalidatePath(`/tenant/${tenant}/payroll/runs`);revalidatePath(`/tenant/${tenant}/payroll/payments`);revalidatePath(`/tenant/${tenant}/people`);}
 return {saved:operation!=='preview',error:'',signature:'',attempt:'',kind,previewHash:result.data.preview_hash,caseId:result.data.case_id??caseId,revision:result.data.revision,status:result.data.status,route:result.data.route,affected:result.data.affected_outputs};
 }catch{return {...state,saved:false,recoverPending:previous.recoverPending||submitted&&operation!=='preview',error:correctionError(submitted?undefined:'22023')};}
}

export async function correctionChoices(scope:{tenant:string;employer:string;output:string;kind:string},choice:string,query:string,after:string|null,selected:string|null,version:number|null,employee:string|null){
 const client=await createSupabaseServerClient();if(!client)return {error:'تعذر تحميل الخيارات. أعد المحاولة بنفس البحث.'};
 const result=await client.rpc('payroll_correction_choices',{p_tenant:scope.tenant,p_employer:scope.employer,p_output:scope.output,p_kind:scope.kind,p_choice:choice,p_query:query,p_after:after,p_selected:selected||null,p_version:version,p_employee:employee||null});
 return result.error?{error:correctionError(result.error.code,result.error.message)}:{data:result.data};
}
