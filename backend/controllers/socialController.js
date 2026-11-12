const db = require('../config/database');
const { ensureSocialTables } = require('../models/socialModel');
const { successResponse, errorResponse } = require('../utils/responseHandler');

async function formatPostRows(rows, currentUserId) {
  return rows.map((r) => ({
    id: r.id,
    authorId: r.author_id,
    authorUsername: r.author_username,
    authorName: r.author_name || r.author_username,
    authorAvatarUrl: r.author_avatar_url || null,
    authorHeadline: r.author_headline || '',
    authorIsPro: r.author_is_pro === true,
    mode: r.mode,
    communityId: r.community_id,
    groupId: r.group_id,
    postType: r.post_type,
    title: r.title || '',
    content: r.content || '',
    mediaUrls: Array.isArray(r.media_urls) ? r.media_urls : [],
    sharedPostId: r.shared_post_id || null,
    sharedPostAuthor: r.shared_post_author || null,
    sharedPostContent: r.shared_post_content || null,
    visibility: r.visibility || 'public',
    likesCount: r.likes_count || 0,
    commentsCount: r.comments_count || 0,
    sharesCount: r.shares_count || 0,
    isPinned: r.is_pinned === true,
    myReaction: r.my_reaction || null,
    isSaved: r.is_saved === true,
    isOwnPost: r.author_id === currentUserId,
    createdAt: r.created_at
  }));
}

const getFeed = async (req, res) => {
  try {
    await ensureSocialTables();
    const userId = req.user.id;
    const mode = req.query.mode === 'professional' ? 'professional' : 'social';
    const filter = (req.query.filter || 'all').toString();

    const params = [userId, mode];
    let extraWhere = '';
    if (filter === 'saved') {
      extraWhere = 'AND sp.user_id IS NOT NULL';
    } else if (filter === 'following') {
      extraWhere = 'AND (p.author_id = $1 OR EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = $1 AND f.following_id = p.author_id))';
    }

    const orderBy =
      filter === 'trending'
        ? '(p.likes_count * 3 + p.comments_count * 4 + p.shares_count * 5) DESC, p.created_at DESC'
        : 'p.created_at DESC';

    const queryRes = await db.query(
      `SELECT p.*,
              u.username AS author_username,
              COALESCE(NULLIF(up.display_name, ''), NULLIF(up.full_name, ''), u.username) AS author_name,
              up.avatar_url AS author_avatar_url,
              COALESCE(pp.headline, '') AS author_headline,
              EXISTS (
                SELECT 1 FROM user_subscriptions us
                WHERE us.user_id = p.author_id AND us.status = 'active' AND us.expires_at > NOW() AND us.plan_id <> 'free'
              ) AS author_is_pro,
              pr.reaction_type AS my_reaction,
              (sp.user_id IS NOT NULL) AS is_saved,
              COALESCE(NULLIF(sup.display_name, ''), NULLIF(sup.full_name, ''), su.username) AS shared_post_author,
              sh.content AS shared_post_content
       FROM social_posts p
       JOIN users u ON u.id = p.author_id
       LEFT JOIN user_profiles up ON up.user_id = p.author_id
       LEFT JOIN professional_profiles pp ON pp.user_id = p.author_id
       LEFT JOIN post_reactions pr ON pr.post_id = p.id AND pr.user_id = $1
       LEFT JOIN saved_posts sp ON sp.post_id = p.id AND sp.user_id = $1
       LEFT JOIN social_posts sh ON sh.id = p.shared_post_id
       LEFT JOIN users su ON su.id = sh.author_id
       LEFT JOIN user_profiles sup ON sup.user_id = su.id
       WHERE p.mode = $2
         AND p.community_id IS NULL
         AND NOT EXISTS (
           SELECT 1 FROM blocked_users b
           WHERE (b.blocker_id = $1 AND b.blocked_id = p.author_id)
              OR (b.blocker_id = p.author_id AND b.blocked_id = $1)
         )
         AND (
           p.visibility = 'public'
           OR p.author_id = $1
           OR (
             p.visibility IN ('friends', 'connections')
             AND EXISTS (
               SELECT 1 FROM friendships fr
               WHERE fr.status = 'accepted'
                 AND ((fr.requester_id = $1 AND fr.addressee_id = p.author_id)
                   OR (fr.requester_id = p.author_id AND fr.addressee_id = $1))
             )
           )
         )
         ${extraWhere}
       ORDER BY ${orderBy}
       LIMIT 60`,
      params
    );

    const posts = await formatPostRows(queryRes.rows, userId);
    return successResponse(res, 200, 'Feed loaded', { posts });
  } catch (err) {
    console.error('[Social Feed Error]:', err);
    return errorResponse(res, 500, 'Failed to load feed', err.message);
  }
};

