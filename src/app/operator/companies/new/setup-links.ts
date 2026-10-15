import { redirect } from 'next/navigation';
export async function redirectLegacySetup(mode: 'invite' | 'existing', searchParams: Promise<{ key?: string; state?: string }>) {
  const query = await searchParams; const params = new URLSearchParams({ mode });
  if (query.key !== undefined) params.set('key', typeof query.key === 'string' ? query.key : 'invalid');
  if (typeof query.state === 'string') params.set('state', query.state.slice(0, 60));
  redirect(`/operator/companies/new?${params}`);
}
