'use client';

import Link from 'next/link';

export default function PageError({ retry }: { retry: () => void }) {
  return <main className="app-shell">
    <section className="auth-card" aria-labelledby="page-error-title">
      <h1 id="page-error-title">تعذر عرض الصفحة</h1>
      <p>حاول فتح الصفحة مرة أخرى. إذا كنت قد أرسلت طلبًا ولم تتأكد نتيجته، راجع سجله قبل إرسال طلب آخر.</p>
      <div className="workspace-form-actions">
        <button type="button" className="primary-button" onClick={retry}>إعادة فتح الصفحة</button>
        <Link className="secondary-button" href="/">العودة للرئيسية</Link>
      </div>
    </section>
  </main>;
}
