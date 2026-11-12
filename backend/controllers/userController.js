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
           LOWER(COALESCE(p.full_name, '')) LIKE $2
         )
         ORDER BY full_name ASC LIMIT 50`,
        [req.user.id, q]
      );
      return successResponse(res, 200, 'Contacts retrieved', { contacts: result.rows });
    } catch (err) {
      console.error('[Get Contacts Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch contacts');
    }
  }
}

module.exports = UserController;
