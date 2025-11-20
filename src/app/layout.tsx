import React from 'react';
import type { Metadata } from "next";
import "./globals.css";
import Header from "../components/Header";
import Footer from "../components/Footer";

export const metadata: Metadata = {
  title: "RescuePC Repairs - Professional Windows Repair Toolkit",
  description: "Automated diagnostics, driver management, security scanning, and system optimization for Windows. Professional repair tools with AI-powered diagnostics.",
  keywords: ["Windows repair", "system diagnostics", "driver management", "malware removal", "PC optimization"],
  authors: [{ name: "RescuePC Repairs" }],
  openGraph: {
    title: "RescuePC Repairs - Professional Windows Repair Toolkit",
    description: "Automated diagnostics, driver management, security scanning, and system optimization for Windows.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen flex flex-col">
        <Header />
        <main className="flex-grow">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
