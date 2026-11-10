import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../widgets/safe_avatar.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onBackToHome;

  const ChatsScreen({super.key, this.user, this.onBackToHome});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _conversations = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get totalUnreadChats =>
      _conversations.fold<int>(0, (sum, item) => sum + ((item['unread'] as int?) ?? 0));

  void _openChat(Map<String, dynamic> conv) {
    setState(() {
      conv['unread'] = 0;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contactName: conv['name'] ?? 'Chat',
          avatarUrl: conv['avatar'] ?? '',
          showBackButton: true,
        ),
      ),
    );
  }

  void _showNewChatSheet(BuildContext context) {
    final contactController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Conversation',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: contactController,
              autofocus: true,
              style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter username, email or phone...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.person_search_rounded, color: AppTheme.accentBlue),
                filled: true,
                fillColor: AppTheme.getInputColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                label: const Text('Start Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final target = contactController.text.trim();
                  if (target.isEmpty) return;
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        contactName: target,
                        avatarUrl: '',
                        showBackButton: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bgColor = AppTheme.getBackgroundColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final inputColor = AppTheme.getInputColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final borderColor = AppTheme.getBorderColor(context);

    final filteredList = _conversations.where((c) {
      if (_selectedFilter == 'Direct') return c['isGroup'] == false;
      if (_selectedFilter == 'Groups') return c['isGroup'] == true;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentBlue,
        onPressed: () => _showNewChatSheet(context),
        child: const Icon(Icons.chat_outlined, color: Colors.white),
      ),
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: widget.onBackToHome != null
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                tooltip: 'Back to Home',
                onPressed: widget.onBackToHome,
              )
            : null,
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_rounded, color: AppTheme.accentBlue, size: 24),
            const SizedBox(width: 10),
            Text(
              'Chats',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
            ),
            if (totalUnreadChats > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentCoral,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalUnreadChats',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.group_add_outlined, color: isDark ? Colors.white70 : Colors.black87),
            onPressed: () => _showNewChatSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search chats & people...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  fillColor: inputColor,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  _buildFilterChip('All', isDark, cardColor, textSecondary),
                  const SizedBox(width: 8),
                  _buildFilterChip('Direct', isDark, cardColor, textSecondary),
                  const SizedBox(width: 8),
                  _buildFilterChip('Groups', isDark, cardColor, textSecondary),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Conversations List or Empty State
            Expanded(
              child: filteredList.isEmpty
                  ? _buildEmptyState(context, isDark, textPrimary, textSecondary)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final conv = filteredList[index];
                        final int unread = (conv['unread'] as int?) ?? 0;
                        final bool isGroup = conv['isGroup'] == true;
                        final bool isOnline = conv['isOnline'] == true;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openChat(conv),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: unread > 0 ? cardColor : cardColor.withValues(alpha: isDark ? 0.6 : 0.9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: unread > 0
                                      ? AppTheme.accentBlue.withValues(alpha: 0.3)
                                      : borderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Avatar with online/group indicator
                                  Stack(
                                    children: [
                                      SafeAvatar(
                                        url: conv['avatar'] is String ? conv['avatar'] : null,
                                        fallbackText: (conv['name'] ?? '').toString(),
                                        size: 44,
                                        radius: 22,
                                        fallbackIcon: isGroup ? Icons.group : null,
                                      ),
                                      if (isOnline && !isGroup)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: cardColor, width: 2),
                                            ),
                                          ),
                                        ),
                                      if (isGroup)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentBlue,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: cardColor, width: 1.5),
                                            ),
                                            child: const Icon(Icons.group, size: 9, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Name and Last Message
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                conv['name'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: textPrimary,
                                                  fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                                                  fontSize: 14.5,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              conv['time'],
                                              style: TextStyle(
                                                color: unread > 0 ? AppTheme.accentBlue : AppTheme.textMuted,
                                                fontSize: 11,
                                                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                conv['lastMessage'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: unread > 0 ? textPrimary : AppTheme.textMuted,
                                                  fontSize: 12.5,
                                                  fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                            if (unread > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentCoral,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '$unread',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, Color textPrimary, Color textSecondary) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: isDark ? 0.12 : 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accentBlue.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 42,
                  color: AppTheme.accentBlue,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your latest chats and discussions will appear here.\nTap below to start a new conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_comment_rounded, size: 18),
              label: const Text(
                'Start a Chat',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onPressed: () => _showNewChatSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDark, Color cardColor, Color textSecondary) {
    final bool isSelected = _selectedFilter == label;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : (isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
