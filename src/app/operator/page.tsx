import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { signOutAction } from '@/app/auth/actions';

export const dynamic = 'force-dynamic';

export default async function OperatorPage() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة إلى ملف البيئة ثم أعد تشغيل التطبيق." />;
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  if (userError) return <Status title="تعذر التحقق من الجلسة" detail="حاول تسجيل الدخول مرة أخرى." link="/auth/login" linkText="تسجيل الدخول" />;
  const { data: status, error } = await supabase.rpc('current_platform_operator_status');
  if (error) return <Status title="تعذر التحقق من الصلاحية" detail="تعذر التحقق من صلاحية مشغّل المنصة. حاول لاحقًا." />;
  if (status === 'not_operator') return <Status title="لا توجد صلاحية تشغيل" detail="هذا الحساب لا يملك صلاحية مشغّل المنصة." />;
  if (status !== 'active') return <Status title="تم إيقاف الصلاحية" detail="صلاحية هذا الحساب غير مفعلة حاليًا. سجّل الخروج واطلب مراجعة الوصول." />;
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link><form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></header><section className="auth-card" aria-labelledby="operator-title"><p className="eyebrow">بوابة مشغّل المنصة</p><h1 id="operator-title">تم التحقق من صلاحية التشغيل</h1><p className="intro">هذه بوابة تأسيسية. أدوات إدارة المنصة ستضاف في مراحل لاحقة.</p><p className="foundation-note">الحساب: <bdi>{user.email ?? 'مستخدم موثّق'}</bdi></p></section><footer className="footer">منصة الأعمال · أساس التطوير</footer></main>;
}

function Status({ title, detail, link, linkText }: { title: string; detail: string; link?: string; linkText?: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link><form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></header><section className="auth-card" aria-labelledby="status-title"><p className="eyebrow">بوابة مشغّل المنصة</p><h1 id="status-title">{title}</h1><p className="intro">{detail}</p>{link && <a className="primary-button link-button" href={link}>{linkText}</a>}</section><footer className="footer">منصة الأعمال · أساس التطوير</footer></main>;
}
