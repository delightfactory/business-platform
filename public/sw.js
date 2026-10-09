/* Public fixed precache only. Asset byte integrity excludes private or rewritten responses. */
const CACHE = 'bp-public-v1';
const ASSETS = [
  [
    "/offline.html",
    "sha256-uoDFuxMmZdoUl9w+/iJH5/02p66bgS+nsurs8a8kqls="
  ],
  [
    "/pwa/offline.css",
    "sha256-NqlocxHgnM94p3aW3RWb9d55uw5y7+X/U7hPxvH0gNk="
  ],
  [
    "/pwa/offline.js",
    "sha256-LuPIkwoFRjQU8ABue2tIGkuF+s/pMKA+GnwMwnx2nfY="
  ],
  [
    "/pwa/tokens.css",
    "sha256-vg7L5Fq/+93TcZVj08kECySQrFUwro2FAiBabziWFw8="
  ],
  [
    "/pwa/alexandria-arabic-500-normal.woff2",
    "sha256-N29mhZ7TbYP7Q70cqLCom9Hr6IACsavDWRemuqYSY7s="
  ],
  [
    "/pwa/alexandria-latin-500-normal.woff2",
    "sha256-bF8Y62xoAGETXZ1BfRPY8ULtwHee5sdjW16F62ZLnN4="
  ],
  [
    "/pwa/alexandria-arabic-600-normal.woff2",
    "sha256-c6qlXzo91P1SSnx+44NVwU3nT4/OnelFCFYBJQaiIM8="
  ],
  [
    "/pwa/alexandria-latin-600-normal.woff2",
    "sha256-idqFVGmMoJiEtTpGW+zoTEX6yZzgwiAmcjKi9p0ji/A="
  ],
  [
    "/pwa/ibm-plex-sans-arabic-arabic-400-normal.woff2",
    "sha256-YBDn/Q3OXVJ1g5UXUHKMvjyJXvvRaqD4CauMgkh4ydg="
  ],
  [
    "/pwa/ibm-plex-sans-arabic-latin-400-normal.woff2",
    "sha256-ntjcsC5sckbeTBIClfr6Oae7cwhfSVGkUkoH3JEQafI="
  ],
  [
    "/pwa/ibm-plex-sans-arabic-arabic-500-normal.woff2",
    "sha256-kK72T+qXlPIyMy6QfUWBCrJo0aEXITQAJeuios2zbVw="
  ],
  [
    "/pwa/ibm-plex-sans-arabic-latin-500-normal.woff2",
    "sha256-vmo7LjfzrWeqgipVzjVtKMQWMxyXUwoewHbCEYJAyi0="
  ],
  [
    "/pwa/ibm-plex-sans-arabic-arabic-600-normal.woff2",
    "sha256-FnNKWtsnsPNj5WbLvqzsSA2g3AuqGcjwBTJRwuK8Dqw="
  ],
  [
    "/pwa/ibm-plex-sans-arabic-latin-600-normal.woff2",
    "sha256-Y/R1cnHkA/e67Ahi8oT/qkVg6mCWup/ovG5YXKZW5yQ="
  ],
  [
    "/pwa/ibm-plex-sans-arabic-arabic-700-normal.woff2",
    "sha256-BMcwtCknMcztrdW9gHVhJDZK5JI4lRRdnNex8o5EPeE="
  ],
  [
    "/pwa/ibm-plex-sans-arabic-latin-700-normal.woff2",
    "sha256-ri1Z+R7Pn37SeeSh/BqdqBcPsM5bkVKReo91kDP1d3w="
  ],
  [
    "/pwa/icon-192.png",
    "sha256-Xb5ujLqQPOQJP4P2MYhlU6O6WY+nVnakXG7eqsP/BmA="
  ],
  [
    "/pwa/icon-512.png",
    "sha256-FlSmvehA8Q6ldLI9soUBLQaS1Tu+3UlXVevmG2v1UKk="
  ],
  [
    "/pwa/maskable-512.png",
    "sha256-lk9zF+rd7CTVPkoFd8oGdqM8h6ji1L0FvwgNyyykgWc="
  ]
];
const urls = new Set(ASSETS.map(([pathname]) => new URL(pathname, self.location.origin).href));
const STATIC_CACHE = 'bp-static-v1';
const STATIC_LIMIT = 32;
const STATIC_BYTES = 2 * 1024 * 1024;
let staticWrites = Promise.resolve();
let pendingStaticWrites = 0;

