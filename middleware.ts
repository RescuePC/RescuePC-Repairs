import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

const HTTPS_STATUS = 308;
const RATE_LIMIT_WINDOW = 15 * 60 * 1000; // 15 minutes
const RATE_LIMIT_MAX_REQUESTS = 100;

// Simple in-memory rate limiting (for production, use Redis)
const rateLimitMap = new Map<string, { count: number; resetTime: number }>();

function getClientIdentifier(request: NextRequest): string {
  const forwarded = request.headers.get('x-forwarded-for');
  const realIp = request.headers.get('x-real-ip');
  const ip = forwarded?.split(',')[0] || realIp || 'unknown';
  return ip;
}

function isRateLimited(identifier: string): boolean {
  const now = Date.now();
  const record = rateLimitMap.get(identifier);
  
  if (!record || now > record.resetTime) {
    rateLimitMap.set(identifier, {
      count: 1,
      resetTime: now + RATE_LIMIT_WINDOW
    });
    return false;
  }
  
  if (record.count >= RATE_LIMIT_MAX_REQUESTS) {
    return true;
  }
  
  record.count++;
  return false;
}

export function middleware(request: NextRequest) {
  const response = NextResponse.next();
  
  // Multi-tenant support: Extract tenant from header or use default
  const tenantId = request.headers.get('x-tenant-id') || 'default';
  response.headers.set('x-tenant-id', tenantId);
  
  // Security Headers
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-XSS-Protection', '1; mode=block');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set(
    'Content-Security-Policy',
    "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://js.stripe.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://api.stripe.com https://resend.com; frame-src https://js.stripe.com; object-src 'none'; base-uri 'self'; form-action 'self';"
  );
  
  // HTTPS enforcement in production
  const proto = request.headers.get("x-forwarded-proto");
  const host = request.headers.get("host");
  
  if (process.env.NODE_ENV === 'production' && proto && proto !== "https") {
    const url = new URL(request.url);
    url.protocol = "https:";
    if (host) {
      url.host = host;
    }
    return NextResponse.redirect(url, HTTPS_STATUS);
  }
  
  // Rate limiting for API routes
  if (request.nextUrl.pathname.startsWith('/api/')) {
    const identifier = getClientIdentifier(request);
    
    if (isRateLimited(identifier)) {
      return new NextResponse(
        JSON.stringify({ error: 'Too many requests' }),
        {
          status: 429,
          headers: {
            'Content-Type': 'application/json',
            'Retry-After': '900'
          }
        }
      );
    }
  }
  
  // Strict rate limiting for sensitive endpoints
  if (request.nextUrl.pathname === '/api/activate' || request.nextUrl.pathname === '/api/checkout') {
    const identifier = getClientIdentifier(request);
    const sensitiveRecord = rateLimitMap.get(`sensitive_${identifier}`);
    const now = Date.now();
    
    if (sensitiveRecord && now < sensitiveRecord.resetTime && sensitiveRecord.count >= 5) {
      return new NextResponse(
        JSON.stringify({ error: 'Too many requests on sensitive endpoint' }),
        {
          status: 429,
          headers: {
            'Content-Type': 'application/json',
            'Retry-After': '300'
          }
        }
      );
    }
    
    if (!sensitiveRecord || now > sensitiveRecord.resetTime) {
      rateLimitMap.set(`sensitive_${identifier}`, {
        count: 1,
        resetTime: now + (5 * 60 * 1000) // 5 minutes
      });
    } else {
      sensitiveRecord.count++;
    }
  }
  
  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|robots.txt|sitemap.xml|api/health).*)",
  ],
};