const createPost = async (req, res) => {
  try {
    await ensureSocialTables();
    const {
      mode = 'social',
      postType = 'text',
      title = '',
      content = '',
      mediaUrls = [],
      visibility = 'public',
      sharedPostId = null
    } = req.body || {};

    if (!content.toString().trim() && (!Array.isArray(mediaUrls) || mediaUrls.length === 0) && !sharedPostId) {
      return errorResponse(res, 400, 'Post content or media is required');
    }

    const safeMode = mode === 'professional' ? 'professional' : 'social';
    const insertRes = await db.query(
      `INSERT INTO social_posts (
        author_id, mode, post_type, title, content, media_urls, shared_post_id, visibility
      ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8)
      RETURNING *`,
      [
        req.user.id,
        safeMode,
        postType,
        title.toString().trim(),
        content.toString().trim(),
        JSON.stringify(Array.isArray(mediaUrls) ? mediaUrls : []),
        sharedPostId || null,
        visibility
      ]
    );

    if (sharedPostId) {
      await db.query('UPDATE social_posts SET shares_count = shares_count + 1 WHERE id = $1', [sharedPostId]);
    }

    const enriched = await db.query(
      `SELECT p.*, u.username AS author_username,
              COALESCE(NULLIF(up.display_name, ''), NULLIF(up.full_name, ''), u.username) AS author_name,
              up.avatar_url AS author_avatar_url,
              COALESCE(pp.headline, '') AS author_headline,
              false AS author_is_pro, null AS my_reaction, false AS is_saved,
              null AS shared_post_author, null AS shared_post_content
       FROM social_posts p
       JOIN users u ON u.id = p.author_id
       LEFT JOIN user_profiles up ON up.user_id = p.author_id
       LEFT JOIN professional_profiles pp ON pp.user_id = p.author_id
       WHERE p.id = $1`,
      [insertRes.rows[0].id]
    );

    const [post] = await formatPostRows(enriched.rows, req.user.id);
    return successResponse(res, 201, 'Post published', { post });
  } catch (err) {
    console.error('[Social Create Post Error]:', err);
    return errorResponse(res, 500, 'Failed to create post', err.message);
  }
};

const updatePost = async (req, res) => {
  try {
    await ensureSocialTables();
    const { title, content, visibility } = req.body || {};
    const resUpd = await db.query(
      `UPDATE social_posts
       SET title = COALESCE($1, title),
           content = COALESCE($2, content),
           visibility = COALESCE($3, visibility),
           updated_at = NOW()
       WHERE id = $4 AND author_id = $5
       RETURNING id, title, content, visibility`,
      [title ?? null, content ?? null, visibility ?? null, req.params.id, req.user.id]
    );
    if (resUpd.rows.length === 0) {
      return errorResponse(res, 404, 'Post not found or unauthorized');
    }
    return successResponse(res, 200, 'Post updated', { post: resUpd.rows[0] });
  } catch (err) {
    console.error('[Social Update Post Error]:', err);
    return errorResponse(res, 500, 'Failed to update post', err.message);
  }
};

const deletePost = async (req, res) => {
  try {
    await ensureSocialTables();
    const resDel = await db.query(
      'DELETE FROM social_posts WHERE id = $1 AND author_id = $2 RETURNING id',
      [req.params.id, req.user.id]
    );
    if (resDel.rowCount === 0) {
      return errorResponse(res, 404, 'Post not found or unauthorized');
    }
    return successResponse(res, 200, 'Post deleted');
  } catch (err) {
    console.error('[Social Delete Post Error]:', err);
    return errorResponse(res, 500, 'Failed to delete post', err.message);
  }
};

