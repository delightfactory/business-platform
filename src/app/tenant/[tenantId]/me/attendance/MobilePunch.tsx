'use client';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { channelReasonLabel, type MobileAttempt, type MobileSnapshot, type PunchResult } from '@/lib/attendance-channel';
import { reconcileMobilePunch, submitMobilePunch } from './actions';
type Pending = { id: string; scope: string };
export function MobilePunch({ tenantId, snapshot }: { tenantId: string; snapshot: MobileSnapshot }) {
  const router=useRouter();
  const [pending,setPending]=useState<Pending|null>(null), [busy,setBusy]=useState(false), [ready,setReady]=useState(false), [message,setMessage]=useState(''), [terminal,setTerminal]=useState(false), [next,setNext]=useState(snapshot.next_direction);
  const completeAttempt=useRef<MobileAttempt|null>(null), flight=useRef(false), status=useRef<HTMLDivElement>(null);
  const storageKey=`attendance-pending:${tenantId}`;
  useEffect(()=>{ try { const raw=sessionStorage.getItem(storageKey); if(raw) { const saved:unknown=JSON.parse(raw); if(!saved || typeof saved!=='object' || !('id' in saved) || !('scope' in saved) || typeof saved.id!=='string' || typeof saved.scope!=='string' || !/^[0-9a-f-]{36}$/i.test(saved.id)) throw new Error('invalid pending'); setPending({id:saved.id,scope:saved.scope}); setMessage('لديك محاولة سابقة غير مؤكدة. تحقق منها قبل تسجيل حضور جديد.'); } } catch { setMessage('تعذر قراءة المحاولة السابقة. لا تسجّل محاولة أخرى قبل مراجعة المسؤول.'); setPending({id:'',scope:''}); } setReady(true); },[storageKey]);
  useEffect(()=>{setNext(snapshot.next_direction);},[snapshot.next_direction]);
  function announce(text:string) { setMessage(text); requestAnimationFrame(()=>status.current?.focus()); }
  function release() { try { sessionStorage.removeItem(storageKey); } catch { /* Authoritative outcome remains visible. */ } completeAttempt.current=null;setPending(null); }
  function finish(result:PunchResult,reconciled=false) {
    if(result.next_direction) setNext(result.next_direction);
    if(['accepted','duplicate'].includes(result.state)) { release();setTerminal(false);announce(result.review?'تم التسجيل ويحتاج مراجعة المسؤول.':result.state==='duplicate'?'المحاولة مسجلة بالفعل. لم تُضف حركة أخرى.':'تم تسجيل الحركة.');router.refresh(); }
    else if(result.state==='blocked' && result.reason==='scope_changed') { release();setTerminal(true);announce('المحاولة السابقة لا تخص رابط الموظف الحالي، ولا يمكن الوصول إليها بهذا الرابط. يمكنك تجهيز محاولة جديدة لحسابك الحالي.');router.refresh(); }
    else if(result.state==='rejected' && (result.reason==='cancelled' || !reconciled || ['scope_changed','policy_changed'].includes(result.reason??''))) { release();setTerminal(true);announce(channelReasonLabel(result.reason));router.refresh(); }
    else announce(channelReasonLabel(result.reason));
  }
  async function reconcile() { if(!pending?.id || flight.current) return;flight.current=true;setBusy(true);announce('جارٍ التحقق من المحاولة السابقة.');try {finish(await reconcileMobilePunch(tenantId,pending.id,pending.scope),true);} catch {announce('تعذر الاتصال. نتيجة المحاولة لم تتأكد بعد. أعد التحقق عندما يعود الاتصال.');} finally {flight.current=false;setBusy(false);} }
  async function punch() {
    if(flight.current || !snapshot.available || (pending && !completeAttempt.current)) return;
    flight.current=true;setBusy(true);
    try {
      let current=completeAttempt.current;
      if(!current) {
        current={id:crypto.randomUUID(),direction:next,happened_at:new Date().toISOString(),scope:snapshot.scope,policy_version:snapshot.policy_version,location:null};
        if(snapshot.geofence_required) {
          announce('جارٍ تحديد موقعك لهذه المحاولة فقط.');
          current.location=await new Promise((resolve,reject)=>{ if(!navigator.geolocation) {reject(new Error('location_unavailable'));return;} navigator.geolocation.getCurrentPosition(p=>resolve({latitude:p.coords.latitude,longitude:p.coords.longitude,accuracy:p.coords.accuracy,captured_at:new Date(p.timestamp).toISOString()}),e=>reject(new Error(e.code===1?'location_denied':e.code===3?'location_timeout':'location_unavailable')),{enableHighAccuracy:true,timeout:15000,maximumAge:0}); });
          current.happened_at=new Date().toISOString();
        }
        sessionStorage.setItem(storageKey,JSON.stringify({id:current.id,scope:current.scope}));
        completeAttempt.current=current;setPending({id:current.id,scope:current.scope});
      }
      announce('جارٍ إرسال الحركة. انتظر تأكيد التسجيل.');finish(await Promise.race([submitMobilePunch(tenantId,current),new Promise<never>((_,reject)=>setTimeout(()=>reject(new Error('response_timeout')),20000))]));
    } catch(error) { const reason=error instanceof Error?error.message:'';announce(reason==='location_denied'?'إذن الموقع مرفوض. فعّله من إعدادات المتصفح ثم أعد المحاولة، أو تواصل مع المسؤول.':reason==='location_timeout'?'انتهت مهلة تحديد الموقع. أعد المحاولة من مكان مفتوح.':reason==='location_unavailable'?'الموقع غير متاح. راجع إعدادات الهاتف أو تواصل مع المسؤول.':completeAttempt.current?'لم يتأكد التسجيل. تحقق من المحاولة أو أعد إرسال المحاولة نفسها عند عودة الاتصال.':'تعذر تجهيز المحاولة. تحقق من إعدادات المتصفح ثم أعد المحاولة.'); } finally {flight.current=false;setBusy(false);}
  }
  return <section className="workspace-records-panel channel-punch" aria-busy={busy}>
    <h2>{next==='in'?'جاهز لتسجيل الحضور':'الإجراء التالي: تسجيل الانصراف'}</h2>
    {snapshot.site_name && <p>موقع العمل: {snapshot.site_name}</p>}{snapshot.geofence_required && <p className="field-hint">يُطلب موقعك مرة واحدة للتحقق من نطاق العمل.</p>}
    {!snapshot.available && <p className="form-message">{channelReasonLabel(snapshot.reason)}</p>}
    <div className="channel-outcome" ref={status} tabIndex={-1} role="status" aria-live="polite">{message}</div>
    <div className="workspace-form-actions">{pending?<><button type="button" className="primary-button" disabled={busy || !pending.id} onClick={reconcile}>التحقق من المحاولة</button>{completeAttempt.current && <button type="button" className="secondary-button" disabled={busy || !snapshot.available} onClick={punch}>إعادة إرسال نفس المحاولة</button>}</>:terminal?<button type="button" className="primary-button" disabled={busy || !ready} onClick={()=>{setTerminal(false);router.refresh();announce('تم تحديث السياق. راجع الإجراء المطلوب ثم سجّل الحركة.');}}>تجهيز محاولة جديدة</button>:<button type="button" className="primary-button" disabled={busy || !ready || !snapshot.available} onClick={punch}>{busy?'جارٍ الإرسال…':next==='in'?'تسجيل الحضور':'تسجيل الانصراف'}</button>}</div>
  </section>;
}
