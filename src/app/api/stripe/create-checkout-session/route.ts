import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";

const stripeSecretKey = process.env.STRIPE_SECRET_KEY;

if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY is not set in environment variables");
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));

    // You can pass different prices or tiers later
    const priceId =
      body.priceId || process.env.STRIPE_DEFAULT_PRICE_ID || "";

    if (!priceId) {
      return NextResponse.json(
        { error: "Missing Stripe priceId" },
        { status: 400 }
      );
    }

    const planCode = body.planCode || "STANDARD_MONTHLY";
    const planName = body.planName || "RescuePC Standard Monthly";
    const productSku = body.productSku || "RESCUEPC_STANDARD";

    const origin = req.headers.get("origin") ?? process.env.NEXT_PUBLIC_APP_URL;

    const session = await stripe.checkout.sessions.create({
      mode: "subscription", // use "payment" if you want one time
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: `${origin}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/pricing?canceled=1`,
      automatic_tax: { enabled: true },
      billing_address_collection: "required",
      allow_promotion_codes: true,
      metadata: {
        plan_code: planCode,
        plan_name: planName,
        product_sku: productSku,
      },
    });

    return NextResponse.json({ url: session.url }, { status: 200 });
  } catch (err: any) {
    console.error("Error creating Stripe Checkout session", err);
    return NextResponse.json(
      {
        error: "Failed to create Stripe Checkout session",
        details: err?.message ?? "Unknown error",
      },
      { status: 500 }
    );
  }
}
