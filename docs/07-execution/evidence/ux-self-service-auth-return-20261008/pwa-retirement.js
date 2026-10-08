/* Replace sw.js only under a separately authorised release. Native lifecycle; no fetch handler. */
self.addEventListener('activate', event => event.waitUntil(caches.delete('bp-public-v1').then(() => self.registration.unregister())));
