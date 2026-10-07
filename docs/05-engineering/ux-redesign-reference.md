# مرجع إعادة التصميم أثناء التنفيذ

هذا المرجع مطلوب لكل شريحة UX في business-platform. طلب المالك أن يبقى متاحًا أثناء التنفيذ.

## نقطة البداية
- [الديمو التفاعلي المنشور](https://business-platform-ux-concept-c.delight2025.chatgpt.site/)
- [صفحة المرجع والتنزيلات](https://business-platform-ux-concept-c.delight2025.chatgpt.site/reference.html)
- [تنزيل المصدر الأصلي المطابق للبصمة](https://business-platform-ux-concept-c.delight2025.chatgpt.site/ux-concept-c-original.txt)؛ احفظه بامتداد `.html`، أو استخدم زر التنزيل في صفحة المرجع.
- [تذكرة التنفيذ #47](https://github.com/delightfactory/business-platform/issues/47)
- [تقرير التوافق المثبت](https://github.com/delightfactory/business-platform/blob/76c7a8e662954be8f9228cf1bb66d3351274d9d7/docs/05-engineering/ux-redesign-review-20261007.md)
- [خطة Claude الأصلية المثبتة](https://github.com/delightfactory/business-platform/blob/76c7a8e662954be8f9228cf1bb66d3351274d9d7/docs/07-execution/evidence/ux-redesign-proposal-20261007/ux-redesign-plan.md)
- [HTML الأصلي المثبت](https://github.com/delightfactory/business-platform/blob/76c7a8e662954be8f9228cf1bb66d3351274d9d7/docs/07-execution/evidence/ux-redesign-proposal-20261007/ux-concept-c.html)

## استعمال المرجع
1. قبل تعديل أي رحلة أو مكون، اقرأ الخطة وتقرير التوافق، وافتح الجزء المقابل في الديمو.
2. سجل نطاق الشريحة والمرجع البصري المستعمل، ثم قارنه بالعقود الفعلية والمواصفات.
3. الديمو مرجع بصري بمحاكاة بيانات وقرارات؛ لا تنقل JavaScript أو الأرقام أو الصلاحيات أو حسابات الحضور والرواتب منه.
4. سجل أي اختلاف مقصود في التذكرة مع السبب. تغييرات الخط وأبعاد التحكم والتنقل والقدرات الجديدة تحتاج amendment؛ لا تتوسع تلقائيًا.
5. أثبت التنفيذ بصور قبل/بعد ومقاسات مناسبة وفحوص الشريحة. توفر المرجع لا يثبت قبول الرحلات الخلفية.
6. إذا تعذر الرابط الحي، استخدم نسخة HTML المثبتة على GitHub أو المحلية؛ يمكن فتح الملف مباشرة دون حساب.

## النسخة المحلية
الملفات الأصلية في فرع `codex/ux-redesign-reference`:
`docs/07-execution/evidence/ux-redesign-proposal-20261007/`.
يمكن استرجاعها من الكوميت المثبت في نسخة مستقلة دون reset/checkout فوق عمل قائم. بصمة HTML SHA256:
`AF24015383285EAF543E9C95839F55225C2FE9817DD8B1E16D2084F857725508`.

## هوية المرجع والتنفيذ
- كوميت ملفات Claude والمراجعة: `76c7a8e662954be8f9228cf1bb66d3351274d9d7`.
- مصدر نشر الديمو على Sites: `6ff32b18c2ef6187ebf481e6506afb22cd735761`، version2. ملف index.html في المصدر مطابق لبصمة HTML الأصلي. الاستضافة تضيف سكربتًا لصفحات HTML عند العرض؛ ملف التنزيل `.txt` والحزمة ZIP يحفظان بايتات الأصل، وتم التحقق من بصمتيهما عبر الرابط العام.
- أساس Cube5: `3a310d25c91a84eda52a47cf0491c5a235933a31`، الشجرة `1c06640dbbc0b3975c2cc8eff2cfe12345da66ea`.
- أساس النسخ المحفوظ: `afdc9a2b37a7a66a4ff1ba1532e411497b4b01a4`. main لا يحتوي هذا الأساس أثناء إعداد المرجع.
- W1.a المبدوءة: ألوان ورموز المظهر الفاتح فقط، مع الحفاظ على Cairo والتحكم والسلوك. توسيع التنفيذ يتبع تقرير التوافق والقرارات المفتوحة.

هذا موقع ديمو مستقل بلا اتصال ببيانات التطبيق الحقيقي. نشره لا يعني نشر business-platform أو دمج إعادة التصميم.
