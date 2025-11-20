/* eslint-disable react/no-unescaped-entities */

const overview = [
  {
    title: "License Types",
    items: [
      "Standard (per-seat) license for technicians and MSP teams.",
      "Owner Lifetime license reserved for RescuePC internal operations.",
      "Tenant scoped licenses that include tenantId metadata for multi-org deployments.",
    ],
  },
  {
    title: "Activation",
    items: [
      "Each license key is tied to an email address and tenant.",
      "Activation requires the RescuePC Repairs launcher to call /api/verify-license over HTTPS.",
      "Offline caching may be used for 72 hours after a successful verification.",
    ],
  },
  {
    title: "Restrictions",
    items: [
      "No resale, sublicensing, or hosting the Toolkit as a public service.",
      "No tampering with verification endpoints or modifying signed PowerShell scripts.",
      "No sharing of Owner Lifetime license credentials in production machines.",
    ],
  },
  {
    title: "Compliance",
    items: [
      "All usage is subject to the EULA and the SaaS Terms of Service.",
      "Enterprises must maintain audit records of which technicians received keys.",
      "Violations trigger immediate revocation through the licensing API.",
    ],
  },
];

export const metadata = {
  title: "License Terms | RescuePC Repairs",
  description: "Licensing overview, activation rules, and compliance policy for the RescuePC Repairs Toolkit.",
};

export default function LicensePage() {
  return (
    <main className="mx-auto max-w-4xl px-6 py-16 text-slate-900">
      <header className="mb-10">
        <p className="text-xs uppercase tracking-[0.35em] text-slate-500">Legal</p>
        <h1 className="mt-2 text-4xl font-bold">License Terms</h1>
        <p className="mt-3 text-slate-600">Effective date: November 2025</p>
      </header>

      <article className="space-y-8 rounded-2xl border border-slate-200 bg-white p-8 shadow-sm">
        <section>
          <p className="text-sm font-semibold text-amber-600">SUMMARY</p>
          <p className="mt-2 text-lg leading-relaxed text-slate-700">
            RescuePC Repairs licenses are issued per tenant and per technician. By downloading, installing, or activating the Toolkit you agree
            to follow the rules below and the End User License Agreement. Licenses may be revoked for misuse without refund.
          </p>
        </section>

        {overview.map((block) => (
          <section key={block.title}>
            <h2 className="text-2xl font-semibold">{block.title}</h2>
            <ul className="mt-3 list-disc space-y-2 pl-5 text-slate-700">
              {block.items.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </section>
        ))}

        <section className="space-y-3">
          <h2 className="text-2xl font-semibold">Support & Questions</h2>
          <p className="text-slate-700">
            Submit licensing questions to legal@rescuepcrepairs.com. Provide your tenantId, customer email, and license key prefix (first 8
            characters). Never send a full key over email.
          </p>
        </section>

        <section className="border-t border-slate-200 pt-6 text-sm text-slate-600">
          <p>
            © {new Date().getFullYear()} RescuePC Repairs. All rights reserved. Licenses are governed by U.S. law and enforced through the
            RescuePC SaaS platform.
          </p>
        </section>
      </article>
    </main>
  );
}
