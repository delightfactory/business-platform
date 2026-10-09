import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

export function getSupabasePublicConfig() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  return url && key ? { url, key } : null;
}

export async function createSupabaseServerClient() {
  const config = getSupabasePublicConfig();
  if (!config) return null;
  const cookieStore = await cookies();
  // Local previews can reach their own API without a round trip through the
  // public phone tunnel. The browser still uses the public URL and anon key.
  return createServerClient(process.env.SUPABASE_INTERNAL_URL || config.url, config.key, {
    cookieOptions: process.env.SUPABASE_INTERNAL_URL
      ? { name: `sb-${new URL(config.url).hostname.split('.')[0]}-auth-token` }
      : undefined,
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          // Server Components cannot write cookies; the root proxy handles refresh writes.
        }
      },
    },
  });
}
