const UserModel = require('../models/userModel');
const { successResponse, errorResponse } = require('../utils/responseHandler');

class UserController {
  /**
   * Switch between Common Mode, Professional Mode, and Both Mode
   */
  static async switchMode(req, res) {
    try {
      const { mode } = req.body;
      if (!mode || !['common', 'professional', 'both'].includes(mode)) {
        return errorResponse(res, 400, 'Invalid mode. Allowed: common, professional, both');
      }

      const updated = await UserModel.updateCurrentMode(req.user.id, mode);
      const user = await UserModel.findById(req.user.id);

      return successResponse(res, 200, `Switched to ${mode.toUpperCase()} mode.`, {
        currentMode: updated.current_mode,
        user
      });
    } catch (err) {
      console.error('[Switch Mode Error]:', err);
      return errorResponse(res, 500, 'Failed to update user mode.');
    }
  }

  /**
   * Update preferred language for the authenticated user
   */
  static async updateLanguage(req, res) {
    try {
      const { language } = req.body;
      if (!language || typeof language !== 'string') {
        return errorResponse(res, 400, 'Language code is required.');
      }

      const langCode = language.trim().toLowerCase();
      await UserModel.updatePreferredLanguage(req.user.id, langCode);
      const user = await UserModel.findById(req.user.id);

      return successResponse(res, 200, 'Language updated successfully.', {
        preferredLanguage: langCode,
        user
      });
    } catch (err) {
      console.error('[Update Language Error]:', err);
      return errorResponse(res, 500, 'Failed to update preferred language.');
    }
  }

  /**
   * Get preferred language for the authenticated user
   */
  static async getLanguage(req, res) {
    try {
      const user = await UserModel.findById(req.user.id);
      return successResponse(res, 200, 'Preferred language retrieved.', {
        preferredLanguage: user?.preferred_language || 'en'
      });
    } catch (err) {
      console.error('[Get Language Error]:', err);
      return errorResponse(res, 500, 'Failed to retrieve preferred language.');
    }
  }

  /**
   * Update personal profile information
   */
  static async updatePersonalProfile(req, res) {
    try {
      const {
        fullName,
        displayName,
        bio,
        location,
        website,
        birthdate,
        gender,
        interests
      } = req.body;

      const updated = await UserModel.updatePersonalProfile(req.user.id, {
        fullName,
        displayName,
        bio,
        location,
        website,
        birthdate,
        gender,
        interests: Array.isArray(interests) ? interests : undefined
      });

      return successResponse(res, 200, 'Personal profile updated successfully.', {
        personalProfile: updated
      });
    } catch (err) {
      console.error('[Update Personal Profile Error]:', err);
      return errorResponse(res, 500, 'Failed to update personal profile.');
    }
  }

  /**
   * Update professional profile information
   */
  static async updateProfessionalProfile(req, res) {
    try {
      const {
        headline,
        currentCompany,
        industry,
        summary,
        yearsOfExperience,
        portfolioUrl,
        githubUrl,
        linkedinUrl,
        resumeUrl,
        isOpenToWork,
        isHiring
      } = req.body;

      const updated = await UserModel.updateProfessionalProfile(req.user.id, {
        headline,
        currentCompany,
        industry,
        summary,
        yearsOfExperience: yearsOfExperience !== undefined ? parseInt(yearsOfExperience, 10) : undefined,
        portfolioUrl,
        githubUrl,
        linkedinUrl,
        resumeUrl,
        isOpenToWork: isOpenToWork !== undefined ? Boolean(isOpenToWork) : undefined,
        isHiring: isHiring !== undefined ? Boolean(isHiring) : undefined
      });

      return successResponse(res, 200, 'Professional profile updated successfully.', {
        professionalProfile: updated
      });
    } catch (err) {
      console.error('[Update Professional Profile Error]:', err);
      return errorResponse(res, 500, 'Failed to update professional profile.');
    }
  }

  /**
   * Upload user avatar
   */
  static async uploadAvatar(req, res) {
    try {
      if (!req.file) {
        return errorResponse(res, 400, 'No image file uploaded.');
      }

      const avatarUrl = `/uploads/avatars/${req.file.filename}`;
      await UserModel.updateAvatarUrl(req.user.id, avatarUrl);
      const user = await UserModel.findById(req.user.id);

      return successResponse(res, 200, 'Avatar uploaded successfully.', {
        avatarUrl,
        user
      });
    } catch (err) {
      console.error('[Upload Avatar Error]:', err);
      return errorResponse(res, 500, 'Failed to upload avatar image.');
    }
  }

