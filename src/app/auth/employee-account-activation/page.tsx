import Link from 'next/link';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { SubmitButton } from '@/components/submit-button';
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
  const state = query.state ?? String(intent.state ?? 'user_created');
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header>
    <section className="auth-card" aria-labelledby="employee-activation-title">
      <p className="eyebrow">تفعيل حساب الموظف</p><h1 id="employee-activation-title">إعداد حسابك</h1>
      <p className="intro">الحساب مرتبط ببريد <bdi>{String(intent.email ?? user.email ?? '')}</bdi> للموظف {String(intent.employee_name ?? '')} في {String(intent.tenant_name ?? '')}.</p>
      {intent.state === 'activated' && intent.password_ready === true ? <p className="form-message" role="status">{state === 'password-ready'
        ? 'تم تحديث كلمة المرور وتأكيد جاهزيتها. الحساب نشط بالفعل؛ لم تتغير العضوية أو الصلاحيات.'
        : 'الحساب نشط ومرتبط بملف الموظف. تم تأكيد جاهزية كلمة المرور.'}</p>
        : intent.state === 'activated' ? <>
          {state === 'password-ready' && intent.password_ready === true ? <p className="form-message" role="status">تم تحديث كلمة المرور وتأكيد جاهزيتها. الحساب نشط بالفعل؛ لم تتغير العضوية أو الصلاحيات.</p>
            : <p className="form-message capacity-message" role="status">الحساب نشط بالفعل. أعد تعيين كلمة المرور لتأكيد جاهزيتها. لن يغيّر ذلك عضوية الشركة أو صلاحياتها.</p>}
          {state !== 'password-ready' && <form className="auth-form" action={setEmployeeAccountPasswordAction}>
            <input type="hidden" name="intentId" value={intentId} />
            <label htmlFor="employee-password">كلمة مرور جديدة</label><input id="employee-password" name="password" type="password" autoComplete="new-password" minLength={8} required dir="ltr" />
            <label htmlFor="employee-password-confirm">تأكيد كلمة المرور</label><input id="employee-password-confirm" name="confirmation" type="password" autoComplete="new-password" minLength={8} required dir="ltr" />
            <p className="field-hint">لن يختارها أو يطّلع عليها مسؤول الموارد البشرية.</p>
            <SubmitButton label="تحديث كلمة المرور" pendingLabel="جارٍ التحديث…" />
          </form>}
        </> : state === 'limit-full' ? <>
        <p className="form-message capacity-message" role="status">اكتمل عدد المستخدمين المسموح به حاليًا. أُكد بريدك وحُفظت كلمة المرور، لكن العضوية لم تُفعّل بعد. اطلب من مسؤول الشركة معالجة المقاعد ثم أعد المحاولة.</p>
        <form className="auth-form" action={retryEmployeeAccountActivationAction}><input type="hidden" name="intentId" value={intentId} />
          <SubmitButton label="إكمال التفعيل" pendingLabel="جارٍ التحقق…" /></form>
      </> : state === 'employee-unavailable' ? <p className="form-message error-message" role="alert">تعذر إكمال التفعيل لأن ملف الموظف لم يعد نشطًا. تواصل مع الموارد البشرية.</p>
        : <>
          {state === 'password' && <p className="form-message error-message" role="alert">تعذر حفظ كلمة المرور. استخدم 8 أحرف على الأقل وتأكد من تطابق الحقلين.</p>}
          {state === 'readiness' && <p className="form-message capacity-message" role="alert">تم حفظ كلمة المرور، لكن تعذر تأكيد جاهزية الحساب. أعد حفظها لإكمال التفعيل.</p>}
          {state === 'retry' && <p className="form-message capacity-message" role="alert">تم حفظ كلمة المرور، لكن تعذر إكمال عضوية الشركة الآن. أعد المحاولة أو تواصل مع الموارد البشرية.</p>}
          <form className="auth-form" action={setEmployeeAccountPasswordAction}>
            <input type="hidden" name="intentId" value={intentId} />
            <label htmlFor="employee-password">أنشئ كلمة المرور</label><input id="employee-password" name="password" type="password" autoComplete="new-password" minLength={8} required dir="ltr" />
            <label htmlFor="employee-password-confirm">تأكيد كلمة المرور</label><input id="employee-password-confirm" name="confirmation" type="password" autoComplete="new-password" minLength={8} required dir="ltr" />
            <p className="field-hint">لن يختارها أو يطّلع عليها مسؤول الموارد البشرية.</p>
            <SubmitButton label="حفظ وتفعيل الحساب" pendingLabel="جارٍ التفعيل…" />
          </form>
        </>}
    </section></main>;
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header>
    <section className="auth-card"><h1>{title}</h1><p className="intro" role="alert">{detail}</p></section></main>;
}