function staticKind(request, url) {
  if (request.mode === 'navigate' || url.search || url.hash) return null;
  const pathname = url.pathname.replace(/%5b/ig, '[').replace(/%5d/ig, ']');
  if (!/^\/_next\/static\/(?:chunks|css|media)\//.test(pathname)) return null;
  const segments = pathname.split('/').slice(4);
  if (segments.some(part => !part || part === '.' || part === '..' || !/^[A-Za-z0-9_[\].-]+$/.test(part))) return null;
  if (!/(?:^|-)[a-f0-9]{8,}(?:[-.]|$)/.test(segments.at(-1))) return null;
  return /\.(js|css|woff2)$/.exec(pathname)?.[1] ?? null;
}

function publicStaticResponse(response, request, kind) {
  const contentType = response.headers.get('Content-Type')?.split(';')[0].trim().toLowerCase();
  const expected = kind === 'js' ? /^(?:text|application)\/(?:javascript|ecmascript)$/.test(contentType ?? '')
    : kind === 'css' ? contentType === 'text/css' : contentType === 'font/woff2';
  const policy = response.headers.get('Cache-Control')?.toLowerCase() ?? '';
  const vary = response.headers.get('Vary') ?? '';
  return response.status === 200 && !response.redirected && response.url === request.url && expected
    && /\bpublic\b/.test(policy) && /\bimmutable\b/.test(policy) && !/\b(?:private|no-store)\b/.test(policy)
    && !vary.split(',').some(value => /^(?:cookie|authorization|\*)$/i.test(value.trim()));
}

async function boundedBytes(response) {
  if (!response.body) return null;
  const reader = response.body.getReader(), chunks = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > STATIC_BYTES) { void reader.cancel().catch(() => {}); return null; }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    return bytes;
  } finally { reader.releaseLock(); }
}

function rememberStatic(request, response, kind) {
  if (!publicStaticResponse(response, request, kind) || pendingStaticWrites >= STATIC_LIMIT) return Promise.resolve();
  pendingStaticWrites++;
  const task = boundedBytes(response.clone()).then(bytes => {
    if (!bytes) return;
    staticWrites = staticWrites.then(async () => {
      const cache = await caches.open(STATIC_CACHE);
      const keys = await cache.keys();
      const others = keys.filter(key => key.url !== request.url);
      for (const oldest of others.slice(0, Math.max(0, others.length - STATIC_LIMIT + 1))) await cache.delete(oldest);
      await cache.put(request, new Response(bytes, { status: 200, headers: {
        'Content-Type': response.headers.get('Content-Type'), 'Cache-Control': response.headers.get('Cache-Control'),
      } }));
    }).catch(() => { /* Quota/storage failures cannot block this or later network responses. */ });
    return staticWrites;
  }).catch(() => {}).finally(() => { pendingStaticWrites--; });
  return task;
}
self.addEventListener('install', event => { event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS.map(([pathname, integrity]) => new Request(new URL(pathname, self.location.origin), { cache: 'reload', credentials: 'omit', integrity }))))); });
self.addEventListener('activate', event => { event.waitUntil(caches.open(CACHE).then(async cache => { const keys = await cache.keys(); await Promise.all(keys.filter(request => !urls.has(request.url)).map(request => cache.delete(request))); })); });
self.addEventListener('fetch', event => {
  const request = event.request, url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin || request.headers.has('Authorization') || request.headers.has('RSC') || request.headers.has('Range')) return;
  // Provider callbacks, APIs and exports retain native browser handling, including navigation downloads.
  if (url.pathname.startsWith('/api/') || /(?:^|\/)export(?:\/|$)|\.pdf$/i.test(url.pathname) || /(?:^|\/)callback(?:\/|$)/.test(url.pathname)) return;
  const kind = staticKind(request, url);
  if (kind) {
    let write = Promise.resolve();
    const load = (async () => {
      try { const cached = await (await caches.open(STATIC_CACHE)).match(request); if (cached) return cached; } catch { /* Public network response remains authoritative. */ }
      const publicRequest = new Request(request, { credentials: 'omit' });
      const response = await fetch(publicRequest);
      write = rememberStatic(publicRequest, response, kind);
      return response;
    })();
    event.respondWith(load);
    event.waitUntil(load.then(() => write).catch(() => {}));
    return;
  }
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(async () => {
      try { const cached = await (await caches.open(CACHE)).match('/offline.html'); if (cached) return cached; } catch { /* Cache failure cannot masquerade as a successful operation. */ }
      return new Response('تعذّر الوصول إلى المنصة. تحقق من نتيجة أي عملية لم تتأكد قبل تكرارها.', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' } });
    })); return;
  }
  if (url.search || url.hash || !urls.has(url.href)) return;
  event.respondWith((async () => { try { const cached = await (await caches.open(CACHE)).match(request); if (cached) return cached; } catch { /* Online public assets remain available without CacheStorage. */ } return fetch(request); })());
});
