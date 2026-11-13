import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/safe_avatar.dart';
import 'chat_screen.dart';

class WhatsAppStarredScreen extends StatefulWidget {
  const WhatsAppStarredScreen({super.key});

  @override
  State<WhatsAppStarredScreen> createState() => _WhatsAppStarredScreenState();
}

class _WhatsAppStarredScreenState extends State<WhatsAppStarredScreen> {
  final List<Map<String, dynamic>> _starred = [
    {
      'id': 'star_1',
      'sender': 'Lena Rivers',
      'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=120',
      'text': 'The project architecture looks really solid! Sending over the revised spec file now.',
      'time': 'Yesterday, 4:15 pm',
    },
    {
      'id': 'star_2',
      'sender': 'David Kim',
      'avatar': '',
      'text': 'Here is the meeting room link: https://connekt.net.in/meet/team-sync-992',
      'time': 'Oct 24, 11:30 am',
    },
    {
      'id': 'star_3',
      'sender': 'CONNEKT Core Team',
      'avatar': '',
      'isGroup': true,
      'text': 'Sprint release v2.4 deployment scheduled for Friday 8:00 PM EST.',
      'time': 'Oct 20, 2:40 pm',
    },
  ];

  void _unstar(int index) {
    final item = _starred[index];
    setState(() {
      _starred.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unstarred message from ${item['sender']}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _unstarAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: const Text('Unstar all messages?'),
        content: const Text('Are you sure you want to unstar all messages in all chats?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCoral),
            child: const Text('Unstar all', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _starred.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Starred Messages',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_starred.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textPrimary),
              onSelected: (val) {
                if (val == 'unstar_all') _unstarAll();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'unstar_all',
                  child: Text('Unstar all'),
                ),
              ],
            ),
        ],
      ),
      body: _starred.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.star_rounded, size: 40, color: Color(0xFFF59E0B)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No starred messages',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      'Tap and hold any message in a chat to star it, so you can easily find it later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _starred.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _starred[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          contactName: item['sender'],
                          avatarUrl: item['avatar'] ?? '',
                          showBackButton: true,
                          isGroup: item['isGroup'] == true,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sender row
                        Row(
                          children: [
                            SafeAvatar(
                              url: item['avatar'] is String && item['avatar'].isNotEmpty ? item['avatar'] : null,
                              fallbackText: item['sender'],
                              size: 32,
                              radius: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item['sender'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              item['time'],
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.star, color: Color(0xFFF59E0B), size: 18),
                              tooltip: 'Unstar',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _unstar(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Message bubble text
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.getInputColor(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item['text'],
                            style: TextStyle(fontSize: 13.5, color: textPrimary, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
