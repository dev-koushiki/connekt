const crypto = require('crypto');
const db = require('../config/database');
const { ensureSocialTables } = require('../models/socialModel');
const { successResponse, errorResponse } = require('../utils/responseHandler');

async function getMemberRole(communityId, userId) {
  const res = await db.query(
    'SELECT role, status FROM community_members WHERE community_id = $1 AND user_id = $2',
    [communityId, userId]
  );
  return res.rows[0] || null;
}

const listCommunities = async (req, res) => {
  try {
    await ensureSocialTables();
    const q = (req.query.q || '').toString().trim();
    const params = [req.user.id];
    let searchSql = '';
    if (q) {
      params.push(`%${q}%`);
      searchSql = 'AND (c.name ILIKE $2 OR c.description ILIKE $2 OR c.category ILIKE $2)';
    }

    const resList = await db.query(
      `SELECT c.*,
              cm.role AS my_role,
              cm.status AS my_status,
              (SELECT COUNT(*)::int FROM community_groups g WHERE g.community_id = c.id) AS groups_count,
              (SELECT COUNT(*)::int FROM community_live_sessions ls WHERE ls.community_id = c.id AND ls.status = 'live') AS live_count
       FROM communities c
       LEFT JOIN community_members cm ON cm.community_id = c.id AND cm.user_id = $1
       WHERE (c.visibility = 'public' OR c.owner_id = $1 OR cm.user_id = $1)
         ${searchSql}
       ORDER BY (cm.status = 'active') DESC, c.members_count DESC, c.created_at DESC
       LIMIT 60`,
      params
    );

    return successResponse(res, 200, 'Communities loaded', {
      communities: resList.rows.map((c) => ({
        id: c.id,
        ownerId: c.owner_id,
        name: c.name,
        description: c.description,
        coverUrl: c.cover_url,
        rules: c.rules,
        visibility: c.visibility,
        category: c.category,
        membersCount: c.members_count,
        groupsCount: c.groups_count,
        liveCount: c.live_count,
        myRole: c.my_role || null,
        myStatus: c.my_status || null,
        createdAt: c.created_at
      }))
    });
  } catch (err) {
    console.error('[Community List Error]:', err);
    return errorResponse(res, 500, 'Failed to load communities', err.message);
  }
};

const createCommunity = async (req, res) => {
  try {
    await ensureSocialTables();
    const {
      name,
      description = '',
      coverUrl = null,
      rules = 'Be respectful and stay on topic.',
      visibility = 'public',
      category = 'General'
    } = req.body || {};

    if (!name || !name.toString().trim()) {
      return errorResponse(res, 400, 'Community name is required');
    }

    const safeVis = visibility === 'private' ? 'private' : 'public';
    const ins = await db.query(
      `INSERT INTO communities (owner_id, name, description, cover_url, rules, visibility, category, members_count)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 1) RETURNING *`,
      [req.user.id, name.toString().trim(), description, coverUrl, rules, safeVis, category]
    );
    const community = ins.rows[0];

    await db.query(
      `INSERT INTO community_members (community_id, user_id, role, status)
       VALUES ($1, $2, 'admin', 'active')`,
      [community.id, req.user.id]
    );

    // Create default General group inside community
    const grp = await db.query(
      `INSERT INTO community_groups (community_id, created_by, name, description, topic, members_count)
       VALUES ($1, $2, 'General Discussion', 'Open conversations for all community members', 'General', 1)
       RETURNING id`,
      [community.id, req.user.id]
    );
    await db.query(
      `INSERT INTO community_group_members (group_id, user_id, role) VALUES ($1, $2, 'admin')`,
      [grp.rows[0].id, req.user.id]
    );

    return successResponse(res, 201, 'Community created', {
      community: {
        id: community.id,
        ownerId: community.owner_id,
        name: community.name,
        description: community.description,
        coverUrl: community.cover_url,
        rules: community.rules,
        visibility: community.visibility,
        category: community.category,
        membersCount: community.members_count,
        groupsCount: 1,
        liveCount: 0,
        myRole: 'admin',
        myStatus: 'active'
      }
    });
  } catch (err) {
    console.error('[Create Community Error]:', err);
    return errorResponse(res, 500, 'Failed to create community', err.message);
  }
};

