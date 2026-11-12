const db = require('../config/database');

/**
 * Complete User Data Access Layer
 */
class UserModel {
  /**
   * Create user along with Personal Profile, Professional Profile, and Privacy Settings in a single transaction
   */
  static async createUser({
    phone,
    username,
    email,
    passwordHash,
    fullName,
    displayName = null,
    currentMode = 'common',
    recoveryEmail = null
  }) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      // 1. Insert into users table
      const userRes = await client.query(
        `INSERT INTO users (phone, username, email, password_hash, current_mode, recovery_email)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, phone, username, email, current_mode, allowed_modes, role, status, is_verified, created_at`,
        [phone.trim(), username.trim().toLowerCase(), email.trim().toLowerCase(), passwordHash, currentMode, recoveryEmail]
      );
      const user = userRes.rows[0];

      // 2. Insert into user_profiles
      const profRes = await client.query(
        `INSERT INTO user_profiles (user_id, full_name, display_name)
         VALUES ($1, $2, $3)
         RETURNING id, full_name, display_name, avatar_url, banner_url, bio, location, website, birthdate, gender, interests`,
        [user.id, fullName.trim(), displayName ? displayName.trim() : fullName.trim()]
      );
      const personalProfile = profRes.rows[0];

      // 3. Insert into professional_profiles
      const profModeRes = await client.query(
        `INSERT INTO professional_profiles (user_id, headline)
         VALUES ($1, $2)
         RETURNING id, headline, current_company, industry, summary, years_of_experience, portfolio_url, github_url, linkedin_url, resume_url, is_open_to_work, is_hiring`,
        [user.id, 'Member at CONNEKT']
      );
      const professionalProfile = profModeRes.rows[0];

      // 4. Insert default privacy settings
      const privRes = await client.query(
        `INSERT INTO privacy_settings (user_id)
         VALUES ($1)
         RETURNING id, profile_visibility, read_receipts, online_status, last_seen_visibility, group_invitation_approval, message_requests`,
        [user.id]
      );
      const privacySettings = privRes.rows[0];

      await client.query('COMMIT');

