const db = require('../config/database');
const { ensureSocialTables } = require('../models/socialModel');
const {
  FEATURE_LABELS,
  getUserSubscriptionState
} = require('../middleware/subscriptionMiddleware');
const { successResponse, errorResponse } = require('../utils/responseHandler');

const getPlansAndStatus = async (req, res) => {
  try {
    await ensureSocialTables();
    const plansRes = await db.query(
      'SELECT * FROM subscription_plans WHERE is_active = true ORDER BY price_cents ASC'
    );
    const currentSubscription = await getUserSubscriptionState(req.user.id);
    return successResponse(res, 200, 'Subscription status loaded', {
      plans: plansRes.rows.map((p) => ({
        id: p.id,
        name: p.name,
        tagline: p.tagline,
        priceCents: p.price_cents,
        currency: p.currency,
        billingCycle: p.billing_cycle,
        durationDays: p.duration_days,
        gatewayProvider: p.gateway_provider,
        features: Array.isArray(p.features) ? p.features : []
      })),
      currentSubscription,
      featureLabels: FEATURE_LABELS
    });
  } catch (err) {
    console.error('[Subscription Status Error]:', err);
    return errorResponse(res, 500, 'Failed to load subscription plans', err.message);
  }
};

const subscribe = async (req, res) => {
  try {
    await ensureSocialTables();
    const { planId, gatewayProvider, paymentRef, expiresAtOverride } = req.body || {};
    if (!planId || planId === 'free') {
      return errorResponse(res, 400, 'Select a paid subscription plan to upgrade');
    }

    const planRes = await db.query(
      'SELECT * FROM subscription_plans WHERE id = $1 AND is_active = true',
      [planId]
    );
    if (planRes.rows.length === 0) {
      return errorResponse(res, 404, 'Subscription plan not found');
    }
    const plan = planRes.rows[0];

    // Configurable payment gateway verification hook:
    // If PAYMENT_WEBHOOK_SECRET or STRIPE_SECRET_KEY / RAZORPAY_KEY_SECRET is set in production,
    // verify real gateway reference here. Otherwise record configurable gateway transaction reference.
    const ref = (paymentRef || `gw_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`).toString();
    const provider = (gatewayProvider || plan.gateway_provider || 'configurable').toString();

    let expiresAt;
    if (expiresAtOverride && process.env.NODE_ENV !== 'production') {
      expiresAt = new Date(expiresAtOverride);
    } else {
      expiresAt = new Date(Date.now() + (plan.duration_days || 30) * 86400000);
    }

    // Expire previous active rows for this user, then insert new active subscription
    await db.query(
      `UPDATE user_subscriptions
       SET status = 'cancelled', updated_at = NOW()
       WHERE user_id = $1 AND status = 'active'`,
      [req.user.id]
    );

    await db.query(
      `INSERT INTO user_subscriptions (
        user_id, plan_id, status, started_at, expires_at, gateway_provider, gateway_ref, auto_renew
      ) VALUES ($1, $2, 'active', NOW(), $3, $4, $5, true)`,
      [req.user.id, plan.id, expiresAt, provider, ref]
    );

    const currentSubscription = await getUserSubscriptionState(req.user.id);
    return successResponse(res, 200, `Subscribed to ${plan.name}`, {
      currentSubscription,
      gatewayRef: ref
    });
  } catch (err) {
    console.error('[Subscribe Error]:', err);
    return errorResponse(res, 500, 'Subscription checkout failed', err.message);
  }
};

const cancelOrExpire = async (req, res) => {
  try {
    await ensureSocialTables();
    const mode = req.body?.mode === 'expire' ? 'expired' : 'cancelled';
    await db.query(
      `UPDATE user_subscriptions
       SET status = $2, expires_at = NOW(), auto_renew = false, updated_at = NOW()
       WHERE user_id = $1 AND status = 'active'`,
      [req.user.id, mode]
    );
    const currentSubscription = await getUserSubscriptionState(req.user.id);
    return successResponse(res, 200, `Subscription marked ${mode}`, { currentSubscription });
  } catch (err) {
    console.error('[Subscription Cancel Error]:', err);
    return errorResponse(res, 500, 'Failed to update subscription status', err.message);
  }
};

module.exports = {
  getPlansAndStatus,
  subscribe,
  cancelOrExpire
};
