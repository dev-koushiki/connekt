const express = require('express');
const router = express.Router();
const UserController = require('../controllers/userController');
const { requireAuth } = require('../middleware/authMiddleware');
const { uploadAvatar } = require('../middleware/upload');

// Mode management
router.post('/mode', requireAuth, UserController.switchMode);

// Personal Profile
router.put('/profile/personal', requireAuth, UserController.updatePersonalProfile);
router.post('/profile/avatar', requireAuth, uploadAvatar.single('avatar'), UserController.uploadAvatar);
router.post('/avatar', requireAuth, uploadAvatar.single('avatar'), UserController.uploadAvatar);

// Professional Profile
router.put('/profile/professional', requireAuth, UserController.updateProfessionalProfile);

// Skills
router.post('/skills', requireAuth, UserController.addSkill);
router.delete('/skills/:skillId', requireAuth, UserController.deleteSkill);

// Education
router.post('/education', requireAuth, UserController.addEducation);
router.delete('/education/:eduId', requireAuth, UserController.deleteEducation);

// Experience
router.post('/experience', requireAuth, UserController.addExperience);
router.delete('/experience/:expId', requireAuth, UserController.deleteExperience);

// Privacy Settings
router.get('/privacy', requireAuth, UserController.getPrivacy);
router.put('/privacy', requireAuth, UserController.updatePrivacy);

// Contacts Search
router.get('/contacts', requireAuth, UserController.getContacts);

module.exports = router;
