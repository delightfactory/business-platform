import type { NextRequest } from 'next/server';
import { updateSession } from '@/lib/supabase/proxy';

export function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|sw\\.js$|offline\\.html$|manifest\\.webmanifest$|pwa/(?:offline\\.(?:css|js)|tokens\\.css|cairo-(?:400|600)\\.woff2|Cairo-OFL\\.txt)$|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
};
