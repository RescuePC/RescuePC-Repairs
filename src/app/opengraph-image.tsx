import { ImageResponse } from "next/og";
import { DEFAULT_DESCRIPTION, SITE_NAME } from "@/lib/seo";

export const runtime = "edge";
export const alt = "RescuePC Repairs Windows repair toolkit";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

export default function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          background: "linear-gradient(135deg, #0f172a 0%, #1d4ed8 100%)",
          color: "white",
          padding: "80px",
          fontFamily: "Arial, sans-serif",
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "18px",
            fontSize: 30,
            fontWeight: 700,
            letterSpacing: "0.08em",
            textTransform: "uppercase",
            color: "#bfdbfe",
          }}
        >
          Windows Repair Software
        </div>
        <div
          style={{
            display: "flex",
            marginTop: 36,
            fontSize: 76,
            lineHeight: 1.05,
            fontWeight: 800,
            maxWidth: 960,
          }}
        >
          {SITE_NAME}
        </div>
        <div
          style={{
            display: "flex",
            marginTop: 28,
            fontSize: 30,
            lineHeight: 1.35,
            maxWidth: 940,
            color: "#dbeafe",
          }}
        >
          {DEFAULT_DESCRIPTION}
        </div>
      </div>
    ),
    size,
  );
}
