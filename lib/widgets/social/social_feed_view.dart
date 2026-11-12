import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/social_models.dart';
import '../../models/user_model.dart';
import '../../services/social_service.dart';
import '../safe_avatar.dart';
import 'post_card_widget.dart';
import 'user_profile_sheet.dart';

class SocialFeedView extends StatefulWidget {
  final UserModel? user;

  const SocialFeedView({super.key, this.user});

  @override
  State<SocialFeedView> createState() => _SocialFeedViewState();
}

class _SocialFeedViewState extends State<SocialFeedView> {
  int _subTab = 0; // 0: Feed, 1: Friends & Requests, 2: My Profile
  String _feedFilter = 'all'; // all | trending | following | saved
  bool _loading = true;

  List<SocialPost> _posts = [];
  List<PersonSummary> _friends = [];
  List<PersonSummary> _incomingRequests = [];
  List<PersonSummary> _suggestions = [];
  Set<String> _followingIds = {};
  int _followersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String get _currentUserId => widget.user?.id ?? '';

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SocialService.getFeed(mode: 'social', filter: _feedFilter),
        SocialService.getPeopleOverview(kind: 'friend'),
      ]);
      if (!mounted) return;
      final posts = results[0] as List<SocialPost>;
      final people = results[1] as Map<String, dynamic>;
      setState(() {
        _posts = posts;
        _friends = (people['connections'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => PersonSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _incomingRequests = (people['incomingRequests'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => PersonSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _suggestions = (people['suggestions'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => PersonSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _followingIds = (people['followingIds'] as List<dynamic>? ?? const []).map((e) => e.toString()).toSet();
        _followersCount = int.tryParse((people['followersCount'] ?? 0).toString()) ?? 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openComposer({SocialPost? editingPost}) async {
    final contentCtrl = TextEditingController(text: editingPost?.content ?? '');
    String visibility = editingPost?.visibility ?? 'public';
    final List<SocialMediaAttachment> media = editingPost != null ? [...editingPost.mediaUrls] : [];
    bool uploading = false;

    final published = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final textPrimary = AppTheme.getTextPrimary(ctx);
          return Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      editingPost != null ? 'Edit Post' : 'Create Social Post',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: visibility,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'public', child: Text('Public')),
                        DropdownMenuItem(value: 'friends', child: Text('Friends')),
                        DropdownMenuItem(value: 'private', child: Text('Only Me')),
                      ],
                      onChanged: (v) {
                        if (v != null) setSheet(() => visibility = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  minLines: 3,
                  decoration: const InputDecoration(hintText: "What's on your mind? Share updates, photos or videos..."),
                ),
                if (media.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: media
                        .map((m) => Chip(
                              avatar: Icon(m.type == 'video' ? Icons.videocam_rounded : Icons.image_rounded, size: 16),
                              label: Text(m.filename.isNotEmpty ? m.filename : m.type, style: const TextStyle(fontSize: 12)),
                              onDeleted: () => setSheet(() => media.remove(m)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (editingPost == null)
                      OutlinedButton.icon(
                        icon: uploading
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.perm_media_outlined, size: 18),
                        label: const Text('Photo / Video'),
                        onPressed: uploading
                            ? null
                            : () async {
                                final files = await FilePicker.pickFiles();
                                if (files.isEmpty) return;
                                final picked = files.first;
                                setSheet(() => uploading = true);
                                try {
                                  final bytes = await picked.readAsBytes();
                                  final uploaded = await SocialService.uploadSocialMedia(
                                    filename: picked.name,
                                    bytes: bytes,
                                  );
                                  if (uploaded != null) {
                                    setSheet(() => media.add(uploaded));
                                  }
                                } finally {
                                  setSheet(() => uploading = false);
                                }
                              },
                      ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(editingPost != null ? 'Save' : 'Post'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (published == true) {
      if (editingPost != null) {
        final ok = await SocialService.updatePost(
          editingPost.id,
          content: contentCtrl.text.trim(),
          visibility: visibility,
        );
        if (ok) await _loadAll();
      } else {
        final hasVideo = media.any((m) => m.type == 'video');
        final hasImage = media.any((m) => m.type == 'image');
        final postType = hasVideo ? 'video' : (hasImage ? 'image' : 'text');
        final created = await SocialService.createPost(
          mode: 'social',
          postType: postType,
          content: contentCtrl.text.trim(),
          mediaUrls: media,
          visibility: visibility,
        );
        if (created != null && mounted) {
          setState(() => _posts.insert(0, created));
        }
      }
    }
    contentCtrl.dispose();
  }

  Future<void> _openShareDialog(SocialPost post) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.repeat_rounded, color: AppTheme.brandBlue),
              title: const Text('Share to your Social Feed'),
              onTap: () => Navigator.pop(ctx, 'feed'),
            ),
            ListTile(
              leading: const Icon(Icons.send_rounded, color: AppTheme.brandBlue),
              title: const Text('Send directly to CONNEKT friends'),
              onTap: () => Navigator.pop(ctx, 'users'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'feed' && mounted) {
      final created = await SocialService.createPost(
        mode: 'social',
        postType: 'share',
        content: 'Shared a post',
        sharedPostId: post.id,
      );
      if (created != null && mounted) {
        setState(() => _posts.insert(0, created));
      }
    } else if (choice == 'users' && mounted) {
      final pool = {..._friends, ..._suggestions}.toList();
      if (pool.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No users available to share with yet')));
        return;
      }
      final selected = <String>{};
      final sent = await showDialog<bool>(
        context: context,
        builder: (dCtx) => StatefulBuilder(
          builder: (dCtx, setDlg) => AlertDialog(
            title: const Text('Share with Friends'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: pool
                    .map((u) => CheckboxListTile(
                          value: selected.contains(u.id),
                          title: Text(u.fullName),
                          subtitle: Text('@${u.username}'),
                          onChanged: (v) => setDlg(() => v == true ? selected.add(u.id) : selected.remove(u.id)),
                        ))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text('Share'),
              ),
            ],
          ),
        ),
      );
      if (sent == true && selected.isNotEmpty) {
        await SocialService.shareWithUsers(post.id, selected.toList());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared successfully')));
      }
    }
  }

  Future<void> _openEditSocialProfileDialog() async {
    final nameCtrl = TextEditingController(text: widget.user?.personalProfile?.fullName ?? widget.user?.username ?? '');
    final bioCtrl = TextEditingController(text: widget.user?.personalProfile?.bio ?? '');
    final locCtrl = TextEditingController(text: widget.user?.personalProfile?.location ?? '');
    String visibility = widget.user?.privacySettings?.profileVisibility ?? 'public';
    String? coverUrl;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Customize Social Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 8),
                TextField(controller: bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio')),
                const SizedBox(height: 8),
                TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: visibility,
                  decoration: const InputDecoration(labelText: 'Profile Privacy'),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                    DropdownMenuItem(value: 'friends', child: Text('Friends Only')),
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlg(() => visibility = v);
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.wallpaper_rounded),
                  label: Text(coverUrl != null ? 'Cover Uploaded' : 'Upload Cover Photo'),
                  onPressed: () async {
                    final files = await FilePicker.pickFiles(type: FileType.image);
                    if (files.isEmpty) return;
                    final f = files.first;
                    final bytes = await f.readAsBytes();
                    final up = await SocialService.uploadSocialMedia(filename: f.name, bytes: bytes);
                    if (up != null) setDlg(() => coverUrl = up.url);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await SocialService.updateSocialProfile({
        'fullName': nameCtrl.text.trim(),
        'displayName': nameCtrl.text.trim(),
        'bio': bioCtrl.text.trim(),
        'location': locCtrl.text.trim(),
        'profileVisibility': visibility,
        'coverUrl': ?coverUrl,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Social profile updated')));
    }
    nameCtrl.dispose();
    bioCtrl.dispose();
    locCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Column(
      children: [
        // Sub-navigation Pills
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Row(
            children: [
              _subNavChip('Feed', 0, Icons.dynamic_feed_rounded),
              const SizedBox(width: 8),
              _subNavChip('Friends (${_friends.length})', 1, Icons.people_outline_rounded, badge: _incomingRequests.length),
              const SizedBox(width: 8),
              _subNavChip('Profile', 2, Icons.person_outline_rounded),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.brandBlue))
              : _subTab == 0
                  ? _buildFeedTab(cardColor, borderColor, textPrimary, textSecondary)
                  : _subTab == 1
                      ? _buildFriendsTab(cardColor, borderColor, textPrimary, textSecondary)
                      : _buildMySocialProfileTab(cardColor, borderColor, textPrimary, textSecondary),
        ),
      ],
    );
  }

  Widget _subNavChip(String label, int idx, IconData icon, {int badge = 0}) {
    final active = _subTab == idx;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: active ? Colors.white : AppTheme.brandBlue),
      label: Text(badge > 0 ? '$label • $badge' : label),
      selected: active,
      selectedColor: AppTheme.brandBlue,
      labelStyle: TextStyle(
        color: active ? Colors.white : AppTheme.getTextSecondary(context),
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _subTab = idx),
    );
  }

  Widget _buildFeedTab(Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          // Create Post Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                SafeAvatar(
                  url: widget.user?.personalProfile?.avatarUrl,
                  fallbackText: (widget.user?.username ?? 'U')[0].toUpperCase(),
                  size: 40,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _openComposer(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.getInputColor(context),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text("What's on your mind? Share photo or video...", style: TextStyle(color: textSecondary, fontSize: 13.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Feed Filters (For You / Trending / Following / Saved)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in const [
                  {'id': 'all', 'label': 'News Feed'},
                  {'id': 'trending', 'label': 'Trending'},
                  {'id': 'following', 'label': 'Following'},
                  {'id': 'saved', 'label': 'Saved Posts'},
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(item['label']!),
                      selected: _feedFilter == item['id'],
                      selectedColor: AppTheme.brandBlue.withValues(alpha: 0.16),
                      checkmarkColor: AppTheme.brandBlue,
                      onSelected: (_) {
                        setState(() => _feedFilter = item['id']!);
                        _loadAll();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  'No social posts yet. Create the first post!',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
              ),
            )
          else
            ..._posts.map((post) => PostCardWidget(
                  post: post,
                  onTapAuthor: () => showUserProfileSheet(context, userId: post.authorId, currentUserId: _currentUserId),
                  onReact: (reaction) async {
                    final res = await SocialService.reactToPost(post.id, reaction);
                    if (res != null && mounted) {
                      setState(() {
                        final i = _posts.indexWhere((p) => p.id == post.id);
                        if (i != -1) {
                          _posts[i] = _posts[i].copyWith(
                            likesCount: res['likesCount'] as int? ?? _posts[i].likesCount,
                            myReaction: res['myReaction']?.toString(),
                            clearReaction: res['myReaction'] == null,
                          );
                        }
                      });
                    }
                  },
                  onOpenComments: () => showPostCommentsSheet(
                    context,
                    post: post,
                    onCommentsUpdated: (count) {
                      setState(() {
                        final i = _posts.indexWhere((p) => p.id == post.id);
                        if (i != -1) _posts[i] = _posts[i].copyWith(commentsCount: count);
                      });
                    },
                  ),
                  onShare: () => _openShareDialog(post),
                  onToggleSave: () async {
                    final saved = await SocialService.toggleSavePost(post.id);
                    if (saved != null && mounted) {
                      setState(() {
                        final i = _posts.indexWhere((p) => p.id == post.id);
                        if (i != -1) _posts[i] = _posts[i].copyWith(isSaved: saved);
                      });
                    }
                  },
                  onEdit: () => _openComposer(editingPost: post),
                  onDelete: () async {
                    final ok = await SocialService.deletePost(post.id);
                    if (ok && mounted) setState(() => _posts.removeWhere((p) => p.id == post.id));
                  },
                  onReport: () async {
                    await SocialService.reportContent(targetType: 'post', targetId: post.id, reason: 'Inappropriate content');
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post reported')));
                  },
                  onBlockAuthor: () async {
                    await SocialService.blockUser(post.authorId);
                    await _loadAll();
                  },
                )),
        ],
      ),
    );
  }

  Widget _buildFriendsTab(Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          if (_incomingRequests.isNotEmpty) ...[
            Text('Friend Requests', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            ..._incomingRequests.map((u) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
                  child: Row(
                    children: [
                      SafeAvatar(url: u.avatarUrl, fallbackText: u.fullName[0].toUpperCase(), size: 40, radius: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.fullName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                            Text('@${u.username}', style: TextStyle(color: textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                        onPressed: () async {
                          if (u.requestId != null) {
                            await SocialService.respondConnectionRequest(u.requestId!, 'accept');
                            await _loadAll();
                          }
                        },
                        child: const Text('Accept'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () async {
                          if (u.requestId != null) {
                            await SocialService.respondConnectionRequest(u.requestId!, 'reject');
                            await _loadAll();
                          }
                        },
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 14),
          ],

          Text('Friends (${_friends.length})', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          if (_friends.isEmpty)
            Text('You have not added any friends yet.', style: TextStyle(color: textSecondary))
          else
            ..._friends.map((u) => ListTile(
                  leading: SafeAvatar(url: u.avatarUrl, fallbackText: u.fullName[0].toUpperCase(), size: 40, radius: 20),
                  title: Text(u.fullName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                  subtitle: Text('@${u.username}', style: TextStyle(color: textSecondary)),
                  onTap: () => showUserProfileSheet(context, userId: u.id, currentUserId: _currentUserId),
                )),

          const SizedBox(height: 16),
          Text('Suggested Friends', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          ..._suggestions.map((u) {
            final isFollowing = _followingIds.contains(u.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => showUserProfileSheet(context, userId: u.id, currentUserId: _currentUserId),
                    child: SafeAvatar(url: u.avatarUrl, fallbackText: u.fullName[0].toUpperCase(), size: 42, radius: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.fullName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                        Text(u.bio.isNotEmpty ? u.bio : '@${u.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final f = await SocialService.toggleFollow(u.id);
                      if (f != null && mounted) {
                        setState(() => f ? _followingIds.add(u.id) : _followingIds.remove(u.id));
                      }
                    },
                    child: Text(isFollowing ? 'Following' : 'Follow'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                    onPressed: () async {
                      await SocialService.sendConnectionRequest(u.id, kind: 'friend');
                      await _loadAll();
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMySocialProfileTab(Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    final fullName = widget.user?.personalProfile?.fullName.isNotEmpty == true
        ? widget.user!.personalProfile!.fullName
        : widget.user?.username ?? 'User';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              SafeAvatar(
                url: widget.user?.personalProfile?.avatarUrl,
                fallbackText: fullName[0].toUpperCase(),
                size: 76,
                radius: 38,
              ),
              const SizedBox(height: 10),
              Text(fullName, style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('@${widget.user?.username ?? 'user'}', style: const TextStyle(color: AppTheme.brandBlue, fontWeight: FontWeight.w600)),
              if (widget.user?.personalProfile?.bio.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(widget.user!.personalProfile!.bio, textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statTile('Friends', '${_friends.length}', textPrimary, textSecondary),
                  _statTile('Followers', '$_followersCount', textPrimary, textSecondary),
                  _statTile('Following', '${_followingIds.length}', textPrimary, textSecondary),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Profile, Cover & Privacy'),
                  onPressed: _openEditSocialProfileDialog,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String val, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: textSecondary, fontSize: 12)),
      ],
    );
  }
}
