import { redirectLegacySetup } from '../companies/new/setup-links';
export const dynamic = 'force-dynamic';
export default async function LegacySetup({ searchParams }: { searchParams: Promise<{ key?: string; state?: string }> }) {
  return redirectLegacySetup('existing', searchParams);
}
