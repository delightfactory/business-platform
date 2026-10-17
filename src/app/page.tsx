import { ProductBrand } from '@/components/product-brand';
import { PageHeader } from '@/components/ui';
import Link from 'next/link';
import { ButtonLink, Icon } from '@/components/ui';
export default function Home() {
  return <main className="app-shell welcome-page">
    <header className="topbar"><Link className="brand" href="/"><ProductBrand /></Link><ButtonLink href="/auth/login" variant="ghost">تسجيل الدخول</ButtonLink></header>
    <section className="welcome-panel" aria-labelledby="welcome-title">
      <p className="eyebrow">مساحة فريقك</p><PageHeader id="welcome-title" title={<>الناس والوقت والرواتب.<br />في مكان واحد.</>} />
      <p className="intro">ابدأ من مساحة شركتك، وأنجز مهامك بخطوات واضحة.</p>
      <ButtonLink href="/tenant/select" size="lg" icon="arrowLeft">افتح مساحة العمل</ButtonLink>
      <div className="welcome-domains"><span><Icon name="users" size={20} />الناس</span><span><Icon name="clock" size={20} />الوقت</span><span><Icon name="wallet" size={20} />الرواتب</span></div>
    </section>
  </main>;
}
