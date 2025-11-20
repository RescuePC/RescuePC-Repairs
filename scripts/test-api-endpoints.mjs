// scripts/test-api-endpoints.mjs
// Simple API smoke test runner for RescuePC endpoints.
// Usage: node scripts/test-api-endpoints.mjs (or npm run test:api)

import fs from "node:fs";
import path from "node:path";

const baseUrl =
  process.env.NEXT_PUBLIC_APP_URL?.replace(/\/+$/, "") ||
  "http://localhost:3000";

const logDir = path.join(process.cwd(), "logs");
const logFile = path.join(logDir, "nextjs-test-results.log");

if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

const endpoints = [
  {
    name: "health",
    method: "GET",
    path: "/api/health",
    body: null,
    expectedStatuses: [200],
  },
  {
    name: "verify-license",
    method: "POST",
    path: "/api/verify-license",
    body: {
      email: "test@example.com",
      licenseKey: "INVALID-TEST-KEY-12345",
    },
    expectedStatuses: [200, 400],
  },
  {
    name: "activate",
    method: "POST",
    path: "/api/activate",
    body: {
      email: "test@example.com",
      licenseKey: "RescuePC-2025",
    },
    expectedStatuses: [200, 400, 401, 403, 404],
  },
  {
    name: "test-email",
    method: "POST",
    path: "/api/test-email",
    body: {},
    expectedStatuses: [200],
  },
  {
    name: "checkout",
    method: "POST",
    path: "/api/checkout",
    body: {
      plan: "basic",
      customerEmail: "test@example.com",
      tenantId: "test-tenant",
    },
    expectedStatuses: [200, 400, 422],
  },
  {
    name: "stripe-webhook",
    method: "POST",
    path: "/api/stripe/webhook",
    body: {
      test: true,
    },
    expectedStatuses: [400],
  },
];

function now() {
  return new Date().toISOString();
}

async function runTest(endpoint) {
  const url = `${baseUrl}${endpoint.path}`;
  const options = {
    method: endpoint.method,
    headers: {
      "Content-Type": "application/json",
    },
  };

  if (endpoint.body) {
    options.body = JSON.stringify(endpoint.body);
  }

  const startedAt = now();

  try {
    const response = await fetch(url, options);
    const status = response.status;
    const text = await response.text();

    const ok = endpoint.expectedStatuses.includes(status);

    return {
      name: endpoint.name,
      method: endpoint.method,
      path: endpoint.path,
      url,
      status,
      ok,
      startedAt,
      finishedAt: now(),
      responseSnippet: text.slice(0, 500),
    };
  } catch (error) {
    return {
      name: endpoint.name,
      method: endpoint.method,
      path: endpoint.path,
      url,
      status: null,
      ok: false,
      startedAt,
      finishedAt: now(),
      error: String(error),
    };
  }
}

async function main() {
  const results = [];

  for (const endpoint of endpoints) {
    console.log(`\n[API TEST] ${endpoint.method} ${endpoint.path}`);
    const result = await runTest(endpoint);
    results.push(result);
    console.log(`[RESULT] ${endpoint.name}: ${result.ok ? "PASS" : "FAIL"} (status=${result.status})`);
  }

  const summary = {
    runAt: now(),
    baseUrl,
    results,
  };

  const logEntry = `\n===== API TEST RUN @ ${summary.runAt} =====\n${JSON.stringify(summary, null, 2)}\n`;
  fs.appendFileSync(logFile, logEntry, "utf8");

  console.table(
    results.map((result) => ({
      name: result.name,
      method: result.method,
      path: result.path,
      status: result.status,
      ok: result.ok,
    }))
  );

  const failed = results.filter((result) => !result.ok);

  if (failed.length > 0) {
    console.error(`\nAPI tests failed for ${failed.length} endpoint(s). See ${logFile} for details.`);
    process.exitCode = 1;
  } else {
    console.log(`\nAll API endpoint checks passed. Log written to ${logFile}.`);
  }
}

main().catch((error) => {
  console.error("Unhandled error in API test runner:", error);
  process.exitCode = 1;
});
