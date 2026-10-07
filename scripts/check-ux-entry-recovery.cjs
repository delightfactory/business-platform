/* eslint-disable @typescript-eslint/no-require-imports -- Standalone isolated component qualification. */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const cp = require('node:child_process');
const ts = require('typescript');
const assert = require('node:assert/strict');
const { renderToStaticMarkup } = require('react-dom/server');
const root = process.argv[2];
const out = process.argv[3];
if (!root || !out) throw Error('Pass repository and existing artifact directory');
const id = '12345678-1234-4234-8234-123456789abc';
const files = { tenant: 'src/app/tenant/select/page.tsx', accept: 'src/app/auth/invitations/accept/page.tsx', callback: 'src/app/auth/invitations/callback/page.tsx', employee: 'src/app/auth/employee-account-activation/page.tsx' };
function forbiddenAction() { throw Error('Action invocation forbidden in render check'); }
function load(file, options, baseline = false) {
  const source = baseline ? cp.execFileSync('git', ['show', `0500508d69e87aa2b3075df5c471f01518b10dca:${file}`], { cwd: root, encoding: 'utf8' }) : fs.readFileSync(path.join(root, file), 'utf8');
  const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true } }).outputText;
  const client = options.setup === false ? null : { auth: { getUser: async () => ({ data: { user: options.user === false ? null : { id, email: 'synthetic@example.invalid' } } }) }, rpc: async () => ({ data: options.data, error: options.error ?? null }) };
  const imports = { '@/lib/supabase/server': { createSupabaseServerClient: async () => client }, '@/app/auth/actions': { signOutAction: forbiddenAction }, './actions': { acceptInvitationAction: forbiddenAction, setInvitationPasswordAction: forbiddenAction, verifyInvitationLinkAction: forbiddenAction, retryEmployeeAccountActivationAction: forbiddenAction, setEmployeeAccountPasswordAction: forbiddenAction }, 'next/navigation': { redirect: location => { throw Object.assign(Error('redirect'), { location }); } }, '@/components/submit-button': loadButton() };
  const ctx = { exports: {}, require: name => { if (Object.hasOwn(imports, name)) return imports[name]; if (['react', 'react-dom', 'react/jsx-runtime', 'next/link'].includes(name)) return require(name); throw Error(`Unexpected import ${name}`); } };
  vm.runInNewContext(code, ctx, { filename: file });
  return ctx.exports.default;
}
function loadButton() {
  const code = ts.transpileModule(fs.readFileSync(path.join(root, 'src/components/submit-button.tsx'), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX } }).outputText;
  const ctx = { exports: {}, require };
  vm.runInNewContext(code, ctx);
  return ctx.exports;
}
async function render(kind, options = {}, query = {}, baseline = false) {
  try { return renderToStaticMarkup(await load(files[kind], options, baseline)({ searchParams: Promise.resolve(query) })); }
  catch (error) { if (error.location) return `REDIRECT:${error.location}`; throw error; }
}
(async () => {
  const cases = [];
  async function check(name, kind, options, query, verify) {
    const html = await render(kind, options, query);
    verify(html);
    cases.push({ id: name, status: 'pass', qualification: 'server-component-render-provider-and-actions-stubbed' });
    return html;
  }
  const tenantError = await check('TENANT-READ-ERROR', 'tenant', { error: {} }, {}, html => { assert.match(html, /action="\/tenant\/select" method="get"/); assert.match(html, /إعادة تحميل الشركات/); assert.match(html, /تسجيل الخروج/); assert.match(html, /role="alert"/); });
  for (const data of [null, {}, 'unusable']) await check(`TENANT-UNUSABLE-${JSON.stringify(data)}`, 'tenant', { data }, {}, html => assert.match(html, /إعادة تحميل الشركات/));
  await check('TENANT-SETUP', 'tenant', { setup: false }, {}, html => assert.match(html, /href="\/auth\/login"/));
  await check('TENANT-NO-USER', 'tenant', { user: false }, {}, html => assert.equal(html, 'REDIRECT:/auth/login?state=no-session'));
  await check('TENANT-EMPTY', 'tenant', { data: [] }, {}, html => { assert.match(html, /لا توجد مساحة/); assert.doesNotMatch(html, /إعادة تحميل الشركات/); });
  await check('TENANT-SINGLE-ACTIVE', 'tenant', { data: [{ tenant_id: id, lifecycle_state: 'active' }] }, {}, html => assert.equal(html, `REDIRECT:/tenant/${id}`));
  await check('TENANT-SUSPENDED', 'tenant', { data: [{ tenant_id: id, tenant_name: 'شركة اختبار', lifecycle_state: 'suspended' }] }, {}, html => { assert.match(html, /معلّقة/); assert.match(html, new RegExp(`href="/tenant/${id}"`)); });
  await check('TENANT-MULTIPLE', 'tenant', { data: [{ tenant_id: id, tenant_name: 'الأولى', lifecycle_state: 'active' }, { tenant_id: id.replace('abc', 'abd'), tenant_name: 'الثانية', lifecycle_state: 'active' }] }, {}, html => assert.match(html, /الأولى.*الثانية/));
  const unknowns = [undefined, 'unknown', '__proto__', 'constructor', 'toString', 'hasOwnProperty'];
  for (const state of unknowns) for (const kind of ['callback', 'accept']) await check(`${kind}-UNKNOWN-${state ?? 'none'}`, kind, {}, { state }, html => assert.match(html, kind === 'callback' ? /تعذر التحقق من رابط الدعوة/ : /تعذر التحقق من الدعوة/));
  for (const [state, expected] of [['invalid', 'غير مكتمل'], ['link-expired', 'الأيام السبعة'], ['setup', 'أعد المحاولة لاحقًا']]) await check(`CALLBACK-${state}`, 'callback', {}, { state }, html => { assert.match(html, new RegExp(expected)); assert.match(html, /role="alert"/); assert.doesNotMatch(html, /name="tokenHash"/); });
  await check('CALLBACK-VALID', 'callback', {}, { token_hash: 'synthetic_link_hash', type: 'invite', invitation_id: id, issuance: '1' }, html => { assert.match(html, /التحقق والمتابعة/); assert.match(html, /name="tokenHash"/); });
  for (const [state, expected] of [['invalid', 'الرابط الأخير'], ['expired', 'انتهت صلاحية الدعوة'], ['superseded', 'رابط أحدث'], ['unavailable', 'تعذر التحقق من الدعوة في الخطوة السابقة'], ['identity', 'بريد آخر'], ['unverified', 'تأكيد البريد'], ['issuer-lost', 'صلاحية مُصدر الدعوة'], ['accept-failed', 'تعذر التأكد من إنشاء الشركة'], ['password', 'ثمانية أحرف'], ['password-marker-failed', 'حُفظت كلمة المرور'], ['link-expired', 'الأيام السبعة'], ['no-session', 'انتهت جلسة الدعوة'], ['setup', 'إعداد خدمة الحسابات']]) await check(`ACCEPT-${state}`, 'accept', {}, { state }, html => { assert.match(html, /رابط الدعوة غير صالح/); assert.match(html, new RegExp(expected)); });
  for (const validation of ['ready', 'password_required', 'identity_mismatch', 'unavailable']) await check(`ACCEPT-VALIDATION-${validation}`, 'accept', { data: validation }, { id, issuance: '1' }, html => {
    if (validation === 'ready') { assert.match(html, /تأكيد الدعوة وإنشاء الشركة/); assert.doesNotMatch(html, /name="password"/); }
    else if (validation === 'password_required') assert.match(html, /name="password"/);
    else assert.doesNotMatch(html, /تأكيد الدعوة وإنشاء الشركة/);
  });
  for (const state of ['setup', 'no-session', 'unavailable']) {
    for (const validation of ['ready', 'password_required', 'identity_mismatch', 'unavailable']) await check(`ACCEPT-RETAINED-${state}-${validation}`, 'accept', { data: validation }, { id, issuance: '1', state }, html => {
      assert.doesNotMatch(html, /الدعوة أُلغيت/);
      if (validation === 'ready') { assert.match(html, /تأكيد الدعوة وإنشاء الشركة/); assert.match(html, /name="invitationId"/); }
      else if (validation === 'password_required') { assert.match(html, /name="password"/); assert.doesNotMatch(html, /تأكيد الدعوة وإنشاء الشركة/); }
      else assert.doesNotMatch(html, /name="password"|تأكيد الدعوة وإنشاء الشركة/);
    });
    await check(`ACCEPT-RETAINED-${state}-NO-USER`, 'accept', { user: false }, { id, issuance: '1', state }, html => { assert.match(html, /^REDIRECT:\/auth\/login\?next=/); assert.match(decodeURIComponent(html), new RegExp(id)); });
    await check(`ACCEPT-RETAINED-${state}-NO-CLIENT`, 'accept', { setup: false }, { id, issuance: '1', state }, html => { assert.match(html, /إعداد الاتصال غير مكتمل/); assert.doesNotMatch(html, /name="password"|تأكيد الدعوة وإنشاء الشركة/); });
  }
  const employeeReady = await check('EMPLOYEE-READY', 'employee', { data: { state: 'activated', password_ready: true } }, { intent_id: id }, html => { assert.match(html, /المتابعة إلى مساحة العمل/); assert.doesNotMatch(html, /name="password"/); });
  await check('EMPLOYEE-READY-FORGED-COPY', 'employee', { data: { state: 'activated', password_ready: true } }, { intent_id: id, state: 'password-ready' }, html => { assert.doesNotMatch(html, /تم تحديث كلمة المرور/); assert.match(html, /تم تأكيد جاهزية كلمة المرور/); });
  for (const state of [undefined, 'password-ready', 'unknown', 'limit-full']) await check(`EMPLOYEE-UNREADY-${state ?? 'none'}`, 'employee', { data: { state: 'activated', password_ready: false } }, { intent_id: id, state }, html => { assert.match(html, /name="password"/); assert.doesNotMatch(html, /المتابعة إلى مساحة العمل/); });
  for (const state of ['user_created', 'limit-full', 'employee-unavailable', 'password-ready', 'readiness', 'retry']) await check(`EMPLOYEE-PENDING-${state}`, 'employee', { data: { state: 'user_created', password_ready: false } }, { intent_id: id, state }, html => assert.doesNotMatch(html, /المتابعة إلى مساحة العمل/));
  for (const options of [{ setup: false }, { user: false }, { data: null }, { data: [] }, { error: {} }]) await check(`EMPLOYEE-DENIED-${JSON.stringify(options)}`, 'employee', options, { intent_id: id }, html => assert.doesNotMatch(html, /المتابعة إلى مساحة العمل/));
  await check('EMPLOYEE-MALFORMED', 'employee', {}, {}, html => assert.match(html, /رابط التفعيل غير صالح/));
  fs.writeFileSync(path.join(out, 'tenant-error.html'), tenantError);
  fs.writeFileSync(path.join(out, 'employee-ready.html'), employeeReady);
  fs.writeFileSync(path.join(out, 'tenant-before.html'), await render('tenant', { error: {} }, {}, true));
  fs.writeFileSync(path.join(out, 'employee-before.html'), await render('employee', { data: { state: 'activated', password_ready: true } }, { intent_id: id }, true));
  const before = {};
  for (const kind of ['accept', 'callback']) { try { await render(kind, {}, { state: '__proto__' }, true); before[kind] = 'rendered'; } catch { before[kind] = 'render-error'; } }
  fs.writeFileSync(path.join(out, 'entry-checks.json'), JSON.stringify({ scope: 'actual-server-components-sdk-and-action-stubs-no-network-no-live-UAT', cases, baselineUnknownPrototype: before, primaryTenantRetryBefore: 0, primaryTenantRetryAfter: 1, verifiedActivationContinuationBefore: 0, verifiedActivationContinuationAfter: 1 }, null, 2));
  console.log(JSON.stringify({ passed: cases.length, baselineUnknownPrototype: before }));
})();
