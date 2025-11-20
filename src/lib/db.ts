import { Pool } from "pg";

const connectionString =
  process.env.DATABASE_URL ?? process.env.POSTGRES_URL;

if (!connectionString) {
  throw new Error("No database connection string set. Add DATABASE_URL to .env.local");
}

const pool = new Pool({
  connectionString,
});

export default pool;

