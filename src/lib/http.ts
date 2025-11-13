import { NextResponse } from "next/server";
import { config } from "./config";

type HeaderMap = Record<string, string>;

export const buildCorsHeaders = (overrides: HeaderMap = {}): HeaderMap => {
  const headers: HeaderMap = { ...overrides };
  headers["Access-Control-Allow-Origin"] =
    overrides["Access-Control-Allow-Origin"] ?? config.security.corsOrigin;
  headers["Access-Control-Allow-Methods"] =
    overrides["Access-Control-Allow-Methods"] ?? "GET,POST,OPTIONS";
  headers["Access-Control-Allow-Headers"] =
    overrides["Access-Control-Allow-Headers"] ??
    "Content-Type, Authorization, Stripe-Signature";
  if (config.security.corsCredentials) {
    headers["Access-Control-Allow-Credentials"] = "true";
  }
  return headers;
};

export const jsonResponse = <T>(
  body: T,
  init?: { status?: number; headers?: HeaderMap }
) => {
  const headers = buildCorsHeaders(init?.headers ?? {});
  return NextResponse.json(body, {
    status: init?.status ?? 200,
    headers,
  });
};

export const emptyResponse = (
  status = 204,
  headers: HeaderMap = {}
): NextResponse => {
  return new NextResponse(null, {
    status,
    headers: buildCorsHeaders(headers),
  });
};

