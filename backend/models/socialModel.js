const fs = require('fs');
const path = require('path');
const db = require('../config/database');

let socialInitPromise = null;

/**
 * Run idempotent SQL schema migration for Social, Professional, Subscriptions, and Communities,
 * and seed configurable default subscription plans.
 */
async function ensureSocialTables() {
  if (!socialInitPromise) {
    socialInitPromise = (async () => {
      const migrationPath = path.resolve(
        __dirname,
        '../../database/migrations/004_social_community_subscriptions.sql'
      );
      const sql = fs.readFileSync(migrationPath, 'utf8');
      await db.query(sql);

      const gateway = process.env.PAYMENT_GATEWAY || 'configurable';
      const currency = process.env.SUBSCRIPTION_CURRENCY || 'INR';
      const monthlyPrice = parseInt(process.env.PRO_MONTHLY_PRICE_CENTS || '49900', 10);
      const annualPrice = parseInt(process.env.PRO_ANNUAL_PRICE_CENTS || '499900', 10);

      await db.query(
        `INSERT INTO subscription_plans (id, name, tagline, price_cents, currency, billing_cycle, duration_days, gateway_provider, features, is_active)
         VALUES
           ('free', 'Starter Free', 'Core professional profile, network & limited job applications', 0, $1, 'free', 36500, $2, $3::jsonb, true),
           ('pro_monthly', 'Connekt Pro Monthly', 'Unlock career insights, unlimited job applications, articles & recruiter tools', $4, $1, 'monthly', 30, $2, $5::jsonb, true),
           ('pro_annual', 'Connekt Pro Annual', 'Full-year Pro suite with priority visibility & recruiter publishing', $6, $1, 'annual', 365, $2, $5::jsonb, true)
         ON CONFLICT (id) DO UPDATE SET
           price_cents = CASE
             WHEN EXCLUDED.id = 'pro_monthly' THEN $4
             WHEN EXCLUDED.id = 'pro_annual' THEN $6
             ELSE subscription_plans.price_cents
           END,
           currency = EXCLUDED.currency,
           gateway_provider = EXCLUDED.gateway_provider,
           features = EXCLUDED.features`,
        [
          currency,
          gateway,
          JSON.stringify(['basic_profile', 'basic_feed', 'browse_jobs', 'standard_connect']),
          monthlyPrice,
          JSON.stringify([
            'basic_profile',
            'basic_feed',
            'browse_jobs',
            'standard_connect',
            'unlimited_job_applications',
            'profile_analytics',
            'publish_articles',
            'post_job_listings',
            'recruiter_company_tools',
            'verified_pro_badge',
            'priority_applicant'
          ]),
          annualPrice
        ]
      );
    })().catch((err) => {
      socialInitPromise = null;
      throw err;
    });
  }
  return socialInitPromise;
}

module.exports = { ensureSocialTables };
