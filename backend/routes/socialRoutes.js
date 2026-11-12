const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const router = express.Router();
const socialController = require('../controllers/socialController');
const { requireAuth } = require('../middleware/authMiddleware');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../uploads/social');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '';
    cb(null, `soc_${Date.now()}_${Math.round(Math.random() * 1e9)}${ext}`);
  }
});

const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });

router.use(requireAuth);

router.get('/feed', socialController.getFeed);
router.post('/posts', socialController.createPost);
router.patch('/posts/:id', socialController.updatePost);
router.delete('/posts/:id', socialController.deletePost);
router.post('/posts/:id/react', socialController.reactToPost);
router.get('/posts/:id/comments', socialController.getComments);
router.post('/posts/:id/comments', socialController.addComment);
router.post('/posts/:id/save', socialController.toggleSavePost);
router.post('/posts/:id/share-users', socialController.shareWithUsers);

router.get('/people', socialController.getPeopleOverview);
router.get('/users/search', socialController.searchUsers);
router.get('/users/:id/profile', socialController.getUserProfile);
router.post('/connections', socialController.sendConnectionRequest);
router.post('/connections/:id/respond', socialController.respondConnectionRequest);
router.post('/follow/:id', socialController.toggleFollow);
router.put('/profile', socialController.updateSocialProfile);
router.post('/block/:id', socialController.blockUser);
router.post('/reports', socialController.reportContent);
router.post('/notifications/read', socialController.markNotificationsRead);
router.post('/media', upload.single('file'), socialController.uploadSocialMedia);

module.exports = router;
