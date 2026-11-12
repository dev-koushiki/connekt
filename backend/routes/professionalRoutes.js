const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const router = express.Router();
const proController = require('../controllers/professionalController');
const { requireAuth } = require('../middleware/authMiddleware');
const { requireSubscriptionFeature } = require('../middleware/subscriptionMiddleware');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../uploads/professional');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '';
    cb(null, `pro_${Date.now()}_${Math.round(Math.random() * 1e9)}${ext}`);
  }
});

const upload = multer({ storage, limits: { fileSize: 20 * 1024 * 1024 } });

router.use(requireAuth);

router.put('/profile', proController.updateProProfile);
router.post('/certifications', proController.addCertification);
router.delete('/certifications/:id', proController.deleteCertification);
router.post('/projects', proController.addProject);
router.delete('/projects/:id', proController.deleteProject);
router.post('/skills/:skillId/endorse', proController.endorseSkill);
router.post('/recommendations/:userId', proController.addRecommendation);
router.post('/upload', upload.single('file'), proController.uploadProFile);

router.get('/jobs', proController.listJobsAndCompanies);
router.post('/jobs/:id/apply', proController.applyForJob);

// Premium subscription-gated endpoints enforced on the server
router.post('/companies', requireSubscriptionFeature('recruiter_company_tools'), proController.createCompany);
router.post('/jobs', requireSubscriptionFeature('post_job_listings'), proController.createJob);
router.post('/articles', requireSubscriptionFeature('publish_articles'), proController.publishArticle);
router.get('/analytics', requireSubscriptionFeature('profile_analytics'), proController.getProfileAnalytics);

module.exports = router;
