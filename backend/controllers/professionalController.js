const crypto = require('crypto');
const db = require('../config/database');
const { ensureSocialTables } = require('../models/socialModel');
const { getUserSubscriptionState } = require('../middleware/subscriptionMiddleware');
const { successResponse, errorResponse } = require('../utils/responseHandler');

const updateProProfile = async (req, res) => {
  try {
    await ensureSocialTables();
    const {
      headline,
      about,
      industry,
      bannerUrl,
      resumeUrl,
      portfolioUrl,
      contactEmail,
      githubUrl
    } = req.body || {};

    await db.query(
      'INSERT INTO professional_profiles (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING',
      [req.user.id]
    );

    const upd = await db.query(
      `UPDATE professional_profiles
       SET headline = COALESCE($1, headline),
           about = COALESCE($2, about),
           industry = COALESCE($3, industry),
           banner_url = COALESCE($4, banner_url),
           resume_url = COALESCE($5, resume_url),
           portfolio_url = COALESCE($6, portfolio_url),
           contact_email = COALESCE($7, contact_email),
           github_url = COALESCE($8, github_url),
           updated_at = NOW()
       WHERE user_id = $9
       RETURNING *`,
      [
        headline ?? null,
        about ?? null,
        industry ?? null,
        bannerUrl ?? null,
        resumeUrl ?? null,
        portfolioUrl ?? null,
        contactEmail ?? null,
        githubUrl ?? null,
        req.user.id
      ]
    );

    return successResponse(res, 200, 'Professional profile updated', { profile: upd.rows[0] });
  } catch (err) {
    console.error('[Pro Profile Update Error]:', err);
    return errorResponse(res, 500, 'Failed to update professional profile', err.message);
  }
};

const addCertification = async (req, res) => {
  try {
    await ensureSocialTables();
    const { name, issuer = '', issueDate = '', credentialId = '', credentialUrl = '' } = req.body || {};
    if (!name || !name.toString().trim()) return errorResponse(res, 400, 'Certification name is required');
    const ins = await db.query(
      `INSERT INTO user_certifications (user_id, name, issuer, issue_date, credential_id, credential_url)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [req.user.id, name.toString().trim(), issuer, issueDate, credentialId, credentialUrl]
    );
    return successResponse(res, 201, 'Certification added', { certification: ins.rows[0] });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to add certification', err.message);
  }
};

const deleteCertification = async (req, res) => {
  try {
    await ensureSocialTables();
    await db.query('DELETE FROM user_certifications WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    return successResponse(res, 200, 'Certification deleted');
  } catch (err) {
    return errorResponse(res, 500, 'Failed to delete certification', err.message);
  }
};

const addProject = async (req, res) => {
  try {
    await ensureSocialTables();
    const { title, description = '', projectUrl = '', startDate = '', endDate = '' } = req.body || {};
    if (!title || !title.toString().trim()) return errorResponse(res, 400, 'Project title is required');
    const ins = await db.query(
      `INSERT INTO user_projects (user_id, title, description, project_url, start_date, end_date)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [req.user.id, title.toString().trim(), description, projectUrl, startDate, endDate]
    );
    return successResponse(res, 201, 'Project added', { project: ins.rows[0] });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to add project', err.message);
  }
};

