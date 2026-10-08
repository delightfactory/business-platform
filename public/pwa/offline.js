/* Public recovery page only. No business payload, cookie write, storage or automatic retry. */
(() => {
  let preference = 'system';
  try {
    const match = document.cookie.match(/(?:^|;\s*)bp-theme=(light|dark|system)(?:;|$)/);
    if (match) preference = match[1];
  } catch { /* Unavailable preferences follow the OS via CSS. */ }
  document.documentElement.dataset.theme = preference;
  document.getElementById('retry')?.addEventListener('click', () => window.location.reload());
})();
