'use client';

import React from 'react';

const plans = [
  {
    name: "Basic",
    price: "$49.99/yr",
    popular: false,
    url: "https://buy.stripe.com/5kQfZggMacypcSl9wP08g05",
    features: [
      "One license = One PC",
      "For personal, non-commercial use only",
      "Full access to all repair tools",
      "Standard email support (2 business day response)",
      "1 year of updates included"
    ]
  },
  {
    name: "Pro",
    price: "$199.99/yr",
    popular: true,
    url: "https://buy.stripe.com/00wcN4dzY0PHaKdfVd08g04",
    features: [
      "One license = One PC",
      "Commercial use allowed (paid repair work)",
      "Full access to all repair tools",
      "Priority email support (1 business day response)",
      "Help with tricky cases by email",
      "1 year of updates included"
    ]
  },
  {
    name: "Enterprise",
    price: "$499.99/yr",
    popular: false,
    url: "https://buy.stripe.com/4gM8wO53s1TLaKd9wP08g02",
    features: [
      "One license = One PC",
      "Business/commercial use included",
      "Full access to all repair tools",
      "Named support contact",
      "Remote assistance available",
      "1 year of updates included"
    ]
  },
  {
    name: "Lifetime",
    price: "$699 one-time",
    popular: false,
    url: "https://buy.stripe.com/14A5kCeE28i92dH9wP08g06",
    features: [
      "One license = One PC",
      "Lifetime updates (for supported Windows versions)*",
      "Personal or commercial use",
      "Priority email support",
      "No recurring fees for this machine",
      "30 day money back guarantee"
    ]
  }
];

const allPlansInclude = [
  "One license per machine (1:1)",
  "Automatic updates while active",
  "30-day money-back guarantee",
  "Secure license activation",
  "English language support"
];

export default function Pricing() {
  const [loadingPlan, setLoadingPlan] = React.useState<string | null>(null);
  return (
    <main className="min-h-screen bg-slate-50 py-20">
      <div className="max-w-7xl mx-auto px-6">
        <div className="text-center mb-16">
          <h1 className="text-4xl md:text-5xl font-bold text-slate-900 mb-4">
            Choose Your Plan
          </h1>
          <p className="text-xl text-slate-600 max-w-3xl mx-auto">
            Simple, straightforward licensing - one license per machine. All plans include
            the full RescuePC repair toolkit. Choose the plan that matches your needs.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
          {plans.map(p => (
            <div key={p.name} className={`relative rounded-2xl border-2 p-8 ${p.popular ? 'border-blue-500 shadow-xl scale-105' : 'border-slate-200'} bg-white`}>
              {p.popular && (
                <span className="absolute -top-4 left-1/2 -translate-x-1/2 bg-blue-600 text-white text-sm font-semibold px-3 py-1 rounded-full shadow-md">
                  Most Popular
                </span>
              )}
              <div className="text-center">
                <h2 className="text-2xl font-bold text-slate-900">{p.name}</h2>
                <p className="mt-2 text-3xl font-bold text-blue-600">{p.price}</p>
                <ul className="mt-6 space-y-3 text-left">
                  {p.features.map((feature, index) => (
                    <li key={index} className="flex items-center">
                      <span className="text-green-500 mr-3">✓</span>
                      <span className="text-slate-600">{feature}</span>
                    </li>
                  ))}
                </ul>
                <button
                  onClick={(e) => {
                    e.preventDefault();
                    setLoadingPlan(p.name);
                    window.location.href = p.url;
                  }}
                  disabled={!!loadingPlan}
                  className={`mt-8 w-full px-6 py-3 rounded-xl font-semibold transition-colors ${
                    p.popular
                      ? 'bg-blue-600 text-white hover:bg-blue-700'
                      : 'bg-slate-900 text-white hover:bg-slate-800'
                  } ${loadingPlan === p.name ? 'opacity-70 cursor-not-allowed' : ''}`}
                >
                  {loadingPlan === p.name ? 'Processing...' : 'Get Started'}
                </button>
              </div>
            </div>
          ))}
        </div>

        <div className="mt-16 text-center">
          <div className="bg-white rounded-xl p-8 border border-slate-200 max-w-4xl mx-auto">
            <h3 className="text-2xl font-bold text-slate-900 mb-4">All Plans Include</h3>
            <div className="grid md:grid-cols-2 gap-6 text-left">
              {allPlansInclude.map((item, index) => (
                <div key={index} className="flex items-center">
                  <span className="text-green-500 mr-3 text-xl">✓</span>
                  <span>{item}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="mt-16 text-center">
          <p className="text-slate-600 mb-4">
            🔒 Secured by Stripe • Instant license delivery • 30-day money-back guarantee
          </p>
          <p className="text-sm text-slate-500 mb-2">
            *Lifetime = supported product lifetime for current Windows version
          </p>
          <p className="text-sm text-slate-500">
            Questions? Contact our support team at rescuepcrepairs@gmail.com
          </p>
        </div>
      </div>
    </main>
  );
}