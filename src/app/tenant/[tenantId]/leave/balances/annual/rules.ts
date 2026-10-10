import { isObject } from '../../rules';
export type Policy = { version:number; first_year_days:number; later_year_days:number; minimum_service_days:number; year_days:number; source:string; reason:string };
export type Rate = { from:string; annual_days:number; source:string };
export type Quote = { review_hash:string; policy:Policy; eligible:boolean; target_total:number; already_granted:number; delta:number; service_days:number; segments:{ from:string; to:string; annual_days:number; days:number; source:string }[] };
export type AnnualState = { error:string; message:string; quote:Quote|null; policy:Policy|null; posted:boolean; accountId:string|null; reviewedInput:string };
export const EMPTY_ANNUAL_STATE:AnnualState={error:'',message:'',quote:null,policy:null,posted:false,accountId:null,reviewedInput:''};
export function readPolicy(data:unknown):Policy|null{
 if(!isObject(data)||!['version','first_year_days','later_year_days','minimum_service_days','year_days'].every(k=>typeof data[k]==='number'&&Number.isFinite(data[k]))||typeof data.source!=='string'||typeof data.reason!=='string')return null;
 return data as Policy;
}
export function readQuote(data:unknown):Quote|null{
 if(!isObject(data)||!readPolicy(data.policy)||typeof data.review_hash!=='string'||!/^[a-f0-9]{64}$/.test(data.review_hash)||typeof data.eligible!=='boolean'||!['target_total','already_granted','delta','service_days'].every(k=>typeof data[k]==='number'&&Number.isFinite(data[k]))||!Array.isArray(data.segments)||!data.segments.every(s=>isObject(s)&&typeof s.from==='string'&&typeof s.to==='string'&&typeof s.annual_days==='number'&&typeof s.days==='number'&&typeof s.source==='string'))return null;
 return data as Quote;
}
export function annualError(message:string):string{
 if(message.includes('review_conflict'))return 'تغيّر الإعداد أو الحساب منذ المراجعة. أعد عرض الحساب قبل التأكيد.';
 if(message.includes('manual_balance'))return 'هذا الحساب يحتوي على رصيد افتتاحي أو استحقاق سنوي مسجل يدويًا. أكمل تعديل رصيده يدويًا لهذه الفترة؛ الحساب التلقائي يبدأ في فترة دون رصيد افتتاحي أو استحقاق سنوي يدوي، لمنع تكرار الاستحقاق.';
 if(message.includes('reduction_requires_review'))return 'الناتج أقل من الاستحقاق المسجل سابقًا. يلزم تصحيح موثّق من HR؛ لن يُخصم شيء تلقائيًا.';
 if(message.includes('employment_history'))return 'توجد أكثر من علاقة عمل خلال الفترة. يلزم مراجعة الخدمة من HR قبل حسابها تلقائيًا.';
 if(message.includes('not_eligible'))return 'لم يكتمل حدّ الخدمة المطلوب بعد. لم يُسجّل استحقاق.';
 if(message.includes('type_requires'))return 'الحساب السنوي يتطلب نوع إجازة مدفوعًا، برصيد، وأساسه أيام العمل. راجع إعدادات النوع.';
 if(message.includes('rates_invalid')||message.includes('rate_below'))return 'راجع تواريخ الفئات ومراجعها وقيمها؛ لا يجوز أن تقل عن قاعدة الشركة في أي يوم.';
 if(message.includes('forbidden'))return 'ليست لديك صلاحية تنفيذ هذا الإجراء.';
 if(message.includes('disabled'))return 'خدمة الإجازات أو الموظفين موقوفة؛ تسجيل استحقاق جديد غير متاح.';
 if(message.includes('input_invalid')||message.includes('period_invalid'))return 'راجع القيم والتاريخ والمرجع. الحساب عن خدمة فعلية فقط، داخل فترة لا تتجاوز 366 يومًا.';
 return 'تعذر تأكيد العملية. أعد المحاولة بنفس البيانات، أو حدّث الصفحة وأعد عرض الحساب للتحقق من المبلغ المسجّل.';
}