const updateCommunity = async (req, res) => {
  try {
    await ensureSocialTables();
    const member = await getMemberRole(req.params.id, req.user.id);
    if (!member || member.status !== 'active' || !['admin', 'moderator'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins or moderators can update community settings');
    }
    const { name, description, coverUrl, rules, visibility, category } = req.body || {};
    const upd = await db.query(
      `UPDATE communities
       SET name = COALESCE($1, name),
           description = COALESCE($2, description),
           cover_url = COALESCE($3, cover_url),
           rules = COALESCE($4, rules),
           visibility = COALESCE($5, visibility),
           category = COALESCE($6, category),
           updated_at = NOW()
       WHERE id = $7
       RETURNING *`,
      [name ?? null, description ?? null, coverUrl ?? null, rules ?? null, visibility ?? null, category ?? null, req.params.id]
    );
    return successResponse(res, 200, 'Community updated', { community: upd.rows[0] });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to update community', err.message);
  }
};

const joinCommunity = async (req, res) => {
  try {
    await ensureSocialTables();
    const communityId = req.params.id;
    const commRes = await db.query('SELECT visibility FROM communities WHERE id = $1', [communityId]);
    if (commRes.rows.length === 0) return errorResponse(res, 404, 'Community not found');

    const existing = await getMemberRole(communityId, req.user.id);
    let nextStatus = commRes.rows[0].visibility === 'private' ? 'pending' : 'active';
    if (existing?.status === 'invited') {
      nextStatus = 'active';
    } else if (existing?.status === 'banned') {
      return errorResponse(res, 403, 'You are banned from this community');
    }

    await db.query(
      `INSERT INTO community_members (community_id, user_id, role, status)
       VALUES ($1, $2, 'member', $3)
       ON CONFLICT (community_id, user_id) DO UPDATE SET status = EXCLUDED.status`,
      [communityId, req.user.id, nextStatus]
    );

    const cntRes = await db.query(
      "SELECT COUNT(*)::int AS cnt FROM community_members WHERE community_id = $1 AND status = 'active'",
      [communityId]
    );
    await db.query('UPDATE communities SET members_count = $1 WHERE id = $2', [cntRes.rows[0].cnt, communityId]);

    return successResponse(res, 200, nextStatus === 'active' ? 'Joined community' : 'Join request sent for admin approval', {
      status: nextStatus,
      membersCount: cntRes.rows[0].cnt
    });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to join community', err.message);
  }
};

const leaveCommunity = async (req, res) => {
  try {
    await ensureSocialTables();
    const communityId = req.params.id;
    const comm = await db.query('SELECT owner_id FROM communities WHERE id = $1', [communityId]);
    if (comm.rows[0]?.owner_id === req.user.id) {
      return errorResponse(res, 400, 'Community owner cannot leave without transferring ownership');
    }
    await db.query('DELETE FROM community_members WHERE community_id = $1 AND user_id = $2', [communityId, req.user.id]);
    const cntRes = await db.query(
      "SELECT COUNT(*)::int AS cnt FROM community_members WHERE community_id = $1 AND status = 'active'",
      [communityId]
    );
    await db.query('UPDATE communities SET members_count = $1 WHERE id = $2', [cntRes.rows[0].cnt, communityId]);
    return successResponse(res, 200, 'Left community', { membersCount: cntRes.rows[0].cnt });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to leave community', err.message);
  }
};

const getCommunityDetail = async (req, res) => {
  try {
    await ensureSocialTables();
    const communityId = req.params.id;
    const groupIdFilter = req.query.groupId || null;

    const commRes = await db.query('SELECT * FROM communities WHERE id = $1', [communityId]);
    if (commRes.rows.length === 0) return errorResponse(res, 404, 'Community not found');
    const community = commRes.rows[0];
    const membership = await getMemberRole(communityId, req.user.id);

    if (community.visibility === 'private' && (!membership || !['active', 'invited'].includes(membership.status)) && community.owner_id !== req.user.id) {
      return successResponse(res, 200, 'Private community preview', {
        community: {
          id: community.id,
          name: community.name,
          description: community.description,
          coverUrl: community.cover_url,
          rules: community.rules,
          visibility: community.visibility,
          category: community.category,
          membersCount: community.members_count,
          myRole: membership?.role || null,
          myStatus: membership?.status || null
        },
        restricted: true,
        members: [],
        groups: [],
        posts: [],
        liveSessions: []
      });
    }

    const postParams = [communityId, req.user.id];
    let groupSql = '';
    if (groupIdFilter) {
      postParams.push(groupIdFilter);
      groupSql = 'AND p.group_id = $3';
    }

    const [membersRes, groupsRes, postsRes, liveRes] = await Promise.all([
      db.query(
        `SELECT cm.*, u.username,
                COALESCE(NULLIF(up.display_name, ''), NULLIF(up.full_name, ''), u.username) AS full_name,
                up.avatar_url
         FROM community_members cm
         JOIN users u ON u.id = cm.user_id
         LEFT JOIN user_profiles up ON up.user_id = u.id
         WHERE cm.community_id = $1
         ORDER BY (cm.role = 'admin') DESC, (cm.role = 'moderator') DESC, cm.joined_at ASC`,
        [communityId]
      ),
      db.query(
        `SELECT g.*,
                EXISTS (SELECT 1 FROM community_group_members gm WHERE gm.group_id = g.id AND gm.user_id = $2) AS is_member
         FROM community_groups g
         WHERE g.community_id = $1
         ORDER BY g.created_at ASC`,
        [communityId, req.user.id]
      ),
      db.query(
        `SELECT p.*, u.username AS author_username,
                COALESCE(NULLIF(up.display_name, ''), NULLIF(up.full_name, ''), u.username) AS author_name,
                up.avatar_url AS author_avatar_url,
                pr.reaction_type AS my_reaction
         FROM social_posts p
         JOIN users u ON u.id = p.author_id
         LEFT JOIN user_profiles up ON up.user_id = p.author_id
         LEFT JOIN post_reactions pr ON pr.post_id = p.id AND pr.user_id = $2
         WHERE p.community_id = $1 ${groupSql}
         ORDER BY p.is_pinned DESC, p.created_at DESC
         LIMIT 50`,
        postParams
      ),
      db.query(
        `SELECT ls.*, u.username AS host_username,
                COALESCE(NULLIF(up.full_name, ''), u.username) AS host_name,
                up.avatar_url AS host_avatar_url
         FROM community_live_sessions ls
         JOIN users u ON u.id = ls.host_id
         LEFT JOIN user_profiles up ON up.user_id = u.id
         WHERE ls.community_id = $1
         ORDER BY (ls.status = 'live') DESC, (ls.status = 'scheduled') DESC, ls.created_at DESC
         LIMIT 20`,
        [communityId]
      )
    ]);

    return successResponse(res, 200, 'Community detail loaded', {
      restricted: false,
      community: {
        id: community.id,
        ownerId: community.owner_id,
        name: community.name,
        description: community.description,
        coverUrl: community.cover_url,
        rules: community.rules,
        visibility: community.visibility,
        category: community.category,
        membersCount: community.members_count,
        myRole: membership?.role || null,
        myStatus: membership?.status || null
      },
      members: membersRes.rows,
      groups: groupsRes.rows,
      posts: postsRes.rows.map((p) => ({
        id: p.id,
        authorId: p.author_id,
        authorUsername: p.author_username,
        authorName: p.author_name,
        authorAvatarUrl: p.author_avatar_url,
        communityId: p.community_id,
        groupId: p.group_id,
        postType: p.post_type,
        title: p.title,
        content: p.content,
        mediaUrls: Array.isArray(p.media_urls) ? p.media_urls : [],
        likesCount: p.likes_count,
        commentsCount: p.comments_count,
        isPinned: p.is_pinned,
        myReaction: p.my_reaction,
        isOwnPost: p.author_id === req.user.id,
        createdAt: p.created_at
      })),
      liveSessions: liveRes.rows
    });
  } catch (err) {
    console.error('[Community Detail Error]:', err);
    return errorResponse(res, 500, 'Failed to load community', err.message);
  }
};

const manageMember = async (req, res) => {
  try {
    await ensureSocialTables();
    const communityId = req.params.id;
    const actor = await getMemberRole(communityId, req.user.id);
    if (!actor || actor.status !== 'active' || !['admin', 'moderator'].includes(actor.role)) {
      return errorResponse(res, 403, 'Admin or moderator access required');
    }

    const { userId, action, role } = req.body || {};
    if (!userId || !action) return errorResponse(res, 400, 'userId and action are required');

    if (action === 'invite') {
      await db.query(
        `INSERT INTO community_members (community_id, user_id, role, status, invited_by)
         VALUES ($1, $2, 'member', 'invited', $3)
         ON CONFLICT (community_id, user_id) DO NOTHING`,
        [communityId, userId, req.user.id]
      );
      await db.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'community_invite', $2, $3, $4::jsonb)`,
        [
          userId,
          `${req.user.username} invited you to join a community`,
          'Tap to view and accept invitation',
          JSON.stringify({ communityId })
        ]
      ).catch(() => {});
    } else if (action === 'approve') {
      await db.query(
        `UPDATE community_members SET status = 'active' WHERE community_id = $1 AND user_id = $2`,
        [communityId, userId]
      );
    } else if (action === 'set_role' && ['admin', 'moderator', 'member'].includes(role)) {
      if (actor.role !== 'admin') return errorResponse(res, 403, 'Only admins can assign roles');
      await db.query(
        'UPDATE community_members SET role = $1 WHERE community_id = $2 AND user_id = $3',
        [role, communityId, userId]
      );
    } else if (action === 'remove') {
      await db.query(
        'DELETE FROM community_members WHERE community_id = $1 AND user_id = $2',
        [communityId, userId]
      );
    }

    const cntRes = await db.query(
      "SELECT COUNT(*)::int AS cnt FROM community_members WHERE community_id = $1 AND status = 'active'",
      [communityId]
    );
    await db.query('UPDATE communities SET members_count = $1 WHERE id = $2', [cntRes.rows[0].cnt, communityId]);
    return successResponse(res, 200, 'Member updated', { membersCount: cntRes.rows[0].cnt });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to manage member', err.message);
  }
};

const createGroup = async (req, res) => {
  try {
    await ensureSocialTables();
    const communityId = req.params.id;
    const actor = await getMemberRole(communityId, req.user.id);
    if (!actor || actor.status !== 'active') {
      return errorResponse(res, 403, 'Join this community before creating a group');
    }

    const { name, description = '', topic = 'Discussion', isAnnouncementOnly = false } = req.body || {};
    if (!name || !name.toString().trim()) return errorResponse(res, 400, 'Group name is required');

    const ins = await db.query(
      `INSERT INTO community_groups (community_id, created_by, name, description, topic, is_announcement_only, members_count)
       VALUES ($1, $2, $3, $4, $5, $6, 1) RETURNING *`,
      [communityId, req.user.id, name.toString().trim(), description, topic, isAnnouncementOnly === true]
    );
    await db.query(
      `INSERT INTO community_group_members (group_id, user_id, role) VALUES ($1, $2, 'admin')`,
      [ins.rows[0].id, req.user.id]
    );

    return successResponse(res, 201, 'Group created inside community', { group: ins.rows[0] });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to create group', err.message);
  }
};

const toggleJoinGroup = async (req, res) => {
  try {
    await ensureSocialTables();
    const groupId = req.params.groupId;
    const exists = await db.query(
      'SELECT 1 FROM community_group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, req.user.id]
    );

    let isMember;
    if (exists.rows.length > 0) {
      await db.query('DELETE FROM community_group_members WHERE group_id = $1 AND user_id = $2', [groupId, req.user.id]);
      isMember = false;
    } else {
      await db.query(
        'INSERT INTO community_group_members (group_id, user_id, role) VALUES ($1, $2, \'member\')',
        [groupId, req.user.id]
      );
      isMember = true;
    }

    const cntRes = await db.query('SELECT COUNT(*)::int AS cnt FROM community_group_members WHERE group_id = $1', [groupId]);
    await db.query('UPDATE community_groups SET members_count = $1 WHERE id = $2', [cntRes.rows[0].cnt, groupId]);

    return successResponse(res, 200, isMember ? 'Joined group' : 'Left group', {
      isMember,
      membersCount: cntRes.rows[0].cnt
    });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to update group membership', err.message);
  }
};

const createCommunityPost = async (req, res) => {
  try {
    await ensureSocialTables();
    const communityId = req.params.id;
    const actor = await getMemberRole(communityId, req.user.id);
    if (!actor || actor.status !== 'active') {
      return errorResponse(res, 403, 'Join this community before posting');
    }

    const { groupId = null, postType = 'text', title = '', content = '', mediaUrls = [] } = req.body || {};
    if (!content.toString().trim() && (!Array.isArray(mediaUrls) || mediaUrls.length === 0)) {
      return errorResponse(res, 400, 'Post content is required');
    }

    const ins = await db.query(
      `INSERT INTO social_posts (author_id, mode, community_id, group_id, post_type, title, content, media_urls, visibility)
       VALUES ($1, 'community', $2, $3, $4, $5, $6, $7::jsonb, 'community')
       RETURNING *`,
      [req.user.id, communityId, groupId || null, postType, title, content.toString().trim(), JSON.stringify(mediaUrls)]
    );

    return successResponse(res, 201, 'Posted to community', { post: ins.rows[0] });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to post in community', err.message);
  }
};

const moderatePost = async (req, res) => {
  try {
    await ensureSocialTables();
    const { postId } = req.params;
    const { action } = req.body || {};
    const postRes = await db.query('SELECT author_id, community_id, is_pinned FROM social_posts WHERE id = $1', [postId]);
    if (postRes.rows.length === 0) return errorResponse(res, 404, 'Post not found');
    const post = postRes.rows[0];

    const actor = await getMemberRole(post.community_id, req.user.id);
    const isMod = actor && actor.status === 'active' && ['admin', 'moderator'].includes(actor.role);

    if (action === 'pin') {
      if (!isMod) return errorResponse(res, 403, 'Moderator access required');
      await db.query('UPDATE social_posts SET is_pinned = $1 WHERE id = $2', [!post.is_pinned, postId]);
      return successResponse(res, 200, !post.is_pinned ? 'Post pinned' : 'Post unpinned');
    }

    if (action === 'delete') {
      if (!isMod && post.author_id !== req.user.id) {
        return errorResponse(res, 403, 'Unauthorized to remove post');
      }
      await db.query('DELETE FROM social_posts WHERE id = $1', [postId]);
      return successResponse(res, 200, 'Post removed');
    }

    return errorResponse(res, 400, 'Unknown moderation action');
  } catch (err) {
    return errorResponse(res, 500, 'Moderation action failed', err.message);
  }
};

const startOrScheduleLive = async (req, res) => {
  try {
    await ensureSocialTables();
    const communityId = req.params.id;
    const actor = await getMemberRole(communityId, req.user.id);
    if (!actor || actor.status !== 'active') {
      return errorResponse(res, 403, 'Join this community before going live');
    }

    const { title, description = '', groupId = null, scheduledFor = null } = req.body || {};
    if (!title || !title.toString().trim()) {
      return errorResponse(res, 400, 'Live stream title is required');
    }

    const schedDate = scheduledFor ? new Date(scheduledFor) : null;
    const isScheduled = schedDate && !isNaN(schedDate.getTime()) && schedDate > new Date();
    const status = isScheduled ? 'scheduled' : 'live';
    const roomCode = `live_${crypto.randomBytes(5).toString('hex')}`;

    const ins = await db.query(
      `INSERT INTO community_live_sessions (
        community_id, group_id, host_id, title, description, status, scheduled_for, started_at, room_code
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *`,
      [
        communityId,
        groupId || null,
        req.user.id,
        title.toString().trim(),
        description,
        status,
        isScheduled ? schedDate : null,
        status === 'live' ? new Date() : null,
        roomCode
      ]
    );
    const session = ins.rows[0];

    // Notify active community members
    const membersRes = await db.query(
      "SELECT user_id FROM community_members WHERE community_id = $1 AND status = 'active' AND user_id <> $2",
      [communityId, req.user.id]
    );
    const io = req.app.get('io');
    for (const m of membersRes.rows) {
      await db.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'community_live', $2, $3, $4::jsonb)`,
        [
          m.user_id,
          status === 'live' ? `${req.user.username} is LIVE now!` : `${req.user.username} scheduled a live stream`,
          session.title,
          JSON.stringify({ communityId, sessionId: session.id, roomCode })
        ]
      ).catch(() => {});

      if (io) {
        io.to(`user:${m.user_id}`).emit('community:live-notification', {
          communityId,
          sessionId: session.id,
          title: session.title,
          status,
          roomCode
        });
      }
    }

    return successResponse(res, 201, status === 'live' ? 'Live stream started' : 'Live stream scheduled', {
      session
    });
  } catch (err) {
    console.error('[Community Live Start Error]:', err);
    return errorResponse(res, 500, 'Failed to start live session', err.message);
  }
};

