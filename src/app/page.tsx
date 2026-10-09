import Link from 'next/link';
import { ButtonLink, Icon } from '@/components/ui';
export default function Home() {
  return <main className="app-shell welcome-page">
    <header className="topbar"><Link className="brand" href="/"><span className="brand-mark" aria-hidden="true">م</span>منصة الأعمال</Link><ButtonLink href="/auth/login" variant="ghost">تسجيل الدخول</ButtonLink></header>
    <section className="welcome-panel" aria-labelledby="welcome-title"><div className="welcome-illustration" aria-hidden="true"><Icon name="building" size={40} /></div>
      <p className="eyebrow">مساحة فريقك</p><h1 id="welcome-title">الناس والوقت والرواتب.<br />في مكان واحد.</h1>
      <p className="intro">ابدأ من مساحة شركتك، وأنجز مهامك بخطوات واضحة.</p>
      <ButtonLink href="/tenant/select" size="lg" icon="arrowLeft">افتح مساحة العمل</ButtonLink>
      <div className="welcome-domains"><span><Icon name="users" size={20} />الناس</span><span><Icon name="clock" size={20} />الوقت</span><span><Icon name="wallet" size={20} />الرواتب</span></div>
    </section>
  </main>;
}
