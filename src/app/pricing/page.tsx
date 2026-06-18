'use client';

import Link from 'next/link';
import React from 'react';

const plans = [
  {
    id: 'basic',
    name: 'Basic',
    price: '$49.99/yr',
    popular: false,
    tagline: 'Best for one personal Windows PC.',
    features: [
      'One license = One PC',
      'For personal, non-commercial use only',
      'Full access to all repair tools',
      'Standard email support within 2 business days',
      '1 year of updates included',
    ],
  },
  {
    id: 'pro',
    name: 'Pro',
    price: '$199.99/yr',
    popular: true,
    tagline: 'Best for repair techs and paid service work.',
    features: [
      'One license = One PC',
      'Commercial use allowed for paid repair work',
      'Full access to all repair tools',
      'Priority email support within 1 business day',
      'Help with tricky cases by email',
      '1 year of updates included',
    ],
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    price: '$499.99/yr',
    popular: false,
    tagline: 'Best for shops that need a named support lane.',
    features: [
      'One license = One PC',
      'Business/commercial use included',
      'Full access to all repair tools',
      'Named support contact',
      'Remote assistance available',
      '1 year of updates included',
    ],
  },
  {
    id: 'lifetime',
    name: 'Lifetime',
    price: '$699 one-time',
    popular: false,
    tagline: 'Best for one machine with no yearly renewal.',
    features: [
      'One license = One PC',
      'Lifetime updates for supported Windows versions',
      'Personal or commercial use',
      'Priority email support',
      'No recurring fees for this machine',
      '30 day money back guarantee',
    ],
  },
] as const;

type PlanId = (typeof plans)[number]['id'];

const allPlansInclude = [
  'One license per machine (1:1)',
  'Automatic updates while active',
  '30-day money-back guarantee',
  'Secure license activation',
  'Private download link sent by email',
  'Clear Windows install/SmartScreen instructions',
];

export default function Pricing() {
  const [email, setEmail] = React.useState('');
  const [loadingPlan, setLoadingPlan] = React.useState<PlanId | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  async function startCheckout(plan: PlanId) {
    try {
      setError(null);
      setLoadingPlan(plan);

      const normalizedEmail = email.trim().toLowerCase();
      if (!normalizedEmail || !normalizedEmail.includes('@')) {
        throw new Error('Enter your email first so RescuePC can send your license and private download link.');
      }

      const res = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          plan,
          customerEmail: normalizedEmail,
          tenantId: 'default',
        }),
      });

      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        throw new Error(data.error || data.message || 'Unable to start checkout.');
      }

      const checkoutUrl = data.checkoutUrl || data.url;
      if (!checkoutUrl) {
        throw new Error('Checkout did not return a Stripe URL. Please contact support@rescuepcrepairs.com.');
      }

      window.location.href = checkoutUrl;
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Unable to start checkout. Please try again.');
      setLoadingPlan(null);
    }
  }

  return (
    <main className="min-h-screen bg-slate-50 py-16">
      <div className="mx-auto max-w-7xl px-6">
        <div className="mx-auto mb-12 max-w-3xl text-center">
          <p className="mb-3 text-sm font-semibold uppercase tracking-[0.2em] text-blue-600">
            Buy → Download → Repair
          </p>
          <h1 className="text-4xl font-bold text-slate-900 md:text-5xl">
            Choose a RescuePC license
          </h1>
          <p className="mt-4 text-lg text-slate-600">
            One license per machine. Every plan includes the full Windows repair toolkit, a private download link, activation instructions, and support.
          </p>
        </div>

        <div className="mx-auto mb-10 max-w-2xl rounded-2xl border border-blue-200 bg-white p-5 shadow-sm">
          <label className="block text-sm font-semibold text-slate-900" htmlFor="checkout-email">
            Email for license and download delivery
          </label>
          <div className="mt-3 flex flex-col gap-3 sm:flex-row">
            <input
              id="checkout-email"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="you@example.com"
              className="min-w-0 flex-1 rounded-xl border border-slate-300 px-4 py-3 outline-none ring-blue-500 transition focus:ring-2"
            />
            <Link
              href="/install"
              className="rounded-xl border border-slate-300 px-4 py-3 text-center text-sm font-semibold text-slate-700 hover:bg-slate-100"
            >
              Installation steps
            </Link>
          </div>
          <p className="mt-3 text-sm text-slate-500">
            Use the same email at Stripe checkout. This keeps license generation and download delivery clean.
          </p>
          {error && (
            <p className="mt-4 rounded-xl border border-red-200 bg-red-50 p-3 text-sm text-red-700">
              {error}
            </p>
          )}
        </div>

        <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-4">
          {plans.map((plan) => (
            <div
              key={plan.id}
              className={`relative rounded-2xl border-2 bg-white p-8 shadow-sm ${
                plan.popular ? 'scale-[1.02] border-blue-500 shadow-xl' : 'border-slate-200'
              }`}
            >
              {plan.popular && (
                <span className="absolute -top-4 left-1/2 -translate-x-1/2 rounded-full bg-blue-600 px-3 py-1 text-sm font-semibold text-white shadow-md">
                  Most Popular
                </span>
              )}

              <div className="text-center">
                <h2 className="text-2xl font-bold text-slate-900">{plan.name}</h2>
                <p className="mt-2 text-3xl font-bold text-blue-600">{plan.price}</p>
                <p className="mt-3 text-sm text-slate-500">{plan.tagline}</p>
              </div>

              <ul className="mt-6 space-y-3 text-left">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex gap-3">
                    <span className="text-green-500">✓</span>
                    <span className="text-sm text-slate-600">{feature}</span>
                  </li>
                ))}
              </ul>

              <button
                type="button"
                onClick={() => startCheckout(plan.id)}
                disabled={!!loadingPlan}
                className={`mt-8 w-full rounded-xl px-6 py-3 font-semibold transition-colors ${
                  plan.popular
                    ? 'bg-blue-600 text-white hover:bg-blue-700'
                    : 'bg-slate-900 text-white hover:bg-slate-800'
                } ${loadingPlan === plan.id ? 'cursor-not-allowed opacity-70' : ''}`}
              >
                {loadingPlan === plan.id ? 'Opening checkout...' : `Buy ${plan.name}`}
              </button>
            </div>
          ))}
        </div>

        <div className="mx-auto mt-16 max-w-4xl rounded-xl border border-slate-200 bg-white p-8">
          <h3 className="text-center text-2xl font-bold text-slate-900">All plans include</h3>
          <div className="mt-6 grid gap-4 text-left md:grid-cols-2">
            {allPlansInclude.map((item) => (
              <div key={item} className="flex items-center gap-3">
                <span className="text-xl text-green-500">✓</span>
                <span className="text-slate-700">{item}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-12 text-center">
          <p className="text-slate-600">
            🔒 Secured by Stripe • Instant license delivery • 30-day money-back guarantee
          </p>
          <p className="mt-3 text-sm text-slate-500">
            Questions? Email <a className="text-blue-600 hover:underline" href="mailto:support@rescuepcrepairs.com">support@rescuepcrepairs.com</a>
          </p>
        </div>
      </div>
    </main>
  );
}