const getLiveSessionDetail = async (req, res) => {
  try {
    await ensureSocialTables();
    const { sessionId } = req.params;
    const sessRes = await db.query(
      `SELECT ls.*, u.username AS host_username,
              COALESCE(NULLIF(up.full_name, ''), u.username) AS host_name,
              up.avatar_url AS host_avatar_url
       FROM community_live_sessions ls
       JOIN users u ON u.id = ls.host_id
       LEFT JOIN user_profiles up ON up.user_id = u.id
       WHERE ls.id = $1`,
      [sessionId]
    );
    if (sessRes.rows.length === 0) return errorResponse(res, 404, 'Live session not found');

    const commentsRes = await db.query(
      `SELECT lc.*, u.username,
              COALESCE(NULLIF(up.full_name, ''), u.username) AS author_name
       FROM community_live_comments lc
       JOIN users u ON u.id = lc.user_id
       LEFT JOIN user_profiles up ON up.user_id = u.id
       WHERE lc.session_id = $1
       ORDER BY lc.created_at ASC
       LIMIT 100`,
      [sessionId]
    );

    return successResponse(res, 200, 'Live session loaded', {
      session: sessRes.rows[0],
      comments: commentsRes.rows
    });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to load live session', err.message);
  }
};

const postLiveComment = async (req, res) => {
  try {
    await ensureSocialTables();
    const { sessionId } = req.params;
    const { content = '', isReaction = false, reactionType = null } = req.body || {};
    if (!isReaction && !content.toString().trim()) {
      return errorResponse(res, 400, 'Comment content is required');
    }

    const ins = await db.query(
      `INSERT INTO community_live_comments (session_id, user_id, content, is_reaction, reaction_type)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [sessionId, req.user.id, content.toString().trim(), isReaction === true, reactionType]
    );

    const payload = {
      ...ins.rows[0],
      username: req.user.username,
      author_name: req.user.username
    };

    const sessRes = await db.query('SELECT room_code FROM community_live_sessions WHERE id = $1', [sessionId]);
    const io = req.app.get('io');
    if (io && sessRes.rows[0]?.room_code) {
      io.to(`live:${sessRes.rows[0].room_code}`).emit('community:live-comment', payload);
    }

    return successResponse(res, 201, 'Live comment posted', { comment: payload });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to post live comment', err.message);
  }
};

const endLiveSession = async (req, res) => {
  try {
    await ensureSocialTables();
    const { sessionId } = req.params;
    const upd = await db.query(
      `UPDATE community_live_sessions
       SET status = 'ended', ended_at = NOW(), viewer_count = 0
       WHERE id = $1 AND host_id = $2
       RETURNING *`,
      [sessionId, req.user.id]
    );
    if (upd.rows.length === 0) return errorResponse(res, 403, 'Live session not found or unauthorized');

    const io = req.app.get('io');
    if (io && upd.rows[0].room_code) {
      io.to(`live:${upd.rows[0].room_code}`).emit('community:live-ended', { sessionId });
    }
    return successResponse(res, 200, 'Live stream ended', { session: upd.rows[0] });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to end live stream', err.message);
  }
};

module.exports = {
  listCommunities,
  createCommunity,
  updateCommunity,
  joinCommunity,
  leaveCommunity,
  getCommunityDetail,
  manageMember,
  createGroup,
  toggleJoinGroup,
  createCommunityPost,
  moderatePost,
  startOrScheduleLive,
  getLiveSessionDetail,
  postLiveComment,
  endLiveSession
};
