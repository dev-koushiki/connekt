import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/safe_avatar.dart';
import 'chat_screen.dart';

class WhatsAppArchivedScreen extends StatefulWidget {
  final List<Map<String, dynamic>> archivedChats;
  final ValueChanged<Map<String, dynamic>> onUnarchive;

  const WhatsAppArchivedScreen({
    super.key,
    required this.archivedChats,
    required this.onUnarchive,
  });

  @override
  State<WhatsAppArchivedScreen> createState() => _WhatsAppArchivedScreenState();
}

class _WhatsAppArchivedScreenState extends State<WhatsAppArchivedScreen> {
  late List<Map<String, dynamic>> _list;
  bool _keepArchived = true;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.archivedChats);
  }

  void _showArchiveSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Archive Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF1D4ED8),
                title: Text(
                  'Keep chats archived',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                subtitle: const Text(
                  'Archived chats will remain archived when you receive a new message',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                ),
                value: _keepArchived,
                onChanged: (val) {
                  setSheetState(() => _keepArchived = val);
                  setState(() => _keepArchived = val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bgColor = AppTheme.getBackgroundColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Archived',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: textPrimary),
            onPressed: _showArchiveSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner notification
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: isDark ? const Color(0xFF131D31) : const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(Icons.archive_outlined, size: 20, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _keepArchived
                        ? 'These chats stay archived when new messages are received.'
                        : 'Chats will be unarchived when new messages are received.',
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                ),
              ],
            ),
          ),

          // List of archived chats
          Expanded(
            child: _list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.archive_outlined, size: 54, color: textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 14),
                        Text(
                          'No archived chats',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Swipe any chat left on the main screen to archive it',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final chat = _list[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: SafeAvatar(
                            url: chat['avatar'] is String ? chat['avatar'] : null,
                            fallbackText: (chat['name'] ?? '').toString(),
                            size: 44,
                            radius: 22,
                          ),
                          title: Text(
                            chat['name'] ?? '',
                            style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          subtitle: Text(
                            chat['lastMessage'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(chat['time'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              IconButton(
                                icon: const Icon(Icons.unarchive_outlined, color: Color(0xFF1D4ED8)),
                                tooltip: 'Unarchive chat',
                                onPressed: () {
                                  widget.onUnarchive(chat);
                                  setState(() {
                                    _list.removeAt(index);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Chat unarchived: ${chat['name']}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  contactName: (chat['target'] ?? chat['name'] ?? '').toString(),
                                  avatarUrl: (chat['avatar'] ?? '').toString(),
                                  showBackButton: true,
                                  isGroup: chat['isGroup'] == true,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
