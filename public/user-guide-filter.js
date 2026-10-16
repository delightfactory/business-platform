(() => {
  'use strict';
  const labels = {
    profile: 'ملفي وأول دخول', 'self-attendance': 'حضوري', 'self-leave': 'إجازاتي',
    'company-users': 'المستخدمون والصلاحيات', 'company-structure': 'الجهات والفروع', 'company-branding': 'هوية الشركة',
    'people-view': 'ملفات الموظفين', 'people-manage': 'إضافة الموظفين', 'people-employment': 'بيانات العمل',
    'people-compensation': 'الأجور', 'people-import': 'استيراد الموظفين', 'people-org': 'الأقسام والوظائف', 'work-policies': 'أنظمة الدوام',
    'attendance-view': 'قراءة الحضور', 'attendance-input': 'إدخال الحضور', 'attendance-review': 'مراجعة الحضور', 'attendance-sources': 'وسائل التسجيل',
    'leave-view': 'قراءة الإجازات', 'leave-manage': 'إعداد الإجازات', 'leave-approve': 'قرارات الإجازات', 'leave-balances': 'أرصدة الإجازات',
    'payroll-view': 'قراءة مسيرات الرواتب', 'payroll-prepare': 'إعداد وحساب الرواتب', 'payroll-configure': 'إعدادات الرواتب',
    'payroll-approve': 'اعتماد مراجعة الرواتب', 'payroll-close': 'إقفال مسير الرواتب', 'payroll-payments': 'تسجيل صرف الرواتب', 'payroll-correct': 'تصحيح راتب مقفل',
    'payroll-reports': 'تقارير الرواتب', advances: 'السلف', 'operator-companies': 'شركات المنصة',
    'operator-invitations': 'دعوات الشركات', 'operator-commercial': 'خدمات الشركات وحدودها', 'operator-lifecycle': 'حالة الشركات',
    'operator-team': 'فريق التشغيل', 'operator-statutory': 'إعدادات حساب الضرائب والتأمينات',
  };
  const roles = {
    employee: ['profile', 'self-attendance', 'self-leave'],
    company: ['company-users', 'company-structure', 'company-branding'],
    people: ['people-view', 'people-manage', 'people-employment', 'people-compensation', 'people-import', 'people-org', 'work-policies'],
    attendance: ['attendance-view', 'attendance-input', 'attendance-review', 'attendance-sources'],
    leave: ['leave-view', 'leave-manage', 'leave-approve', 'leave-balances'],
    payroll: ['payroll-view', 'payroll-prepare', 'payroll-configure', 'payroll-approve', 'payroll-close', 'payroll-payments', 'payroll-correct', 'payroll-reports'],
    advances: ['advances'], reports: ['payroll-reports'],
    operator: ['operator-companies', 'operator-invitations', 'operator-commercial', 'operator-lifecycle', 'operator-team', 'operator-statutory'],
  };
  // Old bookmarks retain their module scope; new granular keys never expand into unrelated tasks.
  const legacy = { company: roles.company, people: roles.people, attendance: roles.attendance, leave: roles.leave, payroll: [...roles.payroll, 'advances'], operator: roles.operator };
  function resolveTopics(value) {
    return [...new Set((value || '').split(',').flatMap(topic => Object.hasOwn(legacy, topic) ? legacy[topic] : (Object.hasOwn(labels, topic) ? [topic] : [])))];
  }
  function matchesTopics(value, topics, all = false) {
    return all || value.split(' ').some(topic => topic === 'common' || topics.includes(topic));
  }
  function normalizeSearch(value) {
    return value.normalize('NFKC').replace(/[\u064b-\u065f\u0670\u0640]/g, '').replace(/[أإآٱ]/g, 'ا').replace(/ى/g, 'ي').toLocaleLowerCase('ar').replace(/\s+/g, ' ').trim();
  }
  if (typeof module !== 'undefined' && module.exports) { module.exports = { labels, roles, resolveTopics, matchesTopics, normalizeSearch }; return; }
  const params = new URLSearchParams(window.location.search);
  const personal = resolveTopics(params.get('topics'));
  const hasPersonal = params.get('personal') === '1' || personal.length > 0;
  const select = document.getElementById('guide-role');
  const search = document.getElementById('guide-search');
  const clear = document.getElementById('guide-clear');
  const status = document.getElementById('guide-status');
  const empty = document.getElementById('guide-empty');
  if (!select || !search || !clear || !status || !empty) return;
  select.value = hasPersonal ? 'personal' : 'all';
  select.querySelector('[value="personal"]').disabled = !hasPersonal;
  document.getElementById('guide-partial').hidden = params.get('partial') !== '1';
  const intro = document.querySelector('[data-guide-intro]');
  const sections = [...document.querySelectorAll('article section[data-guide-topic]')];
  const toc = [...document.querySelectorAll('nav a[data-guide-topic]')];
  // Search only text remaining visible under the task filter.
  function visibleText(node) {
    if (node.nodeType === 3) return node.textContent;
    if (node.nodeType !== 1 || node.hidden) return '';
    return [...node.childNodes].map(visibleText).join(' ');
  }
  function update() {
    const all = select.value === 'all';
    const topics = select.value === 'personal' ? personal : roles[select.value] || [];
    const query = normalizeSearch(search.value);
    if (intro) intro.hidden = Boolean(query);
    let count = 0;
    sections.forEach((section, index) => {
      section.hidden = false;
      section.querySelectorAll('[data-guide-task]').forEach(task => { task.hidden = !matchesTopics(task.dataset.guideTask, topics, all); });
      section.hidden = !matchesTopics(section.dataset.guideTopic, topics, all) || Boolean(query && !normalizeSearch(visibleText(section)).includes(query));
      if (!section.hidden) count++;
      if (toc[index]) toc[index].hidden = section.hidden;
    });
    clear.hidden = !search.value;
    empty.hidden = count > 0;
    const mode = all ? 'الدليل الكامل للتدريب' : select.value === 'personal' ? 'المهام المقترحة حسب صلاحياتك' : select.selectedOptions[0].textContent;
    const coverScope = document.getElementById('guide-cover-scope');
    if (coverScope) coverScope.textContent = mode;
    status.textContent = mode + ' · ' + count + ' قسم' + (query ? ' يطابق البحث.' : '.');
    if (select.value === 'personal' && !personal.length) status.textContent += ' لم تُحدد مهام إضافية؛ تظهر إرشادات البداية والمساعدة فقط.';
    const target = document.getElementById(window.location.hash.slice(1));
    if (target?.closest('[data-guide-topic]')?.hidden || target?.closest('[data-guide-task]')?.hidden) window.history.replaceState(null, '', window.location.pathname + window.location.search);
  }
  select.addEventListener('change', update);
  search.addEventListener('input', update);
  clear.addEventListener('click', () => { search.value = ''; update(); search.focus(); });
  update();
})();
