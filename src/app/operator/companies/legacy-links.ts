import { redirect } from 'next/navigation';
import { operatorListQuery } from '../operator-list-controls';
import { companyContextSuffix, type CompanyQuery } from './company-context';

export async function redirectLegacyCompanyDetail(section: 'services' | 'limits' | 'status', params: Promise<{ tenantId: string }>, searchParams: Promise<CompanyQuery>) {
  const { tenantId } = await params;
  redirect(`/operator/companies/${encodeURIComponent(tenantId)}/${section}${companyContextSuffix(await searchParams, true)}`);
}

export async function redirectLegacyCompanyList(searchParams: Promise<{ q?: string; page?: string; state?: string }>) {
  const query = await searchParams;
  const { search, page } = operatorListQuery(query);
  const context = new URLSearchParams();
  if (search) context.set('q', search);
  if (page > 1) context.set('page', String(page));
  if (typeof query.state === 'string' && query.state.length <= 80) context.set('state', query.state);
  redirect(`/operator/companies${context.size ? `?${context}` : ''}`);
}
