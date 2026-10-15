(() => {
  'use strict';
  const roles = {
    employee: ['profile', 'self-attendance', 'self-leave'],
    company: ['company'], people: ['people'], attendance: ['attendance'],
    leave: ['leave'], payroll: ['payroll'], operator: ['operator'],
  };
  const labels = {
    profile: 'ملفي وأول دخول', 'self-attendance': 'حضوري', 'self-leave': 'إجازاتي',
    company: 'إدارة الشركة', people: 'الموارد البشرية', attendance: 'إدارة الحضور',
    leave: 'إدارة الإجازات', payroll: 'الرواتب', operator: 'تشغيل المنصة',
  };
  const requested = new URLSearchParams(window.location.search).get('topics');
  const personal = (requested || '').split(',').filter(topic => Object.hasOwn(labels, topic));
  const select = document.getElementById('guide-role');
  const status = document.getElementById('guide-status');
  if (!select || !status) return;
  select.value = personal.length ? 'personal' : 'all';
  select.querySelector('[value="personal"]').disabled = !personal.length;
  function update() {
    const all = select.value === 'all';
    const topics = select.value === 'personal' ? personal : roles[select.value] || [];
    document.querySelectorAll('[data-guide-topic]').forEach(element => {
      const sectionTopics = element.dataset.guideTopic.split(' ');
      element.hidden = !all && !sectionTopics.includes('common') && !sectionTopics.some(topic => topics.includes(topic));
    });
    status.textContent = all ? 'تعرض الآن الدليل الكامل بجميع الأدوار. اختر مهمة للتركيز على أقسامها.'
      : 'الأقسام المعروضة: ' + topics.map(topic => labels[topic]).join('، ') + '. يمكنك تغيير المسار أو اختيار الدليل الكامل.';
    const target = document.getElementById(window.location.hash.slice(1));
    if (target?.closest('[data-guide-topic]')?.hidden) window.history.replaceState(null, '', window.location.pathname + window.location.search);
  }
  select.addEventListener('change', update);
  update();
})();
