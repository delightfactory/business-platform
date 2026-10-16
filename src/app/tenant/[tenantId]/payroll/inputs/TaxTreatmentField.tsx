'use client';

import { useState } from 'react';
import { Field, Input, Select } from '@/components/ui';

// ETA payroll FAQ v4 (March 2026), questions 27–34. These are source
// classifications, not proof that the applicable calculation is qualified.
const treatments = [
  ['01', 'جهة العمل الأصلية', 'للعمالة التي تكون الشركة جهة عملها الأصلية وفق المستند.'],
  ['02', 'جهة عمل غير أصلية', 'يحدد المراجع جهة العمل الأصلية وبياناتها المطلوبة؛ لا تخترها بالتخمين.'],
  ['03', 'جهة غير أصلية تُعامل كالأصلية', 'للحالات المستوفية لشروط الدخل أو الوقت لدى جهة العمل غير الأصلية.'],
  ['04', 'حالة إعاقة أو رعاية موثقة', 'تحتاج مستند الاستحقاق المعتمد؛ لا تستنتجها من بيانات عامة للموظف.'],
  ['05', 'حالة مرض مزمن مستوفية للشروط', 'يحددها المختص وفق المستند وشروط عدم التواجد بمقر العمل.'],
  ['06', 'معاملة خاصة بمنطقة قناة السويس الاقتصادية', 'للمنشأة المستوفية لشروط التأسيس قبل 24 يونيو 2015 واستمرار سريان المعاملة.'],
  ['07', 'المعاملة الخاصة مع إعاقة أو رعاية موثقة', 'يلزم استيفاء شروط المنطقة الاقتصادية ومستند استحقاق الإعاقة أو الرعاية معًا.'],
  ['08', 'متجمد أجور عن فترات سابقة', 'تحتاج مراجعة مستقلة لبيانات الفترات والضريبة؛ الاختيار وحده لا يحسب التسوية.'],
] as const;

export function TaxTreatmentField({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  const known = treatments.find(([code]) => code === value);
  const [manual, setManual] = useState(Boolean(value && !known));
  return <Field id="input-tax_treatment_code" label="المعاملة الضريبية"
    help={`${known?.[2] ?? 'اختر المعاملة التي حددها مراجع الرواتب في المستند، أو أدخل رمزًا آخر موثقًا.'} حفظها لا يعتمد القواعد أو مبالغ الصرف.`}>
    <Select id="input-tax_treatment_code" name={manual ? undefined : 'tax_treatment_code'}
      value={manual ? 'custom' : value} required onChange={event => {
        if (event.target.value === 'custom') setManual(true);
        else { setManual(false); onChange(event.target.value); }
      }}>
      <option value="" disabled>اختر المعاملة من المستند المراجع</option>
      {treatments.map(([code, label]) => <option key={code} value={code}>{label} ({code})</option>)}
      <option value="custom">رمز آخر موثق</option>
    </Select>
    {manual && <Field id="input-tax-treatment-custom" label="الرمز من المستند"
      help="أدخل رمزًا من 01 إلى 99 كما ورد في المستند. القيمة الحالية محفوظة حتى تعدلها؛ توفر قواعد الحساب يُراجع عند حساب المسير.">
      <Input id="input-tax-treatment-custom" name="tax_treatment_code" value={value} onChange={event => onChange(event.target.value)}
        required pattern="(0[1-9]|[1-9][0-9])" inputMode="numeric" maxLength={2} dir="ltr" placeholder="رمز من رقمين" />
    </Field>}
  </Field>;
}
