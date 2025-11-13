import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

const HTTPS_STATUS = 308;

export function middleware(req: NextRequest) {
  const proto = req.headers.get("x-forwarded-proto");

  if (proto && proto !== "https") {
    const url = new URL(req.url);
    url.protocol = "https:";
    return NextResponse.redirect(url, HTTPS_STATUS);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|robots.txt|sitemap.xml|api/health).*)",
  ],
};

