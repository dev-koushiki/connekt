import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../services/social_service.dart';
import '../safe_avatar.dart';

/// Shows full Social & Professional profile details for any user with
/// friend/connect, follow, skill endorsement, recommendation, block, and report controls.
Future<void> showUserProfileSheet(
  BuildContext context, {
  required String userId,
  required String currentUserId,
  String mode = 'social',
}) async {
  final profile = await SocialService.getUserProfile(userId, mode: mode);
  if (!context.mounted) return;
  if (profile == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile unavailable')),
    );
    return;
  }

  String resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final origin = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.getCardColor(context),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final textPrimary = AppTheme.getTextPrimary(ctx);
        final textSecondary = AppTheme.getTextSecondary(ctx);
        final isOwn = userId == currentUserId;
        final fullName = (profile['fullName'] ?? profile['username'] ?? 'Member').toString();
        final coverUrl = resolveUrl((mode == 'professional' ? profile['bannerUrl'] : profile['coverUrl'])?.toString());
        final skills = (profile['skills'] as List<dynamic>? ?? const []);
        final experience = (profile['experience'] as List<dynamic>? ?? const []);
        final education = (profile['education'] as List<dynamic>? ?? const []);
        final certifications = (profile['certifications'] as List<dynamic>? ?? const []);
        final projects = (profile['projects'] as List<dynamic>? ?? const []);
        final recs = (profile['recommendations'] as List<dynamic>? ?? const []);

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Cover / Banner + Avatar
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), AppTheme.brandBlue],
                      ),
                      image: coverUrl.isNotEmpty
                          ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover)
                          : null,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    bottom: -32,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: AppTheme.getCardColor(ctx), shape: BoxShape.circle),
                      child: SafeAvatar(
                        url: profile['avatarUrl']?.toString(),
                        fallbackText: fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                        size: 72,
                        radius: 36,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: TextStyle(color: textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
                    Text('@${profile['username']} • ${profile['profileVisibility'] ?? 'public'}',
                        style: TextStyle(color: AppTheme.brandBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                    if ((profile['headline'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(profile['headline'].toString(), style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                    if ((profile['bio'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(profile['bio'].toString(), style: TextStyle(color: textSecondary, fontSize: 13.5)),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('${profile['friendsCount'] ?? 0} Connections', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 16),
                        Text('${profile['followersCount'] ?? 0} Followers', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    if (!isOwn) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                            icon: const Icon(Icons.person_add_outlined, size: 17),
                            label: Text(mode == 'professional' ? 'Connect' : 'Add Friend'),
                            onPressed: () async {
                              await SocialService.sendConnectionRequest(
                                userId,
                                kind: mode == 'professional' ? 'professional' : 'friend',
                              );
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Request sent')));
                              }
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.rss_feed_rounded, size: 17),
                            label: const Text('Follow / Unfollow'),
                            onPressed: () async {
                              final f = await SocialService.toggleFollow(userId);
                              if (ctx.mounted && f != null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(f ? 'Following $fullName' : 'Unfollowed $fullName')));
                              }
                            },
                          ),
                          if (mode == 'professional')
                            OutlinedButton.icon(
                              icon: const Icon(Icons.rate_review_outlined, size: 17),
                              label: const Text('Recommend'),
                              onPressed: () async {
                                final ctrl = TextEditingController();
                                final ok = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: Text('Recommend $fullName'),
                                    content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Share their strengths and impact...')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                      ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Submit')),
                                    ],
                                  ),
                                );
                                if (ok == true && ctrl.text.trim().isNotEmpty) {
                                  await SocialService.addRecommendation(userId, content: ctrl.text.trim());
                                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Recommendation posted')));
                                }
                                ctrl.dispose();
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.block_rounded, color: AppTheme.accentCoral),
                            tooltip: 'Block user',
                            onPressed: () async {
                              await SocialService.blockUser(userId);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Blocked $fullName')));
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.flag_outlined, color: AppTheme.accentAmber),
                            tooltip: 'Report user',
                            onPressed: () async {
                              await SocialService.reportContent(targetType: 'user', targetId: userId, reason: 'Reported from profile');
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('User reported')));
                              }
                            },
                          ),
                        ],
                      ),
                    ],

                    if ((profile['about'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('About', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(profile['about'].toString(), style: TextStyle(color: textSecondary, fontSize: 13.5)),
                    ],

                    if (skills.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Skills & Endorsements', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: skills.map((sk) {
                          final m = Map<String, dynamic>.from(sk as Map);
                          return ActionChip(
                            avatar: Icon(
                              m['endorsed_by_me'] == true ? Icons.verified_rounded : Icons.add_circle_outline,
                              size: 16,
                              color: AppTheme.brandBlue,
                            ),
                            label: Text('${m['skill_name']} (${m['endorsed_count'] ?? 0})'),
                            onPressed: isOwn
                                ? null
                                : () async {
                                    final res = await SocialService.endorseSkill(int.parse(m['id'].toString()));
                                    if (res != null) {
                                      setSheetState(() {
                                        m['endorsed_by_me'] = res['endorsedByMe'];
                                        m['endorsed_count'] = res['endorsedCount'];
                                      });
                                    }
                                  },
                          );
                        }).toList(),
                      ),
                    ],

                    if (experience.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Experience', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      ...experience.map((e) {
                        final m = Map<String, dynamic>.from(e as Map);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.work_outline_rounded, color: AppTheme.brandBlue),
                          title: Text('${m['title']} at ${m['company']}', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text((m['description'] ?? '').toString(), style: TextStyle(color: textSecondary, fontSize: 12.5)),
                        );
                      }),
                    ],

                    if (education.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('Education', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      ...education.map((e) {
                        final m = Map<String, dynamic>.from(e as Map);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.school_outlined, color: AppTheme.brandBlue),
                          title: Text('${m['institution']}', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('${m['degree'] ?? ''} ${m['field_of_study'] ?? ''}', style: TextStyle(color: textSecondary, fontSize: 12.5)),
                        );
                      }),
                    ],

                    if (certifications.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('Certifications', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      ...certifications.map((c) {
                        final m = Map<String, dynamic>.from(c as Map);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.workspace_premium_outlined, color: AppTheme.brandBlue),
                          title: Text(m['name'].toString(), style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: Text('${m['issuer'] ?? ''} ${m['issue_date'] ?? ''}', style: TextStyle(color: textSecondary, fontSize: 12.5)),
                        );
                      }),
                    ],

                    if (projects.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('Projects & Portfolio', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      ...projects.map((p) {
                        final m = Map<String, dynamic>.from(p as Map);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.folder_special_outlined, color: AppTheme.brandBlue),
                          title: Text(m['title'].toString(), style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: Text('${m['description'] ?? ''} ${m['project_url'] ?? ''}', style: TextStyle(color: textSecondary, fontSize: 12.5)),
                        );
                      }),
                    ],

                    if (recs.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('Recommendations', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      ...recs.map((r) {
                        final m = Map<String, dynamic>.from(r as Map);
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.getInputColor(ctx),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${m['author_name']} • ${m['relationship'] ?? ''}',
                                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                              const SizedBox(height: 4),
                              Text(m['content'].toString(), style: TextStyle(color: textSecondary, fontSize: 13)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
