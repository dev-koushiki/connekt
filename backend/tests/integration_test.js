require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const assert = require('assert');
const crypto = require('crypto');
const db = require('../config/database');
const { generateToken, hashToken } = require('../services/tokenService');

const BASE_URL = 'http://localhost:5000/api';

async function apiCall(path, { method = 'GET', token = null, body = null, headers = {} } = {}) {
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers
    },
    ...(body ? { body: JSON.stringify(body) } : {})
  });
  const text = await res.text();
  let json = {};
  try {
    json = JSON.parse(text);
  } catch (_) {}
  return { status: res.status, json };
}

async function createTempUser(suffix) {
  const username = `integ_${suffix}_${Date.now().toString().slice(-5)}`;
  const email = `${username}@connekt.me`;
  const phone = `+9199000${Math.floor(10000 + Math.random() * 89999)}`;
  const userRes = await db.query(
    `INSERT INTO users (username, email, phone, password_hash, status, is_verified, current_mode)
     VALUES ($1, $2, $3, 'hash_placeholder', 'active', true, 'common')
     RETURNING id, username, email, phone, role, current_mode`,
    [username, email, phone]
  );
  const user = userRes.rows[0];
  await db.query(
    `INSERT INTO user_profiles (user_id, full_name, display_name) VALUES ($1, $2, $2)`,
    [user.id, `User ${suffix}`]
  );
  const token = generateToken({
    id: user.id,
    username: user.username,
    email: user.email,
    role: user.role,
    currentMode: user.current_mode
  });
  const tokenHash = hashToken(token);
  await db.query(
    `INSERT INTO sessions (user_id, token_hash, expires_at)
     VALUES ($1, $2, NOW() + INTERVAL '1 day')`,
    [user.id, tokenHash]
  );
  return { user, token };
}

