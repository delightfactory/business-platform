const uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}';
const tenantPath = new RegExp(`^/tenant/${uuid}(?:/(?:users(?:/invite)?|branding|entities-sites(?:/new|/${uuid}(?:/sites/new)?)?))?$`, 'i');
const operatorPath = new RegExp(`^/operator(?:/(?:onboarding|invitations(?:/new)?|operators|tenants(?:/${uuid})?|commercial(?:/${uuid})?|entitlements(?:/${uuid})?))?$`, 'i');
const invitationPath = new RegExp(`^/auth/(?:membership-)?invitations/accept\\?id=${uuid}&issuance=[1-9]\\d{0,8}$`, 'i');

export function safeAuthNext(value: string): string {
  return tenantPath.test(value) || operatorPath.test(value) || invitationPath.test(value) ? value : '';
}
