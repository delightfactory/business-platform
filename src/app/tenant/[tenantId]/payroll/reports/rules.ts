export const reportKinds = ['sheet','payslip','components','statutory','variance','payments','advances'] as const;
export type ReportKind = typeof reportKinds[number];
export const reportLabels:Record<ReportKind,string> = {
 sheet:'كشف الرواتب',payslip:'قسيمة موظف',components:'ملخص المكونات',statutory:'مطابقة الضريبة والتأمينات',
 variance:'مقارنة فترتين نهائيتين',payments:'المدفوع والمتبقي',advances:'أرصدة السلف',
};
export function isReportKind(value:string):value is ReportKind {
 return (reportKinds as readonly string[]).includes(value);
}
// Financial values stay decimal strings. Converting numeric(18,2) to Number can
// change cents before rendering or exporting a large authoritative amount.
export function reportMoney(value:string|null|undefined):string {
 if(value==null)return 'غير متاح';
 const match=/^(-?)(\d+)(?:\.(\d{1,2}))?$/.exec(value);
 if(!match)return 'غير مكتمل';
 return `${match[1]}${match[2].replace(/\B(?=(\d{3})+(?!\d))/g,'٬')}٫${(match[3]??'').padEnd(2,'0')} ج.م.`;
}
export function csvCell(value:string):string {
 const safe=/^[\s\uFEFF]*[=+\-@]|^[\t\r\n]/u.test(value)?`'${value}`:value;
 return `"${safe.replace(/"/g,'""')}"`;
}
export function csvDocument(rows:readonly (readonly string[])[]):string {
 return '\uFEFF'+rows.map(row=>row.map(csvCell).join(',')).join('\r\n');
}
export type ReportEmployee={name:string;code:string};
export type ReportRow={id:string;detail_employment?:string|null;employee?:ReportEmployee;label?:string;amount?:string|null;insured_wage?:string|null;statutory_context?:{calendar_year?:number|null;category?:string|null;insured_wage_source?:string|null;obligation_months?:string[]|null};employer_cost?:string|null;base?:string|null;gross?:string|null;deductions?:string|null;statutory_deductions?:string|null;net?:string|null;paid?:string|null;remaining?:string|null;previous?:string|null;difference?:string|null;outstanding?:string|null;principal?:string|null;status?:string;lines?:{name:string;classification:string;amount:string}[]};
export type ReportWorkspace={report:ReportKind;statutory_sources?:{version:string;effective_from:string;effective_until:string|null;verified:boolean}[]|null;output_id:string|null;superseded:boolean;replacement_output_id:string|null;employer:{name:string;legal_name:string};period:{starts_on:string;ends_on:string}|null;previous_period:{starts_on:string;ends_on:string}|null;rows:ReportRow[];next:string|null;total_count:number;summary:Record<string,string|null>;issues:string[];can_export:boolean;source_revision:string;};
