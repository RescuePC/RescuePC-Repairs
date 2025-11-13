// License key generation utility for RescuePC
// Generates secure, unique license keys in XXXXX-XXXXX-XXXXX-XXXXX-XXXXX format

export function generateLicenseKey(): string {
  // Generate a cryptographically secure random UUID and convert to license format
  const uuid = crypto.randomUUID().replace(/-/g, "");

  // Split into 5-character chunks for readability
  const chunks = [
    uuid.slice(0, 5),
    uuid.slice(5, 10),
    uuid.slice(10, 15),
    uuid.slice(15, 20),
    uuid.slice(20, 25)
  ];

  // Join with dashes and convert to uppercase
  return chunks.join("-").toUpperCase();
}

// Validate license key format
export function validateLicenseKeyFormat(key: string): boolean {
  const pattern = /^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$/;
  return pattern.test(key);
}

// Extract license tier from SKU (customize based on your products)
export function getLicenseTierFromSku(sku: string): string {
  const tierMap: Record<string, string> = {
    'BASIC': 'Basic',
    'PRO': 'Professional',
    'ENTERPRISE': 'Enterprise',
    'GOVERNMENT': 'Government',
    'LIFETIME': 'Lifetime',
    'ENTERPRISE-PACKAGE': 'Enterprise Package'
  };

  // Try exact match first
  if (tierMap[sku.toUpperCase()]) {
    return tierMap[sku.toUpperCase()];
  }

  // Try partial match
  for (const [key, value] of Object.entries(tierMap)) {
    if (sku.toUpperCase().includes(key)) {
      return value;
    }
  }

  return 'Basic'; // Default fallback
}
