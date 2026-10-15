import { ButtonLink, PageHeader } from '@/components/ui';
export function StatutoryHeader({ comparison = false, head }: { comparison?: boolean; head?: string }) {
  return <header className="statutory-page-header">
    <ButtonLink variant="ghost" href={comparison && head ? `/operator/statutory?head=${head}` : head ? '/operator/statutory' : '/operator'}>{comparison ? 'العودة إلى المسودة' : head ? 'العودة إلى المسودات' : 'العودة إلى تشغيل المنصة'}</ButtonLink>
    <PageHeader eyebrow="الامتثال · الرواتب" title={comparison ? 'مقارنة الحساب بالنتائج المرجعية' : 'القواعد القانونية للرواتب'} description={comparison ? 'راجع نتائج النسخة الحالية وأدلتها قبل الإصدار. الحالات الاصطناعية لا تؤهل قواعد الصرف.' : 'احفظ القواعد ومراجعها وتاريخ بدء العمل بها. حفظ المسودة لا يسمح بحساب الرواتب أو اعتماد الصرف.'} />
  </header>;
}
