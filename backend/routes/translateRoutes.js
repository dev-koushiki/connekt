const express = require('express');
const router = express.Router();
const TranslateController = require('../controllers/translateController');
const { requireAuth } = require('../middleware/authMiddleware');

// Translation endpoint (supports authenticated or session-based queries)
router.post('/', requireAuth, TranslateController.translate);
router.post('/public', TranslateController.translate);

module.exports = router;
