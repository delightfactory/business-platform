export type InputKind = 'component'|'recurring'|'manual_units'|'adjustment'|'opening_ytd'|'policy';
export type InputRecord = {id:string;kind:InputKind;employment_id:string|null;period_id:string|null;revision:number;data:Record<string,string|boolean|number>;effective_from:string;effective_until:string|null;status:string};
export type InputState = {error:string;saved:boolean;head:string;revision:number;attempt:string;signature:string;status:string};
export const kindNames:Record<InputKind,string> = {component:'مكوّنات الراتب',recurring:'المكوّنات المتكررة للموظف',manual_units:'وحدات الأجر اليومي',adjustment:'المكافآت والخصومات',opening_ytd:'الأرصدة الافتتاحية للسنة',policy:'سياسة احتساب الجزء من الفترة'};
export const statusNames:Record<string,string> = {draft:'مسودة',approved:'معتمد',cancelled:'ملغى',applied:'طُبق في راتب مقفل'};
export const inputFields:Record<InputKind,string[]> = {component:['key','name','classification','calculation','base','value','taxable','social','visible','active','proration','order','behavior','reason'],recurring:['component_id','value','reason'],manual_units:['units','reference','reason'],adjustment:['component_id','amount','reference','reason'],opening_ytd:['year','taxable_earnings','tax_withheld','social_base','employee_social','employer_social','reference','reason'],policy:['mode','reason']};
export function inputError(code?:string,message?:string) {
 if(message?.includes('correction_required')) return 'تؤثر هذه البيانات في تاريخ راتب مقفل. اطلب التصحيح من مسؤول الرواتب؛ لم تتغير البيانات السابقة.';
 if(message?.includes('policy_already_set')) return 'سياسة الشركة محددة بالفعل. راجع الإعداد المحفوظ؛ تغيير السياسة يتطلب مسارًا منفصلًا.';
 if(code==='PT409') return 'تغيرت البيانات أثناء العمل. بياناتك محفوظة؛ أعد فتح السجل لمراجعة أحدث نسخة.';
 if(code==='42501') return 'لم يعد هذا الحساب مخولًا لهذا الإجراء. راجع مسؤول الشركة.';
 if(code==='55000') return 'خدمة الرواتب غير مفعلة لإعداد مدخلات جديدة. راجع مسؤول الشركة.';
 if(code==='23505') return 'يوجد مدخل مطابق للموظف أو المكوّن بالفعل. افتح السجل السابق لتحديثه.';
 if(['22023','22P02','23514'].includes(code??'')) return 'راجع القيم والتواريخ والمكوّن المختار. لم تُحفظ هذه التغييرات.';
 return 'تعذر التحقق من نتيجة الطلب. بياناتك محفوظة؛ أعد المحاولة بنفس الطلب.';
}

export const inputOptions:Record<string,[string,string][]>={classification:[['earning','استحقاق'],['deduction','خصم'],['employer_cost','تكلفة جهة العمل']],calculation:[['fixed','قيمة ثابتة'],['percentage','نسبة من الأجر الأساسي']],base:[['','لا ينطبق للقيمة الثابتة'],['base_pay','الأجر الأساسي فقط']],taxable:[['false','لا'],['true','نعم']],social:[['false','لا'],['true','نعم']],visible:[['true','نعم'],['false','لا']],active:[['true','نعم'],['false','لا']],proration:[['salary_proration','تجزئة القيمة وفق سياسة الراتب'],['paid_full_period','القيمة كاملة للفترة دون تجزئة']],behavior:[['recurring','متكرر'],['period_input','لفترة واحدة']],mode:[['calendar_days','أيام الفترة الفعلية'],['fixed_30_day','مقام ٣٠ يومًا']]};
