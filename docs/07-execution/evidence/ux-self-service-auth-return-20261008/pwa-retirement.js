/* Replace sw.js only under a separately authorised release. Native lifecycle; no fetch handler. */
self.addEventListener('activate', event => event.waitUntil(Promise.all([
  caches.delete('bp-public-v1'), caches.delete('bp-static-v1'),
]).then(() => self.registration.unregister())));
