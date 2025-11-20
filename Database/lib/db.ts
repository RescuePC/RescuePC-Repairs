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