  /**
   * Skills management
   */
  static async addSkill(req, res) {
    try {
      const { skillName, proficiency } = req.body;
      if (!skillName || !skillName.trim()) {
        return errorResponse(res, 400, 'Skill name is required.');
      }

      const skill = await UserModel.addSkill(req.user.id, skillName, proficiency);
      return successResponse(res, 201, 'Skill added.', { skill });
    } catch (err) {
      console.error('[Add Skill Error]:', err);
      return errorResponse(res, 500, 'Failed to add skill.');
    }
  }

  static async deleteSkill(req, res) {
    try {
      const { skillId } = req.params;
      const deleted = await UserModel.deleteSkill(req.user.id, skillId);
      if (!deleted) {
        return errorResponse(res, 404, 'Skill not found or unauthorized.');
      }
      return successResponse(res, 200, 'Skill removed.');
    } catch (err) {
      console.error('[Delete Skill Error]:', err);
      return errorResponse(res, 500, 'Failed to delete skill.');
    }
  }

  /**
   * Education management
   */
  static async addEducation(req, res) {
    try {
      const { institution, degree, fieldOfStudy, startYear, endYear } = req.body;
      if (!institution || !degree) {
        return errorResponse(res, 400, 'Institution and degree are required.');
      }

      const edu = await UserModel.addEducation(req.user.id, {
        institution,
        degree,
        fieldOfStudy,
        startYear: startYear ? parseInt(startYear, 10) : null,
        endYear: endYear ? parseInt(endYear, 10) : null
      });

      return successResponse(res, 201, 'Education item added.', { education: edu });
    } catch (err) {
      console.error('[Add Education Error]:', err);
      return errorResponse(res, 500, 'Failed to add education.');
    }
  }

  static async deleteEducation(req, res) {
    try {
      const { eduId } = req.params;
      const deleted = await UserModel.deleteEducation(req.user.id, eduId);
      if (!deleted) {
        return errorResponse(res, 404, 'Education record not found.');
      }
      return successResponse(res, 200, 'Education record removed.');
    } catch (err) {
      console.error('[Delete Education Error]:', err);
      return errorResponse(res, 500, 'Failed to delete education.');
    }
  }

  /**
   * Experience management
   */
  static async addExperience(req, res) {
    try {
      const { companyName, title, location, startDate, endDate, isCurrent, description } = req.body;
      if (!companyName || !title) {
        return errorResponse(res, 400, 'Company name and title are required.');
      }

      const exp = await UserModel.addExperience(req.user.id, {
        companyName,
        title,
        location,
        startDate,
        endDate,
        isCurrent: Boolean(isCurrent),
        description
      });

      return successResponse(res, 201, 'Work experience added.', { experience: exp });
    } catch (err) {
      console.error('[Add Experience Error]:', err);
      return errorResponse(res, 500, 'Failed to add experience.');
    }
  }

  static async deleteExperience(req, res) {
    try {
      const { expId } = req.params;
      const deleted = await UserModel.deleteExperience(req.user.id, expId);
      if (!deleted) {
        return errorResponse(res, 404, 'Experience record not found.');
      }
      return successResponse(res, 200, 'Experience record removed.');
    } catch (err) {
      console.error('[Delete Experience Error]:', err);
      return errorResponse(res, 500, 'Failed to delete experience.');
    }
  }

  /**
   * Privacy settings
   */
  static async getPrivacy(req, res) {
    try {
      const settings = await UserModel.getPrivacySettings(req.user.id);
      return successResponse(res, 200, 'Privacy settings retrieved.', { privacySettings: settings });
    } catch (err) {
      console.error('[Get Privacy Error]:', err);
      return errorResponse(res, 500, 'Failed to get privacy settings.');
    }
  }

  static async updatePrivacy(req, res) {
    try {
      const {
        profileVisibility,
        readReceipts,
        onlineStatus,
        lastSeenVisibility,
        groupInvitationApproval,
        messageRequests
      } = req.body;

      const updated = await UserModel.updatePrivacySettings(req.user.id, {
        profileVisibility,
        readReceipts,
        onlineStatus,
        lastSeenVisibility,
        groupInvitationApproval,
        messageRequests
      });

      return successResponse(res, 200, 'Privacy settings updated successfully.', {
        privacySettings: updated
      });
    } catch (err) {
      console.error('[Update Privacy Error]:', err);
      return errorResponse(res, 500, 'Failed to update privacy settings.');
    }
  }

