export const metadata = { title: "Pricing – RescuePC Repairs" };

const plans = [
  {
    name: "Basic",
    price: "$49.99/yr",
    url: "https://buy.stripe.com/5kQfZggMacypcSl9wP08g05",
    popular: false,
    features: [
      "Core repair functions",
      "Basic diagnostics",
      "Driver validation",
      "System health checks",
      "Email support"
    ]
  },
  {
    name: "Pro",
    price: "$199.99/yr",
    url: "https://buy.stripe.com/00wcN4dzY0PHaKdfVd08g04",
    popular: true,
    features: [
      "All Basic features",
      "AI diagnostics",
      "SDIO driver packs",
      "Malware scanning",
      "Performance optimization",
      "Priority support"
    ]
  },
  {
    name: "Enterprise",
    price: "$499.99/yr",
    url: "https://buy.stripe.com/4gM8wO53s1TLaKd9wP08g02",
    popular: false,
    features: [
      "All Pro features",
      "Advanced malware tools",
      "Network diagnostics",
      "Remote assistance",
      "Custom integrations",
      "24/7 phone support"
    ]
  },
  {
    name: "Lifetime",
    price: "$699 one-time",
    url: "https://buy.stripe.com/14A5kCeE28i92dH9wP08g06",
    popular: false,
    features: [
      "All Enterprise features",
      "Lifetime updates",
      "No recurring fees",
      "VIP support",
      "Early access to new features"
    ]
  },
];

export default function Pricing() {
  return (
    <main className="min-h-screen bg-slate-50 py-20">
      <div className="max-w-7xl mx-auto px-6">
        <div className="text-center mb-16">
          <h1 className="text-4xl md:text-5xl font-bold text-slate-900 mb-4">
            Choose Your Plan
          </h1>
          <p className="text-xl text-slate-600 max-w-3xl mx-auto">
            Select the perfect plan for your Windows repair needs. All plans include
            our core repair toolkit with different feature levels.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
          {plans.map(p => (
            <div key={p.name} className={`relative rounded-2xl border-2 p-8 ${p.popular ? 'border-blue-500 shadow-xl scale-105' : 'border-slate-200'} bg-white`}>
              {p.popular && (
                <div className="absolute -top-4 left-1/2 transform -translate-x-1/2">
                  <span className="bg-blue-500 text-white px-4 py-1 rounded-full text-sm font-semibold">
                    Most Popular
                  </span>
                </div>
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
                <a
                  className={`mt-8 inline-block w-full text-center px-6 py-3 rounded-xl font-semibold transition-colors ${
                    p.popular
                      ? 'bg-blue-600 text-white hover:bg-blue-700'
                      : 'bg-slate-900 text-white hover:bg-slate-800'
                  }`}
                  href={p.url}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Get Started
                </a>
              </div>
            </div>
          ))}
        </div>

        <div className="mt-16 text-center">
          <div className="bg-white rounded-xl p-8 border border-slate-200 max-w-4xl mx-auto">
            <h3 className="text-2xl font-bold text-slate-900 mb-4">All Plans Include</h3>
            <div className="grid md:grid-cols-3 gap-6 text-left">
              <div className="flex items-center">
                <span className="text-green-500 mr-3 text-xl">✓</span>
                <span>Automatic updates</span>
              </div>
              <div className="flex items-center">
                <span className="text-green-500 mr-3 text-xl">✓</span>
                <span>Community forum access</span>
              </div>
              <div className="flex items-center">
                <span className="text-green-500 mr-3 text-xl">✓</span>
                <span>30-day money-back guarantee</span>
              </div>
              <div className="flex items-center">
                <span className="text-green-500 mr-3 text-xl">✓</span>
                <span>Secure license activation</span>
              </div>
              <div className="flex items-center">
                <span className="text-green-500 mr-3 text-xl">✓</span>
                <span>Offline functionality</span>
              </div>
              <div className="flex items-center">
                <span className="text-green-500 mr-3 text-xl">✓</span>
                <span>Multi-language support</span>
              </div>
            </div>
          </div>
        </div>

        <div className="mt-16 text-center">
          <p className="text-slate-600 mb-4">
            🔒 Secured by Stripe • Instant license delivery • Cancel anytime
          </p>
          <p className="text-sm text-slate-500">
            Questions? Contact our support team at support@rescuepcrepairs.com
          </p>
        </div>
      </div>
    </main>
  );
}