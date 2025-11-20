/* eslint-disable react/no-unescaped-entities */

const sections = [
  {
    title: "1. Grant of License",
    subtitle: "1.1 License Grant",
    items: [
      "RescuePC Repairs grants you a non-exclusive, non-transferable license to use the Toolkit as delivered.",
      "You may operate the Software on any compatible Windows system you directly own." ,
      "This license is tied to the physical media or installer that delivered the Software.",
      "Redistribution is prohibited unless you have written authorization from RescuePC Repairs.",
      "Copies may only be created for personal backup purposes." ,
    ],
  },
  {
    title: "2. Copyright and Ownership",
    items: [
      "All intellectual-property rights remain with RescuePC Repairs.",
      "No ownership stake transfers to you when purchasing access to the Software.",
      "All rights not expressly granted remain reserved by the Company.",
    ],
  },
  {
    title: "3. Restrictions",
    subtitle: "3.1 You may not",
    items: [
      "Reverse engineer, decompile, or disassemble the Software unless permitted by law.",
      "Rent, lease, lend, or resell the Software.",
      "Remove proprietary notices, signatures, watermarks, or technical safeguards.",
      "Use the Software to compete against RescuePC Repairs or for unlawful purposes.",
    ],
  },
  {
    title: "4. Privacy & Data",
    items: [
      "The Toolkit runs completely offline; no telemetry is transmitted back to RescuePC Repairs.",
      "Logs created locally remain on the customer machine unless you explicitly export them.",
    ],
  },
  {
    title: "5. Digital Signatures & Verification",
    items: [
      "The Toolkit includes cryptographic signatures and license verification routines.",
      "Tampering with or bypassing these controls voids the license immediately.",
    ],
  },
  {
    title: "6. Warranty Disclaimer",
    body:
      "THE SOFTWARE IS PROVIDED " +
      '"AS IS" WITHOUT WARRANTIES OF ANY KIND. RESCUEPC REPAIRS DISCLAIMS ALL WARRANTIES,' +
      " INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.",
  },
  {
    title: "7. Limitation of Liability",
    body:
      "IN NO EVENT SHALL RESCUEPC REPAIRS BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES " +
      " ARISING FROM THE USE OR INABILITY TO USE THE SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.",
  },
  {
    title: "8. Termination",
    items: [
      "The Agreement terminates immediately if you violate any clause.",
      "Upon termination you must stop using the Toolkit and destroy all copies.",
    ],
  },
  {
    title: "9. Governing Law",
    body:
      "This Agreement is governed by U.S. law, without regard to conflict-of-law principles. " +
      "Any unenforceable provision shall be reformed to the minimum extent necessary.",
  },
  {
    title: "10. Entire Agreement",
    body:
      "This document represents the entire agreement between you and RescuePC Repairs concerning the Toolkit and supersedes prior proposals or discussions.",
  },
];

export const metadata = {
  title: "End User License Agreement | RescuePC Repairs",
  description: "Official terms governing the RescuePC Repairs Toolkit. Read before deploying the software in production environments.",
};

export default function EulaPage() {
  return (
    <main className="mx-auto max-w-5xl px-6 py-16 text-slate-900">
      <div className="mb-8">
        <p className="text-xs uppercase tracking-[0.35em] text-slate-500">Legal</p>
        <h1 className="mt-2 text-4xl font-bold">End User License Agreement (EULA)</h1>
        <p className="mt-3 text-slate-600">Effective date: November 2025</p>
      </div>

      <div className="space-y-8 rounded-2xl border border-slate-200 bg-white p-8 shadow-sm text-sm leading-relaxed">
        <section className="space-y-4">
          <p className="font-semibold text-amber-600">IMPORTANT NOTICE</p>
          <p className="text-base">
            By installing, activating, or using the RescuePC Repairs Toolkit ("Software") you confirm that you have read, understand, and agree to be bound by this Agreement. If you do not agree, you must not install or use the Software.
          </p>
        </section>

        {sections.map((section, index) => (
          <section key={index} className="space-y-4">
            <h2 className="text-xl font-semibold">{section.title}</h2>
            {section.subtitle && (
              <h3 className="font-semibold">{section.subtitle}</h3>
            )}
            {section.body ? (
              <p className="text-slate-700 leading-relaxed">{section.body}</p>
            ) : null}
            {section.items ? (
              <ul className="list-disc space-y-2 pl-5 text-slate-700">
                {section.items.map((item, itemIndex) => (
                  <li key={itemIndex}>{item}</li>
                ))}
              </ul>
            ) : null}
          </section>
        ))}

        <section className="border-t border-slate-200 pt-6 text-sm text-slate-600">
          <p>
            {new Date().getFullYear()} RescuePC Repairs. All trademarks, service marks, and brand names belong to their respective owners.
          </p>
          <p className="mt-2 font-semibold">
            Contact legal@rescuepcrepairs.com with any questions regarding this Agreement or enterprise licensing terms.
          </p>
        </section>
      </div>
    </main>
  );
}