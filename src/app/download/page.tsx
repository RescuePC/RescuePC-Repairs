'use client';

import { useState } from 'react';

export default function DownloadPage() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleBuyNow() {
    try {
      setLoading(true);
      setError(null);

      const res = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ planId: 'basic' })
      });

      if (!res.ok) {
        const error = await res.json().catch(() => ({}));
        throw new Error(error.message || 'Failed to start checkout');
      }

      const { checkoutUrl } = await res.json();
      
      if (!checkoutUrl) {
        throw new Error('No checkout URL received');
      }
      
      // Redirect to Stripe Checkout
      window.location.href = checkoutUrl;
      
    } catch (err: any) {
      console.error('Buy now error:', err);
      setError(err.message || 'Failed to start checkout. Please try again.');
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen flex items-center justify-center bg-slate-950 text-slate-50 px-4">
      <div className="max-w-xl w-full rounded-2xl border border-slate-800 bg-slate-900/70 p-6 shadow-lg space-y-4">
        <h1 className="text-2xl font-semibold">
          Get RescuePC Repairs - Basic Plan
        </h1>

        <p className="text-sm text-slate-300">
          To download the RescuePC desktop tool you need an active paid license.
          Click <strong>Buy now</strong> to get our cheapest Basic plan via secure Stripe checkout. After payment
          your license key and download link are emailed automatically.
        </p>

        {error && (
          <p className="text-sm text-red-400">
            {error}
          </p>
        )}

        <button
          type="button"
          onClick={handleBuyNow}
          disabled={loading}
          className="w-full rounded-xl py-2 text-sm font-medium bg-emerald-500 hover:bg-emerald-400 disabled:opacity-60 disabled:cursor-not-allowed"
        >
          {loading ? "Redirecting to checkout..." : "Buy now"}
        </button>

        <p className="text-xs text-slate-500">
          Already purchased? Check your email for your license key and private download
          link. The app also will not run without a valid license, even if someone
          somehow gets a copy.
        </p>
      </div>
    </main>
  );
}
