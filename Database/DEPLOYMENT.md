# Deployment Checklist

## ✅ Step 1: Fix/Confirm lib/db.ts

**File:** `lib/db.ts`

**Should be exactly:**
```typescript
import { Pool } from "pg";

const connectionString =
  process.env.DATABASE_URL ?? process.env.POSTGRES_URL;

if (!connectionString) {
  throw new Error("No database connection string set");
}

const pool = new Pool({
  connectionString,
});

export default pool;
```

✅ **Status:** Verified - file is correct, no duplicate lines

---

## ✅ Step 2: Insert Test Data in Neon

**Run this SQL in Neon SQL Editor:**

```sql
INSERT INTO licenses (
    customer_id,
    package_id,
    license_key,
    purchased_at,
    expires_at,
    status
) VALUES (
    1,                      -- customers.id
    1,                      -- packages.id
    'TEST-KEY',             -- test license
    NOW(),
    NOW() + INTERVAL '30 days',
    'active'
);
```

**Verify:**
- Check `licenses` table shows 1 row
- `customer_id = 1` (test@example.com)
- `package_id = 1` (BASIC)
- `license_key = 'TEST-KEY'`
- `status = 'active'`
- `expires_at` is in the future

---

## ✅ Step 3: Pull Env Vars and Run Dev Server

**In your RescuePC Database folder:**

```bash
# Pull environment variables from Vercel
vercel env pull .env.local

# Verify .env.local contains:
# DATABASE_URL=postgresql://... 
# OR
# POSTGRES_URL=postgresql://...

# Install dependencies (if needed)
npm install

# Start dev server
npm run dev
```

**Check:** Server should start on `http://localhost:3000` without errors

---

## ✅ Step 4: Test /api/verify-license Locally

**With `npm run dev` running:**

**Request:**
- **URL:** `http://localhost:3000/api/verify-license`
- **Method:** POST
- **Body (JSON):**
  ```json
  {
    "email": "test@example.com",
    "licenseKey": "TEST-KEY"
  }
  ```

**Expected Response:**
```json
{
  "valid": true
}
```

**If you get `{ "valid": false }`:**
- ✅ Check email matches exactly: `test@example.com`
- ✅ Check license key is exactly: `TEST-KEY` (case-sensitive)
- ✅ Verify `status = 'active'` in Neon
- ✅ Verify `expires_at > NOW()` in Neon
- ✅ Check customer_id and package_id match

---

## ✅ Step 5: Move to Main RescuePC Project

**Copy these files to your main RescuePC web repo:**

1. **`lib/db.ts`** → Keep same path: `lib/db.ts`
2. **`app/api/verify-license/route.ts`** → Keep same path: `app/api/verify-license/route.ts`

**Verify in main repo:**
- ✅ `tsconfig.json` has `@/` alias configured:
  ```json
  "paths": {
    "@/*": ["./*"]
  }
  ```
- ✅ Vercel project already has `DATABASE_URL` environment variable set
- ✅ No need to add env vars - they're already in Vercel

**Deploy:**
```bash
git add lib/db.ts app/api/verify-license/route.ts
git commit -m "Add license verification API"
git push
```

Vercel will auto-deploy.

---

## ✅ Step 6: Test Production Endpoint

**After Vercel deployment completes:**

**Request:**
- **URL:** `https://YOUR-RESCUEPC-DOMAIN/api/verify-license`
- **Method:** POST
- **Body (JSON):**
  ```json
  {
    "email": "test@example.com",
    "licenseKey": "TEST-KEY"
  }
  ```

**Expected Response:**
```json
{
  "valid": true
}
```

---

## ✅ Step 7: Wire the .exe

**In your Windows app startup flow:**

1. Prompt user for:
   - Email
   - License key

2. Send POST request to:
   ```
   https://YOUR-RESCUEPC-DOMAIN/api/verify-license
   ```

3. Request body:
   ```json
   {
     "email": "user@example.com",
     "licenseKey": "ABC-123-XYZ"
   }
   ```

4. Handle response:
   - **If `valid === true`:**
     - Request admin rights
     - Launch GUI
     - Allow repairs
   
   - **If `valid === false`:**
     - Show "Invalid or expired license" message
     - Exit application

---

## 🎉 Success Criteria

Once all steps are complete:
- ✅ Centralized database (Neon)
- ✅ Always-on API (Vercel)
- ✅ No secrets in GitHub
- ✅ Database runs even when PC is off
- ✅ Production-ready licensing system

---

## Troubleshooting

### Local dev server won't start
- Check `.env.local` exists and has `DATABASE_URL` or `POSTGRES_URL`
- Run `vercel env pull .env.local` again

### API returns `{ "valid": false }`
- Verify test data exists in Neon
- Check email/license key match exactly (case-sensitive)
- Verify license status is `'active'` and not expired

### Production endpoint fails
- Check Vercel deployment logs
- Verify `DATABASE_URL` is set in Vercel environment variables
- Check Vercel function logs for errors

