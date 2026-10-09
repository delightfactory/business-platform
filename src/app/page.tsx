export default function Home() {
  return (
    <main className="app-shell">
      <header className="topbar">
        <a className="brand" href="#main" aria-label="منصة الأعمال، الصفحة الرئيسية">
          <span className="brand-mark" aria-hidden="true">م</span>
          <span>منصة الأعمال</span>
        </a>
        <span className="environment-pill"><span aria-hidden="true" /> بيئة التطوير</span>
      </header>

      <section className="foundation-card" id="main" aria-labelledby="page-title">
        <div className="foundation-icon" aria-hidden="true">✳</div>
        <p className="eyebrow">المرحلة صفر · أساس المنصة</p>
        <h1 id="page-title">الأساس التقني جاهز</h1>
        <p className="intro">
          هذه مساحة تأسيسية قيد التطوير. ستظهر هنا وظائف المنصة بعد تجهيز
          الشركات وتسجيل الدخول.
        </p>
        <div className="next-slices" aria-label="خطوات التطوير التالية">
          <div><span className="step-number">1</span><span>إعداد الشركة</span><span className="step-status">قادم</span></div>
          <div><span className="step-number">2</span><span>تسجيل الدخول والصلاحيات</span><span className="step-status">قادم</span></div>
        </div>
        <p className="foundation-note">لا توجد بيانات أو وظائف أعمال في هذه المرحلة.</p>
      </section>

      <footer className="footer">منصة الأعمال <span aria-hidden="true">·</span> أساس التطوير</footer>
    </main>
  );
}
