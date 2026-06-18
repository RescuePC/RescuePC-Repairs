'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';

const plans = [
  { id: 'basic', name: 'Basic', price: '$49.99/yr', bestFor: 'Home users and one personal PC' },
  { id: 'pro', name: 'Pro', price: '$199.99/yr', bestFor: 'Repair techs and paid service work' },
  { id: 'lifetime', name: 'Lifetime', price: '$699 once', bestFor: 'One machine, no yearly renewal' },
] as const;

type PlanId = (typeof plans)[number]['id'];

export default function DownloadPage() {
  const [email, setEmail] = useState('');
  const [selectedPlan, setSelectedPlan] = useState<PlanId>('basic');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const selectedPlanLabel = useMemo(
    () => plans.find((plan) => plan.id === selectedPlan)?.name ?? 'Basic',
    [selectedPlan]
  );

  async function handleBuyNow() {
    try {
      setLoading(true);
      setError(null);

      const normalizedEmail = email.trim().toLowerCase();
      if (!normalizedEmail || !normalizedEmail.includes('@')) {
        throw new Error('Enter the email address where you want your license and download link sent.');
      }

      const res = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          plan: selectedPlan,
          customerEmail: normalizedEmail,
          tenantId: 'default',
        }),
      });

      const data = await res.json().catch(() => ({}));

      if (!res.ok) {
        throw new Error(data.error || data.message || 'Failed to start secure checkout.');
      }

      const checkoutUrl = data.checkoutUrl || data.url;
      if (!checkoutUrl) {
        throw new Error('Checkout did not return a Stripe URL. Please contact support@rescuepcrepairs.com.');
      }

      window.location.href = checkoutUrl;
    } catch (err: unknown) {
      console.error('Buy now error:', err);
      setError(err instanceof Error ? err.message : 'Failed to start checkout. Please try again.');
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="mx-auto grid max-w-6xl gap-10 px-6 py-16 lg:grid-cols-[1.1fr_0.9fr] lg:py-24">
        <div className="space-y-8">
          <div className="inline-flex rounded-full border border-emerald-400/30 bg-emerald-400/10 px-4 py-2 text-sm font-medium text-emerald-200">
            Windows repair toolkit • Secure checkout • Instant license email
          </div>

          <div className="space-y-5">
            <h1 className="text-4xl font-bold tracking-tight md:text-6xl">
              Download RescuePC Repairs without the guesswork.
            </h1>
            <p className="max-w-2xl text-lg text-slate-300">
              Buy a license, receive your private download link by email, extract the ZIP, approve the Windows prompts, and launch the repair toolkit. No scavenger hunt. No mystery steps.
            </p>
          </div>

          <div className="grid gap-4 sm:grid-cols-3">
            {[
              ['1', 'Buy securely', 'Stripe handles payment and receipts.'],
              ['2', 'Download safely', 'Your license email includes the private download link.'],
              ['3', 'Run confidently', 'Follow the SmartScreen prompts for the signed RescuePC tools.'],
            ].map(([number, title, body]) => (
              <div key={number} className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
                <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-full bg-blue-500 text-sm font-bold text-white">
                  {number}
                </div>
                <h2 className="font-semibold text-white">{title}</h2>
                <p className="mt-2 text-sm text-slate-400">{body}</p>
              </div>
            ))}
          </div>

          <div className="rounded-2xl border border-amber-400/30 bg-amber-400/10 p-5 text-sm text-amber-100">
            <strong>Windows SmartScreen note:</strong> On first launch, Windows may ask you to approve <code>RescuePCRepairs.exe</code> and the helper <code>runner.exe</code> separately. Click <strong>More info</strong> → <strong>Run anyway</strong> only if the publisher/file name matches RescuePC and you downloaded it from rescuepcrepairs.com.
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900 p-6 shadow-2xl">
          <div className="mb-6">
            <h2 className="text-2xl font-bold">Buy and get your download link</h2>
            <p className="mt-2 text-sm text-slate-400">
              Use the same email at checkout. That is where your license key and download link are sent.
            </p>
          </div>

          <label className="block text-sm font-medium text-slate-200" htmlFor="download-email">
            Email for license delivery
          </label>
          <input
            id="download-email"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            placeholder="you@example.com"
            className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-white outline-none ring-blue-500 transition focus:ring-2"
          />

          <div className="mt-6 space-y-3">
            <p className="text-sm font-medium text-slate-200">Choose plan</p>
            {plans.map((plan) => (
              <button
                key={plan.id}
                type="button"
                onClick={() => setSelectedPlan(plan.id)}
                className={`w-full rounded-2xl border p-4 text-left transition ${
                  selectedPlan === plan.id
                    ? 'border-blue-400 bg-blue-500/15'
                    : 'border-slate-800 bg-slate-950 hover:border-slate-600'
                }`}
              >
                <div className="flex items-center justify-between gap-4">
                  <span className="font-semibold">{plan.name}</span>
                  <span className="text-sm text-blue-200">{plan.price}</span>
                </div>
                <p className="mt-1 text-sm text-slate-400">{plan.bestFor}</p>
              </button>
            ))}
          </div>

          {error && (
            <p className="mt-5 rounded-xl border border-red-400/30 bg-red-500/10 p-3 text-sm text-red-200">
              {error}
            </p>
          )}

          <button
            type="button"
            onClick={handleBuyNow}
            disabled={loading}
            className="mt-6 w-full rounded-xl bg-emerald-500 px-6 py-4 text-base font-bold text-slate-950 transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading ? 'Opening secure checkout...' : `Buy ${selectedPlanLabel} and download`}
          </button>

          <div className="mt-5 flex flex-col gap-2 text-sm text-slate-400 sm:flex-row sm:items-center sm:justify-between">
            <Link href="/pricing" className="text-blue-300 hover:text-blue-200">
              Compare all plans
            </Link>
            <Link href="/install" className="text-blue-300 hover:text-blue-200">
              See install steps
            </Link>
          </div>
        </div>
      </section>
    </main>
  );
}
