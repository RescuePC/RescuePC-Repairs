export const metadata = { title: "Download – RescuePC Repairs" };

export default function Download() {
  return (
    <main className="min-h-screen bg-slate-50 py-20">
      <div className="max-w-4xl mx-auto px-6">
        <div className="text-center mb-12">
          <h1 className="text-4xl md:text-5xl font-bold text-slate-900 mb-4">
            Download RescuePC Repairs
          </h1>
          <p className="text-xl text-slate-600">
            Get started with professional Windows repair tools in minutes.
          </p>
        </div>

        <div className="bg-white rounded-2xl shadow-xl p-8 md:p-12">
          <div className="text-center mb-8">
            <div className="w-16 h-16 bg-blue-100 rounded-full mx-auto mb-4 flex items-center justify-center">
              <span className="text-3xl">💾</span>
            </div>
            <h2 className="text-2xl font-bold text-slate-900 mb-2">Windows Repair Toolkit</h2>
            <p className="text-slate-600">Version 2.0.0 • Compatible with Windows 10/11</p>
          </div>

          <div className="grid md:grid-cols-2 gap-8 mb-8">
            <div>
              <h3 className="text-lg font-semibold text-slate-900 mb-4">System Requirements</h3>
              <ul className="space-y-2 text-slate-600">
                <li className="flex items-center">
                  <span className="text-green-500 mr-3">✓</span>
                  Windows 10 version 1903 or later
                </li>
                <li className="flex items-center">
                  <span className="text-green-500 mr-3">✓</span>
                  Windows 11 (all versions)
                </li>
                <li className="flex items-center">
                  <span className="text-green-500 mr-3">✓</span>
                  Administrator privileges required
                </li>
                <li className="flex items-center">
                  <span className="text-green-500 mr-3">✓</span>
                  500MB free disk space
                </li>
                <li className="flex items-center">
                  <span className="text-green-500 mr-3">✓</span>
                  Internet connection for activation
                </li>
              </ul>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-slate-900 mb-4">What&rsquo;s Included</h3>
              <ul className="space-y-2 text-slate-600">
                <li className="flex items-center">
                  <span className="text-blue-500 mr-3">🧠</span>
                  AI System Diagnostics
                </li>
                <li className="flex items-center">
                  <span className="text-blue-500 mr-3">🔧</span>
                  Automated Repair Tools
                </li>
                <li className="flex items-center">
                  <span className="text-blue-500 mr-3">🚗</span>
                  Driver Management
                </li>
                <li className="flex items-center">
                  <span className="text-blue-500 mr-3">🛡️</span>
                  Security & Malware Tools
                </li>
                <li className="flex items-center">
                  <span className="text-blue-500 mr-3">⚡</span>
                  Performance Optimization
                </li>
              </ul>
            </div>
          </div>

          <div className="text-center">
            <a
              className="inline-flex items-center px-8 py-4 rounded-xl bg-blue-600 text-white font-semibold hover:bg-blue-700 transition-colors shadow-lg text-lg mb-6"
              href="/downloads/RescuePC-Setup.exe"
            >
              <span className="mr-3">⬇️</span>
              Download RescuePC Repairs (15.2 MB)
            </a>

            <div className="text-sm text-slate-500 space-y-2">
              <p>By downloading, you agree to our <a className="underline hover:text-blue-600" href="/legal/eula">End User License Agreement</a></p>
              <p>Need help? Check our <a className="underline hover:text-blue-600" href="/docs/installation">installation guide</a></p>
            </div>
          </div>
        </div>

        <div className="mt-12 text-center">
          <div className="bg-blue-50 rounded-xl p-6 border border-blue-200">
            <h3 className="text-lg font-semibold text-blue-900 mb-2">First Time Setup</h3>
            <p className="text-blue-800">
              After download, run the installer as Administrator and enter your license key when prompted.
              The application will guide you through the initial setup process.
            </p>
          </div>
        </div>
      </div>
    </main>
  );
}


