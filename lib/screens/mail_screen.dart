import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';

class MailScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onBackToHome;

  const MailScreen({super.key, this.user, this.onBackToHome});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  String _selectedFolder = 'Inbox';
  final TextEditingController _searchController = TextEditingController();

  late List<Map<String, dynamic>> _emails;

  @override
  void initState() {
    super.initState();
    _emails = [
      {
        'id': 'm1',
        'sender': 'CONNEKT Security Team',
        'email': 'security@connekt.me',
        'subject': 'Welcome to CONNEKT – Account Setup & Security Keys',
        'snippet': 'Your new unified communications workspace is active. Read our security best practices...',
        'time': '9:42 AM',
        'isUnread': true,
        'isStarred': true,
        'hasAttachment': true,
        'tag': 'Security',
      },
      {
        'id': 'm2',
        'sender': 'Alex Chen (Product Lead)',
        'email': 'alex.chen@connekt.me',
        'subject': 'Q4 Mobile Ecosystem Launch Roadmap & Specifications',
        'snippet': 'Hi team, please find the updated schedule and engineering milestones for the new mobile release...',
        'time': 'Yesterday',
        'isUnread': true,
        'isStarred': false,
        'hasAttachment': true,
        'tag': 'Work',
      },
      {
        'id': 'm3',
        'sender': 'Lena Rivers',
        'email': 'lena.rivers@connekt.me',
        'subject': 'Collaborative Session Notes & Follow-up',
        'snippet': 'Great catching up today! Here are the key bullet points we discussed regarding the media layout...',
        'time': 'Nov 5',
        'isUnread': false,
        'isStarred': true,
        'hasAttachment': false,
        'tag': 'Team',
      },
      {
        'id': 'm4',
        'sender': 'Cloud Infrastructure Bot',
        'email': 'system-alerts@connekt.me',
        'subject': 'Database Optimization & Health Report: All Systems Nominal',
        'snippet': 'Weekly automated server diagnostics completed with 99.98% uptime and zero latency regressions...',
        'time': 'Nov 3',
        'isUnread': false,
        'isStarred': false,
        'hasAttachment': false,
        'tag': 'System',
      },
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get unreadCount => _emails.where((e) => e['isUnread'] == true).length;

  void _showComposeSheet() {
    final toController = TextEditingController();
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Compose Connekt Mail',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'From: ${widget.user?.email.isNotEmpty == true ? widget.user!.email : '${widget.user?.username ?? "user"}@connekt.me'}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: toController,
                decoration: const InputDecoration(
                  hintText: 'To (e.g. colleague@connekt.me)',
                  prefixIcon: Icon(Icons.alternate_email, size: 18, color: AppTheme.accentBlue),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  hintText: 'Subject',
                  prefixIcon: Icon(Icons.subject, size: 18, color: AppTheme.accentBlue),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write your message...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Send Connekt Mail',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    final to = toController.text.trim();
                    final subj = subjectController.text.trim();
                    if (to.isEmpty || subj.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter recipient and subject'),
                          backgroundColor: AppTheme.accentCoral,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Email sent to $to!'),
                        backgroundColor: AppTheme.accentBlue,
                      ),
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

  void _openEmailDetails(Map<String, dynamic> email) {
    setState(() {
      email['isUnread'] = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        child: Column(
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
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.2),
                  child: Text(
                    email['sender'][0].toUpperCase(),
                    style: const TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email['sender'],
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        email['email'],
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  email['time'],
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 28),
            Text(
              email['subject'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  email['snippet'] * 5, // mock body content
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.reply, size: 18),
                    label: const Text('Reply'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showComposeSheet();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.forward, size: 18, color: Colors.white),
                    label: const Text('Forward', style: TextStyle(color: Colors.white)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
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

    final userMail = widget.user?.email.isNotEmpty == true
        ? widget.user!.email
        : '${widget.user?.username ?? "user"}@connekt.me';

    final filteredEmails = _selectedFolder == 'Unread'
        ? _emails.where((e) => e['isUnread'] == true).toList()
        : _emails;

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentBlue,
        onPressed: _showComposeSheet,
        child: const Icon(Icons.edit_outlined, color: Colors.white),
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
            const Icon(Icons.mail_outline_rounded, color: AppTheme.accentBlue, size: 24),
            const SizedBox(width: 10),
            Text(
              'Connekt Mail',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : Colors.black87),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mailbox up to date'),
                  backgroundColor: AppTheme.accentBlue,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // User Connekt Mail Pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mark_email_read_rounded, color: AppTheme.accentBlue, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR CONNEKT MAIL ID',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          Text(
                            userMail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCoral,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount UNREAD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search emails...',
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

            // Folder Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  _buildFolderChip('Inbox', isDark, cardColor, textSecondary, count: _emails.length),
                  const SizedBox(width: 8),
                  _buildFolderChip('Unread', isDark, cardColor, textSecondary, count: unreadCount, isAlert: unreadCount > 0),
                  const SizedBox(width: 8),
                  _buildFolderChip('Starred', isDark, cardColor, textSecondary),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Mail List
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: filteredEmails.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final email = filteredEmails[index];
                  final bool isUnread = email['isUnread'] == true;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openEmailDetails(email),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isUnread
                              ? cardColor
                              : cardColor.withValues(alpha: isDark ? 0.5 : 0.8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isUnread
                                ? AppTheme.accentBlue.withValues(alpha: 0.3)
                                : borderColor,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sender Avatar with Unread Dot
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.2),
                                  child: Text(
                                    email['sender'][0].toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.accentBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isUnread)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentCoral,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: cardColor, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Email Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          email['sender'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        email['time'],
                                        style: TextStyle(
                                          color: isUnread ? AppTheme.accentBlue : AppTheme.textMuted,
                                          fontSize: 11,
                                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    email['subject'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isUnread ? textPrimary : textSecondary,
                                      fontSize: 13,
                                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    email['snippet'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 11.5,
                                    ),
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

  Widget _buildFolderChip(String name, bool isDark, Color cardColor, Color textSecondary, {int? count, bool isAlert = false}) {
    final bool isSelected = _selectedFolder == name;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFolder = name);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : (isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isAlert && !isSelected ? AppTheme.accentCoral : (isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isAlert && !isSelected ? Colors.white : (isDark ? Colors.white : textSecondary),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
