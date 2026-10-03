export type CorrectionKind='compensation'|'assignment'|'employment'|'new_employment'|'input_revision'|'source_change';
export type CorrectionState={error:string;saved:boolean;signature:string;attempt:string;recoverPending?:boolean;closedUncommitted?:boolean;previewHash?:string;caseId?:string;revision?:number;status?:string;route?:string;affected?:{id:string;starts_on:string;ends_on:string}[]};
export const correctionKinds:Record<CorrectionKind,string>={source_change:'تغيير مسجل في الحضور أو الإجازات',compensation:'تصحيح الأجر المؤرخ',assignment:'تصحيح التكليف المؤرخ',employment:'تصحيح التوظيف أو أهلية الراتب',new_employment:'توظيف مستحق لم يُسجّل',input_revision:'تصحيح مدخل راتب'};
export const correctionStatuses:Record<string,string>={draft:'مقترح محفوظ',review:'قيد مراجعة الأثر',approved:'المقترح معتمد',routed:'مسؤولية تسوية مفتوحة',completed:'استُبدلت المخرجات غير المدفوعة',cancelled:'ملغى مع حفظ التاريخ'};
export function correctionError(code?:string,message?:string){
 if(message?.includes('mixed_dispositions'))return 'يشمل الأثر مخرجات مدفوعة وأخرى غير مدفوعة. استكمل مراجعة البدائل والتأهيل القانوني قبل تطبيقها مع مسؤوليات التصحيح معًا.';
 if(message?.includes('proposal_approval_required'))return 'اعتمد المقترح ونطاق الأثر أولًا، ثم راجع اعتماد المرشح المؤهل.';
 if(message?.includes('outside_protected_dates'))return 'هذه التغييرات لا تؤثر في تاريخ راتب مقفل. نفّذ التغيير من مصدره المعتاد.';
 if(message?.includes('cross_employer'))return 'تؤثر السياسة في أكثر من جهة قانونية. يلزم مسار تصحيح يجمع جميع الجهات المتأثرة قبل تغييرها.';
 if(message?.includes('approval_blocked'))return 'لم يجتز المرشح مراجعة الأثر والتأهيل القانوني. راجع الموانع؛ لم يتغير المصدر أو الراتب الأصلي.';
 if(message?.includes('release_required'))return 'أعد المقترح أو المرشح إلى المراجعة قبل إلغائه.';
 if(message?.includes('target_unavailable'))return 'الفترة المستهدفة أو أهلية الموظف لا تسمح بهذا المدخل. اختر فترة مفتوحة صالحة أو تسوية خارجية مستقلة للمراجعة.';
 if(message?.includes('component_unavailable'))return 'المكوّن لا يغطي الفترة أو اتجاه المبلغ. اختر مكافأة للمبلغ الموجب وخصمًا للمبلغ السالب.';
 if(message?.includes('settlement_excess'))return 'المبلغ يتجاوز المسؤولية الخارجية المعتمدة المتبقية لهذا الموظف والاتجاه.';
 if(message?.includes('paid_correction'))return 'سُجّل دفع لهذا المسير سابقًا. يبقى الأصل محفوظًا؛ استخدم مسؤولية التصحيح والتسوية.';
 if(code==='42501')return 'لم يعد الحساب مخولًا لهذا الإجراء أو مصدره. راجع المسؤول؛ الحقول محفوظة.';
 if(code==='PT409')return 'تغير المصدر أو الدفع أو نسخة المقترح. حدّث المراجعة ثم عاين المقترح مجددًا قبل حفظه.';
 if(['22023','22P02','23514','23503','23P01'].includes(code??''))return 'راجع المصدر والقيم والتواريخ ونطاق المسؤولية. لم تُطبّق هذه التغييرات.';
 return 'تعذر التحقق من النتيجة. أعد المحاولة بنفس الطلب قبل إدخال تغييرات أخرى.';
}
