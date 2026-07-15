const baseUrl = (process.env.SEO_BASE_URL || "http://localhost:3000").replace(/\/$/, "");
const canonicalHost = "https://www.rescuepcrepairs.com";

const publicRoutes = ["/", "/pricing/", "/download/", "/legal/eula/", "/legal/license/"];
const forbiddenSitemapFragments = [
  "/api/",
  "/admin/",
  "/dashboard/",
  "/checkout/",
  "/license/",
  "/account/",
  "/auth/",
  "/internal/",
  "/api/client/telemetry",
  "/api/track",
];

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function fetchText(path) {
  const response = await fetch(`${baseUrl}${path}`, { redirect: "manual" });
  const text = await response.text();
  return { response, text };
}

function canonicalFor(path) {
  if (path === "/") {
    return `${canonicalHost}/`;
  }

  return `${canonicalHost}${path.endsWith("/") ? path : `${path}/`}`;
}

function extractSitemapUrls(xml) {
  return [...xml.matchAll(/<loc>(.*?)<\/loc>/g)].map((match) => match[1]);
}

async function checkPublicPage(path) {
  const { response, text } = await fetchText(path);
  assert(response.status === 200, `${path} expected HTTP 200, got ${response.status}`);
  assert(text.includes("<title"), `${path} is missing a <title> tag`);
  assert(text.includes('name="description"'), `${path} is missing a meta description`);
  assert(text.includes(`rel="canonical" href="${canonicalFor(path)}"`), `${path} has a missing or incorrect canonical URL`);
  assert(text.includes('property="og:title"'), `${path} is missing Open Graph title metadata`);
  assert(text.includes('name="twitter:card"'), `${path} is missing Twitter card metadata`);
  assert(!text.includes('name="robots" content="noindex'), `${path} should not be noindex`);
}

async function main() {
  console.log(`SEO smoke test target: ${baseUrl}`);

  for (const route of publicRoutes) {
    await checkPublicPage(route);
    console.log(`✓ ${route} public metadata`);
  }

  const robots = await fetchText("/robots.txt");
  assert(robots.response.status === 200, `/robots.txt expected HTTP 200, got ${robots.response.status}`);
  assert(robots.text.includes("Sitemap: https://www.rescuepcrepairs.com/sitemap.xml"), "robots.txt missing canonical sitemap URL");
  assert(robots.text.includes("Disallow: /api/"), "robots.txt missing /api/ disallow");
  assert(robots.text.includes("Disallow: /admin/"), "robots.txt missing /admin/ disallow");
  console.log("✓ robots.txt policy");

  const sitemap = await fetchText("/sitemap.xml");
  assert(sitemap.response.status === 200, `/sitemap.xml expected HTTP 200, got ${sitemap.response.status}`);
  assert(sitemap.text.includes("<urlset"), "sitemap.xml is not a URL set");

  const sitemapUrls = extractSitemapUrls(sitemap.text);
  assert(sitemapUrls.length === publicRoutes.length, `sitemap expected ${publicRoutes.length} URLs, found ${sitemapUrls.length}`);

  for (const route of publicRoutes) {
    assert(sitemapUrls.includes(canonicalFor(route)), `sitemap missing ${canonicalFor(route)}`);
  }

  for (const fragment of forbiddenSitemapFragments) {
    assert(!sitemap.text.includes(fragment), `sitemap must not include ${fragment}`);
  }

  assert(new Set(sitemapUrls).size === sitemapUrls.length, "sitemap has duplicate URLs");
  console.log("✓ sitemap canonical public URLs only");

  console.log("SEO smoke tests passed.");
}

main().catch((error) => {
  console.error("SEO smoke tests failed:");
  console.error(error);
  process.exit(1);
});
