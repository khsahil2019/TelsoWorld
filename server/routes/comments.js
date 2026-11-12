const express = require('express');
const db = require('../db');
const { authOptional } = require('../middleware/auth');

const router = express.Router();

/**
 * 💬 GET /api/comments
 * Accepts query param `video_id`
 */
router.get('/', authOptional, (req, res) => {
  const videoId = req.query.video_id || req.query.videoId;
  if (!videoId) {
    return res.status(422).json({ status: false, message: 'video_id is required' });
  }

  const currentUserId = req.user ? req.user.id : null;
  const comments = db.getComments(videoId, currentUserId);

  return res.status(200).json({
    status: true,
    data: comments,
    comments,
  });
});

/**
 * ✍️ POST /api/comments/add and POST /api/comments
 * Accepts body: { video_id, comment, parent_id? }
 */
const handleAddComment = (req, res) => {
  const { video_id, comment, content, parent_id } = req.body;
  const commentText = comment || content;

  if (!video_id || !commentText) {
    return res.status(422).json({
      status: false,
      message: 'video_id and comment text are required',
    });
  }

  const user = req.user || db.findUserById(req.body.user_id || 1);
  const resData = db.createComment({
    video_id,
    user_id: user ? user.id : 1,
    user_name: user ? (user.name || user.username) : 'Creator',
    username: user ? user.username : 'creator',
    comment: commentText,
    parent_id: parent_id || null,
  });

  return res.status(201).json({
    status: true,
    message: resData.reward_info ? `Comment posted! You earned ₹${resData.reward_info.reward.toFixed(2)} (${resData.reward_info.label})` : 'Comment added successfully',
    data: resData.comment,
    comment: resData.comment,
    reward_info: resData.reward_info,
  });
};

router.post('/add', authOptional, handleAddComment);
router.post('/', authOptional, handleAddComment);

/**
 * ❤️ POST /api/comments/like
 * Accepts body: { comment_id }
 */
router.post('/like', authOptional, (req, res) => {
  const commentId = req.body.comment_id || req.body.id;
  if (!commentId) {
    return res.status(422).json({ status: false, message: 'comment_id is required' });
  }

  const userId = req.user ? req.user.id : 1;
  const result = db.toggleCommentLike(commentId, userId);

  if (!result) {
    return res.status(404).json({ status: false, message: 'Comment not found' });
  }

  return res.status(200).json({
    status: true,
    message: result.is_liked ? 'Comment liked' : 'Comment unliked',
    is_liked: result.is_liked,
    likes: result.likes,
  });
});

/**
 * 🗑️ DELETE /api/comments/:id
 */
router.delete('/:id', authOptional, (req, res) => {
  const success = db.deleteComment(req.params.id);
  if (!success) {
    return res.status(404).json({ status: false, message: 'Comment not found' });
  }
  return res.status(200).json({ status: true, message: 'Comment deleted successfully' });
});

/**
 * 🔁 GET /api/comments/:id/replies
 */
router.get('/:id/replies', authOptional, (req, res) => {
  const currentUserId = req.user ? req.user.id : null;
  const replies = db.getCommentReplies(req.params.id, currentUserId);
  return res.status(200).json({ status: true, data: replies, replies });
});

module.exports = router;

