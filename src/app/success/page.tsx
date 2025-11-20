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

  // Here is where you could optionally call your backend /api/licenses/by-session
  // to show license key or download link. For now we just show messaging.

  return (
    <main className="min-h-screen flex items-center justify-center px-4">
      <div className="max-w-xl w-full bg-white/5 border border-gray-700 rounded-xl p-8 space-y-4">
        <h1 className="text-3xl font-semibold">
          Payment received. Your license is being generated.
        </h1>

        <p className="text-sm text-muted-foreground">
          We have received your payment and are generating your RescuePC
          license and secure download link. You will receive an email within a
          few minutes with:
        </p>

        <ul className="list-disc list-inside text-sm text-muted-foreground space-y-1">
          <li>Your license key</li>
          <li>A secure link to download RescuePC Repairs</li>
          <li>Instructions for activating your license on first launch</li>
        </ul>

        {sessionId && (
          <p className="text-xs text-muted-foreground">
            Stripe session ID: <code>{sessionId}</code>
          </p>
        )}

        <div className="flex gap-3 pt-4">
          <Link
            href="/"
            className="px-4 py-2 rounded-md bg-blue-600 text-white text-sm hover:bg-blue-700"
          >
            Back to home
          </Link>

          <Link
            href="/support"
            className="px-4 py-2 rounded-md border border-gray-500 text-sm"
          >
            Need help?
          </Link>
        </div>
      </div>
    </main>
  );
}
