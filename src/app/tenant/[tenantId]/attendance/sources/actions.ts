'use server';
import { revalidatePath } from 'next/cache';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { channelReasonLabel, channelStateLabel } from '@/lib/attendance-channel';
export type ChannelActionResult = { ok:boolean;message:string;id?:string };
export async function mutateChannel(tenantId:string,operation:'save'|'map'|'reprocess'|'review',form:FormData):Promise<ChannelActionResult> {
  const db=await createSupabaseServerClient();if(!db) return {ok:false,message:'تعذر الاتصال. احتفظنا بالقيم؛ أعد المحاولة.'};
  const {data:{user}}=await db.auth.getUser();if(!user) return {ok:false,message:'انتهت الجلسة. سجّل الدخول ثم أعد المحاولة.'};
  const {data:access,error:accessError}=await db.rpc('attendance_channel_access',{p_tenant:tenantId});
  if(accessError || !access || (operation==='review'?access.can_review!==true:access.can_manage!==true)) return {ok:false,message:'ليست لديك صلاحية هذا الإجراء. تواصل مع المسؤول.'};
  const value=(key:string)=>String(form.get(key)??'').trim();
  let rpc:string;let args:Record<string,unknown>;
  if(operation==='save') {
    const kind=value('kind');const config:Record<string,unknown>={};
    if(kind==='mobile') {
      config.geofence=value('geofence')==='true';
      const keys=config.geofence?['retention_seconds','latitude','longitude','radius_m','tolerance_m','max_accuracy_m','max_age_seconds']:['retention_seconds'];
      for(const key of keys) { if(!value(key) || !Number.isFinite(Number(value(key)))) return {ok:false,message:'أكمل قيم سياسة الموقع بأرقام صالحة. بقيت القيم كما أدخلتها.'};config[key]=Number(value(key)); }
      if(config.geofence) config.failure_action=value('failure_action');
      if(!['true','false'].includes(value('geofence'))) return {ok:false,message:'اختر هل يتطلب التسجيل التحقق من الموقع.'};
    }
    rpc='attendance_channel_save_source';args={p_tenant:tenantId,p_source:value('source')||null,p_name:value('name'),p_kind:kind,p_site:value('site')||null,p_enabled:value('enabled')==='true',p_config:config,p_reason:value('reason')};
  } else if(operation==='map') {
    const explicitInstant=/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;
    if(!explicitInstant.test(value('valid_from')) || (value('valid_until') && !explicitInstant.test(value('valid_until')))) return {ok:false,message:'اختر فترة سريان ذات توقيت محدد. بقيت القيم كما أدخلتها.'};
    const from=new Date(value('valid_from')),until=value('valid_until')?new Date(value('valid_until')):null;
    if(!Number.isFinite(from.getTime()) || (until && (!Number.isFinite(until.getTime()) || until<=from))) return {ok:false,message:'اختر بداية صالحة ونهاية تليها. بقيت القيم كما أدخلتها.'};
    rpc='attendance_channel_map';args={p_tenant:tenantId,p_source:value('source'),p_external_key:value('external_key'),p_employee:value('employee'),p_site:value('site'),p_valid_from:value('valid_from'),p_valid_until:value('valid_until')||null,p_active:value('active')==='true'};
  } else if(operation==='review') { rpc='attendance_channel_review';args={p_tenant:tenantId,p_event:value('event'),p_decision:value('decision'),p_reason:value('reason')}; }
  else {rpc='attendance_channel_reprocess';args={p_tenant:tenantId,p_event:value('event')};}
  const {data,error}=await db.rpc(rpc,args);
  if(error) return {ok:false,message:!error.code?'لم يتأكد حفظ الإجراء. بقيت القيم؛ راجع سجل القناة قبل إعادة الإرسال.':error.code==='42501'?'تغيرت صلاحيتك أو توقفت الخدمة. تواصل مع المسؤول.':'لم يُحفظ الإجراء. تحقق من الحقول والفترة والموقع ثم أعد المحاولة. بقيت القيم كما أدخلتها.'};
  revalidatePath(`/tenant/${tenantId}/attendance/sources`,'layout');revalidatePath(`/tenant/${tenantId}/me/attendance`);
  return {ok:true,id:typeof data==='string'?data:undefined,message:operation==='save'?'حُفظ إصدار القناة.':operation==='map'?'حُفظ قرار الربط. أعد معالجة الحركة المطلوبة من سجلها.':operation==='review'?'حُفظ قرار المراجعة.':`${channelStateLabel(data?.state)}. ${data?.reason?channelReasonLabel(data.reason):''}`};
}
