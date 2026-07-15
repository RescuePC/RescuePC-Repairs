# SEO Audit — RescuePC Repairs

Date: 2026-07-15  
Branch: `seo/world-class-foundation`  
Repository: `RescuePC/RescuePC-Repairs`  
Canonical domain: `https://www.rescuepcrepairs.com`

## Scope

This audit covered the Next.js App Router application SEO foundation for crawlability, metadata, canonical URLs, sitemap generation, robots policy, structured data, internal linking, and repeatable smoke testing.

## Repository state reviewed

- Default branch: `main`
- Working branch created: `seo/world-class-foundation`
- Framework: Next.js App Router
- Existing package scripts reviewed:
  - `npm run lint`
  - `npm run build`
  - `npm run test`
  - `npm run test:api`
  - `npm run test:all`
- Existing public routes confirmed from source:
  - `/`
  - `/pricing/`
  - `/download/`
  - `/legal/eula/`
  - `/legal/license/`
- Requested routes not found in the current app tree during targeted inspection:
  - `/services/`
  - `/how-it-works/`
  - `/docs/`
  - `/fix-windows/`
  - `/windows-system/`
  - `/repairs/`
  - `/error-codes/`
  - `/blog/`
  - `/about/`
  - `/get-started/`

## Findings before coding

### 1. Root metadata was too thin

The root layout had a title, description, keywords, authors, and partial Open Graph metadata. It did not define a canonical metadata base, title template, canonical alternates, Twitter card metadata, detailed robots defaults, or a reusable metadata helper.

### 2. Sitemap was missing from the App Router SEO foundation

No `src/app/sitemap.ts` file existed. Search engines had no generated canonical sitemap from the app source.

### 3. Robots policy was missing from the App Router SEO foundation

No `src/app/robots.ts` file existed. Private paths such as API, admin, dashboard, checkout, license, telemetry, webhook, and internal paths needed explicit crawler exclusion.

### 4. Route-level metadata was inconsistent

Legal pages had local metadata. Client pages such as `/pricing/` and `/download/` could not directly export metadata because they use `use client`, so route metadata needed nested layouts.

### 5. Structured data was missing

No reusable JSON-LD renderer existed. Organization, WebSite, SoftwareApplication, Product/Offer, and BreadcrumbList data were not consistently emitted.

### 6. Canonical host consistency needed hardening

The production project has both `rescuepcrepairs.com` and `www.rescuepcrepairs.com`. Canonicals needed to standardize on the www domain, and non-www traffic needed a safe permanent redirect.

### 7. Public copy needed stronger search-intent coverage

The homepage talked about Windows repair broadly, but it did not clearly cover several real intent clusters: Windows Update repair, network repair, slow startup cleanup, BSOD troubleshooting, and high CPU usage investigation.

### 8. Production health risk exists outside metadata

Recent Vercel runtime errors show repeated analytics/database write failures for telemetry routes and API routes. These do not appear to block the public static marketing pages directly, but they are noisy and should be separately fixed so crawler/render reliability and production observability stay clean.

## Changes made

### SEO infrastructure

- Added `src/lib/seo.ts`
  - canonical site constants
  - public route registry
  - blocked route prefixes
  - canonical URL helper
  - reusable metadata helper
  - root metadata
  - Organization JSON-LD
  - WebSite JSON-LD
  - SoftwareApplication JSON-LD
  - Product/Offer pricing JSON-LD
  - BreadcrumbList helper

- Added `src/components/JsonLd.tsx`
  - safe JSON-LD script renderer
  - escapes `<` to reduce inline script parsing risk

- Added `src/app/sitemap.ts`
  - generates `/sitemap.xml`
  - includes only canonical public URLs
  - includes `lastModified`, `changeFrequency`, and `priority`

- Added `src/app/robots.ts`
  - generates `/robots.txt`
  - allows public routes
  - disallows private/API/admin/dashboard/checkout/license/telemetry/internal/webhook paths
  - includes canonical sitemap URL

- Added `src/app/opengraph-image.tsx`
  - generates a 1200×630 Open Graph image from the App Router

### Metadata and structured data

