# مساهمة Codex للمراجعة المشتركة — Proposed

المصدر: HEAD6bfd604، قاعدة Cube5 المقبولة محفوظة. هذه ملاحظات مصححة من الكود، وليست إثبات تنفيذ أو تأهيل كامل.

## المقام الذي نراجعه

254 ملف مصدر؛75 صفحة؛3 route endpoints (Auth callback وتصديرا الرواتب)؛8 حدود مشتركة؛107 server actions بما فيها attach inline؛341 موضعRPC؛215 اسمRPC حرفي و6 مواضع ديناميكية؛985 موضع form/button/input/select/textarea. تخصيص مالك لكل موضع لا يثبت صحة رحلة أو اكتمال سيناريوهاتها.

## تصحيح السلوك الأساسي

src/app/tenant/[tenantId]/attendance/page.tsx:25-28 يستدعي attendance_open_day أثناء render للمخولين. استبداله بزر صريح تعديل سلوك يحتاج مواصفة أثر، لا retheme. تعليق «لم تتغير أي سجلات» بعد نتيجة خطأ لا يبرر إثبات عدم وقوع mutation؛ يلزم سيناريو uncertain/reconcile مناسب للعقد الفعلي. خطة Claude الأصلية تصف الحالة بشكل غير مطابق؛ يُحفظ الأصل ويضاف التصحيح.

## توسعةRPC الديناميكية التي تحقق منها Codex

| الموضع | المسارات الفعلية |
| --- | --- |
| attendance/sources/actions.ts:31 | save_source / map / review / reprocess؛ جميعها attendance_channel_* |
| leave/actions.ts:117 | leave_approve_historical_request / leave_approve_request |
| payroll/advances/actions.ts:11 | payroll_resolve_advance_attempt / payroll_advance_command |
| payroll/corrections/actions.ts:64 | payroll_correction_proposal / finalize / settlement / command؛ payroll_candidate_approval؛ reconcile يستخدم calls حرفية أخرى مستقلة |
| payroll/runs/actions.ts:17 | payroll_run_command / payroll_run_reconcile / payroll_run_finalize / payroll_run_finalization_reconcile |
| people/work-policy-actions.ts:33 | save_time_work_policy_with_leave_mapping / save_time_work_policy |

هذه قراءة source للبدائل، وليست إثبات grants أو النتائج من قاعدة بيانات.

## فروع عمليات لا يجوز إسقاطها

runAction: calculate/cancel/finalize، مع reconcile وclosed_uncommitted. approvalAction: approve/release، same-attempt. advances: save/approve/activate/cancel/settle/compensate/termination/defer/correct_deduction/correct_disbursement من AdvanceOperation. corrections: preview/save/finalize/settlement/approve_candidate/release_candidate والأوامر الإضافية في قواعد الحالة، وستة أنواع مصادر مستقلة؛ ليست دالة واحدة بحالة قبول واحدة. mutateChannel: save/map/reprocess/review، ونوع mobile/external واتصال الموقع enabled/failure policy كفروع بيانات. أنواع الحالات واتحاد القيم المستورد من rules/client/SQL تحتاج توسعة بشرية؛ عد الإجراءات107 لا يغلقها.

## شكل الاحتراف المطلوب في خرائط الرحلات

لكل مهمة: المستخدم/الصلاحية → نقطة الدخول/السياق → قراءات التجهيز → قرار قابل للفهم → mutation إن وجدت → إيصال مثبت → الإجراء التالي. لكل فرع رفض/تعارض/فقد استجابة/فقد جلسة سهم عودة محدد، مع هوية المحاولة حيث يدعمها المصدر. المخططات تربط أسماء الخدمات الفعلية، وتفصل الحالات المعروضة عن نواتج الخادم.

يجب أن تكون العودة من مانع رواتب إلى مصدر People/Leave/Attendance ثم إلى نفس الجهة والفترة مرسومة. استعادة الدعوة/كلمة المرور لا تختصر إلى زر Login؛ إنشاء الحساب ودليل وصول رسالته وتفعيله ثلاث نتائج مستقلة. السحب وطلب إلغاء المعتمد والاستبدال والتصحيح المالي أربع رحلات مختلفة.

## معيار التبسيط

قس قبل/بعد: التنقلات، إعادة اختيار السياق، الحقول المطلوبة، الأفعال الأساسية المتنافسة، الرجوع لفهم سبب المنع، ومعرفة هل تم الحفظ. لا ادعاء تقليل النقرات قبل قياس baseline. لا تحذف وظيفة أو شرطًا أو تأكيدًا لازمًا لتقليل العدد. تسجل الزيادة الضرورية بعلة المخاطر وأثرها على المهمة؛ الإجراءات الثانوية تظل قابلة للاكتشاف والوصول.

## بوابة100%

100% تخص مقامًا معلنًا ومراجعًا، لا كل قيم المدخلات اللانهائية. تغطى حالات الأعمال والقرارات والأدوار الممكنة وفئات البيانات/الحدود/الأخطاء والاستعادة. أي تركيبة غير ممكنة لها إثبات constraint وN/A مسبب. النقد المالي والصلاحيات والخصوصية لا يكتفون بـpairwise أو screenshot.

نفصل تخصيص المصدر للمراحل، تعريف الوظائف وفروعها، مواصفات سيناريوهاتها، التنفيذ، والاختبار بالأدلة. الحالة الحالية لا تتعدى تخصيص المصدر وجرد مبدئي ومراجعة عينات واسعة. لا حالة مكتمل أو Frozen من تعداد الملفات وحده.
