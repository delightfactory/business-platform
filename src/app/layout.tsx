import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import { cookies } from 'next/headers';
import { ThemeProvider } from '@/components/theme-preference';
import { themePreference } from '@/lib/theme';
import "@fontsource/cairo/400.css";
import "@fontsource/cairo/600.css";
import "@fontsource/cairo/700.css";
import "./globals.css";
import "./workspace.css";

export const metadata: Metadata = {
  title: "منصة الأعمال | أساس التطوير",
  description: "الأساس التقني لمنصة الأعمال قيد التطوير.",
};

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#f2f3f1' },
    { media: '(prefers-color-scheme: dark)', color: '#0d1211' },
  ],
};

export default async function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  const preference = themePreference((await cookies()).get('bp-theme')?.value);
  return (
    <html lang="ar" dir="rtl" data-theme={preference}>
      <body><ThemeProvider initialPreference={preference}>{children}</ThemeProvider></body>
    </html>
  );
}
