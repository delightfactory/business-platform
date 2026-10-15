import { redirect } from 'next/navigation';
import { readOperatorAuthority } from '@/lib/operator-authority';

export default async function CompanyEntry({ params, searchParams }: {
  params: Promise<{ tenantId: string }>; searchParams: Promise<{ q?: string; page?: string }>;
}) {
  const { tenantId } = await params;
  const authority = await readOperatorAuthority();
  const query = await searchParams;
  const context = new URLSearchParams();
  if (typeof query.q === 'string') context.set('q', query.q.slice(0, 120));
  if (typeof query.page === 'string' && /^[1-9]\d{0,5}$/.test(query.page)) context.set('page', query.page);
  const suffix = context.size ? `?${context}` : '';
  // Existing detail routes retain their own authoritative access checks until D3 replaces their presentation.
  if (authority.active && authority.commercial) redirect(`/operator/entitlements/${encodeURIComponent(tenantId)}${suffix}`);
  if (authority.active && authority.lifecycle) redirect(`/operator/tenants/${encodeURIComponent(tenantId)}${suffix}`);
  redirect('/operator/companies');
}
