import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/social_models.dart';
import '../../services/social_service.dart';
import '../safe_avatar.dart';

class PostCardWidget extends StatelessWidget {
  final SocialPost post;
  final VoidCallback onTapAuthor;
  final ValueChanged<String> onReact;
  final VoidCallback onOpenComments;
  final VoidCallback onShare;
  final VoidCallback onToggleSave;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPinToggle;
  final VoidCallback? onReport;
  final VoidCallback? onBlockAuthor;

  const PostCardWidget({
    super.key,
    required this.post,
    required this.onTapAuthor,
    required this.onReact,
    required this.onOpenComments,
    required this.onShare,
    required this.onToggleSave,
    this.onEdit,
    this.onDelete,
    this.onPinToggle,
    this.onReport,
    this.onBlockAuthor,
  });

  String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final origin = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _visibilityIcon(String vis) {
    switch (vis) {
      case 'friends':
      case 'connections':
        return Icons.group_outlined;
      case 'private':
        return Icons.lock_outline_rounded;
      case 'community':
        return Icons.groups_outlined;
      default:
        return Icons.public_rounded;
    }
  }

  Widget _reactionChip(BuildContext context, String type, String emoji, String label) {
    final selected = post.myReaction == type;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onReact(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandBlue.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.brandBlue : AppTheme.getBorderColor(context),
          ),
        ),
        child: Text(
          '$emoji $label',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.brandBlue : AppTheme.getTextSecondary(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.isPinned)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: const [
                  Icon(Icons.push_pin_rounded, size: 14, color: AppTheme.brandBlue),
                  SizedBox(width: 5),
                  Text('Pinned Post', style: TextStyle(color: AppTheme.brandBlue, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

          // Author Header
          Row(
            children: [
              GestureDetector(
                onTap: onTapAuthor,
                child: SafeAvatar(
                  url: post.authorAvatarUrl,
                  fallbackText: post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'U',
                  size: 42,
                  radius: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onTapAuthor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5),
                            ),
                          ),
                          if (post.authorIsPro) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.brandBlue.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(color: AppTheme.brandBlue, fontSize: 9.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                          if (post.postType == 'article') ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.brandBlueLight.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ARTICLE',
                                style: TextStyle(color: AppTheme.brandBlueLight, fontSize: 9.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (post.authorHeadline.isNotEmpty && post.mode == 'professional')
                        Text(
                          post.authorHeadline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textSecondary, fontSize: 11.5),
                        ),
                      Row(
                        children: [
                          Text(
                            '@${post.authorUsername} • ${_timeAgo(post.createdAt)} • ',
                            style: TextStyle(color: textSecondary, fontSize: 11.5),
                          ),
                          Icon(_visibilityIcon(post.visibility), size: 12.5, color: textSecondary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: post.isSaved ? AppTheme.brandBlue : textSecondary,
                  size: 20,
                ),
                tooltip: post.isSaved ? 'Saved' : 'Save post',
                onPressed: onToggleSave,
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: textSecondary),
                onSelected: (v) {
                  if (v == 'edit' && onEdit != null) onEdit!();
                  if (v == 'delete' && onDelete != null) onDelete!();
                  if (v == 'pin' && onPinToggle != null) onPinToggle!();
                  if (v == 'report' && onReport != null) onReport!();
                  if (v == 'block' && onBlockAuthor != null) onBlockAuthor!();
                },
                itemBuilder: (_) => [
                  if (onPinToggle != null)
                    PopupMenuItem(value: 'pin', child: Text(post.isPinned ? 'Unpin Post' : 'Pin Post')),
                  if (post.isOwnPost && onEdit != null)
                    const PopupMenuItem(value: 'edit', child: Text('Edit Post')),
                  if ((post.isOwnPost || onPinToggle != null) && onDelete != null)
                    const PopupMenuItem(value: 'delete', child: Text('Delete Post')),
                  if (!post.isOwnPost && onReport != null)
                    const PopupMenuItem(value: 'report', child: Text('Report Content')),
                  if (!post.isOwnPost && onBlockAuthor != null)
                    const PopupMenuItem(value: 'block', child: Text('Block User')),
                ],
              ),
            ],
          ),

          if (post.title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.title,
              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],

          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              post.content,
              style: TextStyle(color: textPrimary, fontSize: 14.2, height: 1.45),
            ),
          ],

          // Embedded Shared Post preview
          if (post.sharedPostId != null && post.sharedPostContent != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.getInputColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shared from ${post.sharedPostAuthor ?? 'Member'}',
                    style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(post.sharedPostContent!, style: TextStyle(color: textPrimary, fontSize: 13)),
                ],
              ),
            ),
          ],

          // Media Attachments
          if (post.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...post.mediaUrls.map((m) {
              if (m.type == 'video') {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.filename.isNotEmpty ? m.filename : 'Uploaded Video',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            Text(_resolveUrl(m.url), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _resolveUrl(m.url),
                    height: 210,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      color: AppTheme.getInputColor(context),
                      child: Center(child: Text(m.filename.isNotEmpty ? m.filename : 'Media Attachment', style: TextStyle(color: textSecondary))),
                    ),
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 10),
          // Multi-Reaction Quick Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _reactionChip(context, 'like', '👍', 'Like'),
                const SizedBox(width: 6),
                _reactionChip(context, 'love', '❤️', 'Love'),
                const SizedBox(width: 6),
                _reactionChip(context, 'celebrate', '🎉', 'Celebrate'),
                const SizedBox(width: 6),
                _reactionChip(context, 'insightful', '💡', 'Insightful'),
              ],
            ),
          ),

          const Divider(height: 18),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => onReact(post.myReaction ?? 'like'),
                icon: Icon(
                  post.myReaction != null ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                  size: 18,
                  color: post.myReaction != null ? AppTheme.brandBlue : textSecondary,
                ),
                label: Text(
                  '${post.likesCount}',
                  style: TextStyle(color: post.myReaction != null ? AppTheme.brandBlue : textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onOpenComments,
                icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: textSecondary),
                label: Text('${post.commentsCount} Comments', style: TextStyle(color: textSecondary)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onShare,
                icon: Icon(Icons.share_outlined, size: 18, color: textSecondary),
                label: Text('${post.sharesCount}', style: TextStyle(color: textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reusable modal sheet showing post comments and nested replies.
Future<void> showPostCommentsSheet(
  BuildContext context, {
  required SocialPost post,
  required ValueChanged<int> onCommentsUpdated,
}) async {
  final textCtrl = TextEditingController();
  String? replyToId;
  String? replyToName;
  List<PostComment> comments = await SocialService.getComments(post.id);

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.getCardColor(context),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final textPrimary = AppTheme.getTextPrimary(ctx);
        final textSecondary = AppTheme.getTextSecondary(ctx);
        final topLevel = comments.where((c) => c.parentCommentId == null).toList();

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.68,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.forum_outlined, color: AppTheme.brandBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Comments (${comments.length})', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: comments.isEmpty
                      ? Center(child: Text('No comments yet. Start the conversation!', style: TextStyle(color: textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: topLevel.length,
                          itemBuilder: (_, idx) {
                            final c = topLevel[idx];
                            final replies = comments.where((r) => r.parentCommentId == c.id).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCommentRow(ctx, c, onReply: () {
                                  setSheetState(() {
                                    replyToId = c.id;
                                    replyToName = c.authorName;
                                  });
                                }),
                                ...replies.map((r) => Padding(
                                      padding: const EdgeInsets.only(left: 34),
                                      child: _buildCommentRow(ctx, r),
                                    )),
                              ],
                            );
                          },
                        ),
                ),
                if (replyToName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: AppTheme.brandBlue.withValues(alpha: 0.08),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Replying to $replyToName', style: const TextStyle(color: AppTheme.brandBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        GestureDetector(
                          onTap: () => setSheetState(() {
                            replyToId = null;
                            replyToName = null;
                          }),
                          child: const Icon(Icons.close, size: 16, color: AppTheme.brandBlue),
                        ),
                      ],
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textCtrl,
                            decoration: InputDecoration(
                              hintText: replyToName != null ? 'Write a reply...' : 'Write a comment...',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: AppTheme.brandBlue),
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          onPressed: () async {
                            final body = textCtrl.text.trim();
                            if (body.isEmpty) return;
                            textCtrl.clear();
                            final created = await SocialService.addComment(post.id, body, parentCommentId: replyToId);
                            if (created != null) {
                              setSheetState(() {
                                comments.add(created);
                                replyToId = null;
                                replyToName = null;
                              });
                              onCommentsUpdated(comments.length);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  textCtrl.dispose();
}

Widget _buildCommentRow(BuildContext context, PostComment c, {VoidCallback? onReply}) {
  final textPrimary = AppTheme.getTextPrimary(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeAvatar(
          url: c.authorAvatarUrl,
          fallbackText: c.authorName.isNotEmpty ? c.authorName[0].toUpperCase() : 'U',
          size: 28,
          radius: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.getInputColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.authorName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(c.content, style: TextStyle(color: textPrimary, fontSize: 13.5)),
                if (onReply != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: onReply,
                      child: Text('Reply', style: TextStyle(color: AppTheme.brandBlue, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
