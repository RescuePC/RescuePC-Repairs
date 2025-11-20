import React from 'react';
import Link from "next/link";

export default function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-slate-900 text-slate-300">
      <div className="max-w-7xl mx-auto px-6 py-12">
        <div className="grid md:grid-cols-4 gap-8">
          <div>
            <h3 className="text-white font-bold text-lg mb-4">RescuePC Repairs</h3>
            <p className="text-sm">
              Windows repair toolkit with essential diagnostics, repair scripts, and performance tools.
            </p>
          </div>

          <div>
            <h4 className="text-white font-semibold mb-4">Product</h4>
            <ul className="space-y-2 text-sm">
              <li>
                <Link href="/pricing" className="hover:text-white transition-colors">
                  Pricing
                </Link>
              </li>
              <li>
                <Link href="/legal/eula" className="hover:text-white transition-colors">
                  License Agreement
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <h4 className="text-white font-semibold mb-4">Support</h4>
            <ul className="space-y-2 text-sm">
              <li>
                <a href="mailto:rescuepcrepairs@gmail.com" className="hover:text-white transition-colors">
                  rescuepcrepairs@gmail.com
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h4 className="text-white font-semibold mb-4">Legal</h4>
            <ul className="space-y-2 text-sm">
              <li>
                <Link href="/legal/eula" className="hover:text-white transition-colors">
                  End User License Agreement
                </Link>
              </li>
              <li>
                <Link href="/legal/license" className="hover:text-white transition-colors">
                  License
                </Link>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-8 pt-8 border-t border-slate-800 text-center text-sm">
          <p>&copy; {currentYear} RescuePC Repairs. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}

