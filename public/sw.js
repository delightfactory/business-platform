/* Public fixed precache only. Asset byte integrity excludes private or rewritten responses. */
const CACHE = 'bp-public-v1';
const ASSETS = [
  [
    "/offline.html",
    "sha256-uoDFuxMmZdoUl9w+/iJH5/02p66bgS+nsurs8a8kqls="
  ],
  [
    "/pwa/offline.css",
    "sha256-CDgKAy4B+y/Fx5Rz+zRMnCdFCUVepyx8N8sr9zbGnlQ="
  ],
  [
    "/pwa/offline.js",
    "sha256-LuPIkwoFRjQU8ABue2tIGkuF+s/pMKA+GnwMwnx2nfY="
  ],
  [
    "/pwa/tokens.css",
    "sha256-k6RXsxC4GYm+rx3veypB1rlRB6RvqCa/Nsrvy7t+AdI="
  ],
  [
    "/pwa/cairo-400.woff2",
    "sha256-GzaUX19qPR/tN4OZm4h9DFbP1mpBoEISooqnmrvf8OE="
  ],
  [
    "/pwa/cairo-600.woff2",
    "sha256-YhkJ0uTIcg0686dAKFVpVtNDuqpb5IxHoK1AZgf8ZRU="
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
self.addEventListener('install', event => { event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS.map(([pathname, integrity]) => new Request(new URL(pathname, self.location.origin), { cache: 'reload', credentials: 'omit', integrity }))))); });
self.addEventListener('activate', event => { event.waitUntil(caches.open(CACHE).then(async cache => { const keys = await cache.keys(); await Promise.all(keys.filter(request => !urls.has(request.url)).map(request => cache.delete(request))); })); });
self.addEventListener('fetch', event => {
  const request = event.request, url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin || request.headers.has('Authorization') || request.headers.has('RSC') || request.headers.has('Range')) return;
  // Provider callbacks, APIs and exports retain native browser handling, including navigation downloads.
  if (url.pathname.startsWith('/api/') || /(?:^|\/)export(?:\/|$)|\.pdf$/i.test(url.pathname) || /(?:^|\/)callback(?:\/|$)/.test(url.pathname)) return;
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(async () => {
      try { const cached = await (await caches.open(CACHE)).match('/offline.html'); if (cached) return cached; } catch { /* Cache failure cannot masquerade as a successful operation. */ }
      return new Response('تعذّر الوصول إلى المنصة. تحقق من نتيجة أي عملية لم تتأكد قبل تكرارها.', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' } });
    })); return;
  }
  if (url.search || url.hash || !urls.has(url.href)) return;
  event.respondWith((async () => { try { const cached = await (await caches.open(CACHE)).match(request); if (cached) return cached; } catch { /* Online public assets remain available without CacheStorage. */ } return fetch(request); })());
});
