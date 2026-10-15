const catalog = [
  { key: 'employee.attendance.self.v1', label: 'الحضور الشخصي من الهاتف', description: 'يسجل العضو حضوره وانصرافه فقط. يحتاج ربطًا بموظف نشط وموقع وسياسة حضور مهيأة؛ لا يمنح إدارة حضور الآخرين.' },
  { key: 'people.reader.v1', label: 'قراءة بيانات الموظفين', description: 'عرض دليل الموظفين وبيانات العمل. لا تشمل الاطلاع على الأجور.' },
  { key: 'people.operations.v1', label: 'عمليات الموارد البشرية', description: 'إدارة ملفات الموظفين والتوظيف والعمل، وتشمل الاطلاع على الأجر الأساسي وتعديله.' },
  { key: 'people.compensation_reader.v1', label: 'عرض الأجور', description: 'عرض بيانات الأجر الأساسي وسجل تغييره، دون تعديلها.' },
  { key: 'people.compensation_manager.v1', label: 'إدارة الأجور', description: 'عرض الأجر الأساسي وتعديله وسجل تغييره.' },
  { key: 'people.import_operator.v1', label: 'استيراد الموظفين', description: 'استيراد الموظفين من CSV؛ تشمل إدارة بيانات الموظف والتوظيف والاطلاع على الأجور الأساسية وتعديلها.' },
  { key: 'attendance.policy.manager.v1', label: 'مدير سياسات الدوام', description: 'إنشاء قوالب الدوام المسماة وإصداراتها وإيقافها. لا تشمل هذه الصلاحيات إدارة الموظفين أو الاطلاع على الأجور.' },
  { key: 'attendance.reader.v1', label: 'عرض الحضور', description: 'عرض أيام الحضور وسجلها دون إدخال أو اعتماد.' },
  { key: 'attendance.operator.v1', label: 'إدخال الحضور', description: 'إدخال البصمات اليدوية ومتابعة الحالات، دون صلاحية التصحيح أو الاعتماد.' },
  { key: 'attendance.reviewer.v1', label: 'مراجع الحضور', description: 'تصحيح سجل البصمات واعتماد النتائج اليومية. لا تشمل إدخال بصمات جديدة.' },
  { key: 'employee.leave.self.v1', label: 'الخدمة الذاتية للإجازات', description: 'عرض الملف الشخصي وطلب الإجازة مستقبلًا. لا تمنح عرض دليل الموظفين أو الأجور.' },
  { key: 'payroll.reader.v1', label: 'عرض الرواتب', description: 'عرض دورات الرواتب وفتراتها.' },
  { key: 'payroll.preparer.v1', label: 'معد الرواتب', description: 'عرض الرواتب مع صلاحية التحضير عند تفعيل الحساب.' },
  { key: 'payroll.payment.recorder.v1', label: 'مسجل دفعات الرواتب الخارجية', description: 'عرض المستحق النهائي وتسجيل دفعات صُرفت خارجيًا ؛ لا تنفيذ تحويل بنكي.' },
  { key: 'payroll.reviewer.v1', label: 'مراجع الرواتب', description: 'عرض الحساب المبدئي والعوائق والفروق دون الحساب أو الاعتماد المالي.' },
  { key: 'payroll.input.approver.v1', label: 'اعتماد حساب المسير', description: 'اعتماد نسخة حساب المسير أو إعادتها للمراجعة واعتماد الوحدات اليومية؛ لا تشمل التحضير أو الحفظ النهائي.' },
  { key: 'employee_finance.reader.v1', label: 'قارئ مكافآت وخصومات الموظفين', description: 'عرض المدخلات المالية ضمن الجهة والفترة.' },
  { key: 'employee_finance.author.v1', label: 'معد مكافآت وخصومات الموظفين', description: 'تحضير المسودة وإلغاؤها دون اعتماد.' },
  { key: 'employee_finance.approver.v1', label: 'معتمد مكافآت وخصومات الموظفين', description: 'اعتماد المدخلات المالية دون تحضيرها.' },
  { key: 'payroll.correction.requester.v1', label: 'مسؤول تصحيح الرواتب', description: 'إعداد ومراجعة مقترح تصحيح التاريخ المقفل؛ يلزم أيضًا تفويض المصدر والاعتماد أو تسجيل التسوية بحسب المهمة.' },
  { key: 'payroll.calendar.manager.v1', label: 'مدير دورة الرواتب', description: 'إعداد الدورة ومراجعة تواريخ الفترات وحفظها.' },
  { key: 'leave.reader.v1', label: 'عرض الإجازات', description: 'عرض سجلات الإجازات ضمن الصلاحيات الممنوحة.' },
  { key: 'leave.manager.v1', label: 'مدير الإجازات', description: 'عرض وإدارة سجلات الإجازات دون اعتماد الطلبات.' },
  { key: 'leave.approver.v1', label: 'معتمد الإجازات', description: 'عرض واعتماد طلبات الإجازة دون إدارة السجلات أو تعديل الأرصدة.' },
  { key: 'leave.balance.manager.v1', label: 'مدير أرصدة الإجازات', description: 'عرض الإجازات وتعديل الأرصدة ضمن سجل تدقيق.' },
  { key: 'payroll.finalizer.v1', label: 'الحفظ النهائي للمسير', description: 'حفظ نسخة مسير معتمدة نهائيًا بعد تأكيد الإجماليات. مطلوبة أيضًا مع تصحيح الرواتب لتنفيذ تصحيح مسير محفوظ. لا تشمل التحضير أو الاعتماد.' },
  { key: 'payroll.exporter.v1', label: 'تصدير الرواتب', description: 'تنزيل الكشوف والتقارير المحفوظة ملفًا؛ يُسجَّل كل تنزيل.' },
] as const;
export const BUNDLE_DOMAINS = ['الخدمة الذاتية', 'الموظفون', 'الحضور', 'الإجازات', 'الرواتب', 'مكافآت وخصومات الموظفين'] as const;
const sensitive = new Set<string>(['people.compensation_manager.v1', 'people.operations.v1', 'people.import_operator.v1', 'payroll.input.approver.v1', 'payroll.finalizer.v1', 'payroll.exporter.v1', 'payroll.payment.recorder.v1', 'payroll.correction.requester.v1', 'employee_finance.approver.v1']);
const financial = new Set<string>(['payroll.input.approver.v1', 'payroll.finalizer.v1', 'payroll.exporter.v1', 'payroll.payment.recorder.v1', 'payroll.correction.requester.v1', 'employee_finance.approver.v1']);
function domain(key: string): typeof BUNDLE_DOMAINS[number] {
  if (key.startsWith('employee.')) return 'الخدمة الذاتية';
  if (key.startsWith('people.')) return 'الموظفون';
  if (key.startsWith('attendance.')) return 'الحضور';
  if (key.startsWith('leave.')) return 'الإجازات';
  return key.startsWith('employee_finance.') ? 'مكافآت وخصومات الموظفين' : 'الرواتب';
}
export const PEOPLE_ROLE_BUNDLES = catalog.map(bundle => ({ ...bundle, domain: domain(bundle.key), sensitive: sensitive.has(bundle.key), financial: financial.has(bundle.key) }));
export const bundleKeySet: ReadonlySet<string> = new Set(PEOPLE_ROLE_BUNDLES.map(bundle => bundle.key));