- Updated `src/app/layout.tsx`
  - uses centralized `rootMetadata`
  - root metadata now includes metadata base, canonical, Open Graph, Twitter, and robots defaults

- Added `src/app/pricing/layout.tsx`
  - unique route metadata for `/pricing/`

- Added `src/app/download/layout.tsx`
  - unique route metadata for `/download/`

- Updated `src/app/page.tsx`
  - adds Organization, WebSite, and SoftwareApplication JSON-LD
  - improves homepage copy for real Windows repair search intent
  - adds descriptive internal links to pricing and download pages

- Updated `src/app/pricing/page.tsx`
  - adds Product/Offer JSON-LD only where visible pricing exists

- Updated `src/app/legal/eula/page.tsx`
  - uses metadata helper
  - adds BreadcrumbList JSON-LD

- Updated `src/app/legal/license/page.tsx`
  - uses metadata helper
  - adds BreadcrumbList JSON-LD

### Canonical/redirect hygiene

- Updated `next.config.ts`
  - keeps existing `trailingSlash: true`
  - adds permanent redirect from `rescuepcrepairs.com/*` to `https://www.rescuepcrepairs.com/*`
  - preserves existing security headers

### Testing and SOPs

- Updated `package.json`
  - adds `npm run test:seo`

- Added `scripts/seo-smoke.mjs`
  - checks public page status codes
  - checks title/meta description/canonical/Open Graph/Twitter metadata
  - checks no accidental public `noindex`
  - checks robots policy
  - checks sitemap public canonical URLs only
  - checks sitemap excludes private/admin/API/dashboard/checkout/license/internal routes
  - checks duplicate sitemap URLs

- Added `docs/SOP_SEO.md`
  - metadata standards
  - sitemap rules
  - robots rules
  - canonical rules
  - structured data rules
  - content quality rules
  - testing checklist
  - post-deploy validation checklist
  - Google Search Console tasks

## Expected generated public sitemap URLs

- `https://www.rescuepcrepairs.com/`
- `https://www.rescuepcrepairs.com/pricing/`
- `https://www.rescuepcrepairs.com/download/`
- `https://www.rescuepcrepairs.com/legal/eula/`
- `https://www.rescuepcrepairs.com/legal/license/`

## Expected excluded URL families

- `/api/*`
- `/admin/*`
- `/dashboard/*`
- `/checkout/*`
- `/license/*`
- `/account/*`
- `/auth/*`
- `/internal/*`
- `/client/telemetry`
- `/api/client/telemetry`
- `/api/track`
- `/webhook/*`
- `/stripe/*`

## Tests to run locally before merge

```bash
npm install
npm run lint
npm run build
npm run test
```

Then run the SEO smoke test against a running local server:

```bash
npm run build
npm run start
```

In another terminal:

```bash
SEO_BASE_URL=http://localhost:3000 npm run test:seo
```

## Tooling limitation note

The connected GitHub/Vercel workflow allowed source inspection and branch commits, but this environment could not clone GitHub over the container network, so local `npm install`, `npm run lint`, `npm run build`, and `npm run test:seo` still need to be executed in the actual WSL checkout or by Vercel/GitHub CI after the PR is opened.

## Remaining risks

1. The production analytics/database error groups should be fixed separately. They are likely not caused by SEO metadata, but noisy production errors are still bad for reliability.
2. Google Search Console sitemap submission and URL inspection must be completed manually after merge/deploy.
3. Missing marketing/content routes should not be added to the sitemap until they actually exist and have real content.
4. If more public pages are added later, they must be added to `publicRoutes` and tested.
5. The SEO smoke script checks core metadata by HTML output. It does not replace Google Search Console, Rich Results Test, Lighthouse, or real crawl monitoring.

## Recommended next SEO expansion

The strongest next organic growth move is to create real, useful guide pages around:

- Windows Update repair
- DNS/network repair
- slow startup cleanup
- BSOD troubleshooting checklist
- high CPU usage troubleshooting
- Windows audio service repair
- technician PC repair workflow checklist

Each guide should have visible helpful content, one H1, internal links to pricing/download, and only truthful Article/HowTo/FAQ schema when the page content supports it.
