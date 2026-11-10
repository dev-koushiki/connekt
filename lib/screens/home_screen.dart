import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../services/theme_service.dart';

class HomeScreen extends StatelessWidget {
  final UserModel? user;
  final ValueChanged<int>? onNavigateToTab;
  final ValueChanged<String>? onModeChanged;

  const HomeScreen({
    super.key,
    required this.user,
    this.onNavigateToTab,
    this.onModeChanged,
  });

  String get _displayName {
    final personal = user?.personalProfile;
    if (personal != null && personal.fullName.trim().isNotEmpty) {
      return personal.fullName.trim();
    }
    if (personal != null && personal.displayName.trim().isNotEmpty) {
      return personal.displayName.trim();
    }
    if (user != null && user!.username.trim().isNotEmpty) {
      return user!.username.trim();
    }
    return 'User';
  }

  String get _connektEmail {
    if (user != null && user!.email.trim().isNotEmpty) {
      return user!.email.trim();
    }
    if (user != null && user!.username.trim().isNotEmpty) {
      return '${user!.username.trim().toLowerCase()}@connekt.me';
    }
    return 'user@connekt.me';
  }

  void _showNotificationsSheet(BuildContext context) {
    final notifications = [
      {
        'title': 'Upcoming Meeting',
        'body': 'CONNEKT Product & Architecture Sync starts in 15 minutes.',
        'time': 'Just now',
        'icon': Icons.videocam_rounded,
        'isNew': true,
      },
      {
        'title': 'Connekt Mail Delivery',
        'body': 'Security Team: Welcome to CONNEKT – Account Setup & Security Keys',
        'time': '1h ago',
        'icon': Icons.mail_rounded,
        'isNew': false,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, color: AppTheme.accentBlue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCoral,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '2 NEW',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 24),
            ...notifications.map(
              (n) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(n['icon'] as IconData, color: AppTheme.accentBlue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                n['title'] as String,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                n['time'] as String,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            n['body'] as String,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (n['isNew'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentCoral,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.personalProfile?.avatarUrl;
    final currentMode = user?.currentMode ?? 'common';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----------------------------------------------------
              // 1. TOP SECTION (Compact Mobile Header)
              // ----------------------------------------------------
              Row(
                children: [
                  // CONNEKT Brand Logo Badge (Official Red Swirl Emblem)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF13192B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF243048) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(
                      'assets/icons/connekt_emblem.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'C',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.brandRed,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Application Name & Mode Pill
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CONNEKT',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.brandBlue,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.brandBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.brandBlue.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          currentMode.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Light Mood and Dark Mood Toggle Option
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? const Color(0xFFFFB800) : const Color(0xFF334155),
                      size: 22,
                    ),
                    tooltip: isDark ? 'Switch to Light Mood' : 'Switch to Dark Mood',
                    onPressed: () => ThemeService.toggleTheme(),
                  ),
                  // Notification Bell with Red Indicator Dot
                  IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                          size: 24,
                        ),
                        Positioned(
                          right: 1,
                          top: 1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.accentCoral,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    tooltip: 'Notifications',
                    onPressed: () => _showNotificationsSheet(context),
                  ),
                  const SizedBox(width: 4),
                  // User Profile Avatar
                  GestureDetector(
                    onTap: () => onNavigateToTab?.call(4),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accentBlue.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: avatarUrl != null && avatarUrl.isNotEmpty && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                              )
                            : _buildAvatarFallback(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ----------------------------------------------------
              // 2. WELCOME SECTION
              // ----------------------------------------------------
              Text(
                'Hello, $_displayName!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome to CONNEKT!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Everything you need to connect, communicate and collaborate.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // ----------------------------------------------------
              // 3. MAIN APPLICATION SECTION (3 Interactive Cards)
              // ----------------------------------------------------
              // Card 1: Meetings
              _buildAppCard(
                context: context,
                icon: Icons.videocam_rounded,
                title: 'Meetings',
                description: 'Connect through video and audio meetings.',
                badgeText: '1 UPCOMING',
                badgeColor: AppTheme.accentBlue,
                infoSnippet: 'Sync at 3:00 PM • Room ready',
                onTap: () => onNavigateToTab?.call(1),
              ),

              const SizedBox(height: 14),

              // Card 2: Chats
              _buildAppCard(
                context: context,
                icon: Icons.chat_bubble_rounded,
                title: 'Chats',
                description: 'Connect through individual and group conversations.',
                badgeText: null,
                badgeColor: null,
                infoSnippet: 'No active conversations',
                onTap: () => onNavigateToTab?.call(2),
              ),

              const SizedBox(height: 14),

              // Card 3: Mails
              _buildAppCard(
                context: context,
                icon: Icons.mail_rounded,
                title: 'Mails',
                description: 'Send, receive and manage your emails.',
                badgeText: '2 UNREAD',
                badgeColor: AppTheme.accentCoral,
                infoSnippet: _connektEmail,
                onTap: () => onNavigateToTab?.call(3),
              ),

              const SizedBox(height: 28),

              // Bottom subtle security / workspace pill
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 14, color: AppTheme.accentBlue),
                      const SizedBox(width: 6),
                      Text(
                        'CONNEKT Unified Workspace • Session Active',
                        style: TextStyle(
                          color: AppTheme.textMuted.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final initial = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'C';
    return Container(
      color: AppTheme.accentBlue.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    String? badgeText,
    Color? badgeColor,
    required String infoSnippet,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF13192B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        splashColor: AppTheme.brandBlue.withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Icon Box
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.brandBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.brandBlue.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: AppTheme.brandBlue,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Middle Text & Badge Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          if (badgeText != null && badgeText.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            // Subtle Notification / Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? AppTheme.brandBlue).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (badgeColor ?? AppTheme.brandBlue).withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  color: badgeColor ?? AppTheme.brandBlue,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Extra contextual indicator (e.g. meeting time, email handle)
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: badgeColor ?? AppTheme.brandBlue,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              infoSnippet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.textMuted.withValues(alpha: 0.9)
                                    : AppTheme.textMutedLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Right Clickable Arrow Indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
