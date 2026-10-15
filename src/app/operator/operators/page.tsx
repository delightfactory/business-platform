import { redirect } from 'next/navigation';
export const dynamic = 'force-dynamic';
export default async function LegacyOperatorsPage({ searchParams }: { searchParams: Promise<{ state?: string }> }) {
  const query = await searchParams;
  redirect(`/operator/team${query.state ? `?state=${encodeURIComponent(query.state)}` : ''}`);
}
