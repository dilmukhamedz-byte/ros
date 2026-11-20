import pg from 'pg';
export const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

export async function init() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS conversations(
      id TEXT PRIMARY KEY,
      device_id TEXT NOT NULL,
      title TEXT NOT NULL DEFAULT 'Новый чат',
      role TEXT NOT NULL DEFAULT 'consultant',
      created_at TIMESTAMPTZ DEFAULT now());
    CREATE TABLE IF NOT EXISTS messages(
      id SERIAL PRIMARY KEY,
      conversation_id TEXT REFERENCES conversations(id) ON DELETE CASCADE,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT now());
    CREATE TABLE IF NOT EXISTS usage_log(
      id SERIAL PRIMARY KEY,
      device_id TEXT,
      conversation_id TEXT,
      prompt_tokens INT DEFAULT 0,
      completion_tokens INT DEFAULT 0,
      cost_usd NUMERIC(10,6) DEFAULT 0,
      created_at TIMESTAMPTZ DEFAULT now());
  `);
}
