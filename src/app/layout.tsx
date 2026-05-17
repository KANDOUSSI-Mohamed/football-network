import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Football Network",
  description: "Le réseau professionnel mondial du football"
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
