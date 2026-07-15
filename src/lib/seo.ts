import type { Metadata } from "next";

export const SITE_NAME = "RescuePC Repairs";
export const SITE_URL = "https://www.rescuepcrepairs.com";
export const DEFAULT_TITLE = "RescuePC Repairs | Windows Repair Software & PC Toolkit";
export const DEFAULT_DESCRIPTION =
  "RescuePC Repairs is a Windows repair toolkit for diagnostics, network repair, Windows Update issues, startup cleanup, BSOD troubleshooting, and PC performance workflows.";
export const DEFAULT_OG_IMAGE = "/opengraph-image";

export type RouteChangeFrequency =
  | "always"
  | "hourly"
  | "daily"
  | "weekly"
  | "monthly"
  | "yearly"
  | "never";

export type PublicRoute = {
  path: string;
  title: string;
  description: string;
  changeFrequency: RouteChangeFrequency;
  priority: number;
  lastModified: string;
};

export const publicRoutes = [
  {
    path: "/",
    title: "Windows Repair Software & PC Toolkit",
    description:
      "Repair common Windows problems with RescuePC diagnostics, network fixes, Windows Update repair workflows, BSOD troubleshooting, and performance cleanup tools.",
    changeFrequency: "weekly",
    priority: 1,
    lastModified: "2026-07-15",
  },
  {
    path: "/pricing/",
    title: "Pricing & License Plans",
    description:
      "Compare RescuePC Repairs Basic, Pro, Enterprise, and Lifetime license plans for Windows repair software and technician PC repair workflows.",
    changeFrequency: "weekly",
    priority: 0.9,
    lastModified: "2026-07-15",
  },
  {
    path: "/download/",
    title: "Download RescuePC Repairs",
    description:
      "Get RescuePC Repairs after purchasing a valid license. License keys and download access are delivered through the secure purchase flow.",
    changeFrequency: "monthly",
    priority: 0.7,
    lastModified: "2026-07-15",
  },
  {
    path: "/legal/eula/",
    title: "End User License Agreement",
    description:
      "Read the RescuePC Repairs End User License Agreement for software usage rights, restrictions, privacy, warranty, and liability terms.",
    changeFrequency: "yearly",
    priority: 0.3,
    lastModified: "2026-07-15",
  },
  {
    path: "/legal/license/",
    title: "License Terms",
    description:
      "Review RescuePC Repairs license types, activation rules, compliance expectations, and support requirements for toolkit usage.",
    changeFrequency: "yearly",
    priority: 0.3,
    lastModified: "2026-07-15",
  },
] as const satisfies readonly PublicRoute[];

export const blockedRoutePrefixes = [
  "/api/",
  "/admin/",
  "/dashboard/",
  "/checkout/",
  "/license/",
  "/account/",
  "/auth/",
  "/internal/",
  "/client/telemetry",
  "/api/client/telemetry",
  "/api/track",
  "/webhook/",
  "/stripe/",
];

export function normalizePath(path = "/") {
  if (!path || path === "/") {
    return "/";
  }

  const withLeadingSlash = path.startsWith("/") ? path : `/${path}`;
  return withLeadingSlash.endsWith("/") ? withLeadingSlash : `${withLeadingSlash}/`;
}

export function canonicalUrl(path = "/") {
  return new URL(normalizePath(path), SITE_URL).toString();
}

type SeoMetadataInput = {
  title: string;
  description: string;
  path?: string;
  noIndex?: boolean;
};

export function createMetadata({
  title,
  description,
  path = "/",
  noIndex = false,
}: SeoMetadataInput): Metadata {
  const canonical = canonicalUrl(path);
  const socialTitle = title.includes(SITE_NAME) ? title : `${title} | ${SITE_NAME}`;

  return {
    metadataBase: new URL(SITE_URL),
    title,
    description,
    applicationName: SITE_NAME,
    authors: [{ name: SITE_NAME, url: SITE_URL }],
    creator: SITE_NAME,
    publisher: SITE_NAME,
    category: "technology",
    alternates: {
      canonical,
    },
    openGraph: {
      title: socialTitle,
      description,
      url: canonical,
      siteName: SITE_NAME,
      locale: "en_US",
      type: "website",
      images: [
        {
          url: DEFAULT_OG_IMAGE,
          width: 1200,
          height: 630,
          alt: "RescuePC Repairs Windows repair toolkit",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: socialTitle,
      description,
      images: [DEFAULT_OG_IMAGE],
    },
    robots: noIndex
      ? {
          index: false,
          follow: false,
          nocache: true,
        }
      : {
          index: true,
          follow: true,
          googleBot: {
            index: true,
            follow: true,
            noimageindex: false,
            "max-video-preview": -1,
            "max-image-preview": "large",
            "max-snippet": -1,
          },
        },
  };
}

export const rootMetadata: Metadata = {
  ...createMetadata({
    title: DEFAULT_TITLE,
    description: DEFAULT_DESCRIPTION,
    path: "/",
  }),
  title: {
    default: DEFAULT_TITLE,
    template: `%s | ${SITE_NAME}`,
  },
};

export const organizationJsonLd = {
  "@context": "https://schema.org",
  "@type": "Organization",
  name: SITE_NAME,
  url: SITE_URL,
  email: "support@rescuepcrepairs.com",
};

export const websiteJsonLd = {
  "@context": "https://schema.org",
  "@type": "WebSite",
  name: SITE_NAME,
  url: SITE_URL,
};

export const softwareApplicationJsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: SITE_NAME,
  applicationCategory: "UtilitiesApplication",
  operatingSystem: "Windows",
  url: SITE_URL,
  description: DEFAULT_DESCRIPTION,
};

export const pricingProductJsonLd = {
  "@context": "https://schema.org",
  "@type": "Product",
  name: "RescuePC Repairs Windows Repair Toolkit",
  brand: {
    "@type": "Brand",
    name: SITE_NAME,
  },
  category: "Windows repair software",
  description:
    "A licensed Windows repair toolkit for diagnostics, repair workflows, driver checks, backup support, and performance cleanup.",
  url: canonicalUrl("/pricing/"),
  offers: [
    {
      "@type": "Offer",
      name: "Basic",
      price: "49.99",
      priceCurrency: "USD",
      url: canonicalUrl("/pricing/"),
      availability: "https://schema.org/InStock",
    },
    {
      "@type": "Offer",
      name: "Pro",
      price: "199.99",
      priceCurrency: "USD",
      url: canonicalUrl("/pricing/"),
      availability: "https://schema.org/InStock",
    },
    {
      "@type": "Offer",
      name: "Enterprise",
      price: "499.99",
      priceCurrency: "USD",
      url: canonicalUrl("/pricing/"),
      availability: "https://schema.org/InStock",
    },
    {
      "@type": "Offer",
      name: "Lifetime",
      price: "699.00",
      priceCurrency: "USD",
      url: canonicalUrl("/pricing/"),
      availability: "https://schema.org/InStock",
    },
  ],
};

export function breadcrumbJsonLd(items: Array<{ name: string; path: string }>) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((item, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: item.name,
      item: canonicalUrl(item.path),
    })),
  };
}
