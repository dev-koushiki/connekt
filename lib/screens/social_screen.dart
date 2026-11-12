import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/social_models.dart';
import '../models/user_model.dart';
import '../services/social_service.dart';
import '../widgets/safe_avatar.dart';
import '../widgets/social/community_view.dart';
import '../widgets/social/professional_view.dart';
import '../widgets/social/social_feed_view.dart';
import '../widgets/social/user_profile_sheet.dart';

class SocialScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onBackToHome;

  const SocialScreen({super.key, this.user, this.onBackToHome});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  // 'social' | 'professional' | 'community'
  String _activeSection = 'social';
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _refreshNotificationsCount();
  }

  Future<void> _refreshNotificationsCount() async {
    try {
      final people = await SocialService.getPeopleOverview();
      final list = (people['notifications'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((n) => SocialNotification.fromJson(Map<String, dynamic>.from(n)))
          .toList();
      if (mounted) {
        setState(() => _unreadNotifications = list.where((n) => !n.isRead).length);
      }
    } catch (_) {}
  }

  Future<void> _openPeopleSearch() async {
    final searchCtrl = TextEditingController();
    List<PersonSummary> results = await SocialService.searchUsers('');
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        onChanged: (q) async {
                          final hits = await SocialService.searchUsers(q);
                          setSheet(() => results = hits);
                        },
                        decoration: InputDecoration(
                          hintText: _activeSection == 'professional' ? 'Search professionals...' : 'Search people...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final u = results[i];
                    return ListTile(
                      leading: SafeAvatar(url: u.avatarUrl, fallbackText: u.fullName[0].toUpperCase(), size: 40, radius: 20),
                      title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(u.headline.isNotEmpty ? u.headline : '@${u.username}'),
                      onTap: () {
                        Navigator.pop(ctx);
                        showUserProfileSheet(
                          context,
                          userId: u.id,
                          currentUserId: widget.user?.id ?? '',
                          mode: _activeSection == 'professional' ? 'professional' : 'social',
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    searchCtrl.dispose();
  }

  Future<void> _openNotificationsSheet() async {
    final people = await SocialService.getPeopleOverview();
    await SocialService.markNotificationsRead();
    if (!mounted) return;
    setState(() => _unreadNotifications = 0);

    final notifs = (people['notifications'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((n) => SocialNotification.fromJson(Map<String, dynamic>.from(n)))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Social & Career Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Divider(),
              if (notifs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('No notifications yet')),
                )
              else
                SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: notifs.length,
                    itemBuilder: (_, i) {
                      final n = notifs[i];
                      return ListTile(
                        leading: const Icon(Icons.notifications_active_outlined, color: AppTheme.brandBlue),
                        title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.getBackgroundColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top CONNEKT Social Header
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (widget.onBackToHome != null)
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                          tooltip: 'Back to Home',
                          onPressed: widget.onBackToHome,
                        ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.brandBlue.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.public_rounded, color: AppTheme.brandBlue, size: 19),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Social',
                          style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.search_rounded, color: textPrimary),
                        tooltip: 'Search people',
                        onPressed: _openPeopleSearch,
                      ),
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(Icons.notifications_none_rounded, color: textPrimary),
                            tooltip: 'Notifications',
                            onPressed: _openNotificationsSheet,
                          ),
                          if (_unreadNotifications > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: CircleAvatar(
                                radius: 7,
                                backgroundColor: AppTheme.accentCoral,
                                child: Text(
                                  '$_unreadNotifications',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Clear Visible Switch: Social Mode | Professional Mode | Community (Separate Section)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.getInputColor(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        _modeTabButton(
                          id: 'social',
                          label: 'Social Mode',
                          icon: Icons.people_alt_outlined,
                          textSecondary: textSecondary,
                        ),
                        _modeTabButton(
                          id: 'professional',
                          label: 'Professional Mode',
                          icon: Icons.work_outline_rounded,
                          textSecondary: textSecondary,
                        ),
                        _modeTabButton(
                          id: 'community',
                          label: 'Community',
                          icon: Icons.groups_outlined,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Active Section Body
            Expanded(
              child: IndexedStack(
                index: _activeSection == 'social'
                    ? 0
                    : (_activeSection == 'professional' ? 1 : 2),
                children: [
                  SocialFeedView(user: widget.user),
                  ProfessionalView(user: widget.user),
                  CommunityView(user: widget.user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeTabButton({
    required String id,
    required String label,
    required IconData icon,
    required Color textSecondary,
  }) {
    final active = _activeSection == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSection = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? AppTheme.brandBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? Colors.white : textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : textSecondary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
