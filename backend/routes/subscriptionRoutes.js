const express = require('express');
const router = express.Router();
const subscriptionController = require('../controllers/subscriptionController');
const { requireAuth } = require('../middleware/authMiddleware');

router.use(requireAuth);

router.get('/plans', subscriptionController.getPlansAndStatus);
router.post('/subscribe', subscriptionController.subscribe);
router.post('/cancel', subscriptionController.cancelOrExpire);

module.exports = router;
