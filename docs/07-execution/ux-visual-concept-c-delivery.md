# تسليم التحول البصري Concept C

- الأساس 13b2b7a، والفرع ux/visual-concept-c؛ تغييرات واجهة فقط.
- خطوط ومكونات وإطار وتنقل حسب الدور، بطاقات اليوم والحضور، لوحات القرار، الناس والرواتب والإدارة، وخريطة المقر.
- build شامل TypeScript ناجح؛ lint: صفر أخطاء و4 تحذيرات قديمة في أدلة سابقة.
- مراجعة مستقلة واحدة: لا P1؛ أصلحت مظهر لوحة المفاتيح، الإحداثيات، وتكرار تفاصيل الإضافي.
- عينات مرئية محدودة: معرض المكونات، اليوم، الناس على الديسكتوب والهاتف؛ أصلح قص البحث. هذه عينات وليست قبولًا بصريًا لكل حالة.
- لا تغيير في supabase/ أو actions.ts؛ لا إعادة اختبارات قواعد البيانات. اختبار الأجهزة الفعلية والقبول الشامل قبل النشر لدى المالك.
- حد جلسة Claude سبق أن توقف؛ استُخدمت خطته ومراجعته السابقة دون إعادة محاولات أو استبدال نموذج تلقائي.
- CI لا يُشغّل لهذا التسليم ([skip ci])، وتعطيل نشر Vercel خاص بهذا الفرع؛ لا main أو نشر.

## اكتمال التعميم — 2026-10-09

- استبدال عناصر العرض والنماذج الظاهرة بمكونات مشتركة للحقول والأزرار والبطاقات والرسائل والجداول، مع تنظيم أقسام النماذج وطي التفاصيل الاختيارية.
- مراجعة مصدرية مستقلة حافظت على أسماء الحقول والقيود والأحداث والإرسال والصلاحيات؛ أُصلح توزيع نماذج الموظفين بعد اعتماد Field.
- معاينة الأرصدة على الديسكتوب والهاتف ناجحة؛ لا مصفوفة صور أو اختبارات قواعد بيانات إضافية.
- توحيد بواقي التوافق في CSS ومظهر صفحة offline؛ تحقق سلامة 19 أصلًا عامًا مخزنًا مسبقًا.

## تغطية 75 صفحة

كل الصفحات الـ75 تحتوي تعديلات مباشرة مقارنة بالأساس 13b2b7a، مع استخدام المكونات المشتركة وتنسيق المجال. هذا حصر تنفيذ مصدري، ولا يعني قبول جميع الحالات بصريًا.

| المسار | المجال | التنفيذ |
|---|---|---|
| `/auth/employee-account-activation/callback` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/employee-account-activation` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/forgot-password` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/invitations/accept` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/invitations/callback` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/login` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/membership-invitations/accept` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/membership-invitations/callback` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/password/update` | الدخول | تعديل مباشر + الأساس المشترك |
| `/operator/commercial/[tenantId]` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/commercial` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/entitlements/[tenantId]` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/entitlements` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/invitations/new` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/invitations` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/onboarding` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/operators` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/statutory/comparisons` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/statutory` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/tenants/[tenantId]` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/operator/tenants` | المشغّل | تعديل مباشر + الأساس المشترك |
| `/` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance/[instanceId]` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance/import` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance/review` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance/sources/[sourceId]/events/[eventId]` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance/sources/[sourceId]` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance/sources/new` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance/sources` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance/unassigned` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/branding` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/entities-sites/[entityId]` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/entities-sites/[entityId]/sites/new` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/entities-sites/new` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/entities-sites` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/balances/[accountId]` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/balances/annual` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/balances` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/new` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/requests/[requestId]` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/settings/[employerId]/calendars/[calendarId]` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/settings/[employerId]/calendars/new` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/settings/[employerId]` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/settings/[employerId]/types/[typeId]` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/settings/[employerId]/types/new` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/settings/[employerId]/year-periods/new` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/settings` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/me/attendance` | الموظف | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/me/leave/[requestId]` | الموظف | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/me/leave/new` | الموظف | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/me/leave` | الموظف | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/me` | الموظف | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll/advances` | الرواتب | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll/corrections` | الرواتب | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll/inputs` | الرواتب | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll/output` | الرواتب | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll` | الرواتب | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll/payments` | الرواتب | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll/reports` | الرواتب | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll/runs` | الرواتب | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll/setup` | الرواتب | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/people/[employeeId]` | الناس | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/people/import` | الناس | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/people/new` | الناس | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/people/organization/[kind]/[recordId]` | الناس | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/people/organization` | الناس | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/people` | الناس | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/people/work-policies` | الناس | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/users/invite` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/users` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/select` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |

## ملاحظات اختبار المالك على الهاتف — 2026-10-09
اختبار المالك أظهر أن التعميم المصدري لم يكف لقبول التصميم، خصوصًا الرواتب؛ يبقى القبول البصري مفتوحًا. الدفعة الحالية تضيف المداخل المصرح بها للدورة والمدخلات والمراجعة، وتظهر إعدادات الشركة وبيانات الضريبة والتأمين في بداية المدخلات، وتجمع نفس حقول الضريبة والتأمين والمكوّنات. تحسين تنسيق الهاتف والتقارير لا يغير الطباعة أو حسابات الرواتب.
زر خروج الهيدر يحافظ على النموذج أثناء الإرسال؛ خروج فعلي من جلسة فحص محلية ظهر signed-out. مشاركة المصادقة داخل الطلب في22صفحة، وخيار SUPABASE_INTERNAL_URL للخادم المحلي يحافظ على اسم كوكي العنوان العام؛ لم يجر قياس أداء شامل.
بناء مجمع شامل TypeScript وlint مركز ناجحان؛ معاينة مدخلات واحدة390px كشفت تكدس روابط العنوان، أُعيد تجميعها في شريط أزرار. لا إعادة اختبار معاملات مالية أو قاعدة البيانات. قواعد الضريبة والتأمين العامة في operator/statutory وتحتاج دور الامتثال؛ بيانات الموظف في payroll/inputs?kind=statutory_context. لا تغيير actions/Supabase أو نشر.
