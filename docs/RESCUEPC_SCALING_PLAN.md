# RescuePC Repairs – Enterprise Scaling Plan (Simple Mode)

## Context
- Stack is fixed: Next.js 15 (App Router), PostgreSQL + Prisma, Stripe, Docker, PowerShell repair scripts, existing licensing API.
- Repo root: C:\Users\Tyler\Desktop\RescuePC Repairs
- Your job: extend what exists (multi-tenant, multi-region-ready, zero-downtime), without rewrites or fancy new frameworks.

## 1) Multi-tenant (simple, data-level)

Goal: support many customers on shared infra, no cross-tenant leaks.

### Database changes (conceptual):

- Add tenant_id columns:

  ```sql
  ALTER TABLE licenses
    ADD COLUMN IF NOT EXISTS tenant_id varchar(50) NOT NULL DEFAULT 'default';

  ALTER TABLE test_customers
    ADD COLUMN IF NOT EXISTS tenant_id varchar(50) NOT NULL DEFAULT 'default';
  ```

### Prisma sketch:

  ```prisma
  model License {
    // existing fields...
    tenantId String @default("default") @map("tenant_id")
  }
  ```

### Tenant helper:

  ```typescript
  // src/lib/tenant.ts
  import { NextRequest } from "next/server";

  export function getTenantId(req: NextRequest): string {
    return req.headers.get("x-tenant-id") ?? "default";
  }
  ```

### Usage in API:

  ```typescript
  import { getTenantId } from "@/lib/tenant";

  export async function POST(req: NextRequest) {
    const tenantId = getTenantId(req);
    const { email, licenseKey } = await req.json();

    const license = await prisma.license.findFirst({
      where: {
        tenantId,
        customerEmail: email.toLowerCase(),
        licenseKey,
        status: "active",
      },
    });

    // existing behavior...
  }
  ```

### Optional extra guard (later): enable RLS and a tenant_isolation policy on licenses, using current_setting('app.tenant_id', true), wired via SET LOCAL in the DB session.

## 2) Multi-region (design ready, keep it simple)

- Primary region: us-east-1
- Secondary region: eu-west-1
- Use:
  - CDN (Cloudflare) for static assets and download EXE.
  - Postgres read replica in EU.
  - App containers are stateless; region chosen by DNS / load balancer, not by code changes.

Configuration idea (not exact compose syntax):

- Separate compose or env per region, e.g. docker-compose.us-east-1.yml and docker-compose.eu-west-1.yml, with APP_REGION env variable.

## 3) Zero-downtime deploys (blue-green style)

Simple pattern:

- Build and start "green" stack alongside "blue".
- Health check new stack at /api/health.
- Switch traffic at the load balancer (nginx or cloud LB).
- Keep old stack running for fast rollback until new one is proven.

Pseudo deploy script:

  ```bash
  # 1. start green
  docker-compose -f docker-compose.green.yml up -d

  # 2. health check
  curl -f http://green-host:3000/api/health || exit 1

  # 3. reload nginx / LB to point to green
  nginx -s reload

  # 4. keep blue around for rollback
  ```

## 4) Scale to millions (practical steps)

- Horizontal scale app containers (Kubernetes or Docker Swarm later; for now, compose replicas conceptually).
- Use a connection pooler (PgBouncer) when connection count becomes an issue.
- Optional Redis:
  - Cache hot license lookups by {tenantId, email, licenseKey} for short TTL to reduce DB load.
- Keep APIs simple: fast queries, indexes on (tenant_id, email, license_key, status).

## 5) Week-by-week rollout (realistic)

### Week 1 – Multi-tenant foundation
- Add tenantId to License and any customer tables.
- Add tenant helper and thread tenantId through /api/verify-license and any other license APIs.
- Write basic tests: different x-tenant-id headers see only their own data.

### Week 2 – Multi-region ready
- Introduce APP_REGION env variable, but keep a single region in dev.
- Make logs and health endpoints include region.
- Document how Postgres replicas and DNS-based region routing will work.

### Week 3 – Zero-downtime pipeline
- Add /api/health if not present.
- Extend .github/workflows/release.yml and Docker files to support blue-green or rolling deploys (no downtime while migrations run).
- Test a dummy migration and deploy to prove it.

### Week 4 – Load & performance
- Add simple load tests (artillery or similar) against /api/verify-license.
- Tune DB indexes and connection limits.
- Optional: introduce Redis cache for license verification if profiling shows DB bottlenecks.

## Constraints
- Do not change the core tech stack.
- No secrets or owner licenses hard-coded in binaries.
- Always enforce tenantId in queries.
- Favor small, boring, maintainable changes over complex new systems.
