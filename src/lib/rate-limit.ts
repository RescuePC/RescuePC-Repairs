import type { NextRequest } from "next/server";
import { config } from "./config";

type RateLimitEntry = {
  count: number;
  expiresAt: number;
};

const buckets = new Map<string, RateLimitEntry>();

const extractClientIdentifier = (req: NextRequest): string => {
  const forwardedFor = req.headers.get("x-forwarded-for");
  if (forwardedFor) {
    const [client] = forwardedFor.split(",");
    if (client?.trim()) {
      return client.trim();
    }
  }

  const realIp = req.headers.get("x-real-ip");
  if (realIp) {
    return realIp.trim();
  }

  // NextRequest#ip is only available in middleware/edge but include for completeness
  if ((req as { ip?: string }).ip) {
    return (req as { ip?: string }).ip as string;
  }

  return "unknown";
};

export const applyRateLimit = (
  req: NextRequest,
  scope = "global"
): { allowed: boolean; retryAfter?: number } => {
  const max = config.security.rateLimitMaxRequests;
  const windowMs = config.security.rateLimitWindowMs;

  if (max <= 0 || windowMs <= 0) {
    return { allowed: true };
  }

  const identifier = `${scope}:${extractClientIdentifier(req)}`;
  const now = Date.now();
  const bucket = buckets.get(identifier);

  if (!bucket || now >= bucket.expiresAt) {
    buckets.set(identifier, { count: 1, expiresAt: now + windowMs });
    return { allowed: true };
  }

  if (bucket.count >= max) {
    const retryAfter = Math.ceil((bucket.expiresAt - now) / 1000);
    return { allowed: false, retryAfter };
  }

  bucket.count += 1;
  return { allowed: true };
};

