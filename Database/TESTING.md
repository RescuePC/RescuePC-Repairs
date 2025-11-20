# Testing Guide

## Quick Setup Checklist

1. ✅ **Database Connection**
   - Run `vercel env pull .env.local` to get your DATABASE_URL from Vercel
   - OR manually create `.env.local` with your Neon connection string
   - Verify `.env.local` contains: `DATABASE_URL=postgres://...` or `POSTGRES_URL=postgres://...`

2. ✅ **Install Dependencies**
   ```bash
   npm install
   ```

3. ✅ **Start Dev Server**
   ```bash
   npm run dev
   ```

4. ✅ **Test API Endpoint**

## Testing the API

### Using Thunder Client / Postman

**URL:** `http://localhost:3000/api/verify-license`

**Method:** POST

**Headers:**
```
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "email": "test@example.com",
  "licenseKey": "TEST-KEY"
}
```

### Using curl

```bash
curl -X POST http://localhost:3000/api/verify-license \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","licenseKey":"TEST-KEY"}'
```

### Expected Responses

**Success (valid license):**
```json
{
  "valid": true
}
```

**Invalid/Missing License:**
```json
{
  "valid": false
}
```

**Error (missing parameters):**
```json
{
  "valid": false,
  "error": "Missing email or licenseKey"
}
```

**Error (server error):**
```json
{
  "valid": false,
  "error": "Server error"
}
```

## Troubleshooting

### Getting `{ "valid": false }`?

This is expected if:
- No matching customer/license exists in the database
- License is expired (`expires_at < NOW()`)
- License status is not `'active'`
- Email or license key doesn't match

**To test with a valid license:**
1. Insert a customer in your Neon database:
   ```sql
   INSERT INTO customers (email) VALUES ('test@example.com');
   ```

2. Insert a matching license:
   ```sql
   INSERT INTO licenses (customer_id, package_id, license_key, expires_at, status)
   VALUES (
     (SELECT id FROM customers WHERE email = 'test@example.com'),
     (SELECT id FROM packages LIMIT 1),
     'TEST-KEY',
     NOW() + INTERVAL '30 days',
     'active'
   );
   ```

3. Test again - should return `{ "valid": true }`

### Connection Errors?

- Verify `.env.local` exists and has `DATABASE_URL` or `POSTGRES_URL`
- Check your Neon database is running and accessible
- Verify the connection string is correct (no extra spaces/quotes)

### Next Steps

Once you see `{ "valid": true }` locally:
1. Copy `lib/db.ts` and `app/api/verify-license/route.ts` to your main RescuePC repo
2. Redeploy on Vercel
3. Point your `.exe` at: `https://your-rescuepc-domain.com/api/verify-license`

