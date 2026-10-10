export type AdvanceOperation='save'|'approve'|'activate'|'cancel'|'settle'|'compensate'|'termination'|'defer'|'correct_deduction'|'correct_disbursement';
export type AdvanceIntent={operation:AdvanceOperation;advance:string;employment:string;expected:number;data:Record<string,string>};
export type AdvanceJournal={version:1;actor:string;tenant:string;employer:string;attempt:string;intent:AdvanceIntent;resolution?:'closed_without_commit'};
export type AdvanceResult={resolution?:'committed'|'closed_without_commit';error?:string;result?:{id:string;revision:number;outstanding:string;status:string}};
export const operations:AdvanceOperation[]=['save','approve','activate','cancel','settle','compensate','termination','defer','correct_deduction','correct_disbursement'];
export const labels:Record<AdvanceOperation,string>={save:'حفظ مسودة السلفة',approve:'اعتماد المبلغ والجدول',activate:'تسجيل الصرف الخارجي وتفعيل السلفة',cancel:'إلغاء قبل الصرف',settle:'تسجيل تسوية خارجية مُراجعة',compensate:'تصحيح سجل تسوية خاطئ',termination:'توثيق مراجعة الرصيد عند انتهاء التوظيف',defer:'اعتماد ترحيل القسط',correct_disbursement:'عكس دليل صرف خاطئ قبل أي سداد',correct_deduction:'تسجيل حركة تصحيح مقابلة لخصم الرواتب'};
export const statuses:Record<string,string>={draft:'مسودة',approved:'معتمدة؛ تنتظر دليل الصرف',active:'سارية',record_corrected:'دليل صرف صُحّح؛ الأصل محفوظ',settled:'مُسددة بالكامل',cancelled:'أُلغيت قبل الصرف'};
export const eventNames:Record<string,string>={approval:'اعتماد الجدول',disbursement:'صرف خارجي مسجّل',settlement:'تسوية خارجية',compensation:'حركة تصحيح تحفظ الأصل',termination_review:'مراجعة رصيد نهاية التوظيف',deferral_review:'ترحيل مُراجع للقسط',payroll_deduction:'خصم مقفل من الرواتب'};
export function advanceError(code?:string,message?:string){
 if(code==='42501')return 'لم تعد لهذا الحساب صلاحية تنفيذ هذه العملية. راجع مسؤول الشركة؛ الطلب السابق والقيم الأصلية محفوظان.';
 if(message?.includes('schedule_periods_missing'))return 'عدد الفترات المحفوظة لا يكفي للجدول. اطلب من مدير إعداد الرواتب توليد الفترات التالية ثم أعد الحفظ.';
 if(message?.includes('first_period_invalid')||message?.includes('activation_blocked'))return 'راجع اعتماد السلفة وتاريخ الصرف والفترة الأولى. لا يمكن إضافة التزام إلى فترة مقفلة أو تفعيل سلفة دون دليل صرف خارجي.';
 if(message?.includes('principal_reconciliation'))return 'تصحيح دليل الصرف متاح قبل أي سداد أو خصم فقط. بعد حدوثهما يلزم أساس تسوية مستقل مُراجع؛ لا تُسقط المسؤولية ولا تسجّل ردًا بنكيًا بهذا المسار.';
 if(message?.includes('settlement_excess'))return 'مبلغ التسوية يتجاوز الرصيد المتبقي. حدّث مراجعة الرصيد قبل تسجيل تسوية جديدة.';
 if(message?.includes('governed_correction'))return 'يلزم تصحيح رواتب مُراجع مرتبط بالمسير والموظف قبل تسجيل حركة التصحيح المقابلة للخصم. اطلب من مسؤول تصحيح الرواتب استكمال المسار.';
 if(message?.includes('deferral_invalid'))return 'اختر فترة لاحقة محفوظة وغير مقفلة لهذا القسط. لا يغيّر الترحيل مبلغ الدين.';
 if(code==='PT409')return 'تغيّر السجل أو أُغلقت هذه المحاولة. تحقّق من نتيجتها أولًا، ثم راجع أحدث رصيد قبل حفظ طلب جديد.';
 if(code==='55000')return 'خدمة سلف الموظفين غير مفعّلة لإنشاء التزامات جديدة. تبقى تسوية الالتزامات القائمة متاحة لمسؤولها صاحب الصلاحية.';
 if(code==='22023'||code==='23514')return 'راجع المبلغ والتاريخ والمرجع وسبب العملية وحالة السلفة. القيم محفوظة ولم تتأكد نتيجة الطلب بعد.';
 return 'تعذر تأكيد نتيجة الطلب. تحقّق من الطلب السابق قبل تغيير قيمه أو إرسال عملية جديدة.';
}
export type Choice={id:string;name:string;code?:string;starts_on?:string;ends_on?:string};
export type Installment={id:string;ordinal:number;amount:string;remaining:string;period_id:string;starts_on:string;ends_on:string;deferred:boolean};
export type AdvanceEvent={id:string;kind:string;delta:string;occurred_on:string;reference:string;reason:string;output_id:string|null;original_event:string|null;compensated:boolean};
export type AdvanceSummary={id:string;employment_id:string;revision:number;name:string;code:string;principal:string;outstanding:string;status:string;next_installment:{id:string;amount:string;starts_on:string}|null};
export type AdvanceDetail={id:string;employment_id:string;revision:number;name:string;outstanding:string;status:string;termination_on:string|null;next_installment:{amount:string;starts_on:string}|null;version:{principal:string;effective_on:string;first_period:string;installment_count:number;reason:string};schedule:Installment[];history:AdvanceEvent[]};
export type AdvanceWorkspace={access:{can_manage:boolean;can_approve:boolean;can_correct_payroll:boolean;can_view_final:boolean;can_review_payroll:boolean;enabled:boolean};employer:{id:string;name:string};items:AdvanceSummary[];detail:AdvanceDetail|null;next:string|null;today:string};
