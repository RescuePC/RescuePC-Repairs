# 🚀 RescuePC Automated Licensing System Setup

**Status:** Production Ready | **Cost:** FREE | **Maintenance:** Zero

This system automatically processes Stripe payments, generates licenses, and emails customers - all serverless and free.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Database Setup](#database-setup)
5. [Stripe Configuration](#stripe-configuration)
6. [Email Setup](#email-setup)
7. [Environment Variables](#environment-variables)
8. [Deployment](#deployment)
9. [Testing](#testing)
10. [Troubleshooting](#troubleshooting)

## 🎯 Overview

**What it does:**
- ✅ Processes Stripe payments automatically
- ✅ Generates unique license keys instantly
- ✅ Emails license to customers immediately
- ✅ Validates licenses in your PowerShell app
- ✅ Zero manual intervention required

**Tech Stack:**
- Next.js 14 (App Router)
- Prisma + PostgreSQL
- Stripe Webhooks
- Resend Email Service
- Vercel (deployment)

**Cost:** Completely FREE (Stripe fees only)

---

## 🏗️ Architecture

```
Stripe Payment → Webhook → Next.js API → Database → Email → Customer
     ↓              ↓          ↓         ↓        ↓        ↓
  checkout.session.completed → /api/stripe/webhook → Prisma → Resend → License Email
```

**Data Flow:**
1. Customer buys on your site
2. Stripe processes payment
3. Stripe calls your webhook
4. System generates license key
5. License saved to database
6. Email sent to customer
7. Customer enters license in app
8. App validates via API

---

## 📋 Prerequisites

### Required Accounts:
- ✅ **Stripe Account** (for payments)
- ✅ **Vercel Account** (for deployment)
- ✅ **PostgreSQL Database** (Vercel Postgres or Supabase free tier)
- ✅ **Resend Account** (free tier for email)

### Software:
- ✅ **Node.js 18+**
- ✅ **npm or yarn**
- ✅ **Git**

---

## 🗄️ Database Setup

### Option 1: Vercel Postgres (Recommended)

1. **Go to Vercel Dashboard:**
   ```
   https://vercel.com/dashboard
   ```

2. **Create Postgres Database:**
   - Go to your project → Storage → Create
   - Select "Postgres"
   - Choose plan (free tier available)
   - Copy the connection string

### Option 2: Supabase (Free Tier)

1. **Create Supabase Project:**
   ```
   https://supabase.com → Create project
   ```

2. **Get Connection String:**
   - Go to Settings → Database
   - Copy the connection string

### Initialize Database:

```powershell
# Run the setup script
.\scripts\setup-database.ps1

# Or manually:
npm install
npx prisma generate
npx prisma db push
```

---

## 💳 Stripe Configuration

### 1. Get API Keys

**Stripe Dashboard:**
```
https://dashboard.stripe.com/apikeys
```

**Copy these keys:**
- `pk_live_...` (Publishable key)
- `sk_live_...` (Secret key - keep secret!)

### 2. Create Webhook Endpoint

**In Stripe Dashboard:**
```
Developers → Webhooks → Add endpoint
```

**Endpoint URL:**
```
https://rescuepcrepairs.com/api/stripe/webhook
```

**Events to subscribe:**
- `checkout.session.completed`
- `payment_intent.succeeded`
- `charge.refunded`

**Copy Webhook Signing Secret:**
- After creating, copy the `whsec_...` key

### 3. Configure Products

**Create products in Stripe:**
```
Products → Create product
```

**Set metadata for each product:**
```json
{
  "sku": "BASIC"
}
```

**Products needed:**
- Basic License (sku: "BASIC")
- Professional License (sku: "PRO")
- Enterprise License (sku: "ENTERPRISE")
- Lifetime License (sku: "LIFETIME")

---

## 📧 Email Setup

### 1. Create Resend Account

**Sign up:**
```
https://resend.com → Sign up (free tier)
```

### 2. Verify Domain

**Add your domain:**
```
Domains → Add domain → rescuepcrepairs.com
```

**Follow DNS verification steps.**

### 3. Create API Key

**API Keys:**
```
API Keys → Create API key
```

**Copy the key:** `re_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

---

## 🔧 Environment Variables

### Local Development (.env.local):

```env
# Database
DATABASE_URL=postgresql://user:pass@host:5432/rescuepc

# Stripe
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Email
RESEND_API_KEY=re_...

# Security
JWT_SECRET=your_32_char_secret_here
API_SECRET_KEY=your_32_char_secret_here
```

### Vercel Production:

**Add to Vercel Dashboard:**
```
Project → Settings → Environment Variables
```

**Required Variables:**
- `DATABASE_URL`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `RESEND_API_KEY`
- `JWT_SECRET`
- `API_SECRET_KEY`

---

## 🚀 Deployment

### 1. Install Dependencies

```bash
npm install
```

### 2. Database Setup

```bash
# Generate Prisma client
npx prisma generate

# Push schema to database
npx prisma db push
```

### 3. Deploy to Vercel

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy
vercel --prod
```

### 4. Configure Domain

**In Vercel:**
```
Project → Settings → Domains → Add rescuepcrepairs.com
```

**Update DNS:**
```
Type: A     Name: @     Value: 76.76.21.21
Type: CNAME Name: www   Value: cname.vercel-dns.com
```

---

## 🧪 Testing

### 1. Test Webhook Locally

```bash
# Install Stripe CLI
npm install -g stripe

# Forward webhooks to local dev
stripe listen --forward-to localhost:3000/api/stripe/webhook
```

### 2. Test License Generation

```bash
# Start dev server
npm run dev

# Test health endpoint
curl http://localhost:3000/api/health

# Test license activation (use test license key)
curl -X POST http://localhost:3000/api/activate \
  -H "Content-Type: application/json" \
  -d '{"licenseKey":"XXXXX-XXXXX-XXXXX-XXXXX-XXXXX","machineId":"TEST"}'
```

### 3. Test Full Flow

1. **Create test payment in Stripe**
2. **Verify webhook received**
3. **Check database for license**
4. **Check email delivery**
5. **Test license activation**

---

## 🔧 Troubleshooting

### Database Issues

**Connection failed:**
```bash
# Test connection
npx prisma db push --preview-feature
```

**Migration issues:**
```bash
# Reset database
npx prisma migrate reset
```

### Webhook Issues

**Webhook not firing:**
- Check Stripe dashboard for webhook attempts
- Verify endpoint URL is correct
- Check webhook secret matches

**Signature verification failed:**
- Ensure webhook secret is correct
- Check Vercel environment variables

### Email Issues

**Emails not sending:**
- Check Resend API key
- Verify domain is verified
- Check spam folder

**Template issues:**
- Test email template locally
- Check HTML formatting

### License Issues

**License not generating:**
- Check database connection
- Verify Stripe metadata
- Check webhook logs

**License validation failing:**
- Check JWT secret consistency
- Verify license exists in database
- Check token expiration

---

## 📊 Monitoring

### Vercel Analytics:
- Function execution times
- Error rates
- Request volumes

### Stripe Dashboard:
- Payment success rates
- Webhook delivery status
- Failed payments

### Database:
- License creation rates
- Failed validations
- Error records

---

## 🎯 Success Metrics

**System is working when:**
- ✅ Webhooks process in <5 seconds
- ✅ License emails send in <10 seconds
- ✅ 100% payment success rate
- ✅ 99.9% uptime
- ✅ Zero manual intervention

---

## 🚨 Emergency Procedures

### Rollback Deployment:
```bash
vercel rollback
```

### Pause Webhooks:
- Disable webhook in Stripe dashboard
- Process manually if needed

### Database Recovery:
```bash
# Backup current data
npx prisma db pull

# Reset and restore
npx prisma migrate reset
```

---

**🎉 Setup Complete! Your automated licensing system is now live and processing payments 24/7!**
