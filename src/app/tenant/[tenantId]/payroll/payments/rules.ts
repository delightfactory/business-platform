export type PaymentState={error:string;saved:boolean;revision:number;signature:string;attempt:string;amount?:string;remaining?:string;kind?:string;needsRefresh?:boolean;recoverPending?:boolean};
export type PaymentEmployee={employment_id:string;employee_snapshot:{name:string;code:string};payable:string;paid:string;remaining:string;entry_amount:string|null};
export function paymentError(code?:string,message?:string){
 if(code==='42501')return 'لم يعد الحساب مخولًا لهذا المخرج. راجع مسؤول الشركة؛ بيانات الطلب محفوظة.';
 if(message?.includes('payment_excess'))return 'المبلغ يتجاوز المتبقي لأحد الموظفين. لم يتغير السجل. إذا صُرف مبلغ زائد فعليًا، راجع مسؤول تصحيح الرواتب لتسوية موثقة.';
 if(message?.includes('payment_stale'))return 'تغيّر سجل الدفعات أثناء الطلب. بياناتك محفوظة؛ راجع أحدث مطابقة قبل إرسال طلب جديد.';
 if(message?.includes('attempt_conflict'))return 'مفتاح هذا الطلب مرتبط بقيم أخرى. راجع نتيجة الطلب السابق قبل تسجيل دفعة جديدة.';
 if(message?.includes('payment_compensated'))return 'سبق تصحيح هذا القيد بالكامل. راجع سجل الدفعات.';
 if(message?.includes('payment_complete'))return 'لا يوجد متبقٍ للتسجيل. راجع الدفعات المحفوظة.';
 if(message?.includes('output_superseded'))return 'استُبدل هذا المسير. راجع المخرج الحالي مع مسؤول الرواتب.';
 if(code==='22023')return 'راجع التاريخ والمرجع والسبب والمبالغ وإقرار التسجيل. لم يتغير السجل.';
 if(code==='55P03'||code==='40P01')return 'يوجد إجراء جارٍ على هذا المسير. أعد المحاولة بنفس القيم للتحقق من نتيجة طلبك.';
 return 'تعذر التحقق من نتيجة الطلب. احتفظ بالقيم وأعد المحاولة بنفس الطلب؛ يتحقق النظام من تسجيله السابق.';
}
