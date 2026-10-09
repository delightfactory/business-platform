# تسليم التحول البصري Concept C

- الأساس 13b2b7a، والفرع ux/visual-concept-c؛ تغييرات واجهة فقط.
- خطوط ومكونات وإطار وتنقل حسب الدور، بطاقات اليوم والحضور، لوحات القرار، الناس والرواتب والإدارة، وخريطة المقر.
- build شامل TypeScript ناجح؛ lint: صفر أخطاء و4 تحذيرات قديمة في أدلة سابقة.
- مراجعة مستقلة واحدة: لا P1؛ أصلحت مظهر لوحة المفاتيح، الإحداثيات، وتكرار تفاصيل الإضافي.
- عينات مرئية محدودة: معرض المكونات، اليوم، الناس على الديسكتوب والهاتف؛ أصلح قص البحث. هذه عينات وليست قبولًا بصريًا لكل حالة.
- لا تغيير في supabase/ أو actions.ts؛ لا إعادة اختبارات قواعد البيانات. اختبار الأجهزة الفعلية والقبول الشامل قبل النشر لدى المالك.
- حد جلسة Claude سبق أن توقف؛ استُخدمت خطته ومراجعته السابقة دون إعادة محاولات أو استبدال نموذج تلقائي.
- استخدام الأصناف القديمة الستة في TSX/JSX: 684 → 661؛ الباقي مربوط بالرموز الجديدة. ESLint يمنع استخدامها في UI/patterns/shell الجديدة.
- CI لا يُشغّل لهذا التسليم ([skip ci])، وتعطيل نشر Vercel خاص بهذا الفرع؛ لا main أو نشر.

## تغطية 75 صفحة

التغطية هنا تطبيق الكود والتنسيق، ولا تعني فحص جميع الصفحات بصريًا. الصفحات التابعة تستخدم المكونات المشتركة وCSS المجال؛ لا أدّعي إعادة كتابة كل صفحة من الصفر.

| المسار | المجال | التنفيذ |
|---|---|---|
| `/auth/employee-account-activation/callback` | الدخول | الأساس المشترك وتنسيق المجال |
| `/auth/employee-account-activation` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/forgot-password` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/invitations/accept` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/invitations/callback` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/login` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/membership-invitations/accept` | الدخول | تعديل مباشر + الأساس المشترك |
| `/auth/membership-invitations/callback` | الدخول | الأساس المشترك وتنسيق المجال |
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
| `/tenant/[tenantId]/attendance/import` | الحضور | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/attendance` | الحضور | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/attendance/review` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance/sources/[sourceId]/events/[eventId]` | الحضور | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/attendance/sources/[sourceId]` | الحضور | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/attendance/sources/new` | الحضور | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/attendance/sources` | الحضور | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/attendance/unassigned` | الحضور | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/branding` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/entities-sites/[entityId]` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/entities-sites/[entityId]/sites/new` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/entities-sites/new` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/entities-sites` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/balances/[accountId]` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/leave/balances/annual` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/leave/balances` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/leave/new` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/leave` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/requests/[requestId]` | الإجازات | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/leave/settings/[employerId]/calendars/[calendarId]` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/leave/settings/[employerId]/calendars/new` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/leave/settings/[employerId]` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/leave/settings/[employerId]/types/[typeId]` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/leave/settings/[employerId]/types/new` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/leave/settings/[employerId]/year-periods/new` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/leave/settings` | الإجازات | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/me/attendance` | الموظف | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/me/leave/[requestId]` | الموظف | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/me/leave/new` | الموظف | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/me/leave` | الموظف | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/me` | الموظف | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll/advances` | الرواتب | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/payroll/corrections` | الرواتب | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/payroll/inputs` | الرواتب | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/payroll/output` | الرواتب | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/payroll` | الرواتب | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/payroll/payments` | الرواتب | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/payroll/reports` | الرواتب | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/payroll/runs` | الرواتب | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/payroll/setup` | الرواتب | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/people/[employeeId]` | الناس | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/people/import` | الناس | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/people/new` | الناس | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/people/organization/[kind]/[recordId]` | الناس | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/people/organization` | الناس | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/people` | الناس | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/people/work-policies` | الناس | الأساس المشترك وتنسيق المجال |
| `/tenant/[tenantId]/users/invite` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/[tenantId]/users` | الإدارة والإطار | تعديل مباشر + الأساس المشترك |
| `/tenant/select` | الإدارة والإطار | الأساس المشترك وتنسيق المجال |
