'use client';

import React, { useState } from 'react';
import Link from "next/link";

// Memoize features to prevent unnecessary re-renders
const features = [
  {
    title: "System Health Checks",
    description: "Runs focused checks on key Windows services and settings to detect common issues before they cause problems.",
    icon: "🔍"
  },
  {
    title: "Automated Repairs",
    description: "One-click repairs for network problems, broken Windows services, and audio issues using proven PowerShell routines.",
    icon: "🔧"
  },
  {
    title: "Performance Optimization",
    description: "Cleanup and optimization scripts to remove junk files, trim startup items, and improve responsiveness.",
    icon: "⚡"
  },
  {
    title: "Network Repair",
    description: "Fix common connectivity issues with DNS, adapters, and Windows networking components.",
    icon: "🌐"
  },
  {
    title: "Audio Repair",
    description: "Repair Windows audio services and common sound problems without reinstalling everything.",
    icon: "🎧"
  },
  {
    title: "Backup & Security Tools",
    description: "Backup important user folders and run Windows Defender deep scans plus a security status report.",
    icon: "🛡️"
  }
] as const;

export default function Home() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleBuyNow() {
    try {
      setLoading(true);
      setError(null);

      // Default to 'basic' plan
      const plan = 'basic'; 
      
      // Get the price ID for the basic plan from config
      const priceId = process.env.STRIPE_BASIC_PRICE_ID;
      
      if (!priceId || priceId === 'price_your_basic_price_id') {
        throw new Error("Stripe price ID not configured. Please update the STRIPE_BASIC_PRICE_ID in your .env file with your actual Stripe price ID.");
      }
      
      const res = await fetch("/api/checkout", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          plan: plan,
          priceId: priceId,
          customerEmail: "", // You might want to collect this from the user
        }),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error || "Failed to start checkout");
      }

      const data = await res.json();
      if (!data.url) {
        throw new Error("Stripe did not return a checkout URL");
      }

      window.location.href = data.url;
    } catch (err: any) {
      console.error(err);
      setError(err.message ?? "Something went wrong");
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-blue-600 via-blue-700 to-blue-800 text-white py-20">
        <div className="max-w-7xl mx-auto px-6">
          <div className="text-center max-w-4xl mx-auto">
            <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold mb-6">
              Automated Windows Repair Software
            </h1>
            <p className="text-lg md:text-xl text-blue-100 mb-8">
              One launcher for scripted diagnostics, driver checks, and repair workflows. Licensed per machine with annual or lifetime plans.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link
                href="/pricing"
                className="px-6 py-3 sm:px-8 sm:py-4 bg-white text-blue-600 rounded-lg sm:rounded-xl font-semibold text-base sm:text-lg hover:bg-blue-50 transition-colors shadow-lg"
              >
                View plans & download
              </Link>
            </div>
            {error && (
              <p className="mt-4 text-sm text-red-300">
                {error}
              </p>
            )}
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-6">
          <div className="text-center mb-12">
            <h2 className="text-3xl md:text-4xl font-bold text-slate-900 mb-4">
              Everything You Need to Repair Windows
            </h2>
            <p className="text-lg text-slate-600 max-w-3xl mx-auto">
              Comprehensive tools for diagnosing, repairing, and optimizing Windows systems
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {features.map((feature, index) => (
              <div key={index} className="bg-slate-50 rounded-xl p-6 border border-slate-200 hover:shadow-md transition-shadow">
                <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center mb-3">
                  <span className="text-xl">{feature.icon}</span>
                </div>
                <h3 className="text-lg font-bold text-slate-900 mb-2">{feature.title}</h3>
                <p className="text-slate-600 text-sm">
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-16 bg-gradient-to-br from-blue-600 to-blue-700 text-white">
        <div className="max-w-4xl mx-auto px-6 text-center">
          <h2 className="text-3xl font-bold mb-4">Ready to optimize your PC?</h2>
          <p className="text-lg mb-8 max-w-2xl mx-auto">
            Get started with RescuePC Repairs today and experience the difference.
          </p>
          <button
            onClick={handleBuyNow}
            disabled={loading}
            className="bg-white text-blue-600 hover:bg-blue-50 font-semibold py-3 px-8 rounded-lg text-lg transition-all transform hover:scale-105 disabled:opacity-50 disabled:transform-none"
            aria-label="Get started with RescuePC Repairs"
          >
            {loading ? 'Processing...' : 'Get Started Now'}
          </button>
          {error && (
            <p className="mt-4 text-red-200">
              {error}
            </p>
          )}
        </div>
      </section>
    </div>
  );
}
