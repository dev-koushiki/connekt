const express = require('express');
const router = express.Router();
const SessionController = require('../controllers/sessionController');
const { requireAuth } = require('../middleware/authMiddleware');

router.get('/', requireAuth, SessionController.getSessions);
router.delete('/:sessionId', requireAuth, SessionController.revokeSession);
router.delete('/', requireAuth, SessionController.revokeAllOtherSessions);

module.exports = router;