  /**
   * Search registered CONNEKT users for contacts / calling
   */
  static async getContacts(req, res) {
    try {
      const db = require('../config/database');
      const q = req.query.q ? `%${req.query.q.trim().toLowerCase()}%` : '%';
      const result = await db.query(
        `SELECT u.id, u.username, u.email, u.phone, 
                COALESCE(p.full_name, u.username) AS full_name,
                COALESCE(p.display_name, p.full_name, u.username) AS display_name,
                COALESCE(p.avatar_url, '') AS avatar_url
         FROM users u
         LEFT JOIN user_profiles p ON u.id = p.user_id
         WHERE u.id != $1 AND (
           LOWER(u.username) LIKE $2 OR 
           LOWER(u.email) LIKE $2 OR 
           LOWER(COALESCE(u.phone, '')) LIKE $2 OR
           LOWER(COALESCE(p.full_name, '')) LIKE $2
         )
         ORDER BY full_name ASC LIMIT 200`,
        [req.user.id, q]
      );
      return successResponse(res, 200, 'Contacts retrieved', { contacts: result.rows });
    } catch (err) {
      console.error('[Get Contacts Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch contacts');
    }
  }

  /**
   * Match device phone numbers against registered CONNEKT accounts
   */
  static async matchContacts(req, res) {
    try {
      const db = require('../config/database');
      const { phones = [] } = req.body || {};
      if (!Array.isArray(phones) || phones.length === 0) {
        return successResponse(res, 200, 'No phones provided', { matches: [] });
      }

      const last10Set = new Set();
      for (const raw of phones.slice(0, 500)) {
        const digits = (raw || '').toString().replace(/\D/g, '');
        if (digits.length >= 7) {
          last10Set.add(digits.length > 10 ? digits.slice(-10) : digits);
        }
      }

      const tailList = Array.from(last10Set);
      if (tailList.length === 0) {
        return successResponse(res, 200, 'No valid phone numbers', { matches: [] });
      }

      const result = await db.query(
        `SELECT u.id, u.username, u.email, u.phone,
                COALESCE(p.full_name, u.username) AS full_name,
                COALESCE(p.display_name, p.full_name, u.username) AS display_name,
                COALESCE(p.avatar_url, '') AS avatar_url
         FROM users u
         LEFT JOIN user_profiles p ON u.id = p.user_id
         WHERE u.id != $1
           AND RIGHT(REGEXP_REPLACE(COALESCE(u.phone, ''), '[^0-9]', '', 'g'), 10) = ANY($2)`,
        [req.user.id, tailList]
      );

      return successResponse(res, 200, 'Contacts matched', { matches: result.rows });
    } catch (err) {
      console.error('[Match Contacts Error]:', err);
      return errorResponse(res, 500, 'Failed to match phone contacts');
    }
  }

  /**
   * Send an SMS invitation to a phone contact who does not yet have CONNEKT
   */
  static async sendInvite(req, res) {
    try {
      const db = require('../config/database');
      const { sendSms, normalizePhoneNumber } = require('../services/smsService');
      const rawPhone = (req.body?.phone || '').toString().trim();
      const contactName = (req.body?.name || '').toString().trim();

      if (!rawPhone) {
        return errorResponse(res, 400, 'Recipient phone number is required');
      }

      const formattedPhone = normalizePhoneNumber(rawPhone) || rawPhone;
      const inviterLabel = req.user.username ? `@${req.user.username}` : 'Your contact';
      const inviteMessage = contactName
        ? `Hi ${contactName}, ${inviterLabel} invited you to chat on CONNEKT! Join here: https://connekt.net.in`
        : `${inviterLabel} invited you to chat on CONNEKT! Join here: https://connekt.net.in`;

      await db.query(`
        CREATE TABLE IF NOT EXISTS app_invitations (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          recipient_phone VARCHAR(40) NOT NULL,
          recipient_name VARCHAR(120) DEFAULT '',
          dispatched_via VARCHAR(40) DEFAULT 'native_sms_fallback',
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `);

      let dispatchedViaGateway = false;
      try {
        const smsRes = await sendSms({
          to: formattedPhone,
          message: inviteMessage,
          purpose: 'app_invite'
        });
        dispatchedViaGateway = Boolean(smsRes && smsRes.success);
      } catch (_) {
        dispatchedViaGateway = false;
      }

      await db.query(
        `INSERT INTO app_invitations (inviter_id, recipient_phone, recipient_name, dispatched_via)
         VALUES ($1, $2, $3, $4)`,
        [
          req.user.id,
          formattedPhone,
          contactName.slice(0, 120),
          dispatchedViaGateway ? 'sms_gateway' : 'native_sms_fallback'
        ]
      );

      return successResponse(res, 200, dispatchedViaGateway ? 'Invitation SMS sent' : 'Invitation prepared', {
        phone: formattedPhone,
        inviteMessage,
        dispatchedViaGateway
      });
    } catch (err) {
      console.error('[Send Invite Error]:', err);
      return errorResponse(res, 500, 'Failed to prepare invitation');
    }
  }
}

module.exports = UserController;
