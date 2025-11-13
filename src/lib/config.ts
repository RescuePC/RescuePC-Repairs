// Centralized environment configuration for RescuePC
// Ensures secrets are pulled from process.env exactly once and parsed consistently

type ParseBooleanOptions = {
  defaultValue?: boolean;
};

type ParseNumberOptions = {
  defaultValue?: number;
};

const TRUE_VALUES = new Set(["1", "true", "yes", "on"]);

const parseBoolean = (
  value: string | undefined,
  options: ParseBooleanOptions = {}
): boolean => {
  if (value === undefined || value === null) {
    return options.defaultValue ?? false;
  }
  return TRUE_VALUES.has(value.toLowerCase());
};

const parseNumber = (
  value: string | undefined,
  options: ParseNumberOptions = {}
): number => {
  if (!value) {
    return options.defaultValue ?? 0;
  }
  const parsed = Number(value);
  if (Number.isNaN(parsed)) {
    return options.defaultValue ?? 0;
  }
  return parsed;
};

const parseList = (value: string | undefined): string[] =>
  value
    ? value
        .split(",")
        .map((entry) => entry.trim())
        .filter(Boolean)
    : [];

const getRequiredEnv = (name: string): string => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
};

const optionalEnv = (name: string): string => process.env[name]?.trim() ?? "";

const fallbackUrl = process.env.NEXTAUTH_URL ?? "http://localhost:3000";

export const config = {
  app: {
    env: process.env.NODE_ENV ?? "development",
    port: parseNumber(process.env.PORT, { defaultValue: 3000 }),
    version: process.env.APP_VERSION ?? "2.0.0",
  },
  urls: {
    nextAuthUrl: process.env.NEXTAUTH_URL ?? "http://localhost:3000",
    websiteUrl:
      process.env.WEBSITE_URL ??
      process.env.NEXTAUTH_URL ??
      "http://localhost:3000",
    apiBaseUrl: process.env.API_BASE_URL ?? `${fallbackUrl}/api`,
  },
  stripe: {
    secretKey: getRequiredEnv("STRIPE_SECRET_KEY"),
    publishableKey: optionalEnv("STRIPE_PUBLISHABLE_KEY"),
    webhookSecret: getRequiredEnv("STRIPE_WEBHOOK_SECRET"),
    priceIds: {
      basic: optionalEnv("STRIPE_BASIC_PRICE_ID"),
      pro: optionalEnv("STRIPE_PRO_PRICE_ID"),
      enterprise: optionalEnv("STRIPE_ENTERPRISE_PRICE_ID"),
      lifetime: optionalEnv("STRIPE_LIFETIME_PRICE_ID"),
      government: optionalEnv("STRIPE_GOVERNMENT_PRICE_ID"),
      enterprisePackage: optionalEnv("STRIPE_ENTERPRISE_PACKAGE_PRICE_ID"),
    },
    paymentLinks: {
      basic: optionalEnv("STRIPE_BASIC_LICENSE_URL"),
      pro: optionalEnv("STRIPE_PRO_LICENSE_URL"),
      enterprise: optionalEnv("STRIPE_ENTERPRISE_LICENSE_URL"),
      government: optionalEnv("STRIPE_GOVERNMENT_LICENSE_URL"),
      lifetime: optionalEnv("STRIPE_LIFETIME_LICENSE_URL"),
      enterprisePackage: optionalEnv("STRIPE_ENTERPRISE_PACKAGE_URL"),
    },
  },
  database: {
    url: optionalEnv("DATABASE_URL"),
    password: optionalEnv("DATABASE_PASSWORD"),
    poolMin: parseNumber(process.env.DATABASE_POOL_MIN, { defaultValue: 2 }),
    poolMax: parseNumber(process.env.DATABASE_POOL_MAX, { defaultValue: 20 }),
    ssl: parseBoolean(process.env.DATABASE_SSL, { defaultValue: false }),
  },
  email: {
    resendApiKey: optionalEnv("RESEND_API_KEY"),
    smtpHost: optionalEnv("SMTP_HOST"),
    smtpPort: parseNumber(process.env.SMTP_PORT, { defaultValue: 587 }),
    smtpSecure: parseBoolean(process.env.SMTP_SECURE, { defaultValue: true }),
    smtpUser: optionalEnv("SMTP_USER"),
    smtpPass: optionalEnv("SMTP_PASS"),
    fromEmail: optionalEnv("EMAIL_FROM") || "noreply@rescuepcrepairs.com",
    fromName: optionalEnv("EMAIL_FROM_NAME") || "RescuePC Toolkit",
    replyTo: optionalEnv("EMAIL_REPLY_TO"),
    alertTo:
      optionalEnv("EMAIL_ALERT_TO") ||
      optionalEnv("EMAIL_FROM") ||
      "admin@rescuepcrepairs.com",
    sendingEnabled: parseBoolean(process.env.EMAIL_SENDING_ENABLED, {
      defaultValue: true,
    }),
  },
  security: {
    jwtSecret: getRequiredEnv("JWT_SECRET"),
    apiSecretKey: getRequiredEnv("API_SECRET_KEY"),
    encryptionKey: optionalEnv("ENCRYPTION_KEY"),
    adminApiKeys: parseList(process.env.ADMIN_API_KEYS),
    rateLimitWindowMs: parseNumber(process.env.RATE_LIMIT_WINDOW_MS, {
      defaultValue: 15 * 60 * 1000,
    }),
    rateLimitMaxRequests: parseNumber(process.env.RATE_LIMIT_MAX_REQUESTS, {
      defaultValue: 100,
    }),
    corsOrigin: optionalEnv("CORS_ORIGIN") || "*",
    corsCredentials: parseBoolean(process.env.CORS_CREDENTIALS, {
      defaultValue: false,
    }),
    cspReportUri: optionalEnv("CSP_REPORT_URI"),
  },
  features: {
    trialsEnabled: parseBoolean(process.env.FEATURE_TRIALS_ENABLED),
    donationsEnabled: parseBoolean(process.env.FEATURE_DONATIONS_ENABLED),
    enterpriseEnabled: parseBoolean(process.env.FEATURE_ENTERPRISE_ENABLED, {
      defaultValue: true,
    }),
    apiDocsPublic: parseBoolean(process.env.FEATURE_API_DOCS_PUBLIC),
  },
  analytics: {
    gaId: optionalEnv("NEXT_PUBLIC_GA_ID"),
  },
  logging: {
    level: process.env.LOG_LEVEL ?? "info",
    format: process.env.LOG_FORMAT ?? "json",
    output: process.env.LOG_OUTPUT ?? "stdout",
  },
};

export const envParsers = {
  parseBoolean,
  parseNumber,
  parseList,
};

