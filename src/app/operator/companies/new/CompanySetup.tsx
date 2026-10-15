'use client';
import { useRef, useState, useSyncExternalStore, type FormEvent, type ReactNode } from 'react';
import { Banner, Button, ButtonLink } from '@/components/ui';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { OnboardingForm } from '../../onboarding/OnboardingForm';
import { createInvitationAction, type InvitationFormState } from '../../invitations/actions';
import { CompanySetupFields, initialSetupValues, type SetupValues } from './CompanySetupFields';
const subscribe = () => () => {};

export function CompanySetup({ actorId, requestKey, initialMode, canManageServices }: { actorId: string; requestKey: string; initialMode: 'invite' | 'existing'; canManageServices: boolean }) {
  const [key] = useState(requestKey);
  const [mode, setMode] = useState(initialMode);
  const [locked, setLocked] = useState(false);
  const [values, setValues] = useState<SetupValues>(initialSetupValues);
  const ready = useSyncExternalStore(subscribe, () => true, () => false);
  const fields = <CompanySetupFields mode={mode} values={values} onChange={(field, value) => setValues(previous => ({ ...previous, [field]: value }))} />;
  return <div className="operator-company-setup"><fieldset className="operator-setup-mode" disabled={locked || !ready}><legend>كيف سينضم مسؤول الشركة؟</legend>
    <label className={mode === 'invite' ? 'is-selected' : ''}><input type="radio" name="setupMode" value="invite" checked={mode === 'invite'} onChange={() => setMode('invite')} /><span><strong>أرسل دعوة للمسؤول</strong><small>ليس لديه حساب. تُنشأ الشركة بعد قبول الدعوة.</small></span></label>
    <label className={mode === 'existing' ? 'is-selected' : ''}><input type="radio" name="setupMode" value="existing" checked={mode === 'existing'} onChange={() => setMode('existing')} /><span><strong>أنشئ الشركة الآن</strong><small>لدى المسؤول حساب موجود وبريد مؤكد.</small></span></label>
  </fieldset>
    {mode === 'existing' ? <OnboardingForm actorId={actorId} requestKey={key} canManageServices={canManageServices} onDispatch={() => setLocked(true)}>{fields}</OnboardingForm>
      : <SetupInvitationForm requestKey={key} onDispatch={() => setLocked(true)}>{fields}</SetupInvitationForm>}
  </div>;
}

const errors = {
  invalid: 'راجع اسم الشركة والبريد والحدود، ثم حاول من جديد.',
  setup: 'تعذر الاتصال بخدمة الدعوات. بياناتك ما زالت في هذه الصفحة.',
  forbidden: 'لم تعد صلاحية إنشاء الدعوات متاحة لهذا الحساب.',
  conflict: 'هذا الطلب مرتبط ببيانات مختلفة. راجع الدعوات قبل بدء طلب آخر.',
  unknown: 'لم تتأكد نتيجة الطلب. راجع الدعوات قبل إرسال طلب آخر.',
};
function SetupInvitationForm({ requestKey, onDispatch, children }: { requestKey: string; onDispatch: () => void; children: ReactNode }) {
  const [answer, setAnswer] = useState<InvitationFormState>({ error: null, attempt: 0, values: { idempotencyKey: requestKey, tenantName: '', entityName: '', siteName: 'المقر الرئيسي', targetEmail: '', seatsMode: 'limited', seatsLimit: '10', sitesMode: 'limited', sitesLimit: '10' } });
  const [pending, setPending] = useState(false); const inFlight = useRef(false);
  const ready = useSyncExternalStore(subscribe, () => true, () => false);
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const frozen = answer.error === 'unknown' || answer.error === 'conflict';
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (!ready || inFlight.current || frozen || blockOfflineSubmission()) return;
    const original = new FormData(event.currentTarget); onDispatch(); inFlight.current = true; setPending(true);
    try {
      const result = await createInvitationAction(answer, original);
      if (!result || !result.values || typeof result.attempt !== 'number') throw new Error('unconfirmed');
      setAnswer(result);
    } catch { setAnswer(previous => ({ ...previous, error: 'unknown' })); }
    finally { inFlight.current = false; setPending(false); }
  }
  const receipt = answer.receipt;
  if (receipt) return <section className="operator-setup-result" role="status">
    <h2>{receipt.created ? 'أُنشئت الدعوة؛ لم تُنشأ الشركة بعد.' : receipt.lifecycle === 'accepted' ? 'قُبلت هذه الدعوة من قبل.' : 'هذه الدعوة محفوظة من قبل.'}</h2>
    <p>{receipt.lifecycle === 'accepted' ? 'تابع الدعوة لمراجعة الشركة التي أُنشئت.' : 'تُنشأ الشركة بفرعها وحدودها عند قبول مسؤولها الأول للدعوة.'}</p>
    <p>{receipt.delivery === 'sent' ? 'قبلت خدمة البريد الإرسال؛ لا يؤكد ذلك وصول الرسالة أو قبول الدعوة.' : receipt.delivery === 'failed' ? 'حُفظت الدعوة، وتعذر إرسال البريد. يمكنك متابعة الدعوة واختيار إرسال رابط جديد.' : 'حُفظت الدعوة، ولم تتأكد نتيجة إرسال البريد. راجع حالتها قبل اختيار إعادة الإرسال.'}</p>
    <ButtonLink href={`/operator/invitations?id=${receipt.id}`}>متابعة الدعوة</ButtonLink>
    <form method="get" action="/operator/companies/new"><input type="hidden" name="mode" value="invite" /><Button variant="ghost" type="submit">شركة أخرى</Button></form>
  </section>;
  return <div>
    {answer.error && <Banner tone="warn" role="alert">{errors[answer.error]}{frozen && <p><ButtonLink variant="ghost" href="/operator/invitations">مراجعة الدعوات</ButtonLink></p>}</Banner>}
    <form onSubmit={event => void submit(event)} className="onboarding-form" aria-busy={pending}>
      <fieldset className="operator-action-fields" disabled={!ready || pending || frozen}><input type="hidden" name="idempotencyKey" value={requestKey} />{children}<Button type="submit" disabled={offline} pending={pending} pendingLabel="جارٍ إنشاء الدعوة…">إرسال الدعوة</Button></fieldset>
      {offline && <OfflineSubmissionNotice id="setup-invitation-offline" purpose={frozen ? 'recovery' : 'submission'} />}
      <noscript><Banner>يمكنك قراءة البيانات؛ يتطلب الإرسال JavaScript.</Banner></noscript>
    </form>
  </div>;
}
