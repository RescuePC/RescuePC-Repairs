import React from 'react';
import Link from "next/link";

export default function Header() {
  return (
    <header className="bg-white border-b border-slate-200 sticky top-0 z-50 shadow-sm">
      <nav className="max-w-7xl mx-auto px-6 py-4">
        <div className="flex items-center justify-between">
          <Link href="/" className="flex items-center space-x-2">
            <span className="text-2xl font-bold text-blue-600">RescuePC</span>
            <span className="text-slate-600">Repairs</span>
          </Link>
          
          <div className="hidden md:flex items-center space-x-8">
            <Link href="/" className="text-slate-700 hover:text-blue-600 transition-colors">
              Home
            </Link>
            <Link href="/pricing" className="text-slate-700 hover:text-blue-600 transition-colors">
              Pricing
            </Link>
            <Link href="/legal/eula" className="text-slate-700 hover:text-blue-600 transition-colors">
              Legal
            </Link>
          </div>

          <Link
            href="/pricing"
            className="px-6 py-2 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700 transition-colors"
          >
            Get Started
          </Link>
        </div>
      </nav>
    </header>
  );
}

