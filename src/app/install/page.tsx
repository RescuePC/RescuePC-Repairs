import Link from 'next/link';

const steps = [
  {
    title: 'Buy your license',
    body: 'Choose a plan, enter the email where you want the license delivered, and complete secure Stripe checkout.',
  },
  {
    title: 'Open the license email',
    body: 'After payment, check your inbox and spam folder for the RescuePC license key and private download link.',
  },
  {
    title: 'Download and extract the ZIP',
    body: 'Save the file somewhere easy to find, such as Downloads or Desktop, then extract it before launching the app.',
  },
  {
    title: 'Approve Windows prompts',
    body: 'Windows may ask about RescuePCRepairs.exe and runner.exe separately. Choose More info, then Run anyway, only when the file came from rescuepcrepairs.com.',
  },
  {
    title: 'Launch and activate',
    body: 'Open RescuePC Repairs, paste your license key when asked, and start with the recommended diagnostics.',
  },
];

export default function InstallGuidePage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="mx-auto max-w-5xl px-6 py-16">
        <div className="mb-10 max-w-3xl">
          <p className="mb-3 text-sm font-semibold uppercase tracking-[0.2em] text-blue-300">
            RescuePC install guide
          </p>
          <h1 className="text-4xl font-bold tracking-tight md:text-5xl">
            Download, extract, approve, and launch RescuePC Repairs.
          </h1>
          <p className="mt-5 text-lg text-slate-300">
            Follow these steps after checkout so Windows security prompts do not turn into confusion.
          </p>
        </div>

        <div className="grid gap-5">
          {steps.map((step, index) => (
            <article key={step.title} className="rounded-2xl border border-slate-800 bg-slate-900 p-6">
              <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-full bg-blue-500 font-bold text-white">
                {index + 1}
              </div>
              <h2 className="text-xl font-bold">{step.title}</h2>
              <p className="mt-2 text-slate-300">{step.body}</p>
            </article>
          ))}
        </div>

        <div className="mt-8 rounded-2xl border border-amber-400/30 bg-amber-400/10 p-6 text-amber-100">
          <h2 className="font-bold">SmartScreen safety check</h2>
          <p className="mt-2 text-sm">
            SmartScreen warnings are common for new Windows desktop software until the app builds reputation. Only continue when you downloaded RescuePC from rescuepcrepairs.com and the file names match the RescuePC package.
          </p>
        </div>

        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Link href="/download" className="rounded-xl bg-emerald-400 px-6 py-3 text-center font-bold text-slate-950 hover:bg-emerald-300">
            Buy and download
          </Link>
          <Link href="/pricing" className="rounded-xl border border-slate-700 px-6 py-3 text-center font-bold text-white hover:bg-slate-900">
            Compare plans
          </Link>
          <a href="mailto:support@rescuepcrepairs.com" className="rounded-xl border border-slate-700 px-6 py-3 text-center font-bold text-white hover:bg-slate-900">
            Contact support
          </a>
        </div>
      </section>
    </main>
  );
}
