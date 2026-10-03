const uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}';
const tenantPath = new RegExp(`^/tenant/${uuid}(?:/(?:users(?:/invite)?|branding|entities-sites(?:/new|/${uuid}(?:/sites/new)?)?))?$`, 'i');
const operatorPath = new RegExp(`^/operator(?:/(?:onboarding|invitations(?:/new)?|operators|tenants(?:/${uuid})?|commercial(?:/${uuid})?|entitlements(?:/${uuid})?))?$`, 'i');
const invitationPath = new RegExp(`^/auth/(?:membership-)?invitations/accept\\?id=${uuid}&issuance=[1-9]\\d{0,8}$`, 'i');
const payrollPath = new RegExp(`^/tenant/${uuid}/payroll(?:/(?:setup|inputs|runs|output|payments|advances|corrections|reports))?(?:\\?[^\\x00-\\x20#\\\\]*)?$`, 'i');

export function safeAuthNext(value: string): string {
  // Keep the original payroll selection through login, while allowing only
  // known internal pages and rejecting controls that cannot be a safe Location.
  const payroll = value.length <= 8192 && payrollPath.test(value) && !/%(?:00|0a|0d)/i.test(value);
  return tenantPath.test(value) || operatorPath.test(value) || invitationPath.test(value) || payroll ? value : '';
}
