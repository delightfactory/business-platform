import { operatorListQuery } from '../operator-list-controls';
export type CompanyQuery = { q?: string; page?: string; state?: string };
export function companyContextSuffix(query: CompanyQuery, includeState = false) {
  const { search, page } = operatorListQuery(query);
  const params = new URLSearchParams();
  if (search) params.set('q', search);
  if (page > 1) params.set('page', String(page));
  if (includeState && query.state) params.set('state', query.state.slice(0, 60));
  return params.size ? `?${params}` : '';
}
