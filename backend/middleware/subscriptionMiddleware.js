const db = require('../config/database');
const { ensureSocialTables } = require('../models/socialModel');
const { errorResponse } = require('../utils/responseHandler');

const FEATURE_LABELS = {
  unlimited_job_applications: 'Unlimited Job & Internship Applications',
  profile_analytics: 'Who Viewed Your Profile & Career Analytics',
  publish_articles: 'Publish Long-Form Professional Articles',
  post_job_listings: 'Post Job & Internship Listings',
  recruiter_company_tools: 'Create & Manage Recruiter Company Pages',
  verified_pro_badge: 'Verified Professional Pro Badge',
  priority_applicant: 'Priority Applicant Highlighting'
};

/**
 * Fetch user's current subscription status from PostgreSQL, automatically expiring
 * past-due plans and falling back cleanly to the Free plan.
 */
async function getUserSubscriptionState(userId) {
  await ensureSocialTables();

  // Auto-expire overdue active subscriptions on the server
  await db.query(
    `UPDATE user_subscriptions
     SET status = 'expired', updated_at = NOW()
     WHERE user_id = $1 AND status = 'active' AND expires_at <= NOW()`,
    [userId]
  );

  const subRes = await db.query(
    `SELECT us.id, us.plan_id, us.status, us.started_at, us.expires_at,
            us.gateway_provider, us.gateway_ref, us.auto_renew,
            sp.name AS plan_name, sp.tagline, sp.price_cents, sp.currency,
            sp.billing_cycle, sp.features
     FROM user_subscriptions us
     JOIN subscription_plans sp ON sp.id = us.plan_id
     WHERE us.user_id = $1
     ORDER BY (us.status = 'active') DESC, us.expires_at DESC
     LIMIT 1`,
    [userId]
  );

  const activeRow = subRes.rows[0];
  if (activeRow && activeRow.status === 'active' && new Date(activeRow.expires_at) > new Date()) {
    return {
      isSubscribed: activeRow.plan_id !== 'free',
      planId: activeRow.plan_id,
      planName: activeRow.plan_name,
      status: activeRow.status,
      startedAt: activeRow.started_at,
      expiresAt: activeRow.expires_at,
      gatewayProvider: activeRow.gateway_provider,
      autoRenew: activeRow.auto_renew,
      features: Array.isArray(activeRow.features) ? activeRow.features : []
    };
  }

  const freePlanRes = await db.query('SELECT * FROM subscription_plans WHERE id = $1', ['free']);
  const freePlan = freePlanRes.rows[0];
  return {
    isSubscribed: false,
    planId: 'free',
    planName: freePlan?.name || 'Starter Free',
    status: activeRow ? activeRow.status : 'free',
    startedAt: activeRow?.started_at || null,
    expiresAt: activeRow?.expires_at || null,
    gatewayProvider: freePlan?.gateway_provider || 'configurable',
    autoRenew: false,
    features: Array.isArray(freePlan?.features)
      ? freePlan.features
      : ['basic_profile', 'basic_feed', 'browse_jobs', 'standard_connect']
  };
}

/**
 * Express middleware enforcing server-side subscription feature entitlement.
 */
function requireSubscriptionFeature(featureKey) {
  return async (req, res, next) => {
    try {
      const state = await getUserSubscriptionState(req.user.id);
      if (state.features.includes(featureKey)) {
        req.subscription = state;
        return next();
      }
      return res.status(403).json({
        success: false,
        code: 'SUBSCRIPTION_REQUIRED',
        requiredFeature: featureKey,
        featureTitle: FEATURE_LABELS[featureKey] || featureKey,
        currentPlan: state.planId,
        currentStatus: state.status,
        message: `Upgrade to Connekt Pro to access ${FEATURE_LABELS[featureKey] || featureKey}.`
      });
    } catch (err) {
      console.error('[Subscription Middleware Error]:', err);
      return errorResponse(res, 500, 'Failed to verify subscription entitlement');
    }
  };
}

module.exports = {
  FEATURE_LABELS,
  getUserSubscriptionState,
  requireSubscriptionFeature
};
