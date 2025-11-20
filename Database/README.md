# RescuePC Licensing Database

Central, secure, always-on database for RescuePC licensing system.

## Architecture

- **Database**: PostgreSQL (hosted: Neon / Railway / Supabase)
- **Backend**: Next.js on Vercel
- **Frontend/App**: RescuePC.exe calls a single API endpoint
- **Secret handling**: Vercel environment variable

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Database Setup

1. Create a hosted PostgreSQL database (Neon, Railway, or Supabase)
2. Get the Postgres connection string from the provider dashboard
3. Run the SQL schema from `SOP.txt` (Part 1, Step 3) in your database console
4. Seed some test data

### 3. Environment Variables

**Option 1: Pull from Vercel (Recommended)**
```bash
vercel env pull .env.local
```
This will create `.env.local` with the same `DATABASE_URL` from your Vercel project.

**Option 2: Manual Setup**
1. Copy `.env.local.example` to `.env.local`
2. Add your `DATABASE_URL` connection string

**For Vercel deployment:**
1. Go to Project -> Settings -> Environment Variables
2. Add `DATABASE_URL` with your connection string
3. Select environments (Production, Preview)

### 4. Development

```bash
npm run dev
```

The API will be available at `http://localhost:3000/api/verify-license`

### 5. Deployment

Deploy to Vercel:

```bash
npm run build
```

Or connect your GitHub repo to Vercel for automatic deployments.

## API Endpoint

### POST `/api/verify-license`

Validates a license key for a customer.

**Request Body:**
```json
{
  "email": "user@example.com",
  "licenseKey": "ABC-123-XYZ"
}
```

**Response:**
```json
{
  "valid": true
}
```

Or on error:
```json
{
  "valid": false,
  "error": "Missing email or licenseKey"
}
```

## Testing

### Local Testing

1. Start the dev server:
```bash
npm run dev
```

2. Test the API endpoint using Thunder Client, Postman, or curl:

**URL:** `http://localhost:3000/api/verify-license`

**Method:** POST

**Body (JSON):**
```json
{
  "email": "test@example.com",
  "licenseKey": "TEST-KEY"
}
```

**Expected Response:**
- `{ "valid": false }` - Until you insert a matching row in customers + licenses
- `{ "valid": true }` - Once you insert a real license in your database

### Production Testing

Use curl or any HTTP client:

```bash
curl -X POST https://YOUR_DOMAIN/api/verify-license \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","licenseKey":"TEST-KEY"}'
```

## Project Structure

```
.
├── app/
│   └── api/
│       └── verify-license/
│           └── route.ts      # License validation endpoint
├── lib/
│   └── db.ts                 # PostgreSQL connection pool
├── SOP.txt                   # Complete setup instructions
└── package.json
```

## License

See SOP.txt for complete implementation details and testing checklist.

