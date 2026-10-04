'use client';
import { useEffect, useRef, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { channelReasonLabel, type MobileAttempt, type MobileSnapshot, type PunchResult } from '@/lib/attendance-channel';
import { reconcileMobilePunch, submitMobilePunch } from './actions';
type Pending = { id: string; scope: string };
export function MobilePunch({ tenantId, snapshot }: { tenantId: string; snapshot: MobileSnapshot }) {
  const router=useRouter();
  const [pending,setPending]=useState<Pending|null>(null), [busy,setBusy]=useState(false), [hydratedKey,setHydratedKey]=useState<string|null>(null), [message,setMessage]=useState(''), [terminal,setTerminal]=useState(false), [canResend,setCanResend]=useState(false);
  const completeAttempt=useRef<MobileAttempt|null>(null), flight=useRef(false), status=useRef<HTMLDivElement>(null);
  const nativeLocationFeedback=useRef('');
  const storageKey=`attendance-pending:${tenantId}`;
  const ready=hydratedKey===storageKey;
  const next=snapshot.next_direction;
  const [refreshing,startRefresh]=useTransition();
  function refreshSnapshot() { startRefresh(()=>router.refresh()); }
  useEffect(()=>{
    // Read tab storage in a cancellable post-hydration browser callback.
    const hydration=requestAnimationFrame(()=>{
      completeAttempt.current=null;nativeLocationFeedback.current='';setCanResend(false);
      try {
        const raw=sessionStorage.getItem(storageKey);
        if(raw) {
          const saved:unknown=JSON.parse(raw);
          if(!saved || typeof saved!=='object' || !('id' in saved) || !('scope' in saved) || typeof saved.id!=='string' || typeof saved.scope!=='string' || !/^[0-9a-f-]{36}$/i.test(saved.id)) throw new Error('invalid pending');
          setPending({id:saved.id,scope:saved.scope});setMessage('لديك محاولة سابقة غير مؤكدة. تحقق منها قبل تسجيل حضور جديد.');
        } else {setPending(null);setMessage('');}
      } catch {setMessage('تعذر قراءة المحاولة السابقة. لا تسجّل محاولة أخرى قبل مراجعة المسؤول.');setPending({id:'',scope:''});}
      setHydratedKey(storageKey);
    });
    return ()=>cancelAnimationFrame(hydration);
  },[storageKey]);
  function announce(text:string) { setMessage(text); requestAnimationFrame(()=>status.current?.focus()); }
  function release() { try { sessionStorage.removeItem(storageKey); } catch { /* Authoritative outcome remains visible. */ } completeAttempt.current=null;setCanResend(false);setPending(null); }
  function finish(result:PunchResult,nativeFeedback='') {
    if(['accepted','duplicate'].includes(result.state)) { release();setTerminal(false);announce(nativeFeedback+(result.review?'سُجلت الحركة وتحتاج مراجعة المسؤول وفق سياسة الموقع.':result.state==='duplicate'?'المحاولة مسجلة بالفعل. لم تُضف حركة أخرى.':'تم تسجيل الحركة.'));refreshSnapshot(); }
    else if(result.state==='blocked' && result.reason==='scope_changed') { release();setTerminal(true);announce('المحاولة السابقة لا تخص رابط الموظف الحالي، ولا يمكن الوصول إليها بهذا الرابط. يمكنك تجهيز محاولة جديدة لحسابك الحالي.');refreshSnapshot(); }
    else if(result.state==='rejected') { release();setTerminal(true);announce(nativeFeedback+channelReasonLabel(result.reason));refreshSnapshot(); }
    else announce(nativeFeedback+channelReasonLabel(result.reason));
  }
  async function reconcile() { if(!ready || refreshing || !pending?.id || flight.current) return;flight.current=true;setBusy(true);announce('جارٍ التحقق من المحاولة السابقة.');try {finish(await reconcileMobilePunch(tenantId,pending.id,pending.scope));} catch {announce('تعذر الاتصال. نتيجة المحاولة لم تتأكد بعد. أعد التحقق عندما يعود الاتصال.');} finally {flight.current=false;setBusy(false);} }
  async function punch() {
    if(!ready || refreshing || flight.current || !snapshot.available || (pending && !completeAttempt.current)) return;
    flight.current=true;setBusy(true);
    try {
      let current=completeAttempt.current;
      if(!current) {
        nativeLocationFeedback.current='';
        current={id:crypto.randomUUID(),direction:next,happened_at:new Date().toISOString(),scope:snapshot.scope,policy_version:snapshot.policy_version,location:null};
        if(snapshot.geofence_required) {
          announce('جارٍ تحديد موقعك لهذه المحاولة فقط.');
          try {
            current.location=await new Promise((resolve,reject)=>{
              if(!navigator.geolocation) {reject(new Error('location_unavailable'));return;}
              navigator.geolocation.getCurrentPosition(p=>{
                try {resolve({latitude:p.coords.latitude,longitude:p.coords.longitude,accuracy:p.coords.accuracy,captured_at:new Date(p.timestamp).toISOString()});}
                catch {reject(new Error('location_serialization'));}
              },e=>reject(new Error(e.code===1?'location_denied':e.code===2?'location_unavailable':e.code===3?'location_timeout':'location_unknown')),{enableHighAccuracy:true,timeout:15000,maximumAge:0});
            });
          } catch(error) {
            const reason=error instanceof Error?error.message:'';
            const nativeMessages:Record<string,string>={location_denied:'رفض المتصفح إذن الموقع. ',location_timeout:'انتهت مهلة تحديد الموقع. ',location_unavailable:'تعذر على الجهاز توفير الموقع. '};
            if(!nativeMessages[reason]) throw error;
            current.location=null;nativeLocationFeedback.current=nativeMessages[reason];
            announce(nativeMessages[reason]+'ستُرسل المحاولة دون دليل موقع؛ سياسة موقع العمل تحدد قبولها للمراجعة أو رفضها.');
          }
          current.happened_at=new Date().toISOString();
        }
        sessionStorage.setItem(storageKey,JSON.stringify({id:current.id,scope:current.scope}));
        completeAttempt.current=current;setCanResend(true);setPending({id:current.id,scope:current.scope});
      }
      announce('جارٍ إرسال الحركة. انتظر تأكيد التسجيل.');finish(await Promise.race([submitMobilePunch(tenantId,current),new Promise<never>((_,reject)=>setTimeout(()=>reject(new Error('response_timeout')),20000))]),nativeLocationFeedback.current);
    } catch {announce(completeAttempt.current?nativeLocationFeedback.current+'لم يتأكد التسجيل. تحقق من المحاولة أو أعد إرسال المحاولة نفسها عند عودة الاتصال.':'تعذر تجهيز المحاولة. لم تُرسل حركة؛ راجع إعدادات المتصفح أو تواصل مع المسؤول.'); } finally {flight.current=false;setBusy(false);}
  }
  return <section className="workspace-records-panel channel-punch" aria-busy={busy || refreshing || !ready}>
    <h2>{next==='in'?'جاهز لتسجيل الحضور':'الإجراء التالي: تسجيل الانصراف'}</h2>
    {snapshot.site_name && <p>موقع العمل: {snapshot.site_name}</p>}{snapshot.geofence_required && <p className="field-hint">يُطلب موقعك مرة واحدة للتحقق من نطاق العمل.</p>}
    {!snapshot.available && <p className="form-message">{channelReasonLabel(snapshot.reason)}</p>}
    <div className="channel-outcome" ref={status} tabIndex={-1} role="status" aria-live="polite">{ready?message:'جارٍ التحقق من المحاولة السابقة…'}</div>
    <div className="workspace-form-actions">{pending?<><button type="button" className="primary-button" disabled={busy || refreshing || !ready || !pending.id} onClick={reconcile}>التحقق من المحاولة</button>{canResend && <button type="button" className="secondary-button" disabled={busy || refreshing || !ready || !snapshot.available} onClick={punch}>إعادة إرسال نفس المحاولة</button>}</>:terminal?<button type="button" className="primary-button" disabled={busy || refreshing || !ready} onClick={()=>{setTerminal(false);refreshSnapshot();announce('جارٍ تحديث السياق. انتظر ظهور الإجراء المطلوب ثم سجّل الحركة.');}}>تجهيز محاولة جديدة</button>:<button type="button" className="primary-button" disabled={busy || refreshing || !ready || !snapshot.available} onClick={punch}>{busy?'جارٍ الإرسال…':next==='in'?'تسجيل الحضور':'تسجيل الانصراف'}</button>}</div>
  </section>;
}
