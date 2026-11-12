const express = require('express');
const router = express.Router();
const communityController = require('../controllers/communityController');
const { requireAuth } = require('../middleware/authMiddleware');

router.use(requireAuth);

router.get('/', communityController.listCommunities);
router.post('/', communityController.createCommunity);
router.get('/:id', communityController.getCommunityDetail);
router.put('/:id', communityController.updateCommunity);
router.post('/:id/join', communityController.joinCommunity);
router.post('/:id/leave', communityController.leaveCommunity);
router.post('/:id/members', communityController.manageMember);

router.post('/:id/groups', communityController.createGroup);
router.post('/groups/:groupId/toggle-join', communityController.toggleJoinGroup);

router.post('/:id/posts', communityController.createCommunityPost);
router.post('/posts/:postId/moderate', communityController.moderatePost);

router.post('/:id/live', communityController.startOrScheduleLive);
router.get('/live/:sessionId', communityController.getLiveSessionDetail);
router.post('/live/:sessionId/comments', communityController.postLiveComment);
router.post('/live/:sessionId/end', communityController.endLiveSession);

module.exports = router;
