// Janssen AI - PostgreSQL Database Connection
// ============================================
// Graceful: if PostgreSQL is unavailable, the app still runs
// using in-memory fallback (no persistence)
// ============================================
const { Pool } = require('pg');

let pool = null;
let dbAvailable = false;

// Support DATABASE_URL (Render, Heroku) or individual DB_ vars
const dbConfig = process.env.DATABASE_URL
  ? {
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
      connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 30000,
      max: 10
    }
  : {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'janssen_ai',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || '',
      connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 30000,
      max: 10
    };

try {
  pool = new Pool(dbConfig);

  pool.on('connect', () => {
    dbAvailable = true;
    console.log('[DB] Connected to PostgreSQL');
  });

  pool.on('error', (err) => {
    console.error('[DB] Pool error:', err.message);
    dbAvailable = false;
  });

  // Test connection on startup
  pool.query('SELECT 1')
    .then(() => {
      dbAvailable = true;
      console.log('[DB] PostgreSQL connection verified');
    })
    .catch((err) => {
      dbAvailable = false;
      console.warn('[DB] PostgreSQL unavailable — running in fallback mode:', err.message);
    });
} catch (err) {
  console.warn('[DB] Could not create pool — running in fallback mode:', err.message);
}

// Wrapper that returns empty results when DB is down instead of crashing
const db = {
  query: async (text, params) => {
    if (!pool || !dbAvailable) {
      // Return empty result set so callers don't crash
      return { rows: [], rowCount: 0 };
    }
    try {
      return await pool.query(text, params);
    } catch (err) {
      // If it's a connection error, mark DB as unavailable
      if (err.code === 'ECONNREFUSED' || err.code === '57P03' || err.code === 'ENOTFOUND') {
        dbAvailable = false;
        console.warn('[DB] Connection lost — switching to fallback mode');
      }
      throw err;
    }
  },
  isAvailable: () => dbAvailable,
  getPool: () => pool
};

module.exports = db;
