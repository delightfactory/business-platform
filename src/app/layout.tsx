import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import { cookies } from 'next/headers';
import { ThemeProvider } from '@/components/theme-preference';
import { themePreference } from '@/lib/theme';
import { PwaFoundation } from '@/components/pwa-foundation';
import brand from '@/lib/product-brand.json';
import "../styles/fonts.css";
import "./globals.css";
import "../components/ui/ui.css";
import "./workspace.css";

export const metadata: Metadata = {
  metadataBase: new URL('https://platform.delight-world.com'),
  title: { default: brand.title, template: `%s | ${brand.nameAr}` },
  applicationName: brand.title,
  description: `${brand.taglineAr} — إدارة الموظفين والحضور والإجازات والرواتب.`,
  appleWebApp: { capable: true, title: brand.nameAr, statusBarStyle: 'default' },
  icons: { icon: [{ url: '/brand/favicon-32.png', sizes: '32x32', type: 'image/png' }] },
  openGraph: { title: brand.title, description: brand.taglineAr, siteName: brand.title,
    locale: 'ar_EG', type: 'website', images: [{ url: '/brand/basher-social.png', width: 1200, height: 630, alt: brand.title }] },
  twitter: { card: 'summary_large_image', title: brand.title, description: brand.taglineAr, images: ['/brand/basher-social.png'] },
};

export const viewport: Viewport = {
  viewportFit: 'cover',
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#f2f3f1' },
    { media: '(prefers-color-scheme: dark)', color: '#0d1211' },
  ],
};

export default async function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  const preference = themePreference((await cookies()).get('bp-theme')?.value);
  return (
    <html lang="ar" dir="rtl" data-product="basher" data-theme={preference}>
      <body><ThemeProvider initialPreference={preference}><PwaFoundation />{children}</ThemeProvider></body>
    </html>
  );
}
