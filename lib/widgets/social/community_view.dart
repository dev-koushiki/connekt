import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/social_models.dart';
import '../../models/user_model.dart';
import '../../screens/live_stream_screen.dart';
import '../../services/social_service.dart';
import 'post_card_widget.dart';
import 'user_profile_sheet.dart';

class CommunityView extends StatefulWidget {
  final UserModel? user;

  const CommunityView({super.key, this.user});

  @override
  State<CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends State<CommunityView> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  List<CommunityModel> _communities = [];
  CommunityModel? _selectedCommunity;
  String? _selectedGroupId;

  bool _detailRestricted = false;
  List<CommunityGroupModel> _groups = [];
  List<SocialPost> _posts = [];
  List<Map<String, dynamic>> _members = [];
  List<CommunityLiveSession> _liveSessions = [];

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _currentUserId => widget.user?.id ?? '';

  Future<void> _loadCommunities() async {
    setState(() => _loading = true);
    try {
      final list = await SocialService.listCommunities(q: _searchCtrl.text.trim());
      if (mounted) setState(() => _communities = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCommunity(CommunityModel c, {String? groupId}) async {
    setState(() {
      _selectedCommunity = c;
      _selectedGroupId = groupId;
      _loading = true;
    });
    try {
      final d = await SocialService.getCommunityDetail(c.id, groupId: groupId);
      if (!mounted) return;
      setState(() {
        _detailRestricted = d['restricted'] == true;
        if (d['community'] is Map) {
          _selectedCommunity = CommunityModel.fromJson(Map<String, dynamic>.from(d['community']));
        }
        _groups = (d['groups'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((g) => CommunityGroupModel.fromJson(Map<String, dynamic>.from(g)))
            .toList();
        _posts = (d['posts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((p) => SocialPost.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        _members = (d['members'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _liveSessions = (d['liveSessions'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((ls) => CommunityLiveSession.fromJson(Map<String, dynamic>.from(ls)))
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createCommunityDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final rulesCtrl = TextEditingController(text: 'Respect all members and share constructive insights.');
    String visibility = 'public';
    String category = 'Technology';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Create a Community'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Community Name')),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                TextField(controller: rulesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Community Rules')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: visibility,
                  decoration: const InputDecoration(labelText: 'Visibility'),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Public (Anyone can join)')),
                    DropdownMenuItem(value: 'private', child: Text('Private (Requires approval/invite)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlg(() => visibility = v);
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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final created = await SocialService.createCommunity({
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'rules': rulesCtrl.text.trim(),
        'visibility': visibility,
        'category': category,
      });
      if (created != null) {
        await _loadCommunities();
        await _openCommunity(created);
      }
    }
    nameCtrl.dispose();
    descCtrl.dispose();
    rulesCtrl.dispose();
  }

  Future<void> _createGroupDialog() async {
    if (_selectedCommunity == null) return;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final topicCtrl = TextEditingController(text: 'Discussion');
    bool announcementOnly = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Create Group in Community'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group Name')),
                const SizedBox(height: 8),
                TextField(controller: topicCtrl, decoration: const InputDecoration(labelText: 'Topic')),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                CheckboxListTile(
                  value: announcementOnly,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Announcements Channel', style: TextStyle(fontSize: 13)),
                  onChanged: (v) => setDlg(() => announcementOnly = v == true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final created = await SocialService.createGroup(_selectedCommunity!.id, {
        'name': nameCtrl.text.trim(),
        'topic': topicCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'isAnnouncementOnly': announcementOnly,
      });
      if (created != null) {
        await _openCommunity(_selectedCommunity!, groupId: created.id);
      }
    }
    nameCtrl.dispose();
    descCtrl.dispose();
    topicCtrl.dispose();
  }

  Future<void> _createCommunityPostDialog() async {
    if (_selectedCommunity == null) return;
    final contentCtrl = TextEditingController();
    String postType = 'discussion';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('New Community Discussion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: postType,
                decoration: const InputDecoration(labelText: 'Post Type'),
                items: const [
                  DropdownMenuItem(value: 'discussion', child: Text('Discussion')),
                  DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
                  DropdownMenuItem(value: 'question', child: Text('Question')),
                ],
                onChanged: (v) {
                  if (v != null) setDlg(() => postType = v);
                },
              ),
              const SizedBox(height: 8),
              TextField(controller: contentCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Share with community members...')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && contentCtrl.text.trim().isNotEmpty) {
      await SocialService.createCommunityPost(_selectedCommunity!.id, {
        'groupId': _selectedGroupId,
        'postType': postType,
        'content': contentCtrl.text.trim(),
      });
      await _openCommunity(_selectedCommunity!, groupId: _selectedGroupId);
    }
    contentCtrl.dispose();
  }

  Future<void> _goLiveOrScheduleDialog() async {
    if (_selectedCommunity == null) return;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool scheduleLater = false;
    DateTime scheduledFor = DateTime.now().add(const Duration(hours: 2));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Community Live Broadcast'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Stream Title')),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Topic / Agenda')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Schedule for later'),
                value: scheduleLater,
                onChanged: (v) => setDlg(() => scheduleLater = v),
              ),
              if (scheduleLater)
                Text('Scheduled for +2 hours (${scheduledFor.hour}:${scheduledFor.minute.toString().padLeft(2, '0')})',
                    style: const TextStyle(color: AppTheme.brandBlue, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCoral, foregroundColor: Colors.white),
              icon: const Icon(Icons.sensors_rounded, size: 17),
              label: Text(scheduleLater ? 'Schedule Live' : 'Go Live Now'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      final session = await SocialService.startOrScheduleLive(
        _selectedCommunity!.id,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        groupId: _selectedGroupId,
        scheduledFor: scheduleLater ? scheduledFor : null,
      );
      if (session != null && mounted) {
        if (!scheduleLater) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LiveStreamScreen(session: session, isHost: true)),
          );
        }
        await _openCommunity(_selectedCommunity!, groupId: _selectedGroupId);
      }
    }
    titleCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _openMembersSheet() async {
    if (_selectedCommunity == null) return;
    final isMod = _selectedCommunity!.myRole == 'admin' || _selectedCommunity!.myRole == 'moderator';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Members & Moderators (${_members.length})',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  if (isMod)
                    TextButton.icon(
                      icon: const Icon(Icons.person_add_outlined, size: 17),
                      label: const Text('Invite'),
                      onPressed: () async {
                        final qCtrl = TextEditingController();
                        final hits = await SocialService.searchUsers('');
                        if (!ctx.mounted) return;
                        final chosen = await showDialog<PersonSummary>(
                          context: ctx,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Invite Member to Community'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView(
                                shrinkWrap: true,
                                children: hits
                                    .map((u) => ListTile(
                                          title: Text(u.fullName),
                                          subtitle: Text('@${u.username}'),
                                          onTap: () => Navigator.pop(dCtx, u),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                        );
                        qCtrl.dispose();
                        if (chosen != null) {
                          await SocialService.manageCommunityMember(_selectedCommunity!.id, userId: chosen.id, action: 'invite');
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _openCommunity(_selectedCommunity!, groupId: _selectedGroupId);
                        }
                      },
                    ),
                ],
              ),
              const Divider(),
              ..._members.map((m) {
                final role = (m['role'] ?? 'member').toString();
                final status = (m['status'] ?? 'active').toString();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text((m['full_name'] ?? m['username'] ?? 'Member').toString()),
                  subtitle: Text('${role.toUpperCase()} • ${status.toUpperCase()}'),
                  trailing: isMod && m['user_id'] != _currentUserId
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == 'pending')
                              TextButton(
                                onPressed: () async {
                                  await SocialService.manageCommunityMember(_selectedCommunity!.id, userId: m['user_id'].toString(), action: 'approve');
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _openCommunity(_selectedCommunity!, groupId: _selectedGroupId);
                                },
                                child: const Text('Approve'),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (act) async {
                                if (act == 'mod') {
                                  await SocialService.manageCommunityMember(_selectedCommunity!.id, userId: m['user_id'].toString(), action: 'set_role', role: 'moderator');
                                } else if (act == 'remove') {
                                  await SocialService.manageCommunityMember(_selectedCommunity!.id, userId: m['user_id'].toString(), action: 'remove');
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                await _openCommunity(_selectedCommunity!, groupId: _selectedGroupId);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'mod', child: Text('Make Moderator')),
                                PopupMenuItem(value: 'remove', child: Text('Remove Member')),
                              ],
                            ),
                          ],
                        )
                      : null,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCommunity != null) {
      return _buildCommunityWorkspace(context);
    }

    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _loadCommunities(),
                  decoration: InputDecoration(
                    hintText: 'Search communities & groups...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create'),
                onPressed: _createCommunityDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.brandBlue))
              : RefreshIndicator(
                  onRefresh: _loadCommunities,
                  child: _communities.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.groups_rounded, size: 54, color: AppTheme.brandBlue),
                                  const SizedBox(height: 10),
                                  Text('No communities yet', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('Create a Facebook-style Community with Groups & Live streams.', style: TextStyle(color: textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                          itemCount: _communities.length,
                          itemBuilder: (_, i) {
                            final c = _communities[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppTheme.brandBlue.withValues(alpha: 0.14),
                                        child: Icon(c.visibility == 'private' ? Icons.lock_outline : Icons.groups_rounded, color: AppTheme.brandBlue),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(c.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15.5)),
                                            Text(
                                              '${c.visibility.toUpperCase()} • ${c.membersCount} members • ${c.groupsCount} groups',
                                              style: TextStyle(color: textSecondary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (c.liveCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: AppTheme.accentCoral, borderRadius: BorderRadius.circular(10)),
                                          child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                                        ),
                                    ],
                                  ),
                                  if (c.description.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(c.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textPrimary, fontSize: 13)),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _openCommunity(c),
                                          child: const Text('Open Community'),
                                        ),
                                      ),
                                      if (c.myStatus != 'active') ...[
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                                          onPressed: () async {
                                            await SocialService.joinCommunity(c.id);
                                            await _loadCommunities();
                                          },
                                          child: Text(c.myStatus == 'pending' ? 'Requested' : 'Join'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildCommunityWorkspace(BuildContext context) {
    final c = _selectedCommunity!;
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isActive = c.myStatus == 'active' || c.ownerId == _currentUserId;
    final isMod = c.myRole == 'admin' || c.myRole == 'moderator';

    return Column(
      children: [
        // Community Top Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: cardColor, border: Border(bottom: BorderSide(color: borderColor))),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() => _selectedCommunity = null);
                  _loadCommunities();
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${c.visibility.toUpperCase()} • ${c.membersCount} members', style: TextStyle(color: textSecondary, fontSize: 11.5)),
                  ],
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.people_outline, size: 17),
                label: const Text('Members'),
                onPressed: _openMembersSheet,
              ),
              if (isActive)
                IconButton(
                  tooltip: 'Community Live',
                  icon: const Icon(Icons.sensors_rounded, color: AppTheme.accentCoral),
                  onPressed: _goLiveOrScheduleDialog,
                ),
            ],
          ),
        ),

        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.brandBlue)))
        else if (_detailRestricted)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 52, color: AppTheme.brandBlue),
                    const SizedBox(height: 10),
                    Text('Private Community', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 6),
                    Text(c.description, textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                      onPressed: () async {
                        await SocialService.joinCommunity(c.id);
                        await _openCommunity(c);
                      },
                      child: Text(c.myStatus == 'pending' ? 'Approval Pending' : 'Request to Join'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                // Community Rules Card
                if (c.rules.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.brandBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Community Rules: ${c.rules}', style: TextStyle(color: textPrimary, fontSize: 12.5)),
                  ),

                // Live & Scheduled Broadcasts
                if (_liveSessions.isNotEmpty) ...[
                  Text('Community Live & Scheduled', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 6),
                  ..._liveSessions.where((s) => s.status != 'ended').map((ls) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ls.status == 'live' ? AppTheme.accentCoral : borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              ls.status == 'live' ? Icons.sensors_rounded : Icons.event_available_outlined,
                              color: ls.status == 'live' ? AppTheme.accentCoral : AppTheme.brandBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ls.title, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                                  Text('${ls.status.toUpperCase()} • Host: ${ls.hostName}', style: TextStyle(color: textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ls.status == 'live' ? AppTheme.accentCoral : AppTheme.brandBlue,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LiveStreamScreen(session: ls, isHost: ls.hostId == _currentUserId),
                                  ),
                                );
                              },
                              child: Text(ls.status == 'live' ? 'Watch Live' : 'Open'),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                ],

                // Groups inside Community
                Row(
                  children: [
                    Text('Groups in Community (${_groups.length})', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const Spacer(),
                    if (isActive)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('New Group'),
                        onPressed: _createGroupDialog,
                      ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All Discussions'),
                          selected: _selectedGroupId == null,
                          onSelected: (_) => _openCommunity(c, groupId: null),
                        ),
                      ),
                      ..._groups.map((g) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InputChip(
                              label: Text('${g.name} (${g.membersCount})'),
                              selected: _selectedGroupId == g.id,
                              onPressed: () => _openCommunity(c, groupId: g.id),
                              onDeleted: isActive
                                  ? () async {
                                      await SocialService.toggleJoinGroup(g.id);
                                      await _openCommunity(c, groupId: _selectedGroupId);
                                    }
                                  : null,
                              deleteIcon: Icon(g.isMember ? Icons.check_circle_outline : Icons.add_circle_outline, size: 16),
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                      icon: const Icon(Icons.post_add_rounded, size: 18),
                      label: Text(_selectedGroupId != null ? 'Post in Selected Group' : 'Start Discussion or Announcement'),
                      onPressed: _createCommunityPostDialog,
                    ),
                  ),

                if (_posts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Center(child: Text('No group posts yet.', style: TextStyle(color: textSecondary))),
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
                          onCommentsUpdated: (cnt) {
                            setState(() {
                              final i = _posts.indexWhere((p) => p.id == post.id);
                              if (i != -1) _posts[i] = _posts[i].copyWith(commentsCount: cnt);
                            });
                          },
                        ),
                        onShare: () {},
                        onToggleSave: () => SocialService.toggleSavePost(post.id),
                        onPinToggle: isMod
                            ? () async {
                                await SocialService.moderateCommunityPost(post.id, 'pin');
                                await _openCommunity(c, groupId: _selectedGroupId);
                              }
                            : null,
                        onDelete: (post.isOwnPost || isMod)
                            ? () async {
                                await SocialService.moderateCommunityPost(post.id, 'delete');
                                await _openCommunity(c, groupId: _selectedGroupId);
                              }
                            : null,
                      )),
              ],
            ),
          ),
      ],
    );
  }
}