const deleteProject = async (req, res) => {
  try {
    await ensureSocialTables();
    await db.query('DELETE FROM user_projects WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    return successResponse(res, 200, 'Project deleted');
  } catch (err) {
    return errorResponse(res, 500, 'Failed to delete project', err.message);
  }
};

const endorseSkill = async (req, res) => {
  try {
    await ensureSocialTables();
    const skillId = (req.params.skillId || '').toString().trim();
    if (!skillId) return errorResponse(res, 400, 'Invalid skill ID');

    const skillRes = await db.query('SELECT user_id, skill_name FROM user_skills WHERE id = $1', [skillId]);
    if (skillRes.rows.length === 0) return errorResponse(res, 404, 'Skill not found');
    if (skillRes.rows[0].user_id === req.user.id) {
      return errorResponse(res, 400, 'You cannot endorse your own skill');
    }

    const exists = await db.query(
      'SELECT id FROM skill_endorsements WHERE skill_id = $1 AND endorser_id = $2',
      [skillId, req.user.id]
    );

    let endorsedByMe;
    if (exists.rows.length > 0) {
      await db.query('DELETE FROM skill_endorsements WHERE skill_id = $1 AND endorser_id = $2', [skillId, req.user.id]);
      endorsedByMe = false;
    } else {
      await db.query('INSERT INTO skill_endorsements (skill_id, endorser_id) VALUES ($1, $2)', [skillId, req.user.id]);
      endorsedByMe = true;
    }

    const cntRes = await db.query('SELECT COUNT(*)::int AS cnt FROM skill_endorsements WHERE skill_id = $1', [skillId]);
    await db.query('UPDATE user_skills SET endorsed_count = $1 WHERE id = $2', [cntRes.rows[0].cnt, skillId]);

    return successResponse(res, 200, endorsedByMe ? 'Skill endorsed' : 'Endorsement removed', {
      endorsedByMe,
      endorsedCount: cntRes.rows[0].cnt
    });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to endorse skill', err.message);
  }
};

const addRecommendation = async (req, res) => {
  try {
    await ensureSocialTables();
    const recipientId = req.params.userId;
    const { relationship = 'Colleague', content = '' } = req.body || {};
    if (!recipientId || recipientId === req.user.id) {
      return errorResponse(res, 400, 'Valid recipient user is required');
    }
    if (!content.toString().trim()) {
      return errorResponse(res, 400, 'Recommendation text is required');
    }

    const ins = await db.query(
      `INSERT INTO professional_recommendations (recipient_id, author_id, relationship, content)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [recipientId, req.user.id, relationship, content.toString().trim()]
    );
    return successResponse(res, 201, 'Recommendation submitted', { recommendation: ins.rows[0] });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to add recommendation', err.message);
  }
};

const listJobsAndCompanies = async (req, res) => {
  try {
    await ensureSocialTables();
    const jobType = (req.query.jobType || 'all').toString();
    const search = (req.query.q || '').toString().trim();

    const params = [];
    const conditions = ['j.is_active = true'];
    if (jobType !== 'all') {
      params.push(jobType);
      conditions.push(`j.job_type = $${params.length}`);
    }
    if (search) {
      params.push(`%${search}%`);
      conditions.push(`(j.title ILIKE $${params.length} OR j.location ILIKE $${params.length} OR c.name ILIKE $${params.length})`);
    }

    const [jobsRes, companiesRes, appsRes, subscription] = await Promise.all([
      db.query(
        `SELECT j.*, c.name AS company_name, c.industry AS company_industry, c.location AS company_location, c.logo_url AS company_logo,
                u.username AS recruiter_username,
                EXISTS (SELECT 1 FROM job_applications ja WHERE ja.job_id = j.id AND ja.applicant_id = '${req.user.id}') AS has_applied
         FROM job_listings j
         LEFT JOIN companies c ON c.id = j.company_id
         JOIN users u ON u.id = j.recruiter_id
         WHERE ${conditions.join(' AND ')}
         ORDER BY j.created_at DESC
         LIMIT 50`,
        params
      ),
      db.query(
        `SELECT c.*, u.username AS owner_username
         FROM companies c
         JOIN users u ON u.id = c.owner_id
         ORDER BY c.created_at DESC
         LIMIT 30`
      ),
      db.query(
        `SELECT ja.*, j.title AS job_title, c.name AS company_name
         FROM job_applications ja
         JOIN job_listings j ON j.id = ja.job_id
         LEFT JOIN companies c ON c.id = j.company_id
         WHERE ja.applicant_id = $1
         ORDER BY ja.created_at DESC`,
        [req.user.id]
      ),
      getUserSubscriptionState(req.user.id)
    ]);

    return successResponse(res, 200, 'Careers & recruiters loaded', {
      jobs: jobsRes.rows,
      companies: companiesRes.rows,
      applications: appsRes.rows,
      subscription
    });
  } catch (err) {
    console.error('[Pro Jobs Error]:', err);
    return errorResponse(res, 500, 'Failed to load career opportunities', err.message);
  }
};

const createCompany = async (req, res) => {
  try {
    await ensureSocialTables();
    const { name, industry = '', size = '11-50', website = '', location = '', description = '', logoUrl = null } = req.body || {};
    if (!name || !name.toString().trim()) return errorResponse(res, 400, 'Company name is required');
    const ins = await db.query(
      `INSERT INTO companies (owner_id, name, industry, size, website, location, description, logo_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [req.user.id, name.toString().trim(), industry, size, website, location, description, logoUrl]
    );
    return successResponse(res, 201, 'Company page created', { company: ins.rows[0] });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to create company', err.message);
  }
};

const createJob = async (req, res) => {
  try {
    await ensureSocialTables();
    const {
      companyId = null,
      title,
      jobType = 'full-time',
      location = 'Remote',
      workMode = 'remote',
      salaryRange = '',
      description = '',
      requirements = ''
    } = req.body || {};
    if (!title || !title.toString().trim()) return errorResponse(res, 400, 'Job title is required');

    let resolvedCompanyId = companyId;
    if (!resolvedCompanyId) {
      const ownComp = await db.query('SELECT id FROM companies WHERE owner_id = $1 ORDER BY created_at DESC LIMIT 1', [req.user.id]);
      if (ownComp.rows.length > 0) {
        resolvedCompanyId = ownComp.rows[0].id;
      } else {
        const autoComp = await db.query(
          `INSERT INTO companies (owner_id, name, industry, location)
           VALUES ($1, $2, 'Technology', $3) RETURNING id`,
          [req.user.id, `${req.user.username} Ventures`, location]
        );
        resolvedCompanyId = autoComp.rows[0].id;
      }
    }

    const ins = await db.query(
      `INSERT INTO job_listings (company_id, recruiter_id, title, job_type, location, work_mode, salary_range, description, requirements)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [resolvedCompanyId, req.user.id, title.toString().trim(), jobType, location, workMode, salaryRange, description, requirements]
    );
    return successResponse(res, 201, 'Opportunity published', { job: ins.rows[0] });
  } catch (err) {
    console.error('[Pro Create Job Error]:', err);
    return errorResponse(res, 500, 'Failed to post job listing', err.message);
  }
};

const applyForJob = async (req, res) => {
  try {
    await ensureSocialTables();
    const jobId = req.params.id;
    const { resumeUrl = '', coverNote = '' } = req.body || {};

    const sub = await getUserSubscriptionState(req.user.id);
    const hasUnlimited = sub.features.includes('unlimited_job_applications');

    if (!hasUnlimited) {
      const recentCount = await db.query(
        `SELECT COUNT(*)::int AS cnt FROM job_applications
         WHERE applicant_id = $1 AND created_at > NOW() - INTERVAL '30 days'`,
        [req.user.id]
      );
      if (recentCount.rows[0].cnt >= 3) {
        return res.status(403).json({
          success: false,
          code: 'SUBSCRIPTION_REQUIRED',
          requiredFeature: 'unlimited_job_applications',
          featureTitle: 'Unlimited Job & Internship Applications',
          currentPlan: sub.planId,
          message: 'Free tier allows up to 3 applications per 30 days. Upgrade to Connekt Pro for unlimited applications.'
        });
      }
    }

    const ins = await db.query(
      `INSERT INTO job_applications (job_id, applicant_id, resume_url, cover_note, status)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (job_id, applicant_id) DO UPDATE SET
         resume_url = EXCLUDED.resume_url,
         cover_note = EXCLUDED.cover_note
       RETURNING *`,
      [
        jobId,
        req.user.id,
        resumeUrl,
        coverNote,
        sub.features.includes('priority_applicant') ? 'priority_submitted' : 'submitted'
      ]
    );

    const jobInfo = await db.query('SELECT recruiter_id, title FROM job_listings WHERE id = $1', [jobId]);
    if (jobInfo.rows[0]?.recruiter_id && jobInfo.rows[0].recruiter_id !== req.user.id) {
      await db.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'job_application', $2, $3, $4::jsonb)`,
        [
          jobInfo.rows[0].recruiter_id,
          `New application for ${jobInfo.rows[0].title}`,
          `${req.user.username} applied`,
          JSON.stringify({ jobId, applicantId: req.user.id })
        ]
      ).catch(() => {});
    }

    return successResponse(res, 201, 'Application submitted', {
      application: ins.rows[0],
      priorityApplicant: sub.features.includes('priority_applicant')
    });
  } catch (err) {
    console.error('[Pro Apply Error]:', err);
    return errorResponse(res, 500, 'Failed to submit application', err.message);
  }
};

const publishArticle = async (req, res) => {
  try {
    await ensureSocialTables();
    const { title, content, mediaUrls = [] } = req.body || {};
    if (!title?.toString().trim() || !content?.toString().trim()) {
      return errorResponse(res, 400, 'Article title and content are required');
    }
    const ins = await db.query(
      `INSERT INTO social_posts (author_id, mode, post_type, title, content, media_urls, visibility)
       VALUES ($1, 'professional', 'article', $2, $3, $4::jsonb, 'public')
       RETURNING *`,
      [req.user.id, title.toString().trim(), content.toString().trim(), JSON.stringify(mediaUrls)]
    );
    return successResponse(res, 201, 'Article published', { article: ins.rows[0] });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to publish article', err.message);
  }
};

const getProfileAnalytics = async (req, res) => {
  try {
    await ensureSocialTables();
    const [viewsRes, recentViewersRes, postReachRes] = await Promise.all([
      db.query(
        `SELECT COUNT(*)::int AS total_views,
                COUNT(*) FILTER (WHERE viewed_at > NOW() - INTERVAL '7 days')::int AS views_7d
         FROM profile_views WHERE profile_user_id = $1`,
        [req.user.id]
      ),
      db.query(
        `SELECT DISTINCT ON (pv.viewer_user_id)
                u.id, u.username,
                COALESCE(NULLIF(up.full_name, ''), u.username) AS full_name,
                up.avatar_url, COALESCE(pp.headline, '') AS headline, pv.viewed_at
         FROM profile_views pv
         JOIN users u ON u.id = pv.viewer_user_id
         LEFT JOIN user_profiles up ON up.user_id = u.id
         LEFT JOIN professional_profiles pp ON pp.user_id = u.id
         WHERE pv.profile_user_id = $1
         ORDER BY pv.viewer_user_id, pv.viewed_at DESC
         LIMIT 20`,
        [req.user.id]
      ),
      db.query(
        `SELECT COUNT(*)::int AS posts_count,
                COALESCE(SUM(likes_count), 0)::int AS total_reactions,
                COALESCE(SUM(comments_count), 0)::int AS total_comments
         FROM social_posts WHERE author_id = $1 AND mode = 'professional'`,
        [req.user.id]
      )
    ]);

    return successResponse(res, 200, 'Profile analytics loaded', {
      totalProfileViews: viewsRes.rows[0].total_views,
      viewsLast7Days: viewsRes.rows[0].views_7d,
      recentViewers: recentViewersRes.rows,
      professionalPostsCount: postReachRes.rows[0].posts_count,
      totalReactions: postReachRes.rows[0].total_reactions,
      totalComments: postReachRes.rows[0].total_comments
    });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to load profile analytics', err.message);
  }
};

const uploadProFile = async (req, res) => {
  try {
    if (!req.file) return errorResponse(res, 400, 'No file uploaded');
    return successResponse(res, 200, 'File uploaded', {
      url: `/uploads/professional/${req.file.filename}`,
      filename: req.file.originalname,
      mimetype: req.file.mimetype
    });
  } catch (err) {
    return errorResponse(res, 500, 'Failed to upload file', err.message);
  }
};

module.exports = {
  updateProProfile,
  addCertification,
  deleteCertification,
  addProject,
  deleteProject,
  endorseSkill,
  addRecommendation,
  listJobsAndCompanies,
  createCompany,
  createJob,
  applyForJob,
  publishArticle,
  getProfileAnalytics,
  uploadProFile
};
