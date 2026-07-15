import React from "react";
import "./globals.css";
import Header from "../components/Header";
import Footer from "../components/Footer";
import { rootMetadata } from "@/lib/seo";

export const metadata = rootMetadata;

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen flex flex-col">
        <Header />
        <div className="flex-grow">{children}</div>
        <Footer />
      </body>
    </html>
  );
}
