const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const chatController = require('../controllers/chatController');
const { requireAuth } = require('../middleware/authMiddleware');

// Multer storage for chat files and media
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../uploads/chats');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}_${Math.round(Math.random() * 1e9)}`;
    const ext = path.extname(file.originalname) || '';
    cb(null, `file_${uniqueSuffix}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit
});

// Get all conversations list
router.get('/', requireAuth, chatController.getConversations);

// Create a new group conversation
router.post('/group', requireAuth, chatController.createGroup);

// Get message history with a contact / phone / conversation
router.get('/:target/messages', requireAuth, chatController.getMessages);

// Send message & dispatch SMS
router.post('/send', requireAuth, chatController.sendMessage);

// Upload file / media / audio
router.post('/upload', requireAuth, upload.single('file'), chatController.uploadFile);

// Delete message (for_me or for_everyone)
router.delete('/messages/:messageId', requireAuth, chatController.deleteMessage);

module.exports = router;
