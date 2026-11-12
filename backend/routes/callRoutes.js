const express = require('express');
const router = express.Router();
const CallController = require('../controllers/callController');
const { requireAuth } = require('../middleware/authMiddleware');

// All call log endpoints require authentication
router.use(requireAuth);

// Upload device call logs from phone contacts
router.post('/device-logs', CallController.uploadDeviceLogs);

// Retrieve synced device call logs (with optional ?type=incoming|outgoing|missed)
router.get('/device-logs', CallController.getDeviceLogs);

// Trigger sync request to phone when user logs in to website
router.post('/request-sync', CallController.requestSync);

// Check sync status
router.get('/sync-status', CallController.getSyncStatus);

module.exports = router;
