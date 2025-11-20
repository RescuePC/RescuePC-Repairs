import pool from "@/lib/db";

// Simple rate limiting (in-memory, resets on server restart)
const rateLimitMap = new Map<string, { count: number; resetTime: number }>();
const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX = 20; // 20 requests per minute per IP

function getClientIP(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for");
  const realIP = request.headers.get("x-real-ip");
  return forwarded?.split(",")[0] || realIP || "unknown";
}

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const record = rateLimitMap.get(ip);

  if (!record || now > record.resetTime) {
    rateLimitMap.set(ip, { count: 1, resetTime: now + RATE_LIMIT_WINDOW });
    return true;
  }

  if (record.count >= RATE_LIMIT_MAX) {
    return false;
  }

  record.count++;
  return true;
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

const jsonHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST",
  "Access-Control-Allow-Headers": "Content-Type",
};

export async function POST(request: Request) {
  try {
    // Rate limiting
    const clientIP = getClientIP(request);
    if (!checkRateLimit(clientIP)) {
      return new Response(
        JSON.stringify({ valid: false, error: "Rate limit exceeded" }),
        { status: 429, headers: jsonHeaders }
      );
    }

    const { email, licenseKey } = await request.json();

    // Input validation
    if (!email || !licenseKey) {
      return new Response(
        JSON.stringify({ valid: false, error: "Missing email or licenseKey" }),
        { status: 400, headers: jsonHeaders }
      );
    }

    if (typeof email !== "string" || typeof licenseKey !== "string") {
      return new Response(
        JSON.stringify({ valid: false, error: "Invalid input type" }),
        { status: 400, headers: jsonHeaders }
      );
    }

    if (!isValidEmail(email)) {
      return new Response(
        JSON.stringify({ valid: false, error: "Invalid email format" }),
        { status: 400, headers: jsonHeaders }
      );
    }

    if (licenseKey.trim().length === 0) {
      return new Response(
        JSON.stringify({ valid: false, error: "License key cannot be empty" }),
        { status: 400, headers: jsonHeaders }
      );
    }

    const result = await pool.query(
      `
      SELECT 1
      FROM licenses l
      JOIN customers c ON c.id = l.customer_id
      WHERE c.email = $1
        AND l.license_key = $2
        AND l.status = 'active'
        AND l.expires_at > NOW()
      `,
      [email.trim().toLowerCase(), licenseKey.trim()]
    );

    const valid = result.rowCount === 1;

    return new Response(
      JSON.stringify({ valid }),
      { status: 200, headers: jsonHeaders }
    );
  } catch (err) {
    console.error("verify-license error:", err);
    return new Response(
      JSON.stringify({ valid: false, error: "Server error" }),
      { status: 500, headers: jsonHeaders }
    );
  }
}

// Handle CORS preflight
export async function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}