const reactToPost = async (req, res) => {
  try {
    await ensureSocialTables();
    const postId = req.params.id;
    const reactionType = (req.body?.reactionType || 'like').toString();

    const existing = await db.query(
      'SELECT reaction_type FROM post_reactions WHERE post_id = $1 AND user_id = $2',
      [postId, req.user.id]
    );

    let myReaction = reactionType;
    if (existing.rows.length > 0 && existing.rows[0].reaction_type === reactionType) {
      await db.query('DELETE FROM post_reactions WHERE post_id = $1 AND user_id = $2', [postId, req.user.id]);
      myReaction = null;
    } else {
      await db.query(
        `INSERT INTO post_reactions (post_id, user_id, reaction_type)
         VALUES ($1, $2, $3)
         ON CONFLICT (post_id, user_id) DO UPDATE SET reaction_type = EXCLUDED.reaction_type`,
        [postId, req.user.id, reactionType]
      );
    }

    const cntRes = await db.query(
      'SELECT COUNT(*)::int AS cnt FROM post_reactions WHERE post_id = $1',
      [postId]
    );
    const likesCount = cntRes.rows[0].cnt;
    const postRes = await db.query(
      'UPDATE social_posts SET likes_count = $1 WHERE id = $2 RETURNING author_id, title, content',
      [likesCount, postId]
    );

    const authorId = postRes.rows[0]?.author_id;
    if (myReaction && authorId && authorId !== req.user.id) {
      await db.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'post_reaction', $2, $3, $4::jsonb)`,
        [
          authorId,
          `${req.user.username} reacted (${myReaction}) to your post`,
          (postRes.rows[0].content || postRes.rows[0].title || '').slice(0, 80),
          JSON.stringify({ postId })
        ]
      ).catch(() => {});
    }

    return successResponse(res, 200, 'Reaction updated', { likesCount, myReaction });
  } catch (err) {
    console.error('[Social React Error]:', err);
    return errorResponse(res, 500, 'Failed to react to post', err.message);
  }
};

const getComments = async (req, res) => {
  try {
    await ensureSocialTables();
    const resCmt = await db.query(
      `SELECT c.*, u.username,
              COALESCE(NULLIF(up.display_name, ''), NULLIF(up.full_name, ''), u.username) AS author_name,
              up.avatar_url AS author_avatar_url
       FROM post_comments c
       JOIN users u ON u.id = c.user_id
       LEFT JOIN user_profiles up ON up.user_id = c.user_id
       WHERE c.post_id = $1
         AND NOT EXISTS (
           SELECT 1 FROM blocked_users b
           WHERE (b.blocker_id = $2 AND b.blocked_id = c.user_id)
              OR (b.blocker_id = c.user_id AND b.blocked_id = $2)
         )
       ORDER BY c.created_at ASC`,
      [req.params.id, req.user.id]
    );
    return successResponse(res, 200, 'Comments loaded', {
      comments: resCmt.rows.map((c) => ({
        id: c.id,
        postId: c.post_id,
        userId: c.user_id,
        username: c.username,
        authorName: c.author_name,
        authorAvatarUrl: c.author_avatar_url,
        parentCommentId: c.parent_comment_id,
        content: c.content,
        createdAt: c.created_at
      }))
    });
  } catch (err) {
    console.error('[Social Get Comments Error]:', err);
    return errorResponse(res, 500, 'Failed to load comments', err.message);
  }
};

const addComment = async (req, res) => {
  try {
    await ensureSocialTables();
    const content = (req.body?.content || '').toString().trim();
    const parentCommentId = req.body?.parentCommentId || null;
    if (!content) return errorResponse(res, 400, 'Comment cannot be empty');

    const ins = await db.query(
      `INSERT INTO post_comments (post_id, user_id, parent_comment_id, content)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [req.params.id, req.user.id, parentCommentId, content]
    );
    const cntRes = await db.query(
      'SELECT COUNT(*)::int AS cnt FROM post_comments WHERE post_id = $1',
      [req.params.id]
    );
    const postRes = await db.query(
      'UPDATE social_posts SET comments_count = $1 WHERE id = $2 RETURNING author_id',
      [cntRes.rows[0].cnt, req.params.id]
    );

    const authorId = postRes.rows[0]?.author_id;
    if (authorId && authorId !== req.user.id) {
      await db.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'post_comment', $2, $3, $4::jsonb)`,
        [
          authorId,
          `${req.user.username} commented on your post`,
          content.slice(0, 90),
          JSON.stringify({ postId: req.params.id })
        ]
      ).catch(() => {});
    }

    return successResponse(res, 201, 'Comment added', {
      comment: {
        id: ins.rows[0].id,
        postId: ins.rows[0].post_id,
        userId: req.user.id,
        username: req.user.username,
        authorName: req.user.username,
        parentCommentId: ins.rows[0].parent_comment_id,
        content: ins.rows[0].content,
        createdAt: ins.rows[0].created_at
      },
      commentsCount: cntRes.rows[0].cnt
    });
  } catch (err) {
    console.error('[Social Add Comment Error]:', err);
    return errorResponse(res, 500, 'Failed to add comment', err.message);
  }
};

const toggleSavePost = async (req, res) => {
  try {
    await ensureSocialTables();
    const existing = await db.query(
      'SELECT user_id FROM saved_posts WHERE user_id = $1 AND post_id = $2',
      [req.user.id, req.params.id]
    );
    let isSaved;
    if (existing.rows.length > 0) {
      await db.query('DELETE FROM saved_posts WHERE user_id = $1 AND post_id = $2', [req.user.id, req.params.id]);
      isSaved = false;
    } else {
      await db.query('INSERT INTO saved_posts (user_id, post_id) VALUES ($1, $2)', [req.user.id, req.params.id]);
      isSaved = true;
    }
    return successResponse(res, 200, isSaved ? 'Post saved' : 'Removed from saved posts', { isSaved });
  } catch (err) {
    console.error('[Social Save Post Error]:', err);
    return errorResponse(res, 500, 'Failed to toggle save', err.message);
  }
};

const shareWithUsers = async (req, res) => {
  try {
    await ensureSocialTables();
    const { recipientIds = [], note = '' } = req.body || {};
    if (!Array.isArray(recipientIds) || recipientIds.length === 0) {
      return errorResponse(res, 400, 'Select at least one recipient');
    }
    await db.query('UPDATE social_posts SET shares_count = shares_count + 1 WHERE id = $1', [req.params.id]);

    for (const targetId of recipientIds) {
      await db.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'post_shared', $2, $3, $4::jsonb)`,
        [
          targetId,
          `${req.user.username} shared a post with you`,
          note ? note.toString().slice(0, 120) : 'Tap to view shared post',
          JSON.stringify({ postId: req.params.id, sharedBy: req.user.id })
        ]
      ).catch(() => {});
    }
    return successResponse(res, 200, 'Post shared with selected users');
  } catch (err) {
    console.error('[Social Share Users Error]:', err);
    return errorResponse(res, 500, 'Failed to share post', err.message);
  }
};

