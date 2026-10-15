'use client';
import { useRef, useState, useSyncExternalStore, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { Banner, Button, Disclosure, Input, SegmentedControl, Textarea, Toast } from '@/components/ui';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import type { OperatorCommercialSnapshot, OperatorLimit } from '@/lib/operator-read';
import { readLimitsAction, setLimitAction } from './actions';
const subscribe = () => () => {};
const label = (key: string) => key === 'tenant.users' ? 'المستخدمون النشطون' : 'الفروع النشطة';
export function LimitManager({ initial }: { initial: OperatorCommercialSnapshot }) {
  const [snapshot, setSnapshot] = useState(initial);
  const [editing, setEditing] = useState<OperatorLimit['capability_key'] | null>(null);
  const [mode, setMode] = useState('limited'); const [value, setValue] = useState(''); const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false); const [unknown, setUnknown] = useState(false);
  const [message, setMessage] = useState(''); const [toast, setToast] = useState('');
  const inFlight = useRef(false); const router = useRouter();
  const ready = useSyncExternalStore(subscribe, () => true, () => false);
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const locked = busy || unknown || offline || !ready;
  function accept(next: OperatorCommercialSnapshot) { setSnapshot(next); if (next.lifecycle_state !== initial.lifecycle_state) router.refresh(); }
  async function read() {
    if (inFlight.current || blockOfflineSubmission()) return;
    inFlight.current = true; setBusy(true);
    try {
      const result = await readLimitsAction(snapshot.tenant_id);
      if (!('snapshot' in result)) { setMessage('تعذر قراءة الحدود. أعد المحاولة بعد التحقق من الاتصال والصلاحية.'); return; }
      accept(result.snapshot); setUnknown(false); setEditing(null); setMessage('هذه الحدود الحالية؛ اختر من جديد إن لزم.');
    } catch { setMessage('تعذر قراءة الحدود. حاول مرة أخرى بعد التحقق من الاتصال.'); }
    finally { inFlight.current = false; setBusy(false); }
  }
  async function save(event: FormEvent<HTMLFormElement>, row: OperatorLimit) {
    event.preventDefault(); if (inFlight.current || unknown || blockOfflineSubmission()) return;
    inFlight.current = true; setBusy(true); setMessage(''); setToast('');
    try {
      const result = await setLimitAction(snapshot.tenant_id, row.capability_key, mode, mode === 'limited' ? Number(value) : null, row.valid_from, note);
      if (result.outcome === 'unknown') { setUnknown(true); setMessage('لم تتأكد نتيجة الطلب. أعد قراءة الحدود قبل إرسال أي تعديل آخر.'); return; }
      if (result.outcome === 'error') { setMessage(result.message); return; }
      accept(result.snapshot);
      if (result.outcome === 'stale') { setMessage('تغيّر الحد منذ فتح المحرر. راجع الحد الحالي ثم أعد الاختيار.'); return; }
      setEditing(null);
      if (result.outcome === 'changed') setToast('حُفظ حد الاستخدام.'); else setMessage('الحد الحالي يطابق ما طلبته؛ لم يُسجَّل تغيير جديد.');
    } catch { setUnknown(true); setMessage('لم تتأكد نتيجة الطلب. أعد قراءة الحدود قبل إرسال أي تعديل آخر.'); }
    finally { inFlight.current = false; setBusy(false); }
  }
  return <section aria-labelledby="limits-heading"><div className="operator-section-heading"><h2 id="limits-heading">حدود الاستخدام</h2><Button variant="ghost" disabled={!ready || busy || offline} onClick={() => void read()}>إعادة قراءة الحدود</Button></div>
    <noscript><Banner>الحدود معروضة للقراءة. يحتاج التحرير إلى JavaScript.</Banner></noscript>
    {offline && <OfflineSubmissionNotice id="limits-offline" purpose={unknown ? 'recovery' : 'submission'} />}
    {message && <Banner tone={unknown ? 'warn' : 'info'} role="status">{message}</Banner>}
    <div className="operator-service-list">{[...snapshot.limits].sort((a, b) => Number(a.capability_key === 'tenant.sites') - Number(b.capability_key === 'tenant.sites')).map(row => {
      const blocked = row.status === 'conflict' || row.status === 'future_conflict';
      const finite = row.status === 'effective' && row.mode === 'limited' && row.value !== null;
      return <article className="operator-limit-row" key={row.capability_key}><div className="operator-section-heading"><div><h3>{label(row.capability_key)}</h3>
        <p>{row.status === 'missing' ? `${row.usage} قيد الاستخدام · لا يوجد حد فعّال` : blocked ? 'تحتاج الإعدادات إلى مراجعة فنية' : row.mode === 'unlimited' ? `${row.usage} · بلا حد` : `${row.usage} من ${row.value}`}</p></div>
        {!blocked && editing !== row.capability_key && <Button variant="ghost" disabled={locked} aria-label={`تعديل حد ${row.capability_key === 'tenant.users' ? 'المستخدمين' : 'الفروع'}`}
          onClick={() => { setEditing(row.capability_key); setMode(row.mode ?? 'limited'); setValue(row.value?.toString() ?? ''); setNote(''); setMessage(''); }}>تعديل</Button>}</div>
        {finite && <meter min={0} max={Math.max(row.value!, row.usage, 1)} value={row.usage} aria-label={`استخدام ${row.capability_key === 'tenant.users' ? 'المستخدمين' : 'الفروع'}`} aria-valuetext={`${row.usage} من ${row.value}`} />}
        {finite && row.usage >= row.value! && <p className="field-hint">يبقى الموجود نشطًا؛ تُمنع الإضافة حتى ينخفض الاستخدام إلى ما دون الحد أو يُرفع الحد.</p>}
        {row.status === 'missing' && <p className="field-hint">حدد حدًا جديدًا قبل متابعة إدارة النمو.</p>}
        {editing === row.capability_key && <form onSubmit={event => void save(event, row)} className="operator-limit-editor"><fieldset disabled={locked} className="operator-duration-fields"><legend>تعديل حد {row.capability_key === 'tenant.users' ? 'المستخدمين' : 'الفروع'}</legend>
          <SegmentedControl label="نوع الحد" value={mode} onChange={setMode} options={[{ value: 'limited', label: 'عدد محدد' }, { value: 'unlimited', label: 'غير محدود' }]} />
          {mode === 'limited' && <><label htmlFor="new-commercial-limit">الحد الجديد</label><Input id="new-commercial-limit" type="number" required min={1} step={1} value={value} onChange={event => setValue(event.target.value)}  placeholder="مثال: 10"/></>}
          {mode === 'limited' && Number(value) > 0 && Number(value) < row.usage && <Banner tone="warn">الاستخدام الحالي {row.usage} أعلى من {value}: يبقى الموجود نشطًا، ولن تُضاف موارد جديدة حتى ينخفض الاستخدام أو يُرفع الحد.</Banner>}
          <Disclosure summary="إضافة ملاحظة (اختياري)"><label htmlFor="commercial-limit-note">الملاحظة</label><Textarea id="commercial-limit-note" value={note} maxLength={500} onChange={event => setNote(event.target.value)}  placeholder="مثال: تعديل وفق الاتفاق المحدث مع الشركة"/></Disclosure>
          <div className="operator-form-actions"><Button type="submit" pending={busy}>حفظ الحد</Button><Button variant="ghost" onClick={() => setEditing(null)}>إلغاء</Button></div>
        </fieldset></form>}
      </article>;
    })}</div>{toast && <Toast key={toast} message={toast} />}
  </section>;
}
