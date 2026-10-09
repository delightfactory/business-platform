import { ButtonLink, PageHeader, Panel } from '@/components/ui';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
export type ChannelAccess = { can_view: boolean; can_manage: boolean; can_review: boolean; capture_enabled: boolean };
export type Source = { id: string; name: string; kind: string; site_id?: string; site_name: string | null; enabled: boolean; version: number; config?: Record<string, unknown>; last_success?: string; last_failure?: string; unmapped_count?: number; retry_count?: number; review_count?: number; versions?: Array<{version:number;enabled:boolean;reason:string;created_at:string}> };
export type Options = { employees: Array<{ id: string; full_name: string; employee_code: string }>; sites: Array<{ id: string; display_name: string }> };
export type Mapping = { id:string;external_key:string;employee_id:string;employee_name:string;site_id:string;site_name:string;valid_from:string;valid_until:string|null;active:boolean;created_at:string };
export type EventRow = { id:string;direction:string;happened_at:string;received_at:string;state:string;reason:string|null;employee_name:string|null;review_required:boolean;work_instance_id:string|null;timezone_name:string|null };
export type EventDetail = { id:string;source_id:string;source_name:string;kind:string;external_key:string|null;event_key:string|null;direction:string;happened_at:string;received_at:string;source_version:number;validation:string;review_required:boolean;review_decisions:Array<{decision:string;reason:string;created_at:string;timezone_name:string;actor_label:string}>;results:Array<{id:number;state:string;reason:string|null;created_at:string;work_instance_id:string|null}>;replays:Array<{id:number;state:string;created_at:string}> };
export async function channelSession(tenantId:string) {
  const db=await createSupabaseServerClient();if(!db) return null;
  const {data:{user}}=await db.auth.getUser();if(!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/attendance/sources`)}`);
  const {data,error}=await db.rpc('attendance_channel_access',{p_tenant:tenantId});
  if(error || !data) return null;
  return {db,access:data as ChannelAccess};
}
export function ChannelUnavailable({tenantId,retryHref=`/tenant/${tenantId}/attendance/sources`}:{tenantId:string;retryHref?:string}) { return <PageFrame><Panel ><PageHeader  title={<>قنوات الحضور غير متاحة</>} /><p>تحقق من الاتصال وصلاحية عرض الحضور، أو تواصل مع المسؤول.</p><ButtonLink  href={retryHref}>إعادة تحميل الصفحة</ButtonLink><ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة العمل</ButtonLink></Panel></PageFrame>; }
export function ChannelPager({href,offset,more}:{href:string;offset:number;more:boolean}) { return <nav className="attendance-pagination" aria-label="صفحات السجل">{offset>0 && <ButtonLink variant="ghost"  href={`${href}${href.includes('?')?'&':'?'}offset=${Math.max(0,offset-20)}`}>السابق</ButtonLink>}{more && <ButtonLink variant="ghost"  href={`${href}${href.includes('?')?'&':'?'}offset=${offset+20}`}>التالي</ButtonLink>}</nav>; }
export function channelOffset(value:string|undefined) { const n=Number(value??0);return Number.isInteger(n) && n>=0 && n<=1000000?n:0; }

export function channelHref(href:string,context:{offset?:number;mappingOffset?:number;q?:unknown;siteQ?:unknown}) {
 const query=new URLSearchParams();for(const key of ['offset','mappingOffset'] as const) {const value=channelOffset(String(context[key]??0));if(value>0)query.set(key,String(value));}
 for(const key of ['q','siteQ'] as const){const value=typeof context[key]==='string'?context[key].slice(0,100):'';if(value)query.set(key,value);}
 const suffix=query.toString();return suffix?href+'?'+suffix:href;
}