const getPeopleOverview = async (req, res) => {
  try {
    await ensureSocialTables();
    const userId = req.user.id;
    const kind = req.query.kind === 'professional' ? 'professional' : 'friend';

    const connRes = await db.query(
      `SELECT f.id AS request_id, f.requester_id, f.addressee_id, f.kind, f.status,
              u.id AS peer_id, u.username, u.email,
              COALESCE(NULLIF(up.display_name, ''), NULLIF(up.full_name, ''), u.username) AS full_name,
              up.avatar_url, up.bio, COALESCE(pp.headline, '') AS headline
       FROM friendships f
       JOIN users u ON u.id = CASE WHEN f.requester_id = $1 THEN f.addressee_id ELSE f.requester_id END
       LEFT JOIN user_profiles up ON up.user_id = u.id
       LEFT JOIN professional_profiles pp ON pp.user_id = u.id
       WHERE (f.requester_id = $1 OR f.addressee_id = $1)
         AND f.kind = $2
         AND NOT EXISTS (
           SELECT 1 FROM blocked_users b
           WHERE (b.blocker_id = $1 AND b.blocked_id = u.id) OR (b.blocker_id = u.id AND b.blocked_id = $1)
         )`,
      [userId, kind]
    );

    const followRes = await db.query('SELECT following_id FROM follows WHERE follower_id = $1', [userId]);
    const followerCntRes = await db.query('SELECT COUNT(*)::int AS cnt FROM follows WHERE following_id = $1', [userId]);

    const suggestionsRes = await db.query(
      `SELECT u.id, u.username, u.email,
              COALESCE(NULLIF(up.display_name, ''), NULLIF(up.full_name, ''), u.username) AS full_name,
              up.avatar_url, up.bio, COALESCE(pp.headline, '') AS headline
       FROM users u
       LEFT JOIN user_profiles up ON up.user_id = u.id
       LEFT JOIN professional_profiles pp ON pp.user_id = u.id
       WHERE u.id <> $1 AND u.status = 'active'
         AND NOT EXISTS (
           SELECT 1 FROM friendships f
           WHERE f.kind = $2 AND ((f.requester_id = $1 AND f.addressee_id = u.id) OR (f.requester_id = u.id AND f.addressee_id = $1))
         )
         AND NOT EXISTS (
           SELECT 1 FROM blocked_users b
           WHERE (b.blocker_id = $1 AND b.blocked_id = u.id) OR (b.blocker_id = u.id AND b.blocked_id = $1)
         )
       ORDER BY u.created_at DESC
       LIMIT 20`,
      [userId, kind]
    );

    const notifRes = await db.query(
      `SELECT id, type, title, body, data, is_read, created_at
       FROM notifications
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 40`,
      [userId]
    );

    const friends = [];
    const incomingRequests = [];
    const outgoingRequests = [];

    for (const row of connRes.rows) {
      const person = {
        requestId: row.request_id,
        id: row.peer_id,
        username: row.username,
        email: row.email,
        fullName: row.full_name,
        avatarUrl: row.avatar_url,
        bio: row.bio || '',
        headline: row.headline || '',
        status: row.status
      };
      if (row.status === 'accepted') friends.push(person);
      else if (row.status === 'pending' && row.addressee_id === userId) incomingRequests.push(person);
      else if (row.status === 'pending' && row.requester_id === userId) outgoingRequests.push(person);
    }

    return successResponse(res, 200, 'Connections loaded', {
      connections: friends,
      incomingRequests,
      outgoingRequests,
      followingIds: followRes.rows.map((r) => r.following_id),
      followersCount: followerCntRes.rows[0].cnt,
      suggestions: suggestionsRes.rows.map((s) => ({
        id: s.id,
        username: s.username,
        email: s.email,
        fullName: s.full_name,
        avatarUrl: s.avatar_url,
        bio: s.bio || '',
        headline: s.headline || ''
      })),
      notifications: notifRes.rows
    });
  } catch (err) {
    console.error('[Social People Error]:', err);
    return errorResponse(res, 500, 'Failed to load people & connections', err.message);
  }
};

