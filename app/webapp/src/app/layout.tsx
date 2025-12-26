import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Sample App - Next.js + C# API',
  description: 'Example application with CI/CD pipeline',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
