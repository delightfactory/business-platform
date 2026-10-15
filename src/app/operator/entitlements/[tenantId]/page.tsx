import { redirectLegacyCompanyDetail } from '../../companies/legacy-links';
import type { CompanyQuery } from '../../companies/company-context';
export const dynamic = 'force-dynamic';
export default async function LegacyCompanyDetail({ params, searchParams }: { params: Promise<{ tenantId: string }>; searchParams: Promise<CompanyQuery> }) {
  return redirectLegacyCompanyDetail('services', params, searchParams);
}
