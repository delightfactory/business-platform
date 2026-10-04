export type InputKind = 'component'|'recurring'|'manual_units'|'adjustment'|'opening_ytd'|'policy'|'statutory_context';
export type InputRecord = {id:string;kind:InputKind;employment_id:string|null;period_id:string|null;revision:number;data:Record<string,string|boolean|number>;effective_from:string;effective_until:string|null;status:string};
export type InputState = {error:string;saved:boolean;head:string;revision:number;attempt:string;signature:string;status:string;manual_data?:Record<string,string|boolean|number>};
export const kindNames:Record<InputKind,string> = {component:'مكوّنات الراتب',recurring:'المكوّنات المتكررة للموظف',manual_units:'وحدات الأجر اليومي',adjustment:'المكافآت والخصومات',opening_ytd:'الأرصدة الافتتاحية للسنة',statutory_context:'بيانات الضريبة والتأمينات',policy:'سياسة احتساب الجزء من الفترة'};
export const statusNames:Record<string,string> = {draft:'مسودة',approved:'معتمد',cancelled:'ملغى',applied:'طُبق في راتب مقفل'};
export const statutoryCalculationFields=['calculation_from','calculation_until','tax_duration_days'];
export const inputFields:Record<InputKind,string[]> = {component:['key','name','classification','calculation','base','value','taxable','social','visible','active','proration','order','behavior','reason'],recurring:['component_id','value','reason'],manual_units:['units','reference','reason'],adjustment:['component_id','amount','reference','reason'],opening_ytd:['year','coverage_start','coverage_end','tax_duration_days','taxable_earnings','tax_withheld','tax_due','tax_net_income','social_base','employee_social','employer_social','reference','reason'],policy:['mode','reason'],statutory_context:['tax_treatment_code','insurance_status','insurance_category','insured_wage','insurance_from','insurance_until','insurance_obligation_month','insurance_owner_period','insurance_obligation_reference','insurance_month_disposition','reference','reason',...statutoryCalculationFields]};
export const openingCoverageFields=['coverage_start','coverage_end','tax_duration_days'];
export function inputError(code?:string,message?:string) {
 if(message?.includes('payroll_insurance_disposition_invalid'))return 'راجع استحقاق شهر التأمين ومرجعه والفترة المالكة معًا. لا تستنتج الاستحقاق من أيام الأجر.';
 if(message?.includes('payroll_insurance_ownership_invalid'))return 'راجع شهر الالتزام والفترة المالكة ومرجع ملكية الشهر. يجب نقلها كاملة من المصدر المراجع.';
 if(message?.includes('payroll_opening_coverage_invalid')) return 'راجع بداية ونهاية الفترة السابقة ومدة احتسابها معًا. يجب أن تقع الفترة في السنة المحددة وتسبق تاريخ السريان.';
 if(message?.includes('payroll_effective_conflict')) return 'اختر تاريخ سريان أحدث من النسخة الحالية. لتصحيح بيانات سابقة، استخدم مسار التصحيح.';
 if(message?.includes('payroll_time_source_disabled')) return 'الحضور غير مفعّل حاليًا. اختر إجمالي أيام يدويًا موثقًا، أو راجع مسؤول الشركة لتفعيل الحضور.';
 if(message?.includes('correction_required')) return 'تؤثر هذه البيانات في تاريخ راتب مقفل. اطلب التصحيح من مسؤول الرواتب؛ لم تتغير البيانات السابقة.';
 if(message?.includes('policy_already_set')) return 'سياسة الشركة محددة بالفعل. راجع الإعداد المحفوظ؛ تغيير السياسة يتطلب مسارًا منفصلًا.';
 if(code==='PT409') return 'تغيرت البيانات أثناء العمل. بياناتك محفوظة؛ أعد فتح السجل لمراجعة أحدث نسخة.';
 if(code==='42501') return 'لم يعد هذا الحساب مخولًا لهذا الإجراء. راجع مسؤول الشركة.';
 if(code==='55000') return 'خدمة الرواتب غير مفعلة لإعداد مدخلات جديدة. راجع مسؤول الشركة.';
 if(code==='23505') return 'يوجد مدخل مطابق للموظف أو المكوّن بالفعل. افتح السجل السابق لتحديثه.';
 if(['22023','22P02','23514'].includes(code??'')) return 'راجع القيم والتواريخ والمكوّن المختار. لم تُحفظ هذه التغييرات.';
 return 'تعذر التحقق من نتيجة الطلب. بياناتك محفوظة؛ أعد المحاولة بنفس الطلب.';
}

export const inputOptions:Record<string,[string,string][]>={insurance_month_disposition:[['','شهر كامل وفق الربط السابق'],['reviewed_due','التزام الشهر مستحق وفق المستند المراجع'],['reviewed_not_due','لا يستحق التزام هذا الشهر وفق المستند المراجع']],insurance_status:[['','اختر الحالة من المرجع'],['insured','مشترك في التأمينات'],['not_insured','غير مشترك وفق المرجع']],source:[['manual','أيام مستحقة أدخلها يدويًا'],['time','الحضور المعتمد']],classification:[['earning','استحقاق'],['deduction','خصم'],['employer_cost','تكلفة جهة العمل']],calculation:[['fixed','قيمة ثابتة'],['percentage','نسبة من الأجر الأساسي']],base:[['','لا ينطبق للقيمة الثابتة'],['base_pay','الأجر الأساسي فقط']],taxable:[['false','لا'],['true','نعم']],social:[['false','لا'],['true','نعم']],visible:[['true','نعم'],['false','لا']],active:[['true','نعم'],['false','لا']],proration:[['salary_proration','تجزئة القيمة وفق سياسة الراتب'],['paid_full_period','القيمة كاملة للفترة دون تجزئة']],behavior:[['recurring','متكرر'],['period_input','لفترة واحدة']],mode:[['calendar_days','أيام الفترة الفعلية'],['fixed_30_day','مقام ٣٠ يومًا']]};
