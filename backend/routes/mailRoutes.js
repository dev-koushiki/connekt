const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const router = express.Router();
const mailController = require('../controllers/mailController');
const { requireAuth } = require('../middleware/authMiddleware');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../uploads/mail');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}_${Math.round(Math.random() * 1e9)}`;
    const ext = path.extname(file.originalname) || '';
    cb(null, `att_${uniqueSuffix}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 25 * 1024 * 1024 }
});

// Public inbound webhook endpoint (authenticated by MAIL_WEBHOOK_SECRET or HMAC signature)
router.post('/inbound', mailController.receiveInboundWebhook);

router.get('/', requireAuth, mailController.getMailOverview);
router.get('/external-status', requireAuth, mailController.getExternalMailStatus);
router.post('/sync-imap', requireAuth, mailController.syncImapMailbox);
router.post('/send', requireAuth, mailController.sendOrSaveDraft);
router.post('/bulk', requireAuth, mailController.bulkAction);
router.post('/labels', requireAuth, mailController.createLabel);
router.delete('/labels/:id', requireAuth, mailController.deleteLabel);
router.post('/templates', requireAuth, mailController.saveTemplate);
router.delete('/templates/:id', requireAuth, mailController.deleteTemplate);
router.post('/contacts', requireAuth, mailController.saveContact);
router.delete('/contacts/:id', requireAuth, mailController.deleteContact);
router.delete('/folder/:folder', requireAuth, mailController.emptyFolder);
router.put('/settings', requireAuth, mailController.updateSettings);
router.post('/attachments', requireAuth, upload.single('file'), mailController.uploadAttachment);
router.patch('/:id', requireAuth, mailController.updateMessage);
router.delete('/:id', requireAuth, mailController.deleteMessage);

module.exports = router;
