'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const script = fs.readFileSync(path.join(__dirname, '../public/user-guide-filter.js'), 'utf8');
const { labels, roles, resolveTopics, matchesTopics, normalizeSearch } = require('../public/user-guide-filter.js');

function element(text = '', dataset = {}, children = []) {
  return { nodeType: 1, hidden: false, dataset, value: '', textContent: text,
    childNodes: [...(text ? [{ nodeType: 3, textContent: text }] : []), ...children],
    events: {}, addEventListener(name, fn) { this.events[name] = fn; },
    focus() { this.focused = true; }, querySelectorAll() { return children; } };
}

function page(search) {
  const reader = element('قراءة المسير', { guideTask: 'payroll-view' });
  const payments = element('مرجع التحويل التجريبي', { guideTask: 'payroll-payments' });
  const common = element('البداية والمساعدة', { guideTopic: 'common' });
  const payroll = element('مسير الرواتب', { guideTopic: 'payroll-view payroll-payments' }, [reader, payments]);
  const advances = element('سلف الموظفين', { guideTopic: 'advances' });
  const sections = [common, payroll, advances];
  const toc = sections.map(() => element());
  const nodes = Object.fromEntries(['guide-role', 'guide-search', 'guide-clear', 'guide-status', 'guide-empty', 'guide-partial'].map(id => [id, element()]));
  const personalOption = {};
  nodes['guide-role'].querySelector = () => personalOption;
  nodes['guide-role'].selectedOptions = [{ textContent: 'السلف' }];
  const intro = element('مقدمة الدليل');
  const document = { querySelector: () => intro, getElementById: id => nodes[id], querySelectorAll: selector => selector.startsWith('article') ? sections : toc };
  const window = { location: { search, hash: '', pathname: '/user-guide.html' }, history: { replaceState() {} } };
  vm.runInNewContext(script, { document, window, URLSearchParams });
  return { nodes, sections, toc, payments, reader, personalOption, intro };
}

test('new granular permissions do not expand into payment, correction or advance tasks', () => {
  assert.deepEqual(resolveTopics('payroll-view,payroll-view,unknown,__proto__,constructor'), ['payroll-view']);
  assert.equal(matchesTopics('payroll-payments', resolveTopics('payroll-view')), false);
  assert.equal(matchesTopics('common', []), true);
});

test('old bookmarked module topics retain their original complete training scope', () => {
  assert.ok(resolveTopics('payroll').includes('advances'));
  assert.ok(resolveTopics('operator').includes('operator-statutory'));
  assert.deepEqual(resolveTopics('profile,self-attendance'), roles.employee.slice(0, 2));
});

test('personal empty capabilities stay common-only, without falling back to full training', () => {
  const p = page('?topics=&personal=1');
  assert.equal(p.nodes['guide-role'].value, 'personal');
  assert.deepEqual(p.sections.map(item => item.hidden), [false, true, true]);
  assert.equal(p.personalOption.disabled, false);
  assert.match(p.nodes['guide-status'].textContent, /إرشادات البداية/);
});

test('a payroll reader cannot search into hidden payment instructions; TOC follows results', () => {
  const p = page('?topics=payroll-view&personal=1');
  assert.equal(p.reader.hidden, false);
  assert.equal(p.payments.hidden, true);
  p.nodes['guide-search'].value = 'مرجع التحويل';
  p.nodes['guide-search'].events.input();
  assert.equal(p.intro.hidden, true, 'search brings the matching chapter above the long introduction');
  assert.ok(p.sections.every(item => item.hidden));
  assert.ok(p.toc.every(item => item.hidden));
  assert.equal(p.nodes['guide-empty'].hidden, false);
  assert.match(p.nodes['guide-status'].textContent, /0 قسم/);
  p.nodes['guide-clear'].events.click();
  assert.deepEqual(p.sections.map(item => item.hidden), [false, false, true]);
  assert.equal(p.nodes['guide-search'].focused, true);
  assert.equal(p.intro.hidden, false, 'clearing search restores the complete introduction');
});

test('multiple roles combine and selecting full training intentionally reveals all tasks', () => {
  const p = page('?topics=payroll-view,advances&personal=1');
  assert.ok(p.sections.every(item => !item.hidden));
  assert.equal(p.payments.hidden, true);
  p.nodes['guide-role'].value = 'all';
  p.nodes['guide-role'].events.change();
  assert.equal(p.payments.hidden, false);
  assert.ok(p.toc.every(item => !item.hidden));
});

test('direct public guide is complete; partial verification message is independent of grants', () => {
  const direct = page('');
  assert.equal(direct.nodes['guide-role'].value, 'all');
  assert.ok(direct.sections.every(item => !item.hidden));
  const partial = page('?personal=1&partial=1');
  assert.equal(partial.nodes['guide-partial'].hidden, false);
  assert.equal(partial.sections[1].hidden, true);
});

test('Arabic search tolerates tashkeel and hamza differences', () => {
  assert.equal(normalizeSearch('إِضَافَة   مُوَظَّف'), normalizeSearch('اضافة موظف'));
});

test('generated guide uses recognized topic keys, unique anchors and one matching TOC entry per chapter', () => {
  const html = fs.readFileSync(path.join(__dirname, '../public/user-guide.html'), 'utf8');
  const sections = [...html.matchAll(/<section data-guide-topic="([^"]+)">/g)];
  const links = [...html.matchAll(/<a data-guide-topic="([^"]+)" href="#(section-\d+)"/g)];
  assert.equal(sections.length, 34);
  assert.equal(links.length, sections.length);
  const ids = [...html.matchAll(/id="(section-\d+)"/g)].map(match => match[1]);
  assert.equal(new Set(ids).size, ids.length);
  for (const [, , id] of links) assert.ok(ids.includes(id));
  for (const [, topics] of html.matchAll(/data-guide-(?:topic|task)="([^"]+)"/g)) {
    for (const topic of topics.split(' ')) assert.ok(topic === 'common' || Object.hasOwn(labels, topic), topic);
  }
  assert.ok(!html.includes('&lt;!-- guide:'));
  assert.ok(html.includes('[hidden]{display:none!important}'), 'the role/search filter also applies when printing');
});
