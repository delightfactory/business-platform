import type { NumericRules } from './NumericRules';

// Source transcription for a review draft, never an issued statutory pack.
// Law 7/2024, Article 8 table and Article 13 exemption; NOSI notice 30/11/2025.
// Treatment, column selection and insurance applicability require review.
export function egypt2026Starter() {
  const bands = (...items: [string, string][]) => items.map(([upper, rate]) => ({ upper, rate }));
  const numericRules: NumericRules = {
    tax: {
      treatment: '', exemption: '20000', column_basis: 'annual_raw',
      columns: [
        { through: '600000', bands: bands(['40000', '0'], ['55000', '10'], ['70000', '15'], ['200000', '20'], ['400000', '22.5'], ['', '25']) },
        { through: '700000', bands: bands(['55000', '10'], ['70000', '15'], ['200000', '20'], ['400000', '22.5'], ['', '25']) },
        { through: '800000', bands: bands(['70000', '15'], ['200000', '20'], ['400000', '22.5'], ['', '25']) },
        { through: '900000', bands: bands(['200000', '20'], ['400000', '22.5'], ['', '25']) },
        { through: '1200000', bands: bands(['400000', '22.5'], ['', '25']) },
        { through: '', bands: bands(['1200000', '25'], ['', '27.5']) },
      ],
    },
    insurance: {
      category: '', minimum: '2700', maximum: '16700',
      branches: [{ branch: 'pension', employee: '', employer: '', deductible: false }],
    },
    base_taxable: false,
  };
  return {
    version: 'egypt-2026-review', from: '2026-01-01', until: '2027-01-01',
    sources: [
      { title: 'قانون 7 لسنة 2024 — شرائح الضريبة والإعفاء الشخصي', url: 'https://portal.eta.gov.eg/sites/default/files/2024-03/law_no.7-2024.pdf' },
      { title: 'حدود أجر الاشتراك التأميني اعتبارًا من يناير 2026', url: 'https://www.nosi.gov.eg/ar/News/Pages/2025-11-30.aspx' },
      { title: 'إرشادات ضريبة الأجور والمرتبات — مارس 2026', url: 'https://eta.gov.eg/sites/default/files/2026-05/faqs-payroll-system-v4.pdf' },
      { title: '', url: '' }, { title: '', url: '' }, { title: '', url: '' },
    ],
    numericRules,
  };
}
