import type { MetadataRoute } from 'next';
import brand from '@/lib/product-brand.json';

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: '/', name: brand.title, short_name: brand.nameAr, description: brand.taglineAr, lang: 'ar', dir: 'rtl',
    start_url: '/', scope: '/', display: 'standalone',
    background_color: '#ffffff', theme_color: brand.navy,
    icons: [
      { src: '/pwa/basher-icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: '/pwa/basher-icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
      { src: '/pwa/basher-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
  };
}
