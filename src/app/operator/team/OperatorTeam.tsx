'use client';
import { useId, useRef, useState, useSyncExternalStore, type FormEvent } from 'react';
import { unstable_rethrow } from 'next/navigation';
import { Banner, Badge, Button, Checkbox, Input, PageHeader, Sheet, Textarea } from '@/components/ui';
import { useOfflineSubmission, OfflineSubmissionNotice } from '@/components/offline-submission';
import { operatorCapabilities, type OperatorGrant } from '@/lib/operator-read';
import { operatorTaskLabels } from '@/lib/operator-labels';
import { changeOperatorGrantAction } from '../operators/actions';
const subscribe = () => () => {};
const tasks = [
  { key: 'can_manage_operators', field: 'canManageOperators', description: 'إضافة المشغّلين وتعديل مهامهم وسحبها.' },
  { key: 'can_onboard_tenants', field: 'canOnboardTenants', description: 'إنشاء الشركات وإرسال دعوات مسؤوليها ومتابعتها.' },
  { key: 'can_manage_tenant_lifecycle', field: 'canManageTenantLifecycle', description: 'تعليق الشركات واستعادتها وأرشفتها.' },
  { key: 'can_manage_commercial_access', field: 'canManageCommercialAccess', description: 'تفعيل خدمات الشركات وتحديد حدود الاستخدام.' },
  { key: 'can_manage_statutory_rules', field: 'canManageStatutoryRules', description: 'إدارة نسخ القواعد القانونية للرواتب؛ لا يمنح ذلك اعتمادها للحساب تلقائيًا.' },
] as const;
const errors: Record<string, string> = {
  invalid: 'راجع البريد والإجراء المحدد.', capability: 'اختر مهمة واحدة على الأقل. لسحب جميع المهام استخدم سحب الصلاحية.', reason: 'أدخل سببًا من 3 إلى 500 حرف.',
  setup: 'تعذر الاتصال بالخدمة.', forbidden: 'لم تعد صلاحية إدارة فريق التشغيل متاحة.', 'target-unavailable': 'الحساب غير موجود، أو بريده غير مؤكد، أو غير جاهز لتسجيل الدخول.',
  'last-manager': 'يجب أن يبقى مدير واحد على الأقل قادرًا على إدارة فريق التشغيل.', 'already-active': 'الحساب لديه منح نشط بالفعل. أعد القراءة لتعديل مهامه.',
  'already-revoked': 'الصلاحية مسحوبة بالفعل.', 'not-active': 'لا يوجد منح نشط لتعديله.', unchanged: 'لم تتغير المهام.', unavailable: 'تعذر التحقق من حسابك قبل الإرسال. احتفظ بالبيانات وأعد القراءة.',
};
type Edit = { action: 'grant' | 'update' | 'revoke'; grant?: OperatorGrant };
export function OperatorTeam({ grants, currentUserId, changed }: { grants: OperatorGrant[]; currentUserId: string; changed: boolean }) {
  const [edit, setEdit] = useState<Edit | null>(null);
  const [pending, setPending] = useState(false);
  const [unknown, setUnknown] = useState(false);
  const ready = useSyncExternalStore(subscribe, () => true, () => false);
  const locked = !ready || pending || unknown;
  return <>
    <PageHeader title="فريق التشغيل" description="حدّد مهام كل مشغّل. يظهر أثر التغيير قبل حفظه، ويُسجل السبب." action={<Button disabled={locked} onClick={() => setEdit({ action: 'grant' })}>إضافة مشغّل</Button>} />
    {changed && <Banner>راجع المهام الحالية أدناه؛ الرابط وحده لا يؤكد حفظ تغيير.</Banner>}
    {unknown && <Banner tone="warn" role="alert">لم تتأكد نتيجة التغيير. أعد قراءة الفريق قبل إجراء آخر؛ القراءة لا تثبت وحدها نتيجة المحاولة السابقة.</Banner>}
    <div className="operator-team-refresh"><a className="ui-button ui-button-ghost ui-button-md" href="/operator/team">إعادة قراءة الفريق</a><p className="field-hint">تعرض القراءة الحالة الحالية وتترك الإدخالات غير المرسلة.</p></div>
    <noscript><Banner tone="warn">يمكنك مراجعة الفريق؛ تغيير الصلاحيات يتطلب JavaScript.</Banner></noscript>
    <ul className="operator-team-list">{grants.map(grant => <li className="operator-team-row" key={grant.user_id}>
      <div className="operator-team-identity"><h2><bdi>{grant.email}</bdi></h2><div><Badge tone={grant.is_active ? 'ok' : 'neutral'}>{grant.is_active ? 'نشط' : 'مسحوب'}</Badge>{grant.user_id === currentUserId && <Badge>أنت</Badge>}</div>
        {!grant.recoverable && <p className="field-hint">الحساب غير جاهز لتسجيل الدخول</p>}
        <ul className="operator-team-tasks" aria-label={`مهام ${grant.email}`}>{operatorCapabilities.filter(key => grant[key]).map(key => <li key={key}>{operatorTaskLabels[key]}</li>)}{!operatorCapabilities.some(key => grant[key]) && <li>لا توجد مهام حاليًا</li>}</ul>
      </div>
      <div className="operator-team-actions">{grant.recoverable && <Button variant="ghost" disabled={locked} aria-label={`${grant.is_active ? 'تعديل المهام' : 'إعادة منح المهام'}: ${grant.email}`} onClick={() => setEdit({ action: grant.is_active ? 'update' : 'grant', grant })}>{grant.is_active ? 'تعديل المهام' : 'إعادة منح المهام'}</Button>}
        {grant.is_active && <Button variant="ghost" className="danger-action" disabled={locked} aria-label={`سحب الصلاحية: ${grant.email}`} onClick={() => setEdit({ action: 'revoke', grant })}>سحب الصلاحية</Button>}</div>
    </li>)}</ul>
    {!grants.length && <p>لا يوجد مشغّلون في القائمة الحالية.</p>}
    <Sheet open={Boolean(edit)} onOpenChange={open => { if (!open && !pending) setEdit(null); }} title={edit?.action === 'revoke' ? 'سحب صلاحية التشغيل' : edit?.grant ? 'مهام المشغّل' : 'إضافة مشغّل'}>
      {edit && <TaskForm edit={edit} currentUserId={currentUserId} pending={pending} locked={locked} onPending={setPending} onUnknown={() => setUnknown(true)} />}
    </Sheet>
  </>;
}
function TaskForm({ edit, currentUserId, pending, locked, onPending, onUnknown }: { edit: Edit; currentUserId: string; pending: boolean; locked: boolean; onPending: (pending: boolean) => void; onUnknown: () => void }) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const [selected, setSelected] = useState(() => tasks.map(task => edit.action !== 'revoke' && Boolean(edit.grant?.[task.key])));
  const [error, setError] = useState<string | null>(null);
  const inFlight = useRef(false); const offlineHint = useId();
  const self = edit.grant?.user_id === currentUserId;
  const added = tasks.filter((task, index) => selected[index] && !(edit.grant?.is_active && edit.grant[task.key]));
  const removed = tasks.filter((task, index) => !selected[index] && edit.grant?.is_active && edit.grant[task.key]);
  async function submit(event: FormEvent<HTMLFormElement>) {
    if (blockOfflineSubmission(event)) return;
    event.preventDefault();
    if (locked || inFlight.current) return;
    const data = new FormData(event.currentTarget);
    inFlight.current = true; onPending(true); setError(null);
    try {
      const result = await changeOperatorGrantAction(data);
      if (result === 'failed' || !result) { onUnknown(); setError('لم تتأكد النتيجة. أعد قراءة الفريق قبل أي إرسال آخر.'); }
      else setError(errors[result] ?? 'تعذر إتمام الإجراء. أعد القراءة قبل محاولة أخرى.');
    } catch (caught) { unstable_rethrow(caught); onUnknown(); setError('انقطع الاتصال قبل التأكد من النتيجة. أعد قراءة الفريق قبل إجراء آخر.'); }
    finally { inFlight.current = false; onPending(false); }
  }
  return <form onSubmit={submit} className="auth-form operator-task-form" aria-busy={pending}>
    {edit.grant && <p className="operator-team-target"><bdi>{edit.grant.email}</bdi>{self && <Badge>أنت</Badge>}</p>}
    {edit.action === 'revoke' && <Banner tone="warn">ستُسحب جميع مهام التشغيل لهذا الحساب. يبقى سجل التغيير وسببه محفوظًا.</Banner>}
    {self && <Banner tone="warn">{edit.action === 'revoke' ? 'ستُنهي هذه الخطوة وصولك التشغيلي وتسجيل دخولك المحلي.' : !selected[0] ? 'ستفقد إدارة الفريق فور الحفظ. يجب أن يبقى مدير آخر مؤهل.' : 'أنت تعدّل مهام حسابك الحالي. راجع أثر التغيير قبل الحفظ.'}</Banner>}
    <fieldset disabled={locked} className="operator-task-fields">
      <input type="hidden" name="action" value={edit.action} />
      {edit.grant ? <input type="hidden" name="email" value={edit.grant.email} /> : <div><label htmlFor="operator-email">بريد الحساب المؤكد</label><Input id="operator-email" name="email" type="email" dir="ltr" required maxLength={254} autoComplete="email" /><p className="field-hint">يجب أن يكون الحساب موجودًا وبريده مؤكدًا وقادرًا على تسجيل الدخول.</p></div>}
      {edit.action !== 'revoke' && <fieldset className="operator-task-choices"><legend>المهام المسموح بها</legend>{tasks.map((task, index) => <label key={task.key}><Checkbox name={task.field} checked={selected[index]} onChange={event => setSelected(previous => previous.map((value, slot) => slot === index ? event.target.checked : value))} /><span><strong>{operatorTaskLabels[task.key]}</strong><small>{task.description}</small></span></label>)}</fieldset>}
      <section className="operator-task-diff" aria-label="أثر التغيير" aria-live="polite"><h3>أثر التغيير</h3><p>سيُضاف: {added.map(task => operatorTaskLabels[task.key]).join('، ') || 'لا شيء'}</p><p>سيُزال: {removed.map(task => operatorTaskLabels[task.key]).join('، ') || 'لا شيء'}</p></section>
      <div><label htmlFor="operator-reason">سبب {edit.action === 'revoke' ? 'السحب' : 'التغيير'}</label><Textarea id="operator-reason" name="reason" required minLength={3} maxLength={500} rows={3} /><p className="field-hint">من 3 إلى 500 حرف. يُحفظ مع حالة الصلاحيات قبل التغيير وبعده.</p></div>
      {error && <Banner tone="bad" role="alert">{error}</Banner>}
      <Button variant={edit.action === 'revoke' ? 'danger' : 'solid'} type="submit" aria-describedby={offline ? offlineHint : undefined} disabled={locked || offline || (edit.action !== 'revoke' && !selected.some(Boolean))}>{pending ? 'جارٍ الحفظ…' : edit.action === 'revoke' ? 'تأكيد سحب الصلاحية' : 'حفظ المهام'}</Button>
    </fieldset>
    {offline && <OfflineSubmissionNotice id={offlineHint} purpose="continuation" />}
    <a className="ui-button ui-button-ghost ui-button-md" href="/operator/team">إعادة قراءة الفريق</a>
  </form>;
}
