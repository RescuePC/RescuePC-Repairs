# SEO SOP — RescuePC Repairs

## Purpose

This SOP keeps RescuePC Repairs technical SEO consistent across the Next.js App Router site. The goal is not to chase hacks. The goal is clean crawlability, truthful structured data, strong metadata, stable canonical URLs, and repeatable validation before production deploys.

## Canonical domain

- Primary canonical domain: `https://www.rescuepcrepairs.com`
- Secondary domain: `https://rescuepcrepairs.com`
- All indexable metadata, sitemap URLs, and structured data URLs must use the primary canonical domain.
- The non-www host should redirect to the www host.
- The app currently uses `trailingSlash: true`; public canonical URLs should end with `/` except the domain root.

## Metadata standards

Every indexable public page must have:

1. One unique `<title>`.
2. One unique meta description written for humans.
3. A canonical URL using `https://www.rescuepcrepairs.com`.
4. Open Graph title, description, URL, site name, locale, and image.
5. Twitter card metadata.
6. `index, follow` robots defaults unless the page is intentionally private or low-value.

Use `src/lib/seo.ts` for shared metadata helpers. Do not hand-roll duplicate canonical logic in page files.

## Sitemap rules

The generated sitemap lives at `/sitemap.xml` through `src/app/sitemap.ts`.

Include only canonical public URLs, currently:

- `/`
- `/pricing/`
- `/download/`
- `/legal/eula/`
- `/legal/license/`

Do not include:

- `/api/*`
- `/admin/*`
- `/dashboard/*`
- `/checkout*`
- `/license*` top-level private/license verification paths
- `/account/*`
- `/auth/*`
- `/internal/*`
- telemetry, webhook, Stripe callback, or private utility routes
- duplicate non-www URLs
- URLs that redirect before showing content

When a new public marketing, article, guide, or documentation page ships, add it to `publicRoutes` in `src/lib/seo.ts` and rerun the SEO smoke test.

## Robots rules

The generated robots file lives at `/robots.txt` through `src/app/robots.ts`.

Robots must:

- Allow public marketing/product/legal pages.
- Disallow private app areas, APIs, admin dashboards, checkout/license internals, telemetry, webhooks, and internal routes.
- Include `Sitemap: https://www.rescuepcrepairs.com/sitemap.xml`.

Robots is not security. Private routes still need authentication and server-side access control.

## Structured data rules

Allowed structured data:

- `Organization` for RescuePC Repairs.
- `WebSite` for the canonical site.
- `SoftwareApplication` for the RescuePC Repairs Windows toolkit.
- `Product` and `Offer` only on pages where pricing is visibly shown.
- `BreadcrumbList` on nested pages such as legal/docs/guides.
- `Article`, `FAQPage`, or `HowTo` only when the matching visible content exists on the page.

Forbidden structured data:

- Fake reviews.
- Fake `aggregateRating`.
- Fake awards.
- Fake physical locations.
- FAQ schema when the user cannot see the FAQ on the page.
- HowTo schema for generic marketing copy.

Render JSON-LD with `src/components/JsonLd.tsx` so `<` characters are escaped safely.

## Content quality rules

Write for real Windows users and technicians first. Search intent to support naturally:

- Windows repair software
- PC repair toolkit
- Windows Update repair
- network repair
- slow startup cleanup
- BSOD troubleshooting
- high CPU usage investigation
- diagnostics and repair workflows

Do not keyword-stuff. Do not promise guaranteed fixes. Do not claim certifications, awards, reviews, locations, or partnerships that are not real and visible.

Every public page should have one clear H1 and descriptive internal links. Avoid links to missing pages.

## Pre-merge testing checklist

Run:

```bash
npm install
npm run lint
npm run build
npm run test
```

For SEO smoke checks, start the local production server first:

```bash
npm run build
npm run start
```

Then in another terminal:

```bash
SEO_BASE_URL=http://localhost:3000 npm run test:seo
```

Confirm:

- `/robots.txt` returns 200.
- `/sitemap.xml` returns 200 and valid XML.
- Sitemap contains only canonical public URLs.
- Sitemap excludes admin/API/dashboard/checkout/license/private routes.
- Public pages have title, description, canonical, Open Graph, and Twitter metadata.
- Public pages are not accidentally `noindex`.
- No duplicate canonical URLs.
- No broken internal links on the main public navigation.

## Post-deploy validation checklist

After Vercel production deploy:

```bash
curl -I https://www.rescuepcrepairs.com/
curl https://www.rescuepcrepairs.com/robots.txt
curl https://www.rescuepcrepairs.com/sitemap.xml
curl -I https://rescuepcrepairs.com/
```

Verify:

- `https://rescuepcrepairs.com/*` redirects to `https://www.rescuepcrepairs.com/*`.
- `robots.txt` contains the canonical sitemap URL.
- `sitemap.xml` only contains `www` canonical URLs.
- Google Search Console can fetch the sitemap.
- Rich Results Test can parse JSON-LD without fabricated review/rating warnings.

## Google Search Console tasks

Manual steps that cannot be completed inside the codebase:

1. Verify both domain properties if not already verified.
2. Submit `https://www.rescuepcrepairs.com/sitemap.xml`.
3. Inspect the homepage, pricing page, and download page.
4. Request indexing only after the production deploy is live and stable.
5. Monitor Coverage, Page indexing, Enhancements, and Core Web Vitals for at least 7 days after major SEO changes.