const searchUsers = async (req, res) => {
  try {
    await ensureSocialTables();
    const q = `%${(req.query.q || '').toString().trim()}%`;
    const resUsers = await db.query(
      `SELECT u.id, u.username, u.email,
              COALESCE(NULLIF(up.display_name, ''), NULLIF(up.full_name, ''), u.username) AS full_name,
              up.avatar_url, up.bio, COALESCE(pp.headline, '') AS headline
       FROM users u
       LEFT JOIN user_profiles up ON up.user_id = u.id
       LEFT JOIN professional_profiles pp ON pp.user_id = u.id
       WHERE u.id <> $1 AND u.status = 'active'
         AND (u.username ILIKE $2 OR up.full_name ILIKE $2 OR up.display_name ILIKE $2 OR pp.headline ILIKE $2)
         AND NOT EXISTS (
           SELECT 1 FROM blocked_users b
           WHERE (b.blocker_id = $1 AND b.blocked_id = u.id) OR (b.blocker_id = u.id AND b.blocked_id = $1)
         )
       LIMIT 30`,
      [req.user.id, q]
    );
    return successResponse(res, 200, 'Users found', {
      users: resUsers.rows.map((u) => ({
        id: u.id,
        username: u.username,
        email: u.email,
        fullName: u.full_name,
        avatarUrl: u.avatar_url,
        bio: u.bio || '',
        headline: u.headline || ''
      }))
    });
  } catch (err) {
    console.error('[Social Search Error]:', err);
    return errorResponse(res, 500, 'Failed to search users', err.message);
  }
};