      return {
        ...user,
        personalProfile,
        professionalProfile,
        privacySettings
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  static async findById(id) {
    const userRes = await db.query(
      `SELECT id, phone, username, email, recovery_email, current_mode, allowed_modes, role, status, is_verified, last_login_at, created_at, updated_at
       FROM users WHERE id = $1`,
      [id]
    );
    if (userRes.rows.length === 0) return null;
    const user = userRes.rows[0];

    const personalRes = await db.query(
      `SELECT id, full_name, display_name, avatar_url, banner_url, bio, location, website, birthdate, gender, interests
       FROM user_profiles WHERE user_id = $1`,
      [id]
    );

    const profRes = await db.query(
      `SELECT id, headline, current_company, industry, summary, years_of_experience, portfolio_url, github_url, linkedin_url, resume_url, is_open_to_work, is_hiring
       FROM professional_profiles WHERE user_id = $1`,
      [id]
    );

    const privRes = await db.query(
      `SELECT id, profile_visibility, read_receipts, online_status, last_seen_visibility, group_invitation_approval, message_requests
       FROM privacy_settings WHERE user_id = $1`,
      [id]
    );

    const skillsRes = await db.query(
      `SELECT id, skill_name, proficiency, created_at FROM user_skills WHERE user_id = $1 ORDER BY created_at ASC`,
      [id]
    );

    const eduRes = await db.query(
      `SELECT id, institution, degree, field_of_study, start_year, end_year, created_at FROM user_education WHERE user_id = $1 ORDER BY start_year DESC NULLS LAST`,
      [id]
    );

    const expRes = await db.query(
      `SELECT id, company_name, title, location, start_date, end_date, is_current, description, created_at FROM user_experience WHERE user_id = $1 ORDER BY start_date DESC NULLS LAST`,
      [id]
    );

    return {
      ...user,
      personalProfile: personalRes.rows[0] || null,
      professionalProfile: profRes.rows[0] || null,
      privacySettings: privRes.rows[0] || null,
      skills: skillsRes.rows,
      education: eduRes.rows,
      experience: expRes.rows
    };
  }

  static async findByIdentifier(identifier) {
    const cleaned = identifier.trim().toLowerCase();
    const res = await db.query(
      `SELECT id, phone, username, email, password_hash, current_mode, allowed_modes, role, status, is_verified
       FROM users
       WHERE LOWER(username) = $1 OR phone = $2 OR LOWER(email) = $1`,
      [cleaned, identifier.trim()]
    );
    return res.rows[0] || null;
  }

  static async findByPhone(phone) {
    const res = await db.query(`SELECT id, phone, username, email FROM users WHERE phone = $1`, [phone.trim()]);
    return res.rows[0] || null;
  }

  static async findByUsername(username) {
    const res = await db.query(`SELECT id, phone, username, email FROM users WHERE LOWER(username) = $1`, [username.trim().toLowerCase()]);
    return res.rows[0] || null;
  }

  static async findByEmail(email) {
    const res = await db.query(`SELECT id, phone, username, email FROM users WHERE LOWER(email) = $1`, [email.trim().toLowerCase()]);
    return res.rows[0] || null;
  }

  static async updatePassword(userId, passwordHash) {
    const res = await db.query(
      `UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2 RETURNING id`,
      [passwordHash, userId]
    );
    return res.rows[0] || null;
  }

  static async updateCurrentMode(userId, mode) {
    const res = await db.query(
      `UPDATE users SET current_mode = $1, updated_at = NOW() WHERE id = $2 RETURNING id, current_mode`,
      [mode, userId]
    );
    return res.rows[0] || null;
  }

  static async updateLastLogin(userId) {
    await db.query(`UPDATE users SET last_login_at = NOW() WHERE id = $1`, [userId]);
  }

  static async updatePersonalProfile(userId, { fullName, displayName, bio, location, website, birthdate, gender, interests }) {
    const res = await db.query(
      `UPDATE user_profiles 
       SET full_name = COALESCE($1, full_name),
           display_name = COALESCE($2, display_name),
           bio = COALESCE($3, bio),
           location = COALESCE($4, location),
           website = COALESCE($5, website),
           birthdate = $6,
           gender = COALESCE($7, gender),
           interests = COALESCE($8, interests),
           updated_at = NOW()
       WHERE user_id = $9
       RETURNING *`,
      [fullName, displayName, bio, location, website, birthdate || null, gender, interests, userId]
    );
    return res.rows[0] || null;
  }

  static async updateAvatarUrl(userId, avatarUrl) {
    const res = await db.query(
      `UPDATE user_profiles SET avatar_url = $1, updated_at = NOW() WHERE user_id = $2 RETURNING avatar_url`,
      [avatarUrl, userId]
    );
    if (res.rows.length > 0) {
      return res.rows[0];
    }
    const insertRes = await db.query(
      `INSERT INTO user_profiles (user_id, avatar_url)
       VALUES ($1, $2)
       ON CONFLICT (user_id) DO UPDATE SET avatar_url = EXCLUDED.avatar_url, updated_at = NOW()
       RETURNING avatar_url`,
      [userId, avatarUrl]
    );
    return insertRes.rows[0] || null;
  }

  static async updateProfessionalProfile(userId, { headline, currentCompany, industry, summary, yearsOfExperience, portfolioUrl, githubUrl, linkedinUrl, resumeUrl, isOpenToWork, isHiring }) {
    const res = await db.query(
      `UPDATE professional_profiles
       SET headline = COALESCE($1, headline),
           current_company = COALESCE($2, current_company),
           industry = COALESCE($3, industry),
           summary = COALESCE($4, summary),
           years_of_experience = COALESCE($5, years_of_experience),
           portfolio_url = COALESCE($6, portfolio_url),
           github_url = COALESCE($7, github_url),
           linkedin_url = COALESCE($8, linkedin_url),
           resume_url = COALESCE($9, resume_url),
           is_open_to_work = COALESCE($10, is_open_to_work),
           is_hiring = COALESCE($11, is_hiring),
           updated_at = NOW()
       WHERE user_id = $12
       RETURNING *`,
      [headline, currentCompany, industry, summary, yearsOfExperience, portfolioUrl, githubUrl, linkedinUrl, resumeUrl, isOpenToWork, isHiring, userId]
    );
    return res.rows[0] || null;
  }

  // Skills
  static async addSkill(userId, skillName, proficiency = 'Intermediate') {
    const res = await db.query(
      `INSERT INTO user_skills (user_id, skill_name, proficiency)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, skill_name) DO UPDATE SET proficiency = EXCLUDED.proficiency
       RETURNING *`,
      [userId, skillName.trim(), proficiency]
    );
    return res.rows[0];
  }

  static async deleteSkill(userId, skillId) {
    const res = await db.query(`DELETE FROM user_skills WHERE id = $1 AND user_id = $2 RETURNING id`, [skillId, userId]);
    return res.rowCount > 0;
  }

  // Education
  static async addEducation(userId, { institution, degree, fieldOfStudy, startYear, endYear }) {
    const res = await db.query(
      `INSERT INTO user_education (user_id, institution, degree, field_of_study, start_year, end_year)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [userId, institution.trim(), degree.trim(), fieldOfStudy ? fieldOfStudy.trim() : null, startYear, endYear]
    );
    return res.rows[0];
  }

  static async deleteEducation(userId, eduId) {
    const res = await db.query(`DELETE FROM user_education WHERE id = $1 AND user_id = $2 RETURNING id`, [eduId, userId]);
    return res.rowCount > 0;
  }

  // Experience
  static async addExperience(userId, { companyName, title, location, startDate, endDate, isCurrent, description }) {
    const res = await db.query(
      `INSERT INTO user_experience (user_id, company_name, title, location, start_date, end_date, is_current, description)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [userId, companyName.trim(), title.trim(), location, startDate || null, endDate || null, isCurrent || false, description]
    );
    return res.rows[0];
  }

  static async deleteExperience(userId, expId) {
    const res = await db.query(`DELETE FROM user_experience WHERE id = $1 AND user_id = $2 RETURNING id`, [expId, userId]);
    return res.rowCount > 0;
  }

  // Privacy Settings
  static async getPrivacySettings(userId) {
    const res = await db.query(`SELECT * FROM privacy_settings WHERE user_id = $1`, [userId]);
    return res.rows[0] || null;
  }

  static async updatePrivacySettings(userId, { profileVisibility, readReceipts, onlineStatus, lastSeenVisibility, groupInvitationApproval, messageRequests }) {
    const res = await db.query(
      `UPDATE privacy_settings
       SET profile_visibility = COALESCE($1, profile_visibility),
           read_receipts = COALESCE($2, read_receipts),
           online_status = COALESCE($3, online_status),
           last_seen_visibility = COALESCE($4, last_seen_visibility),
           group_invitation_approval = COALESCE($5, group_invitation_approval),
           message_requests = COALESCE($6, message_requests),
           updated_at = NOW()
       WHERE user_id = $7
       RETURNING *`,
      [profileVisibility, readReceipts, onlineStatus, lastSeenVisibility, groupInvitationApproval, messageRequests, userId]
    );
    return res.rows[0];
  }

  // Sessions & Devices
  static async createSession({ userId, tokenHash, deviceInfo, ipAddress, userAgent, expiresAt }) {
    const res = await db.query(
      `INSERT INTO sessions (user_id, token_hash, device_info, ip_address, user_agent, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, device_info, ip_address, created_at, last_active_at`,
      [userId, tokenHash, deviceInfo, ipAddress, userAgent, expiresAt]
    );
    return res.rows[0];
  }

  static async findSession(tokenHash) {
    const res = await db.query(
      `SELECT s.*, u.status as user_status 
       FROM sessions s
       JOIN users u ON u.id = s.user_id
       WHERE s.token_hash = $1 AND s.is_revoked = false AND s.expires_at > NOW()`,
      [tokenHash]
    );
    return res.rows[0] || null;
  }

  static async touchSession(sessionId) {
    await db.query(`UPDATE sessions SET last_active_at = NOW() WHERE id = $1`, [sessionId]);
  }

  static async getUserSessions(userId, currentSessionTokenHash = null) {
    const res = await db.query(
      `SELECT id, device_info, ip_address, user_agent, is_revoked, last_active_at, created_at,
              (token_hash = $2) as is_current
       FROM sessions
       WHERE user_id = $1 AND is_revoked = false AND expires_at > NOW()
       ORDER BY last_active_at DESC`,
      [userId, currentSessionTokenHash || '']
    );
    return res.rows;
  }

  static async revokeSession(sessionId, userId) {
    const res = await db.query(
      `UPDATE sessions SET is_revoked = true WHERE id = $1 AND user_id = $2 RETURNING id`,
      [sessionId, userId]
    );
    return res.rowCount > 0;
  }

  static async revokeAllOtherSessions(userId, currentTokenHash) {
    const res = await db.query(
      `UPDATE sessions SET is_revoked = true 
       WHERE user_id = $1 AND token_hash != $2 AND is_revoked = false
       RETURNING id`,
      [userId, currentTokenHash]
    );
    return res.rowCount;
  }
}

module.exports = UserModel;
