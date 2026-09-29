import type { Metadata } from "next";
import type { ReactNode } from "react";
import "@fontsource/cairo/400.css";
import "@fontsource/cairo/600.css";
import "@fontsource/cairo/700.css";
import "./globals.css";
import "./workspace.css";

export const metadata: Metadata = {
  title: "منصة الأعمال | أساس التطوير",
  description: "الأساس التقني لمنصة الأعمال قيد التطوير.",
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="ar" dir="rtl">
      <body>{children}</body>
    </html>
  );
}