const getUserProfile = async (req, res) => {
  try {
    await ensureSocialTables();
    const targetId = req.params.id;
    const viewerId = req.user.id;

    const blockedRes = await db.query(
      `SELECT 1 FROM blocked_users
       WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1)`,
      [viewerId, targetId]
    );
    if (blockedRes.rows.length > 0) {
      return errorResponse(res, 403, 'Profile unavailable due to block settings');
    }

    const userRes = await db.query(
      `SELECT u.id, u.username, u.email,
              up.full_name, up.display_name, up.bio, up.avatar_url, up.cover_url, up.location, up.website,
              pp.headline, COALESCE(NULLIF(pp.about, ''), pp.summary, '') AS about, pp.industry, pp.banner_url, pp.resume_url, pp.portfolio_url, pp.contact_email, pp.github_url,
              ps.profile_visibility
       FROM users u
       LEFT JOIN user_profiles up ON up.user_id = u.id
       LEFT JOIN professional_profiles pp ON pp.user_id = u.id
       LEFT JOIN privacy_settings ps ON ps.user_id = u.id
       WHERE u.id = $1`,
      [targetId]
    );
    if (userRes.rows.length === 0) return errorResponse(res, 404, 'User not found');
    const row = userRes.rows[0];

    if (viewerId !== targetId) {
      await db.query(
        'INSERT INTO profile_views (profile_user_id, viewer_user_id, mode) VALUES ($1, $2, $3)',
        [targetId, viewerId, req.query.mode || 'social']
      ).catch(() => {});
    }

    const [friendsCnt, followersCnt, skillsRes, expRes, eduRes, certsRes, projsRes, recsRes] = await Promise.all([
      db.query(
        `SELECT COUNT(*)::int AS cnt FROM friendships
         WHERE status = 'accepted' AND (requester_id = $1 OR addressee_id = $1)`,
        [targetId]
      ),
      db.query('SELECT COUNT(*)::int AS cnt FROM follows WHERE following_id = $1', [targetId]),
      db.query(
        `SELECT s.id, s.skill_name, s.proficiency, s.endorsed_count,
                EXISTS(SELECT 1 FROM skill_endorsements se WHERE se.skill_id = s.id AND se.endorser_id = $2) AS endorsed_by_me
         FROM user_skills s WHERE s.user_id = $1 ORDER BY s.endorsed_count DESC`,
        [targetId, viewerId]
      ),
      db.query('SELECT * FROM user_experience WHERE user_id = $1 ORDER BY is_current DESC, start_date DESC', [targetId]),
      db.query('SELECT * FROM user_education WHERE user_id = $1 ORDER BY end_year DESC', [targetId]),
      db.query('SELECT * FROM user_certifications WHERE user_id = $1 ORDER BY created_at DESC', [targetId]),
      db.query('SELECT * FROM user_projects WHERE user_id = $1 ORDER BY created_at DESC', [targetId]),
      db.query(
        `SELECT r.*, COALESCE(NULLIF(up.full_name, ''), u.username) AS author_name, COALESCE(pp.headline, '') AS author_headline
         FROM professional_recommendations r
         JOIN users u ON u.id = r.author_id
         LEFT JOIN user_profiles up ON up.user_id = u.id
         LEFT JOIN professional_profiles pp ON pp.user_id = u.id
         WHERE r.recipient_id = $1 ORDER BY r.created_at DESC`,
        [targetId]
      )
    ]);

    return successResponse(res, 200, 'Profile loaded', {
      profile: {
        id: row.id,
        username: row.username,
        email: row.email,
        fullName: row.full_name || row.username,
        displayName: row.display_name || row.full_name || row.username,
        bio: row.bio || '',
        avatarUrl: row.avatar_url,
        coverUrl: row.cover_url,
        location: row.location || '',
        website: row.website || '',
        headline: row.headline || '',
        about: row.about || '',
        industry: row.industry || '',
        bannerUrl: row.banner_url,
        resumeUrl: row.resume_url,
        portfolioUrl: row.portfolio_url || '',
        contactEmail: row.contact_email || row.email,
        githubUrl: row.github_url || '',
        profileVisibility: row.profile_visibility || 'public',
        friendsCount: friendsCnt.rows[0].cnt,
        followersCount: followersCnt.rows[0].cnt,
        skills: skillsRes.rows,
        experience: expRes.rows,
        education: eduRes.rows,
        certifications: certsRes.rows,
        projects: projsRes.rows,
        recommendations: recsRes.rows
      }
    });
  } catch (err) {
    console.error('[Social Get Profile Error]:', err);
    return errorResponse(res, 500, 'Failed to load profile', err.message);
  }
};

