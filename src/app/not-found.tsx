import Link from 'next/link';

export default function PageNotFound() {
  return <main className="app-shell">
    <section className="auth-card" aria-labelledby="page-not-found-title">
      <h1 id="page-not-found-title">الصفحة غير متاحة على هذا الرابط</h1>
      <p>تحقق من الرابط، أو ارجع للرئيسية للوصول إلى خدماتك المتاحة.</p>
      <Link className="primary-button" href="/">العودة للرئيسية</Link>
    </section>
  </main>;
}
