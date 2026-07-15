import type { ReactNode } from "react";
import { createMetadata } from "@/lib/seo";

export const metadata = createMetadata({
  title: "Pricing & License Plans",
  description:
    "Compare RescuePC Repairs Basic, Pro, Enterprise, and Lifetime license plans for Windows repair software and technician PC repair workflows.",
  path: "/pricing/",
});

export default function PricingLayout({ children }: { children: ReactNode }) {
  return children;
}
