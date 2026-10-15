import { redirectLegacyCompanyList } from '../companies/legacy-links';

export const dynamic = 'force-dynamic';

export default async function LegacyCompanyList({ searchParams }: {
  searchParams: Promise<{ q?: string; page?: string; state?: string }>;
}) {
  return redirectLegacyCompanyList(searchParams);
}
