'use strict';
const paths = {
  book: '<path d="M3 4h6a3 3 0 0 1 3 3v14a4 4 0 0 0-4-3H3zM12 7a3 3 0 0 1 3-3h6v14h-5a4 4 0 0 0-4 3"/>',
  people: '<circle cx="9" cy="7" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3M16 4a3 3 0 0 1 0 6M18 14a5 5 0 0 1 3 5v2"/>',
  calendar: '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 2v6m10-6v6M3 11h18m-13 5h2m4 0h2"/>',
  wallet: '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 9h18m-5 5h5m-5 3h2"/>',
  arrow: '<path d="M20 12H4m6-6-6 6 6 6"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 8.5a2.5 2.5 0 1 1 4 2c-1 .6-1.5 1-1.5 2.5M12 17h.01"/>',
  file: '<path d="M14 2H5v20h14V7zM14 2v6h5M8 12h8M8 16h8"/>',
};
function icon(name) {
  return `<svg class="guide-icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.book}</svg>`;
}
function paragraphClass(text) {
  const label = /^\*\*([^*]+)\*\*/.exec(text)?.[1] || '';
  if (/^(النتيجة|كيف أعرف|كيف تعرف|النتيجة المطلوبة|نقطة انتهاء)/.test(label)) return ['success', 'check'];
  if (/^(إذا |عند |التعافي|قاعدة مهمة|نتيجة لم|قبل طلب)/.test(label)) return ['caution', 'help'];
  if (/^(ابدأ من|لمن)/.test(label)) return ['entry', 'arrow'];
  if (/^(بعد |الخطوة التالية)/.test(label)) return ['next', 'arrow'];
  return null;
}
function diagram(number) {
  if (number === 8) return `<figure class="guide-diagram" aria-label="الفرق بين فحص الملف وحفظ الموظفين"><figcaption>${icon('file')} افحص أولًا، ثم أكمل الإضافة</figcaption><div class="diagram-flow"><div class="diagram-preview"><strong>«فحص الملف»</strong><span>معاينة ومراجعة · لا يُضاف موظفون</span></div><span class="diagram-boundary">${icon('arrow')}<small>الحفظ</small></span><div class="diagram-saved"><strong>«إضافة الصفوف المحددة»</strong><span>هنا تبدأ الإضافة الفعلية</span></div></div><p>صف مرفوض؟ صحّح الملف الأصلي ثم أعد الفحص. تقرير المرفوضات ليس قالب استيراد.</p></figure>`;
  if (number === 14) return `<figure class="guide-diagram" aria-label="رحلة تسجيل حضور الموظف"><figcaption>${icon('calendar')} من الحركة المطلوبة إلى النتيجة</figcaption><div class="diagram-flow"><div><strong>افتح «يومي»</strong><span>راجع الحركة المطلوبة</span></div><span class="diagram-boundary">${icon('arrow')}</span><div><strong>سجّل الحركة</strong><span>وفق وسيلة الحضور المجهزة</span></div><span class="diagram-boundary">${icon('arrow')}</span><div><strong>راجع النتيجة</strong><span>تحقق من الحالة قبل التكرار</span></div></div><p>هذا رسم للمهمة؛ تفاصيل الموقع والجاهزية والتعافي موضحة في الخطوات أدناه.</p></figure>`;
  if (number === 19) return `<figure class="guide-diagram" aria-label="رحلة طلب إجازة الموظف"><figcaption>${icon('calendar')} تقديم الطلب لا يعني الموافقة عليه</figcaption><div class="diagram-flow"><div><strong>اختر الإجازة</strong><span>النوع والتواريخ</span></div><span class="diagram-boundary">${icon('arrow')}</span><div><strong>راجع وأرسل</strong><span>اقرأ الأثر قبل الإرسال</span></div><span class="diagram-boundary">${icon('arrow')}</span><div><strong>تابع القرار</strong><span>يراجعه المسؤول المخول</span></div></div><p>لا تفترض أن الرصيد أو الموافقة تغيّرا بمجرد إرسال الطلب؛ اقرأ الحالة الحالية.</p></figure>`;
  return '';
}
function masthead() {
  return `<header class="guide-masthead"><div class="guide-brand">${icon('book')} منصة الأعمال <span>دليل الاستخدام</span></div><p class="cover-edition">دليل الشركة للتدريب والاستخدام اليومي</p><div class="cover-layout"><div><p class="cover-title">دليلك إلى<br>عمل <em>أكثر سلاسة.</em></p><p class="cover-lead">اعرف من أين تبدأ، وما الخطوة التالية،<br>وكيف تتأكد أن مهمتك تمت بنجاح.</p><h1>دليل استخدام المنصة والموارد البشرية</h1><p id="guide-cover-scope">للشركة، وفريق الموارد البشرية، وكل موظف.</p></div><div class="cover-journey"><p>من تجهيز الفريق إلى الرواتب</p>${[['people','الموظفون','جهّز ملفات فريقك'],['calendar','الحضور والإجازات','تابع العمل اليومي'],['wallet','الرواتب','راجع وأكمل المسير']].map(([name,label,detail],i)=>`${i ? `<span class="cover-arrow">${icon('arrow')}</span>` : ''}<div>${icon(name)}<strong>${label}</strong><small>${detail}</small></div>`).join('')}<small class="cover-caption">رسم يوضح ارتباط المهام، وليس صورة لشاشة داخل المنصة.</small></div></div><div class="guide-actions"><button type="button" onclick="window.print()">${icon('file')} طباعة الأقسام المعروضة أو حفظها PDF</button><a href="user-guide.pdf" download>${icon('book')} تنزيل الدليل الكامل PDF</a><a href="#guide-tools">اختر مهمتك ${icon('arrow')}</a></div></header>`;
}
module.exports = { icon, paragraphClass, diagram, masthead };
