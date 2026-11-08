const fs = require('fs');
const path = require('path');

// Dynamically resolve modules from backend if running standalone
const backendDir = path.join(__dirname, '../backend');
const backendModules = path.join(backendDir, 'node_modules');

let dotenv, pg;
try {
  dotenv = require('dotenv');
} catch (e) {
  dotenv = require(path.join(backendModules, 'dotenv'));
}

try {
  pg = require('pg');
} catch (e) {
  pg = require(path.join(backendModules, 'pg'));
}

const { Client } = pg;
dotenv.config({ path: path.join(backendDir, '.env') });

const config = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'root',
  database: 'postgres' // connect to default to ensure db exists
};

const targetDb = process.env.DB_NAME || 'connekt_db';

async function runMigration() {
  console.log(`[Database Migration] Connecting to PostgreSQL on ${config.host}:${config.port}...`);
  const rootClient = new Client(config);

  try {
    await rootClient.connect();
    const checkDb = await rootClient.query(`SELECT 1 FROM pg_database WHERE datname = $1`, [targetDb]);
    if (checkDb.rowCount === 0) {
      console.log(`[Database Migration] Database '${targetDb}' does not exist. Creating...`);
      await rootClient.query(`CREATE DATABASE ${targetDb}`);
      console.log(`[Database Migration] Database '${targetDb}' created.`);
    } else {
      console.log(`[Database Migration] Database '${targetDb}' already exists.`);
    }
  } catch (err) {
    console.error(`[Database Migration] Error during database creation check:`, err.message);
  } finally {
    await rootClient.end();
  }

  // Connect to target database
  const dbClient = new Client({
    ...config,
    database: targetDb
  });

  try {
    await dbClient.connect();
    console.log(`[Database Migration] Connected to target database '${targetDb}'. Running schema...`);

    const schemaPath = path.join(__dirname, 'schema.sql');
    const sql = fs.readFileSync(schemaPath, 'utf8');

    await dbClient.query(sql);
    console.log(`[Database Migration] Schema applied successfully! All tables, indexes, and triggers initialized.`);
  } catch (err) {
    console.error(`[Database Migration] Migration failed:`, err);
    process.exit(1);
  } finally {
    await dbClient.end();
  }
}

if (require.main === module) {
  runMigration();
}

module.exports = runMigration;