export const BUNDLE_PRESETS = [
  { key: 'self', label: 'خدمة ذاتية للموظف', detail: 'يضيف الحضور والإجازات الشخصية؛ يلزم ربط الحساب بموظف وتجهيز حضوره.', keys: ['employee.attendance.self.v1', 'employee.leave.self.v1'] },
  { key: 'hr', label: 'موارد بشرية', detail: 'يمنح إدارة الموظفين والأجور الأساسية والإجازات، واعتماد الإجازات وتعديل أرصدتها، وعرض الحضور.', keys: ['people.operations.v1', 'leave.manager.v1', 'leave.approver.v1', 'leave.balance.manager.v1', 'attendance.reader.v1'] },
  { key: 'attendance', label: 'مسؤول الحضور', detail: 'يضيف إدخال الحضور وتصحيحه واعتماده وإدارة سياسات الدوام.', keys: ['attendance.operator.v1', 'attendance.reviewer.v1', 'attendance.policy.manager.v1'] },
  { key: 'prepare', label: 'تحضير الرواتب', detail: 'يضيف التحضير ودورة الرواتب والمراجعة. الاعتماد والحفظ النهائي والتصدير اختيارات مستقلة.', keys: ['payroll.preparer.v1', 'payroll.calendar.manager.v1', 'payroll.reviewer.v1'] },
  { key: 'view', label: 'عرض الرواتب', detail: 'يضيف عرض الرواتب دون صلاحية التحضير أو الاعتماد أو الحفظ النهائي.', keys: ['payroll.reader.v1'] },
] as const;