const sendConnectionRequest = async (req, res) => {
  try {
    await ensureSocialTables();
    const { addresseeId, kind = 'friend' } = req.body || {};
    if (!addresseeId || addresseeId === req.user.id) {
      return errorResponse(res, 400, 'Valid target user is required');
    }
    const safeKind = kind === 'professional' ? 'professional' : 'friend';

    const existing = await db.query(
      `SELECT id, status FROM friendships
       WHERE kind = $3 AND ((requester_id = $1 AND addressee_id = $2) OR (requester_id = $2 AND addressee_id = $1))`,
      [req.user.id, addresseeId, safeKind]
    );
    if (existing.rows.length > 0) {
      return successResponse(res, 200, 'Request already exists', { request: existing.rows[0] });
    }

    const ins = await db.query(
      `INSERT INTO friendships (requester_id, addressee_id, kind, status)
       VALUES ($1, $2, $3, 'pending') RETURNING *`,
      [req.user.id, addresseeId, safeKind]
    );

    await db.query(
      `INSERT INTO notifications (user_id, type, title, body, data)
       VALUES ($1, 'connection_request', $2, $3, $4::jsonb)`,
      [
        addresseeId,
        `${req.user.username} sent you a ${safeKind === 'professional' ? 'connection' : 'friend'} request`,
        'Tap to accept or reject',
        JSON.stringify({ requesterId: req.user.id, kind: safeKind })
      ]
    ).catch(() => {});

    return successResponse(res, 201, 'Request sent', { request: ins.rows[0] });
  } catch (err) {
    console.error('[Send Connection Error]:', err);
    return errorResponse(res, 500, 'Failed to send request', err.message);
  }
};

const respondConnectionRequest = async (req, res) => {
  try {
    await ensureSocialTables();
    const status = req.body?.action === 'accept' ? 'accepted' : 'rejected';
    const upd = await db.query(
      `UPDATE friendships SET status = $1, updated_at = NOW()
       WHERE id = $2 AND addressee_id = $3
       RETURNING *`,
      [status, req.params.id, req.user.id]
    );
    if (upd.rows.length === 0) return errorResponse(res, 404, 'Request not found');
    return successResponse(res, 200, `Request ${status}`, { request: upd.rows[0] });
  } catch (err) {
    console.error('[Respond Connection Error]:', err);
    return errorResponse(res, 500, 'Failed to update request', err.message);
  }
};

const toggleFollow = async (req, res) => {
  try {
    await ensureSocialTables();
    const targetId = req.params.id;
    if (targetId === req.user.id) return errorResponse(res, 400, 'Cannot follow yourself');

    const exists = await db.query(
      'SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2',
      [req.user.id, targetId]
    );
    let isFollowing;
    if (exists.rows.length > 0) {
      await db.query('DELETE FROM follows WHERE follower_id = $1 AND following_id = $2', [req.user.id, targetId]);
      isFollowing = false;
    } else {
      await db.query('INSERT INTO follows (follower_id, following_id) VALUES ($1, $2)', [req.user.id, targetId]);
      isFollowing = true;
    }
    return successResponse(res, 200, isFollowing ? 'Followed user' : 'Unfollowed user', { isFollowing });
  } catch (err) {
    console.error('[Toggle Follow Error]:', err);
    return errorResponse(res, 500, 'Failed to update follow', err.message);
  }
};