async function runTests() {
  const tempA = await createTempUser('alpha');
  const tempB = await createTempUser('beta');
  console.log(`Created temp test users: ${tempA.user.username}, ${tempB.user.username}`);

  try {
    // 1. Mail isolation, templates, contacts, categorization, honest external status
    const tplRes = await apiCall('/mail/templates', {
      method: 'POST',
      token: tempA.token,
      body: { name: 'Follow Up', subject: 'Hello', body: 'Checking in!' }
    });
    assert.strictEqual(tplRes.status, 201, 'Create template');

    const contactRes = await apiCall('/mail/contacts', {
      method: 'POST',
      token: tempA.token,
      body: { name: 'External Peer', email: 'external.peer@gmail.com', company: 'Gmail' }
    });
    assert.strictEqual(contactRes.status, 201, 'Create mail contact');

    // Internal mail send from A to B
    const sendInternal = await apiCall('/mail/send', {
      method: 'POST',
      token: tempA.token,
      body: {
        to: [tempB.user.email],
        subject: 'Invoice #1042 Security Update',
        body: 'Please find your **invoice** update [here](https://connekt.me).',
        htmlBody: '<p>Please find your <strong>invoice</strong> update</p>'
      }
    });
    assert.strictEqual(sendInternal.status, 200, 'Internal email send');
    const mailAId = sendInternal.json.data.message.id;

    // User B receives email in inbox categorized as 'updates'
    const mailBList = await apiCall('/mail', { token: tempB.token });
    assert.strictEqual(mailBList.status, 200);
    const received = mailBList.json.data.messages.find((m) => m.subject === 'Invoice #1042 Security Update');
    assert.ok(received, 'User B received internal email');
    assert.strictEqual(received.category, 'updates', 'Invoice update categorized as updates');

    // User-level mail isolation: User B MUST NOT delete or modify User A's sent message ID
    const crossDelete = await apiCall(`/mail/${mailAId}`, {
      method: 'DELETE',
      token: tempB.token
    });
    assert.strictEqual(crossDelete.status, 404, 'Cross-user mail delete denied cleanly');

    // External email send reports honest 'pending_smtp_config' when SMTP placeholder is present
    const sendExternal = await apiCall('/mail/send', {
      method: 'POST',
      token: tempA.token,
      body: {
        to: ['someone@gmail.com'],
        subject: 'External SMTP Check',
        body: 'Testing external email status reporting'
      }
    });
    assert.strictEqual(sendExternal.status, 200);
    const extStatus = sendExternal.json.data.message.deliveryStatus;
    assert.ok(
      ['pending_smtp_config', 'sent_external', 'failed'].includes(extStatus),
      `Unexpected deliveryStatus: ${extStatus}`
    );

    // Inbound webhook must reject missing/invalid secret
    const badInbound = await apiCall('/mail/inbound', {
      method: 'POST',
      body: { recipient: tempA.user.email, sender: 'attacker@example.com', subject: 'Fake' }
    });
    assert.strictEqual(badInbound.status, 401, 'Unauthorized inbound mail webhook rejected');

    // 2. Social Mode: Post CRUD, React, Comments/Reply, Save, Search
    const postRes = await apiCall('/social/posts', {
      method: 'POST',
      token: tempA.token,
      body: { mode: 'social', content: 'Hello CONNEKT Social!', visibility: 'public' }
    });
    assert.strictEqual(postRes.status, 201, 'Social post created');
    const postId = postRes.json.data.post.id;

    const reactRes = await apiCall(`/social/posts/${postId}/react`, {
      method: 'POST',
      token: tempB.token,
      body: { reactionType: 'love' }
    });
    assert.strictEqual(reactRes.status, 200);
    assert.strictEqual(reactRes.json.data.likesCount, 1);

    const cmt1 = await apiCall(`/social/posts/${postId}/comments`, {
      method: 'POST',
      token: tempB.token,
      body: { content: 'Congrats!' }
    });
    assert.strictEqual(cmt1.status, 201);

    const cmtReply = await apiCall(`/social/posts/${postId}/comments`, {
      method: 'POST',
      token: tempA.token,
      body: { content: 'Thanks!', parentCommentId: cmt1.json.data.comment.id }
    });
    assert.strictEqual(cmtReply.status, 201);

    const saveRes = await apiCall(`/social/posts/${postId}/save`, { method: 'POST', token: tempB.token });
    assert.strictEqual(saveRes.json.data.isSaved, true);

    // 3. Professional Mode & Server-Side Subscription Locking -> Unlocking -> Expiry -> Re-locking
    const lockedArticle = await apiCall('/professional/articles', {
      method: 'POST',
      token: tempA.token,
      body: { title: 'Locked Article', content: 'Should fail on free plan' }
    });
    assert.strictEqual(lockedArticle.status, 403, 'Free user blocked from publishing articles on server');
    assert.strictEqual(lockedArticle.json.code, 'SUBSCRIPTION_REQUIRED');

    const lockedAnalytics = await apiCall('/professional/analytics', { token: tempA.token });
    assert.strictEqual(lockedAnalytics.status, 403, 'Free user blocked from analytics on server');

    // Upgrade to Connekt Pro Monthly
    const subRes = await apiCall('/subscriptions/subscribe', {
      method: 'POST',
      token: tempA.token,
      body: { planId: 'pro_monthly' }
    });
    assert.strictEqual(subRes.status, 200);
    assert.strictEqual(subRes.json.data.currentSubscription.isSubscribed, true);

    // Now premium endpoints succeed
    const unlockedArticle = await apiCall('/professional/articles', {
      method: 'POST',
      token: tempA.token,
      body: { title: 'Unlocked Pro Article', content: 'Published after server verified subscription!' }
    });
    assert.strictEqual(unlockedArticle.status, 201, 'Subscribed user can publish article');

    const unlockedJob = await apiCall('/professional/jobs', {
      method: 'POST',
      token: tempA.token,
      body: { title: 'Flutter Engineer', jobType: 'internship', location: 'Remote' }
    });
    assert.strictEqual(unlockedJob.status, 201, 'Subscribed user can post job');
    const jobId = unlockedJob.json.data.job.id;

    // Free User B can still apply to job
    const applyB = await apiCall(`/professional/jobs/${jobId}/apply`, {
      method: 'POST',
      token: tempB.token,
      body: { coverNote: 'Interested!' }
    });
    assert.strictEqual(applyB.status, 201, 'Job application succeeded');

    // Simulate expiry -> server automatically re-locks!
    const expRes = await apiCall('/subscriptions/cancel', {
      method: 'POST',
      token: tempA.token,
      body: { mode: 'expire' }
    });
    assert.strictEqual(expRes.status, 200);
    assert.strictEqual(expRes.json.data.currentSubscription.isSubscribed, false);

    const relockedArticle = await apiCall('/professional/articles', {
      method: 'POST',
      token: tempA.token,
      body: { title: 'After Expiry', content: 'Must be blocked again' }
    });
    assert.strictEqual(relockedArticle.status, 403, 'Expired user re-locked on server');

    // 4. Communities, Groups inside Community & Community Live
    const commRes = await apiCall('/communities', {
      method: 'POST',
      token: tempA.token,
      body: { name: 'Flutter Builders', visibility: 'public', description: 'Mobile engineering community' }
    });
    assert.strictEqual(commRes.status, 201);
    const commId = commRes.json.data.community.id;

    const joinRes = await apiCall(`/communities/${commId}/join`, { method: 'POST', token: tempB.token });
    assert.strictEqual(joinRes.status, 200);

    const grpRes = await apiCall(`/communities/${commId}/groups`, {
      method: 'POST',
      token: tempA.token,
      body: { name: 'UI Architecture', topic: 'Architecture' }
    });
    assert.strictEqual(grpRes.status, 201);

    const liveRes = await apiCall(`/communities/${commId}/live`, {
      method: 'POST',
      token: tempA.token,
      body: { title: 'Live Q&A Session' }
    });
    assert.strictEqual(liveRes.status, 201);
    const liveId = liveRes.json.data.session.id;

    const liveCmt = await apiCall(`/communities/live/${liveId}/comments`, {
      method: 'POST',
      token: tempB.token,
      body: { content: 'Watching live!' }
    });
    assert.strictEqual(liveCmt.status, 201);

    const endLive = await apiCall(`/communities/live/${liveId}/end`, {
      method: 'POST',
      token: tempA.token
    });
    assert.strictEqual(endLive.status, 200);

    // 5. Phone Contact Matching & Non-CONNEKT App Invite
    const matchRes = await apiCall('/users/contacts/match', {
      method: 'POST',
      token: tempA.token,
      body: { phones: [tempB.user.phone, '+919900099999'] }
    });
    assert.strictEqual(matchRes.status, 200);
    assert.ok(
      matchRes.json.data.matches.some((u) => u.id === tempB.user.id),
      'Matched registered CONNEKT phone contact'
    );

    const inviteRes = await apiCall('/users/invite', {
      method: 'POST',
      token: tempA.token,
      body: { phone: '+919900099999', name: 'NonConnekt Friend' }
    });
    assert.strictEqual(inviteRes.status, 200);
    assert.ok(inviteRes.json.data.inviteMessage.includes('CONNEKT'), 'Invite message generated');

    console.log('ALL BACKEND INTEGRATION TESTS PASSED!');
  } finally {
    await db.query('DELETE FROM users WHERE id IN ($1, $2)', [tempA.user.id, tempB.user.id]);
    await db.pool.end();
  }
}

runTests().catch((err) => {
  console.error('INTEGRATION TEST FAILED:', err);
  process.exit(1);
});
