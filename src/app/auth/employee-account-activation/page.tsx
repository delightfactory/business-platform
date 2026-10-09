import { Input } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { retryEmployeeAccountActivationAction, setEmployeeAccountPasswordAction } from './actions';

export const dynamic = 'force-dynamic';
type Search = Promise<{ intent_id?: string; state?: string }>;

export default async function EmployeeAccountActivationPage({ searchParams }: { searchParams: Search }) {
  const query = await searchParams;
  const intentId = query.intent_id ?? '';
  if (!isUuid(intentId)) return <Status title="رابط التفعيل غير صالح" detail="اطلب من الموارد البشرية إرسال رابط تفعيل جديد." />;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="الخدمة غير متاحة" detail="تعذر الاتصال بخدمة الحسابات الآن. حاول مرة أخرى لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return <Status title="الجلسة غير متاحة" detail="افتح رابط التفعيل من الرسالة التي وصلت إلى بريدك." />;
  const { data, error } = await supabase.rpc('people_employee_account_activation_snapshot', { p_intent_id: intentId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) {
    return <Status title="عملية التفعيل غير متاحة" detail="تحقق من أنك فتحت الرابط المرسل إلى هذا البريد، أو اطلب رابطًا جديدًا." />;
  }
  const intent = data as Record<string, unknown>;
  if (intent.intent_id !== intentId || (intent.state !== 'user_created' && intent.state !== 'activated')
    || (intent.state === 'user_created' && typeof intent.password_ready !== 'boolean')) {
    return <Status title="عملية التفعيل غير متاحة" detail="تعذر تأكيد حالة هذا الحساب. افتح أحدث رابط أو تواصل مع الموارد البشرية." />;
  }
  const hintMessage = query.state === 'password' && intent.password_ready === true ? null : recoveryHint(query.state);
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header>
    <section className="auth-card" aria-labelledby="employee-activation-title">
      <p className="eyebrow">تفعيل حساب الموظف</p><h1 id="employee-activation-title">إعداد حسابك</h1>
      <p className="intro">الحساب مرتبط ببريد <bdi>{String(intent.email ?? user.email ?? '')}</bdi> للموظف {String(intent.employee_name ?? '')} في {String(intent.tenant_name ?? '')}.</p>
      {intent.state === 'activated' && intent.password_ready === true ? <><p className="form-message" role="status">الحساب نشط ومرتبط بملف الموظف. تم تأكيد جاهزية كلمة المرور.</p><Link className="primary-button link-button" href="/tenant/select">المتابعة إلى مساحة العمل</Link></>
        : intent.state === 'activated' ? <>
          <p className="form-message capacity-message" role="status">الحساب نشط بالفعل. أعد تعيين كلمة المرور لتأكيد جاهزيتها. لن يغيّر ذلك عضوية الشركة أو صلاحياتها.</p>
          <OfflineForm className="auth-form" action={setEmployeeAccountPasswordAction}>
            <input type="hidden" name="intentId" value={intentId} />
            <label htmlFor="employee-password">كلمة مرور جديدة</label><Input id="employee-password" name="password" type="password" autoComplete="new-password" minLength={8} required dir="ltr" />
            <label htmlFor="employee-password-confirm">تأكيد كلمة المرور</label><Input id="employee-password-confirm" name="confirmation" type="password" autoComplete="new-password" minLength={8} required dir="ltr" />
            <p className="field-hint">لن يختارها أو يطّلع عليها مسؤول الموارد البشرية.</p>
            <OfflineSubmitButton label="تحديث كلمة المرور" pendingLabel="جارٍ التحديث…" />
          </OfflineForm>
        </> : <>
          {hintMessage && <p className="form-message capacity-message" role="status">{hintMessage}</p>}
          {intent.password_ready === true ? <>
            <p className="form-message" role="status">يمكنك متابعة التفعيل دون إعادة إدخال كلمة المرور. سيتحقق النظام من إمكانية إكمال عضوية الشركة. تواصل مع الموارد البشرية إذا استمرت المشكلة.</p>
            <OfflineForm className="auth-form" action={retryEmployeeAccountActivationAction}>
              <input type="hidden" name="intentId" value={intentId} />
              <OfflineSubmitButton label="إكمال التفعيل" pendingLabel="جارٍ التحقق…" />
            </OfflineForm>
          </> : (
          <OfflineForm className="auth-form" action={setEmployeeAccountPasswordAction}>
            <input type="hidden" name="intentId" value={intentId} />
            <label htmlFor="employee-password">أنشئ كلمة المرور</label><Input id="employee-password" name="password" type="password" autoComplete="new-password" minLength={8} required dir="ltr" />
            <label htmlFor="employee-password-confirm">تأكيد كلمة المرور</label><Input id="employee-password-confirm" name="confirmation" type="password" autoComplete="new-password" minLength={8} required dir="ltr" />
            <p className="field-hint">لن يختارها أو يطّلع عليها مسؤول الموارد البشرية.</p>
            <OfflineSubmitButton label="حفظ وتفعيل الحساب" pendingLabel="جارٍ التفعيل…" />
          </OfflineForm>
          )}
        </>}
    </section></main>;
}

function recoveryHint(state?: string) {
  if (typeof state !== 'string') return null;
  const hints: Record<string, string> = {
    password: 'استخدم 8 أحرف على الأقل وتأكد من تطابق الحقلين.',
    readiness: 'إذا لم يكتمل إعداد الحساب، نفّذ الخطوة الموضحة أدناه. تواصل مع الموارد البشرية إذا استمرت المشكلة.',
    retry: 'إذا لم يكتمل التفعيل، نفّذ الخطوة الموضحة أدناه أو تواصل مع الموارد البشرية.',
    'limit-full': 'إذا استمرت مشكلة المقاعد، اطلب من مسؤول الشركة مراجعة الحد قبل المحاولة التالية.',
    'employee-unavailable': 'إذا استمرت مشكلة ملف الموظف، تواصل مع الموارد البشرية لمراجعته قبل المحاولة التالية.',
  };
  return Object.hasOwn(hints, state) ? hints[state] : null;
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header>
    <section className="auth-card"><h1>{title}</h1><p className="intro" role="alert">{detail}</p></section></main>;
}
