'use client';
import { useRef, useState, useSyncExternalStore, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { Banner, Button, Sheet, Textarea } from '@/components/ui';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { operatorLifecycleLabel } from '@/lib/operator-labels';
import type { OperatorLifecycleSnapshot } from '@/lib/operator-read';
import { readLifecycleAction, setLifecycleAction } from './actions';
const subscribe = () => () => {};
type Transition = { target: string; label: string; description: string };
function transitions(state: string): Transition[] {
  const archive = { target: 'archived', label: 'أرشفة الشركة', description: 'تمنع الأرشفة وصول المستخدمين. الاستعادة تعيد الشركة إلى حالة معلّقة أولًا.' };
  if (state === 'active') return [{ target: 'suspended', label: 'تعليق الشركة', description: 'يوقف وصول المستخدمين إلى بيانات الشركة حتى استعادة التشغيل.' }, archive];
  if (state === 'suspended') return [{ target: 'active', label: 'استعادة التشغيل', description: 'يعيد وصول المستخدمين إلى الشركة.' }, archive];
  return [{ target: 'suspended', label: 'استعادة إلى حالة معلّقة', description: 'تبقى بيانات العمل محجوبة. يلزم إجراء منفصل لاستعادة التشغيل.' }];
}
export function LifecycleManager({ initial }: { initial: OperatorLifecycleSnapshot }) {
  const [snapshot, setSnapshot] = useState(initial); const [choice, setChoice] = useState<Transition | null>(null);
  const [reason, setReason] = useState(''); const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false); const [unknown, setUnknown] = useState(false);
  const inFlight = useRef(false); const router = useRouter();
  const ready = useSyncExternalStore(subscribe, () => true, () => false);
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const locked = busy || unknown || offline || !ready;
  async function act(event?: FormEvent<HTMLFormElement>) {
    event?.preventDefault(); if (inFlight.current || blockOfflineSubmission()) return;
    if (event && (!choice || unknown)) return;
    inFlight.current = true; setBusy(true);
    try {
      const result = event && choice ? await setLifecycleAction(snapshot.tenant_id, snapshot.lifecycle_state, choice.target, reason) : await readLifecycleAction(snapshot.tenant_id);
      if (result.outcome === 'unknown') { setUnknown(true); setChoice(null); setMessage('لم تتأكد النتيجة. أعد قراءة الحالة قبل اختيار أي إجراء جديد.'); return; }
      if (result.outcome === 'error') { setMessage(result.message); return; }
      setSnapshot(result.snapshot); setUnknown(false); setChoice(null);
      setMessage(result.outcome === 'changed' ? `سُجّل الإجراء. الحالة الحالية: ${operatorLifecycleLabel(result.snapshot.lifecycle_state)}.` : result.outcome === 'stale' ? 'تغيّرت حالة الشركة منذ فتح الصفحة. راجع الحالة الحالية واختر الإجراء من جديد.' : 'هذه حالة الشركة الحالية؛ اختر من جديد إن لزم.');
      router.refresh();
    } catch { setUnknown(true); setChoice(null); setMessage('لم تتأكد النتيجة. أعد قراءة الحالة قبل اختيار أي إجراء جديد.'); }
    finally { inFlight.current = false; setBusy(false); }
  }
  return <section aria-labelledby="status-heading"><div className="operator-section-heading"><h2 id="status-heading">حالة الشركة</h2><Button variant="ghost" disabled={busy || offline || !ready} onClick={() => void act()}>إعادة قراءة الحالة</Button></div>
    <p>الحالة الحالية: <strong>{operatorLifecycleLabel(snapshot.lifecycle_state)}</strong>. يُحفظ سبب كل إجراء في سجل المراجعة.</p>
    {offline && <OfflineSubmissionNotice id="lifecycle-offline" purpose={unknown ? 'recovery' : 'submission'} />}
    <noscript><Banner>تحتاج إجراءات الحالة إلى JavaScript. الحالة الحالية معروضة للقراءة.</Banner></noscript>
    {message && <Banner tone={unknown ? 'warn' : 'info'} role="status">{message}</Banner>}
    <div className="operator-service-list">{transitions(snapshot.lifecycle_state).map(item => <article className="operator-service-row" key={item.target}><div><h3>{item.label}</h3><p className="field-hint">{item.description}</p></div><Button variant={item.target === 'archived' ? 'danger' : 'ghost'} disabled={locked} onClick={() => { setChoice(item); setReason(''); setMessage(''); }}>{item.label}</Button></article>)}</div>
    <Sheet open={choice !== null} onOpenChange={open => { if (!open && !inFlight.current) setChoice(null); }} title={choice?.label ?? 'تأكيد الإجراء'} description={choice?.description}>
      {choice && <form onSubmit={event => void act(event)}><fieldset className="operator-duration-fields" disabled={locked}><legend className="ui-sr">تأكيد إجراء الشركة</legend>
        <p>سيُطبق الإجراء على <strong><bdi>{snapshot.tenant_name}</bdi></strong>.</p>
        {message && <Banner role="alert">{message}</Banner>}
        <label htmlFor="lifecycle-reason">سبب الإجراء</label><Textarea id="lifecycle-reason" required minLength={3} maxLength={500} value={reason} onChange={event => setReason(event.target.value)} />
        <div className="operator-form-actions"><Button type="submit" variant={choice.target === 'archived' ? 'danger' : 'solid'} pending={busy}>{choice.label}</Button><Button variant="ghost" onClick={() => setChoice(null)}>إلغاء</Button></div>
      </fieldset></form>}
    </Sheet>
  </section>;
}
