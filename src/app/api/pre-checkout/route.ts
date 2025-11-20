import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2023-10-16",
});

const planPrices = {
  standard: process.env.STRIPE_STANDARD_PRICE_ID || "price_standard",
  pro: process.env.STRIPE_PRO_PRICE_ID || "price_pro", 
  lifetime: process.env.STRIPE_LIFETIME_PRICE_ID || "price_lifetime",
};

const planMetadata = {
  standard: {
    plan_code: "STANDARD_MONTHLY",
    plan_name: "RescuePC Standard Monthly",
    product_sku: "RESCUEPC_STANDARD",
    mode: "subscription" as const,
  },
  pro: {
    plan_code: "PRO_MONTHLY", 
    plan_name: "RescuePC Pro Monthly",
    product_sku: "RESCUEPC_PRO",
    mode: "subscription" as const,
  },
  lifetime: {
    plan_code: "OWNER_LIFETIME",
    plan_name: "RescuePC Lifetime",
    product_sku: "RESCUEPC_OWNER",
    mode: "payment" as const,
  },
};

export async function POST(req: NextRequest) {
  try {
    const { email, plan } = await req.json();

    if (!email || !plan || !planPrices[plan as keyof typeof planPrices]) {
      return NextResponse.json(
        { error: "Invalid email or plan" },
        { status: 400 }
      );
    }

    const planKey = plan as keyof typeof planPrices;
    const metadata = planMetadata[planKey];
    const priceId = planPrices[planKey];

    // Create pending customer record
    const customer = await prisma.test_customers.upsert({
      where: { email },
      update: { 
        created_at: new Date(), // Update timestamp on retry
      },
      create: {
        email,
      },
    });

    // Create Stripe checkout session
    const origin = req.headers.get("origin") ?? process.env.NEXT_PUBLIC_APP_URL;

    const session = await stripe.checkout.sessions.create({
      mode: metadata.mode,
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: `${origin}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/download?canceled=1`,
      customer_email: email,
      metadata: {
        plan_code: metadata.plan_code,
        plan_name: metadata.plan_name,
        product_sku: metadata.product_sku,
        customer_id: customer.id.toString(),
      },
    });

    return NextResponse.json({ 
      checkoutUrl: session.url,
      customerId: customer.id 
    });
  } catch (err: any) {
    console.error("Pre-checkout error:", err);
    return NextResponse.json(
      { error: "Failed to start checkout" },
      { status: 500 }
    );
  }
}
