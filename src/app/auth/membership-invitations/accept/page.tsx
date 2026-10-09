import { Button, ButtonLink, Input } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { acceptMemberInvitationAction, setMemberInvitationPasswordAction } from './actions';

export const dynamic = 'force-dynamic';
type Search = Promise<{ id?: string; issuance?: string; state?: string }>;

export default async function AcceptMemberInvitationPage({ searchParams }: { searchParams: Search }) {
  const query = await searchParams; const id = query.id ?? ''; const issuance = query.issuance ?? '';
  if (!isUuid(id) || !/^\d+$/.test(issuance)) return <Status title="رابط الدعوة غير صالح" detail="افتح أحدث رسالة وصلتك أو اطلب إعادة إرسال الدعوة." />;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/auth/membership-invitations/accept?id=${id}&issuance=${issuance}`)}`);
  const { data: validation, error } = await supabase.rpc('validate_tenant_member_invitation', { p_invitation_id: id, p_issuance: Number(issuance) });
  if (error || (validation !== 'ready' && validation !== 'password_required')) return <Status title="تعذر قبول الدعوة" detail={validationMessage(error ? null : validation, query.state)} />;
  const needsPassword = validation === 'password_required';
  const passwordHint = ['password-set', 'password', 'marker-failed'].includes(query.state ?? '');
  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link><form action={signOutAction}><Button variant="ghost" className="secondary-button" type="submit">تسجيل الخروج</Button></form></header>
      <section className="auth-card" aria-labelledby="accept-title">
        <p className="eyebrow">دعوة عضو</p><h1 id="accept-title">الانضمام إلى الشركة</h1>
        <p className="intro">الدعوة مرتبطة بالبريد <bdi>{user.email}</bdi>. سيُمنح حسابك دور «عضو» بعد تأكيد القبول.</p>
        {passwordHint && <p className="form-message" role="status">{needsPassword ? 'يحتاج هذا الحساب إلى إعداد كلمة المرور. استخدم ثمانية أحرف على الأقل ثم أكمل الخطوة أدناه.' : 'الحساب جاهز للخطوة التالية. يمكنك متابعة قبول الدعوة.'}</p>}
        {query.state && !passwordHint && <p className="form-message" role="alert">{validationMessage(validation, query.state)}</p>}
        {needsPassword ? <OfflineForm className="auth-form" action={setMemberInvitationPasswordAction}>
          <input type="hidden" name="invitationId" value={id} /><input type="hidden" name="issuance" value={issuance} />
          <label htmlFor="member-password">أنشئ كلمة مرور لحسابك</label><Input id="member-password" name="password" type="password" autoComplete="new-password" minLength={8} required />
          <p className="field-hint">ثمانية أحرف على الأقل. ستُستخدم كلمة المرور نفسها لكل مساحاتك.</p>
          <OfflineSubmitButton label="حفظ كلمة المرور" pendingLabel="جارٍ الحفظ…" />
        </OfflineForm> : <OfflineForm className="auth-form" action={acceptMemberInvitationAction}>
          <input type="hidden" name="invitationId" value={id} /><input type="hidden" name="issuance" value={issuance} />
          <OfflineSubmitButton label="قبول الدعوة" pendingLabel="جارٍ القبول…" />
        </OfflineForm>}
      </section>
    </main>
  );
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function validationMessage(validation: unknown, state?: string) {
  if (state === 'password') return 'تعذر تأكيد حالة الحساب أو الدعوة الآن. اطلب من مسؤول الشركة مراجعتها.';
  if (state === 'marker-failed') return 'تعذر تأكيد حالة الحساب أو الدعوة الآن. اطلب من مسؤول الشركة مراجعتها.';
  if (state === 'limit-full') return 'اكتمل عدد المستخدمين المسموح به. اطلب من مسؤول الشركة معالجة المقاعد ثم أعد المحاولة؛ الدعوة ما زالت محفوظة.';
  if (state === 'issuer-lost') return 'لم تعد صلاحية مُصدر الدعوة سارية. يمكن لمسؤول مخوّل مراجعة الطلب وإصدار دعوة جديدة.';
  if (state === 'identity') return 'استخدم الحساب المؤكد بالبريد الذي وصلت إليه الدعوة.';
  if (state === 'unverified') return 'أكد بريدك الإلكتروني أولًا ثم افتح أحدث رابط.';
  if (state === 'superseded') return 'صدر رابط أحدث. استخدم آخر رسالة وصلتك.';
  if (state === 'tenant-unavailable') return 'هذه الشركة غير متاحة حاليًا.';
  if (state === 'target-unavailable') return 'تعذر الانضمام بالحساب الحالي. اطلب من مسؤول الشركة مراجعة الحساب المرتبط بالدعوة.';
  if (validation === 'password_required') return 'يحتاج هذا الحساب إلى كلمة مرور قبل الانضمام.';
  if (validation === 'unavailable') return 'الدعوة غير متاحة أو انتهت صلاحيتها. اطلب إعادة إرسالها من مسؤول الشركة.';
  return 'تعذر التحقق من حالة الدعوة. اطلب من مسؤول الشركة مراجعتها قبل المتابعة.';
}
function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header><section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p><ButtonLink variant="solid" className="primary-button" href="/auth/login">العودة إلى الدخول</ButtonLink></section></main>;
}
