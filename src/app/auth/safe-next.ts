const uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}';
const tenantPath = new RegExp(`^/tenant/${uuid}(?:/(?:users(?:/invite)?|branding|entities-sites(?:/new|/${uuid}(?:/sites/new)?)?))?$`, 'i');
const operatorPath = new RegExp(`^/operator(?:/(?:onboarding|invitations(?:/new)?|operators|tenants(?:/${uuid})?|commercial(?:/${uuid})?|entitlements(?:/${uuid})?))?$`, 'i');
const invitationPath = new RegExp(`^/auth/(?:membership-)?invitations/accept\\?id=${uuid}&issuance=[1-9]\\d{0,8}$`, 'i');
const payrollPath = new RegExp(`^/tenant/${uuid}/payroll(?:/(?:setup|inputs|runs|output|payments|advances|corrections|reports))?(?:\\?[^\\x00-\\x20#\\\\]*)?$`, 'i');

const selfServiceUuid = uuid.replaceAll('a-f', 'a-fA-F');
const selfServicePath = new RegExp(`^/tenant/${selfServiceUuid}/me(?:/(?:attendance|leave(?:/(?:new|${selfServiceUuid}))?))?$`);
const companyPath = new RegExp(`^/operator/companies(?:/(?:new|${uuid}(?:/(?:services|limits|status))?))?$`, 'i');
const tenantTask = new RegExp(`^/tenant/${uuid}/(?:${[
  `people(?:/(?:import|new|work-policies|organization(?:/(?:departments|jobs)/(?:new|${uuid}))?|${uuid}))?`,
  `attendance(?:/(?:calendar|import|review|unassigned|sources(?:/(?:new|${uuid}(?:/events/${uuid})?))?|${uuid}))?`,
  `leave(?:/(?:new|requests/${uuid}|balances(?:/(?:annual|${uuid}))?|settings(?:/${uuid}(?:/(?:calendars/(?:new|${uuid})|types/(?:new|${uuid})|year-periods/new))?)?))?`,
  'payroll/setup/configuration',
  `me(?:/(?:attendance|leave(?:/(?:new|${uuid}))?))?`,
  `users(?:/invite)?|branding|entities-sites(?:/(?:new|${uuid}(?:/sites/new)?))?`,
].join('|')})$`, 'i');

/** Navigation only: each destination still authenticates and authorizes its data. */
function safeTenantTaskNext(value: string): boolean {
  if (value.length > 8192 || /[\x00-\x20\x7f#\\]|%(?:0[0-9a-f]|1[0-9a-f]|7f)/i.test(value)) return false;
  const path = value.split('?')[0];
  if (path !== '/tenant/select' && !tenantTask.test(path)) return false;
  const target = new URL(value, 'https://workspace.invalid');
  return target.origin === 'https://workspace.invalid' && [...target.searchParams].every(([key, entry]) => !/[\x00-\x1f\x7f]/.test(key + entry));
}

function safeCompanyNext(value: string): boolean {
  if (value.length > 1024 || !companyPath.test(value.split('?')[0]) || /[\x00-\x20#\\]|%(?:00|0a|0d)/i.test(value)) return false;
  const target = new URL(value, 'https://workspace.invalid');
  if (target.origin !== 'https://workspace.invalid' || !companyPath.test(target.pathname)) return false;
  const seen = new Set<string>(), creating = target.pathname === '/operator/companies/new';
  for (const [key, entry] of target.searchParams) {
    if (seen.has(key)) return false;
    seen.add(key);
    const allowed = creating
      ? (key === 'mode' && ['invite', 'existing'].includes(entry)) || (key === 'key' && new RegExp(`^${uuid}$`, 'i').test(entry))
      : (key === 'q' && entry.length <= 120 && !/[\x00-\x1f\x7f]/.test(entry)) || (key === 'page' && /^[1-9]\d{0,5}$/.test(entry));
    if (!allowed) return false;
  }
  return true;
}

export function safeAuthNext(value: string): string {
  // Keep the original payroll selection through login, while allowing only
  // known internal pages and rejecting controls that cannot be a safe Location.
  const payroll = value.length <= 8192 && payrollPath.test(value) && !/%(?:00|0a|0d)/i.test(value);
  const selfService = value.length <= 256 && selfServicePath.test(value) && !/[\x00-\x20#\\%?]/.test(value);
  return selfService || tenantPath.test(value) || operatorPath.test(value) || invitationPath.test(value) || payroll || safeCompanyNext(value) || safeTenantTaskNext(value) ? value : '';
}
