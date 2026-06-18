import Link from "next/link";

type SuccessPageProps = {
  searchParams: Promise<{
    session_id?: string;
  }>;
};

export default async function SuccessPage({
  searchParams,
}: SuccessPageProps) {
  const { session_id: sessionId } = await searchParams;

  return (
    <main className="min-h-screen bg-slate-950 px-4 py-16 text-slate-50">
      <div className="mx-auto max-w-3xl rounded-2xl border border-slate-800 bg-slate-900 p-8 shadow-2xl">
        <p className="mb-3 text-sm font-semibold uppercase tracking-[0.2em] text-emerald-300">
          Payment received
        </p>
        <h1 className="text-3xl font-bold md:text-4xl">
          Your RescuePC license and download link are being prepared.
        </h1>

        <p className="mt-4 text-slate-300">
          Check the email address used at checkout. You should receive your license key, private download link, and activation instructions shortly.
        </p>

        <div className="mt-8 grid gap-4 md:grid-cols-3">
          {[
            ['1', 'Check email', 'Look in inbox and spam for RescuePC license delivery.'],
            ['2', 'Download ZIP', 'Use the private download link from that email.'],
            ['3', 'Install safely', 'Extract first, approve Windows prompts, then launch.'],
          ].map(([number, title, body]) => (
            <div key={number} className="rounded-xl border border-slate-800 bg-slate-950 p-5">
              <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-full bg-emerald-400 font-bold text-slate-950">
                {number}
              </div>
              <h2 className="font-semibold text-white">{title}</h2>
              <p className="mt-2 text-sm text-slate-400">{body}</p>
            </div>
          ))}
        </div>

        {sessionId && (
          <p className="mt-6 rounded-xl border border-slate-800 bg-slate-950 p-3 text-xs text-slate-400">
            Stripe session ID: <code>{sessionId}</code>
          </p>
        )}

        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Link
            href="/install"
            className="rounded-xl bg-emerald-400 px-5 py-3 text-center font-bold text-slate-950 hover:bg-emerald-300"
          >
            Open install guide
          </Link>
          <Link
            href="/download"
            className="rounded-xl border border-slate-700 px-5 py-3 text-center font-bold text-white hover:bg-slate-800"
          >
            Back to download
          </Link>
          <a
            href="mailto:support@rescuepcrepairs.com"
            className="rounded-xl border border-slate-700 px-5 py-3 text-center font-bold text-white hover:bg-slate-800"
          >
            Need help?
          </a>
        </div>
      </div>
    </main>
  );
}
