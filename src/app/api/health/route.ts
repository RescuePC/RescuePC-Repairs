// Health check endpoint for license connectivity testing
// Used by PowerShell launcher to verify API availability

import { jsonResponse } from "../../../lib/http";
import { config } from "../../../lib/config";

export async function GET() {
  return jsonResponse({
    status: "healthy",
    service: "RescuePC Licensing API",
    timestamp: new Date().toISOString(),
    version: config.app.version,
    environment: config.app.env,
  });
}
