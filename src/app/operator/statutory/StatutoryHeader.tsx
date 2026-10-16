import { ButtonLink, PageHeader } from '@/components/ui';
export function StatutoryHeader({ comparison = false, head }: { comparison?: boolean; head?: string }) {
  return <header className="statutory-page-header">
    <ButtonLink variant="ghost" href={comparison && head ? `/operator/statutory?head=${head}` : head ? '/operator/statutory' : '/operator'}>{comparison ? 'العودة إلى المسودة' : head ? 'العودة إلى المسودات' : 'العودة إلى تشغيل المنصة'}</ButtonLink>
    <PageHeader eyebrow="إعدادات الرواتب" title={comparison ? 'مقارنة الحساب بالنتائج المرجعية' : 'إعدادات حساب الرواتب'} description={comparison ? 'المقارنات أداة اختيارية لمراجعة الحساب، ولا تشترط لتفعيل الإعدادات.' : 'احفظ إعدادات الضريبة والتأمينات وتاريخ تطبيقها، ثم فعّلها للحساب.'} />
  </header>;
}
