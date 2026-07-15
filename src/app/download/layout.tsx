import type { ReactNode } from "react";
import { createMetadata } from "@/lib/seo";

export const metadata = createMetadata({
  title: "Download RescuePC Repairs",
  description:
    "Get RescuePC Repairs after purchasing a valid license. License keys and download access are delivered through the secure purchase flow.",
  path: "/download/",
});

export default function DownloadLayout({ children }: { children: ReactNode }) {
  return children;
}
