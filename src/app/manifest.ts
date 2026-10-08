import type { MetadataRoute } from 'next';

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: '/', name: 'منصة الأعمال', short_name: 'منصة الأعمال', lang: 'ar', dir: 'rtl',
    start_url: '/', scope: '/', display: 'standalone',
    background_color: '#f2f3f1', theme_color: '#0e6b5c',
    icons: [
      { src: '/pwa/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: '/pwa/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
      { src: '/pwa/maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
  };
}