const updateSocialProfile = async (req, res) => {
  try {
    await ensureSocialTables();
    const { fullName, displayName, bio, location, website, coverUrl, avatarUrl, profileVisibility } = req.body || {};

    await db.query(
      `INSERT INTO user_profiles (user_id, full_name) VALUES ($1, $2) ON CONFLICT (user_id) DO NOTHING`,
      [req.user.id, req.user.username]
    );

    const upd = await db.query(
      `UPDATE user_profiles
       SET full_name = COALESCE($1, full_name),
           display_name = COALESCE($2, display_name),
           bio = COALESCE($3, bio),
           location = COALESCE($4, location),
           website = COALESCE($5, website),
           cover_url = COALESCE($6, cover_url),
           avatar_url = COALESCE($7, avatar_url),
           updated_at = NOW()
       WHERE user_id = $8
       RETURNING *`,
      [
        fullName ?? null,
        displayName ?? null,
        bio ?? null,
        location ?? null,
        website ?? null,
        coverUrl ?? null,
        avatarUrl ?? null,
        req.user.id
      ]
    );

    if (profileVisibility) {
      await db.query(
        `INSERT INTO privacy_settings (user_id, profile_visibility) VALUES ($1, $2)
         ON CONFLICT (user_id) DO UPDATE SET profile_visibility = EXCLUDED.profile_visibility, updated_at = NOW()`,
        [req.user.id, profileVisibility]
      );
    }

    return successResponse(res, 200, 'Social profile updated', { profile: upd.rows[0] });
  } catch (err) {
    console.error('[Social Profile Update Error]:', err);
    return errorResponse(res, 500, 'Failed to update profile', err.message);
  }
};

const blockUser = async (req, res) => {
  try {
    await ensureSocialTables();
    const targetId = req.params.id;
    if (targetId === req.user.id) return errorResponse(res, 400, 'Cannot block yourself');

    await db.query(
      `INSERT INTO blocked_users (blocker_id, blocked_id, reason)
       VALUES ($1, $2, $3) ON CONFLICT (blocker_id, blocked_id) DO NOTHING`,
      [req.user.id, targetId, req.body?.reason || 'User blocked']
    );
    await db.query(
      'DELETE FROM friendships WHERE (requester_id = $1 AND addressee_id = $2) OR (requester_id = $2 AND addressee_id = $1)',
      [req.user.id, targetId]
    );
    return successResponse(res, 200, 'User blocked');
  } catch (err) {
    console.error('[Block User Error]:', err);
    return errorResponse(res, 500, 'Failed to block user', err.message);
  }
};

const reportContent = async (req, res) => {
  try {
    await ensureSocialTables();
    const { targetType = 'post', targetId, reason = 'Inappropriate content' } = req.body || {};
    if (!targetId) return errorResponse(res, 400, 'targetId is required');
    await db.query(
      `INSERT INTO reports (reporter_id, reported_target_type, reported_target_id, reason)
       VALUES ($1, $2, $3, $4)`,
      [req.user.id, targetType, targetId, reason.toString()]
    );
    return successResponse(res, 201, 'Report submitted for moderation review');
  } catch (err) {
    console.error('[Report Error]:', err);
    return errorResponse(res, 500, 'Failed to submit report', err.message);
  }
};

const markNotificationsRead = async (req, res) => {
  try {
    await db.query('UPDATE notifications SET is_read = true WHERE user_id = $1', [req.user.id]);
    return successResponse(res, 200, 'Notifications marked read');
  } catch (err) {
    return errorResponse(res, 500, 'Failed to update notifications', err.message);
  }
};

const uploadSocialMedia = async (req, res) => {
  try {
    if (!req.file) return errorResponse(res, 400, 'No media file uploaded');
    const isVideo = req.file.mimetype.startsWith('video/');
    return successResponse(res, 200, 'Media uploaded', {
      url: `/uploads/social/${req.file.filename}`,
      filename: req.file.originalname,
      mimetype: req.file.mimetype,
      type: isVideo ? 'video' : 'image'
    });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to upload media', err.message);
  }
};

module.exports = {
  getFeed,
  createPost,
  updatePost,
  deletePost,
  reactToPost,
  getComments,
  addComment,
  toggleSavePost,
  shareWithUsers,
  getPeopleOverview,
  searchUsers,
  getUserProfile,
  sendConnectionRequest,
  respondConnectionRequest,
  toggleFollow,
  updateSocialProfile,
  blockUser,
  reportContent,
  markNotificationsRead,
  uploadSocialMedia
};
