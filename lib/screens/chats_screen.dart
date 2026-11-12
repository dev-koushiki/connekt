import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../config/subnet_probe_stub.dart' if (dart.library.io) '../config/subnet_probe_io.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/call_log_service.dart';
import '../widgets/call_log_tile.dart';
import '../widgets/safe_avatar.dart';
import 'chat_screen.dart';
import 'whatsapp_status_screen.dart';
import 'whatsapp_archived_screen.dart';
import 'whatsapp_locked_screen.dart';
import 'whatsapp_starred_screen.dart';
import 'whatsapp_linked_devices_screen.dart';
import 'whatsapp_payments_screen.dart';
import 'whatsapp_settings_screen.dart';

class ChatsScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onBackToHome;
  final int initialTabIndex;

  const ChatsScreen({
    super.key,
    this.user,
    this.onBackToHome,
    this.initialTabIndex = 0,
  });

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _conversations = [];
  final List<Map<String, dynamic>> _archivedConversations = [];
  final List<Map<String, dynamic>> _lockedConversations = [];
  bool _isLoading = false;

  // WhatsApp Multi-selection mode
  bool _isSelectionMode = false;
  final Set<String> _selectedChatIds = {};

  // WhatsApp Media search filters
  String? _selectedMediaFilter;
  final List<String> _mediaFilters = ['Photos', 'Videos', 'Links', 'GIFs', 'Audio', 'Documents', 'Polls'];

  // User's own status updates
  final List<StatusItem> _myStatusItems = [];

  // Contact status updates (Updates tab)
  final List<Map<String, dynamic>> _contactStatuses = [];

  // Calls list (Calls tab)
  final List<Map<String, dynamic>> _callLogs = [];
  bool _isSyncingCalls = false;
  String _selectedCallFilter = 'All';
  Timer? _convSyncTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    CallLogService.syncNotifier.addListener(_onCallLogsSyncChanged);
    _loadConversations();
    _loadCallLogs();
    if (!isFlutterTestEnv) {
      _convSyncTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        _loadConversations();
      });
    }
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ChatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      final targetIndex = widget.initialTabIndex.clamp(0, 2);
      if (_tabController.index != targetIndex) {
        _tabController.animateTo(targetIndex);
      }
    }
  }

  @override
  void dispose() {
    _convSyncTimer?.cancel();
    CallLogService.syncNotifier.removeListener(_onCallLogsSyncChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onCallLogsSyncChanged() {
    _loadCallLogs();
  }

  Future<void> _loadCallLogs() async {
    try {
      final logs = await CallLogService.loadCallLogs(limit: 100);
      if (!mounted) return;
      setState(() {
        _callLogs
          ..clear()
          ..addAll(logs);
      });
    } catch (_) {
      // Ignore passive load failures; user can retry via Sync Logs.
    }
  }

  Future<void> _syncCallLogsNow() async {
    if (_isSyncingCalls) return;
    setState(() => _isSyncingCalls = true);
    try {
      final res = await CallLogService.syncCallLogs(limit: 100);
      await _loadCallLogs();
      if (!mounted) return;
      final bool ok = res['success'] == true;
      final String msg = (res['message'] ?? (ok ? 'Call logs synced.' : 'Unable to sync call logs.')).toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? const Color(0xFF1D4ED8) : AppTheme.accentCoral,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingCalls = false);
      }
    }
  }

  Future<void> _loadConversations() async {
    try {
      final list = await ApiService.getConversations();
      if (mounted) {
        setState(() {
          _conversations.clear();
          _conversations.addAll(list);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get totalUnreadChats =>
      _conversations.fold<int>(0, (sum, item) => sum + ((item['unread'] as int?) ?? 0));

  // ====================================================================
  // NAVIGATION & CHAT OPEN
  // ====================================================================

  Future<void> _openChat(Map<String, dynamic> conv) async {
    if (_isSelectionMode) {
      _toggleSelection(conv['id']?.toString() ?? conv['name']);
      return;
    }

    setState(() {
      conv['unread'] = 0;
    });

    final targetName = (conv['target'] ?? conv['name'] ?? 'Chat').toString();
    final avatar = (conv['avatar'] ?? '').toString();
    final bool isGroup = conv['isGroup'] == true || conv['type'] == 'group';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contactName: targetName,
          avatarUrl: avatar,
          showBackButton: true,
          isGroup: isGroup,
        ),
      ),
    );
    _loadConversations();
  }

  // ====================================================================
  // SELECTION MODE ACTIONS (PIN, DELETE, MUTE, ARCHIVE)
  // ====================================================================

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedChatIds.contains(id)) {
        _selectedChatIds.remove(id);
        if (_selectedChatIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedChatIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedChatIds.clear();
    });
  }

  void _pinSelectedChats() {
    setState(() {
      for (final conv in _conversations) {
        final id = conv['id']?.toString() ?? conv['name'];
        if (_selectedChatIds.contains(id)) {
          conv['isPinned'] = !(conv['isPinned'] == true);
        }
      }
      _exitSelectionMode();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pinned chats updated'), duration: Duration(seconds: 2)),
    );
  }

  void _deleteSelectedChats() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text('Delete ${_selectedChatIds.length} conversation(s)?'),
        content: const Text('Messages will also be deleted from this device.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCoral),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _conversations.removeWhere((c) {
                  final id = c['id']?.toString() ?? c['name'];
                  return _selectedChatIds.contains(id);
                });
                _exitSelectionMode();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversations deleted')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _muteSelectedChats() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mute notifications for ${_selectedChatIds.length} chat(s)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 14),
            _buildMuteOption(ctx, '8 hours'),
            _buildMuteOption(ctx, '1 week'),
            _buildMuteOption(ctx, 'Always'),
          ],
        ),
      ),
    );
  }

  Widget _buildMuteOption(BuildContext ctx, String duration) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(duration, style: TextStyle(color: AppTheme.getTextPrimary(context))),
      onTap: () {
        Navigator.pop(ctx);
        setState(() {
          for (final conv in _conversations) {
            final id = conv['id']?.toString() ?? conv['name'];
            if (_selectedChatIds.contains(id)) {
              conv['isMuted'] = true;
            }
          }
          _exitSelectionMode();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notifications muted for $duration')),
        );
      },
    );
  }

  void _archiveSelectedChats() {
    setState(() {
      final toArchive = _conversations.where((c) {
        final id = c['id']?.toString() ?? c['name'];
        return _selectedChatIds.contains(id);
      }).toList();

      for (final item in toArchive) {
        item['isArchived'] = true;
        _archivedConversations.add(item);
        _conversations.remove(item);
      }
      _exitSelectionMode();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat(s) archived'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _markSelectedAsRead(bool isRead) {
    setState(() {
      for (final conv in _conversations) {
        final id = conv['id']?.toString() ?? conv['name'];
        if (_selectedChatIds.contains(id)) {
          conv['unread'] = isRead ? 0 : 1;
        }
      }
      _exitSelectionMode();
    });
  }

  void _lockSelectedChats() {
    setState(() {
      final toLock = _conversations.where((c) {
        final id = c['id']?.toString() ?? c['name'];
        return _selectedChatIds.contains(id);
      }).toList();

      for (final item in toLock) {
        item['isLocked'] = true;
        _lockedConversations.add(item);
        _conversations.remove(item);
      }
      _exitSelectionMode();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat(s) moved to Locked Chats'),
        backgroundColor: Color(0xFF1D4ED8),
      ),
    );
  }

  void _markAllAsRead() {
    setState(() {
      for (final c in _conversations) {
        c['unread'] = 0;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All chats marked as read'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ====================================================================
  // WHATSAPP 3-DOTS OVERFLOW MENU
  // ====================================================================

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'new_group':
        _showNewChatSheet(context, forceGroup: true);
        break;
      case 'new_broadcast':
        _showNewBroadcastSheet();
        break;
      case 'linked_devices':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WhatsAppLinkedDevicesScreen()),
        );
        break;
      case 'starred':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WhatsAppStarredScreen()),
        );
        break;
      case 'payments':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WhatsAppPaymentsScreen()),
        );
        break;
      case 'archived':
        _openArchivedScreen();
        break;
      case 'locked':
        _openLockedScreen();
        break;
      case 'mark_all_read':
        _markAllAsRead();
        break;
      case 'settings':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WhatsAppSettingsScreen(
              onClearAllChats: () {
                setState(() => _conversations.clear());
              },
            ),
          ),
        );
        break;
    }
  }

  void _openArchivedScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WhatsAppArchivedScreen(
          archivedChats: _archivedConversations,
          onUnarchive: (chat) {
            setState(() {
              _archivedConversations.removeWhere((c) => c['id'] == chat['id']);
              chat['isArchived'] = false;
              _conversations.insert(0, chat);
            });
          },
        ),
      ),
    );
  }

  void _openLockedScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WhatsAppLockedScreen(
          lockedChats: _lockedConversations,
          onUnlockChat: (chat) {
            setState(() {
              _lockedConversations.removeWhere((c) => c['id'] == chat['id']);
              chat['isLocked'] = false;
              _conversations.insert(0, chat);
            });
          },
        ),
      ),
    );
  }

  // ====================================================================
  // WHATSAPP QUICK AVATAR PREVIEW POPUP
  // ====================================================================

  void _showAvatarQuickPreview(Map<String, dynamic> conv) {
    final name = (conv['name'] ?? 'Contact').toString();
    final avatar = (conv['avatar'] ?? '').toString();
    final target = (conv['target'] ?? conv['phone'] ?? name).toString();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: avatar.isNotEmpty
                      ? Image.network(
                          avatar,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(name),
                        )
                      : _buildAvatarPlaceholder(name),
                ),
                Positioned(
                  top: 8,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF1D4ED8)),
                    tooltip: 'Message',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openChat(conv);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: Color(0xFF1D4ED8)),
                    tooltip: 'Voice Call',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCallDialog(name, false);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam_rounded, color: Color(0xFF1D4ED8)),
                    tooltip: 'Video Call',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCallDialog(name, true);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8)),
                    tooltip: 'View Info',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showContactInfoSheet(name, target, avatar);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      width: double.infinity,
      height: 220,
      color: const Color(0xFF1E293B),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white60),
        ),
      ),
    );
  }

  void _showContactInfoSheet(String name, String phone, String avatar) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeAvatar(url: avatar.isNotEmpty ? avatar : null, fallbackText: name, size: 70, radius: 35),
            const SizedBox(height: 12),
            Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context))),
            const SizedBox(height: 4),
            Text(phone, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.lock_rounded, color: Color(0xFF1D4ED8)),
              title: const Text('Lock Chat'),
              subtitle: const Text('Require passcode or biometric to open this conversation'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat locked')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Add to Favourites'),
              subtitle: const Text('Display at top of list with favourites filter'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to favourites')));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCallDialog(String contactName, bool isVideo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isVideo ? Icons.videocam_rounded : Icons.phone_rounded, color: const Color(0xFF1D4ED8)),
            const SizedBox(width: 10),
            Text(isVideo ? 'Video Call' : 'Voice Call'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calling $contactName...'),
            const SizedBox(height: 8),
            const Text(
              'End-to-end encrypted Connekt call',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCoral),
            child: const Text('End Call', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // NEW BROADCAST LIST SHEET
  // ====================================================================

  void _showNewBroadcastSheet() {
    final broadcastMsgController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                    'New Broadcast',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Only contacts who have your number in their address book will receive broadcast messages.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: broadcastMsgController,
                decoration: InputDecoration(
                  hintText: 'Type your broadcast message...',
                  filled: true,
                  fillColor: AppTheme.getInputColor(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                  label: const Text('Send Broadcast', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final text = broadcastMsgController.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Broadcast sent to all contacts: "$text"'),
                        backgroundColor: const Color(0xFF1D4ED8),
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

  // ====================================================================
  // NEW CHAT / GROUP SHEET
  // ====================================================================

  void _showNewChatSheet(BuildContext context, {bool forceGroup = false}) {
    final contactController = TextEditingController();
    bool isGroup = forceGroup;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                    isGroup ? 'New Group' : 'New Conversation',
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
              const SizedBox(height: 10),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Direct Chat'),
                    selected: !isGroup,
                    onSelected: (val) => setSheetState(() => isGroup = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Group Chat'),
                    selected: isGroup,
                    onSelected: (val) => setSheetState(() => isGroup = true),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contactController,
                autofocus: true,
                style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 14),
                decoration: InputDecoration(
                  hintText: isGroup ? 'Enter group name (e.g. Project Team)...' : 'Enter username, email or phone...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  prefixIcon: Icon(isGroup ? Icons.group_add_rounded : Icons.person_search_rounded, color: AppTheme.accentBlue),
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
                    backgroundColor: const Color(0xFF1D4ED8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(isGroup ? Icons.groups_rounded : Icons.send_rounded, size: 18, color: Colors.white),
                  label: Text(isGroup ? 'Create Group' : 'Start Chat', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final target = contactController.text.trim();
                    if (target.isEmpty) return;
                    Navigator.pop(ctx);
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          contactName: target,
                          avatarUrl: '',
                          showBackButton: true,
                          isGroup: isGroup,
                        ),
                      ),
                    );
                    _loadConversations();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // CREATE CALL LINK SHEET (CALLS TAB)
  // ====================================================================

  void _showCreateCallLinkSheet() {
    final link = 'https://connekt.me/call/${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link_rounded, color: Color(0xFF1D4ED8), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connekt Call Link',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Anyone with Connekt can join this call',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.getInputColor(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      link,
                      style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF1D4ED8), size: 20),
                    tooltip: 'Copy link',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Call link copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                label: const Text('Share Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sharing call link via Connekt share sheet...')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // STATUS STORIES VIEWER LAUNCHER
  // ====================================================================

  void _openStatusViewer(Map<String, dynamic> statusData) {
    setState(() {
      statusData['viewed'] = true;
    });

    final items = (statusData['items'] as List<StatusItem>?) ?? [];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WhatsAppStatusViewer(
          userName: statusData['name'] ?? 'Status',
          userAvatar: statusData['avatar'] ?? '',
          timeAgo: statusData['timeAgo'] ?? 'Recently',
          items: items,
        ),
      ),
    );
  }

  void _openTextStatusCreator() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WhatsAppTextStatusCreator(
          onCreated: (item) {
            setState(() {
              _myStatusItems.insert(0, item);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Status update posted!'),
                backgroundColor: Color(0xFF1D4ED8),
              ),
            );
          },
        ),
      ),
    );
  }

  // ====================================================================
  // BUILD METHOD
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bgColor = AppTheme.getBackgroundColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final inputColor = AppTheme.getInputColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(context, textPrimary)
          : _buildStandardAppBar(context, isDark, textPrimary),
      floatingActionButton: _buildDynamicFAB(context),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs Header
            Container(
              color: bgColor,
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                indicatorColor: const Color(0xFF1D4ED8),
                indicatorWeight: 3,
                labelColor: const Color(0xFF1D4ED8),
                unselectedLabelColor: textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_rounded, size: 15),
                          const SizedBox(width: 4),
                          const Text('Messages', maxLines: 1, softWrap: false),
                          if (totalUnreadChats > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D4ED8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$totalUnreadChats',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Updates', maxLines: 1, softWrap: false),
                    ),
                  ),
                  const Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Calls', maxLines: 1, softWrap: false),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Chats (Main conversation screen)
                  _buildChatsTab(context, isDark, bgColor, cardColor, inputColor, textPrimary, textSecondary, borderColor),
                  // Tab 1: Updates (WhatsApp Stories / Status)
                  _buildUpdatesTab(context, isDark, cardColor, textPrimary, textSecondary, borderColor),
                  // Tab 2: Calls (WhatsApp Call logs & Call link)
                  _buildCallsTab(context, isDark, cardColor, textPrimary, textSecondary, borderColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // APP BARS (STANDARD & MULTI-SELECTION)
  // ====================================================================

  PreferredSizeWidget _buildStandardAppBar(BuildContext context, bool isDark, Color textPrimary) {
    return AppBar(
      backgroundColor: AppTheme.getBackgroundColor(context),
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
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF1D4ED8), size: 20),
          ),
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
        // Camera quick access
        IconButton(
          icon: Icon(Icons.camera_alt_outlined, color: textPrimary),
          tooltip: 'Camera',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('WhatsApp Camera quick-capture active')),
            );
          },
        ),
        // 3-dots WhatsApp menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: textPrimary),
          onSelected: _handleMenuSelection,
          color: AppTheme.getCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'new_group', child: Text('New group')),
            const PopupMenuItem(value: 'new_broadcast', child: Text('New broadcast')),
            const PopupMenuItem(value: 'linked_devices', child: Text('Linked devices')),
            const PopupMenuItem(value: 'starred', child: Text('Starred messages')),
            const PopupMenuItem(value: 'payments', child: Text('Payments')),
            const PopupMenuItem(value: 'archived', child: Text('Archived chats')),
            const PopupMenuItem(value: 'locked', child: Text('Locked chats')),
            const PopupMenuItem(value: 'mark_all_read', child: Text('Mark all as read')),
            const PopupMenuItem(value: 'settings', child: Text('Settings')),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(BuildContext context, Color textPrimary) {
    return AppBar(
      backgroundColor: const Color(0xFF1F2937),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        '${_selectedChatIds.length}',
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.push_pin_outlined, color: Colors.white),
          tooltip: 'Pin/Unpin',
          onPressed: _pinSelectedChats,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          tooltip: 'Delete',
          onPressed: _deleteSelectedChats,
        ),
        IconButton(
          icon: const Icon(Icons.volume_off_outlined, color: Colors.white),
          tooltip: 'Mute',
          onPressed: _muteSelectedChats,
        ),
        IconButton(
          icon: const Icon(Icons.archive_outlined, color: Colors.white),
          tooltip: 'Archive',
          onPressed: _archiveSelectedChats,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          color: const Color(0xFF374151),
          onSelected: (val) {
            if (val == 'read') _markSelectedAsRead(true);
            if (val == 'unread') _markSelectedAsRead(false);
            if (val == 'lock') _lockSelectedChats();
            if (val == 'select_all') {
              setState(() {
                _selectedChatIds.addAll(_conversations.map((c) => c['id']?.toString() ?? c['name']));
              });
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'read', child: Text('Mark as read', style: TextStyle(color: Colors.white))),
            const PopupMenuItem(value: 'unread', child: Text('Mark as unread', style: TextStyle(color: Colors.white))),
            const PopupMenuItem(value: 'lock', child: Text('Lock chat', style: TextStyle(color: Colors.white))),
            const PopupMenuItem(value: 'select_all', child: Text('Select all', style: TextStyle(color: Colors.white))),
          ],
        ),
      ],
    );
  }

  // ====================================================================
  // TAB 0: CHATS LIST TAB
  // ====================================================================

  Widget _buildChatsTab(
    BuildContext context,
    bool isDark,
    Color bgColor,
    Color cardColor,
    Color inputColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    // Sorting: Pinned chats on top
    final sortedList = List<Map<String, dynamic>>.from(_conversations);
    sortedList.sort((a, b) {
      final aPinned = a['isPinned'] == true ? 1 : 0;
      final bPinned = b['isPinned'] == true ? 1 : 0;
      return bPinned.compareTo(aPinned);
    });

    final filteredList = sortedList.where((c) {
      final isGroup = c['isGroup'] == true || c['type'] == 'group';
      final unread = (c['unread'] as int?) ?? 0;
      final isFav = c['isFavourite'] == true;

      if (_selectedFilter == 'Direct' && isGroup) return false;
      if (_selectedFilter == 'Groups' && !isGroup) return false;
      if (_selectedFilter == 'Unread' && unread == 0) return false;
      if (_selectedFilter == 'Favourites' && !isFav) return false;

      if (query.isNotEmpty) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final target = (c['target'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? '').toString().toLowerCase();
        final lastMsg = (c['lastMessage'] ?? '').toString().toLowerCase();
        return name.contains(query) || target.contains(query) || phone.contains(query) || lastMsg.contains(query);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // WhatsApp Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search chats & people...',
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
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

        // WhatsApp Search Media Filter Pills (visible when search is focused)
        if (query.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _mediaFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tag = _mediaFilters[index];
                final isSelected = _selectedMediaFilter == tag;
                return ChoiceChip(
                  label: Text(tag, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : textSecondary)),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1D4ED8),
                  backgroundColor: cardColor,
                  onSelected: (val) {
                    setState(() => _selectedMediaFilter = val ? tag : null);
                  },
                );
              },
            ),
          ),

        // Filter Tabs (All, Unread, Favourites, Groups, Direct)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', isDark, cardColor, textSecondary),
                const SizedBox(width: 8),
                _buildFilterChip('Unread', isDark, cardColor, textSecondary),
                const SizedBox(width: 8),
                _buildFilterChip('Favourites', isDark, cardColor, textSecondary),
                const SizedBox(width: 8),
                _buildFilterChip('Groups', isDark, cardColor, textSecondary),
                const SizedBox(width: 8),
                _buildFilterChip('Direct', isDark, cardColor, textSecondary),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Archived & Locked chats bar (when present)
        if (_lockedConversations.isNotEmpty)
          _buildSpecialFolderRow(
            icon: Icons.lock_rounded,
            title: 'Locked chats',
            count: _lockedConversations.length,
            color: const Color(0xFF1D4ED8),
            onTap: _openLockedScreen,
          ),
        if (_archivedConversations.isNotEmpty)
          _buildSpecialFolderRow(
            icon: Icons.archive_outlined,
            title: 'Archived',
            count: _archivedConversations.length,
            color: const Color(0xFF1D4ED8),
            onTap: _openArchivedScreen,
          ),

        // Conversations List or Clean Empty State
        Expanded(
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(color: Color(0xFF1D4ED8), strokeWidth: 2.5),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  color: const Color(0xFF1D4ED8),
                  child: filteredList.isEmpty
                      ? ListView(
                          children: [
                            _buildEmptyState(context, isDark, textPrimary, textSecondary),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: filteredList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final conv = filteredList[index];
                            final id = conv['id']?.toString() ?? conv['name'];
                            final isSelected = _selectedChatIds.contains(id);
                            final int unread = (conv['unread'] as int?) ?? 0;
                            final bool isGroup = conv['isGroup'] == true;
                            final bool isOnline = conv['isOnline'] == true;
                            final bool isPinned = conv['isPinned'] == true;
                            final bool isMuted = conv['isMuted'] == true;

                            return Dismissible(
                              key: Key('chat_$id'),
                              direction: DismissDirection.horizontal,
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D4ED8),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6B7280),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.archive_outlined, color: Colors.white),
                              ),
                              confirmDismiss: (dir) async {
                                if (dir == DismissDirection.startToEnd) {
                                  // Toggle Pin
                                  setState(() => conv['isPinned'] = !isPinned);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isPinned ? 'Chat unpinned' : 'Chat pinned to top')),
                                  );
                                  return false;
                                } else {
                                  // Archive Chat
                                  setState(() {
                                    _conversations.remove(conv);
                                    _archivedConversations.add(conv);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Archived ${conv['name']}'),
                                      action: SnackBarAction(
                                        label: 'UNDO',
                                        onPressed: () {
                                          setState(() {
                                            _archivedConversations.remove(conv);
                                            _conversations.insert(index, conv);
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                  return true;
                                }
                              },
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _openChat(conv),
                                  onLongPress: () {
                                    setState(() {
                                      _isSelectionMode = true;
                                      _toggleSelection(id);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF1D4ED8).withValues(alpha: 0.15)
                                          : (unread > 0 ? cardColor : cardColor.withValues(alpha: isDark ? 0.6 : 0.9)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF1D4ED8)
                                            : (unread > 0
                                                ? const Color(0xFF1D4ED8).withValues(alpha: 0.3)
                                                : borderColor),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar with WhatsApp Status Ring or Preview Tap
                                        GestureDetector(
                                          onTap: () => _showAvatarQuickPreview(conv),
                                          child: Stack(
                                            children: [
                                              SafeAvatar(
                                                url: conv['avatar'] is String ? conv['avatar'] : null,
                                                fallbackText: (conv['name'] ?? '').toString(),
                                                size: 46,
                                                radius: 23,
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
                                                      color: const Color(0xFF1D4ED8),
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
                                                      color: const Color(0xFF1D4ED8),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: cardColor, width: 1.5),
                                                    ),
                                                    child: const Icon(Icons.group, size: 9, color: Colors.white),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Name, Last Message, WhatsApp Ticks
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      conv['name'] ?? '',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: textPrimary,
                                                        fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                                                        fontSize: 14.5,
                                                      ),
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (isPinned)
                                                        const Padding(
                                                          padding: EdgeInsets.only(right: 4),
                                                          child: Icon(Icons.push_pin_rounded, size: 13, color: Color(0xFF1D4ED8)),
                                                        ),
                                                      Text(
                                                        conv['time'] ?? '',
                                                        style: TextStyle(
                                                          color: unread > 0 ? const Color(0xFF1D4ED8) : AppTheme.textMuted,
                                                          fontSize: 11,
                                                          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Builder(
                                                builder: (_) {
                                                  final rawLast = (conv['lastMessage'] ?? '').toString().trim();
                                                  final displayLast = (rawLast == 'This message was deleted' ||
                                                          rawLast == 'You deleted this message' ||
                                                          rawLast == 'Conversation started')
                                                      ? ''
                                                      : rawLast;
                                                  return Row(
                                                    children: [
                                                      // WhatsApp Status Ticks (✓✓) only when a message exists
                                                      if (displayLast.isNotEmpty &&
                                                          (conv['isMe'] == true || conv['unread'] == 0)) ...[
                                                        const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF38BDF8)),
                                                        const SizedBox(width: 4),
                                                      ],
                                                      Expanded(
                                                        child: Text(
                                                          displayLast,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            color: unread > 0 ? textPrimary : AppTheme.textMuted,
                                                            fontSize: 12.5,
                                                            fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
                                                          ),
                                                        ),
                                                      ),
                                                      if (isMuted) ...[
                                                        const SizedBox(width: 6),
                                                        const Icon(Icons.volume_off_rounded, size: 14, color: AppTheme.textMuted),
                                                      ],
                                                      if (unread > 0) ...[
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF1D4ED8),
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
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildSpecialFolderRow({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: color, size: 20),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context), fontSize: 13.5)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  // ====================================================================
  // TAB 1: UPDATES TAB (WHATSAPP STATUS STORIES)
  // ====================================================================

  Widget _buildUpdatesTab(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // My Status Tile
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Stack(
            children: [
              SafeAvatar(
                url: widget.user?.personalProfile?.avatarUrl,
                fallbackText: widget.user?.username ?? 'Me',
                size: 50,
                radius: 25,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D4ED8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          title: Text('My status', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
          subtitle: Text(
            _myStatusItems.isNotEmpty ? 'Tap to view your status' : 'Tap to add status update',
            style: TextStyle(color: textSecondary, fontSize: 12.5),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF1D4ED8)),
            tooltip: 'Type text status',
            onPressed: _openTextStatusCreator,
          ),
          onTap: () {
            if (_myStatusItems.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WhatsAppStatusViewer(
                    userName: 'My status',
                    userAvatar: widget.user?.personalProfile?.avatarUrl ?? '',
                    timeAgo: 'Just now',
                    items: _myStatusItems,
                  ),
                ),
              );
            } else {
              _openTextStatusCreator();
            }
          },
        ),

        const SizedBox(height: 14),

        // Recent Updates Section
        Text(
          'RECENT UPDATES',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary),
        ),
        const SizedBox(height: 8),

        if (_contactStatuses.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Icon(Icons.auto_awesome_outlined, size: 30, color: textSecondary),
                const SizedBox(height: 8),
                Text(
                  'No recent updates yet',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Contact status updates will appear here.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          )
        else
          ..._contactStatuses.map((status) {
          final bool viewed = status['viewed'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: viewed ? AppTheme.textMuted : const Color(0xFF1D4ED8),
                      width: 2.2,
                    ),
                  ),
                  child: SafeAvatar(
                    url: status['avatar'] is String && status['avatar'].isNotEmpty ? status['avatar'] : null,
                    fallbackText: status['name'],
                    size: 42,
                    radius: 21,
                  ),
                ),
                title: Text(status['name'], style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                subtitle: Text(status['timeAgo'], style: TextStyle(color: textSecondary, fontSize: 12)),
                onTap: () => _openStatusViewer(status),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ====================================================================
  // TAB 2: CALLS TAB (WHATSAPP CALL LOGS)
  // ====================================================================

  Widget _buildCallsTab(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final filteredLogs = filterCallLogs(_callLogs, _selectedCallFilter);
    final bool permissionDenied = CallLogService.lastPermissionGranted == false;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // Create Call Link Card
        Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: borderColor),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1D4ED8).withValues(alpha: 0.15),
              child: const Icon(Icons.link_rounded, color: Color(0xFF1D4ED8)),
            ),
            title: Text('Create call link', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
            subtitle: Text('Share a link for your Connekt call', style: TextStyle(color: textSecondary, fontSize: 12)),
            onTap: _showCreateCallLinkSheet,
          ),
        ),

        const SizedBox(height: 16),

        // Recent Calls Header & Sync Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT CALLS',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary),
            ),
            TextButton.icon(
              onPressed: _isSyncingCalls ? null : _syncCallLogsNow,
              icon: _isSyncingCalls
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D4ED8)),
                    )
                  : const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF1D4ED8)),
              label: Text(
                _isSyncingCalls ? 'Syncing...' : 'Sync Logs',
                style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        CallLogFilterBar(
          selectedFilter: _selectedCallFilter,
          onSelected: (f) => setState(() => _selectedCallFilter = f),
          activeColor: const Color(0xFF1D4ED8),
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        if (filteredLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Icon(
                  permissionDenied ? Icons.perm_phone_msg_rounded : Icons.call_rounded,
                  size: 36,
                  color: const Color(0xFF1D4ED8),
                ),
                const SizedBox(height: 10),
                Text(
                  permissionDenied
                      ? 'Allow Phone Call Logs'
                      : (_callLogs.isEmpty ? 'No phone call logs loaded yet' : 'No $_selectedCallFilter calls found'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  permissionDenied
                      ? 'Grant call log access or tap below to fetch your recent calls.'
                      : 'Tap Sync Phone Call Logs to load your device and synced call history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSyncingCalls ? null : _syncCallLogsNow,
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF1D4ED8)),
                  label: const Text(
                    'Sync Phone Call Logs',
                    style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else
          ...filteredLogs.map((call) {
            final bool isVideo = call['isVideo'] == true;
            return CallLogTile(
              call: call,
              cardColor: cardColor,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onCallTap: () => _showCallDialog((call['name'] ?? 'Contact').toString(), isVideo),
            );
          }),
      ],
    );
  }

  // ====================================================================
  // EMPTY STATE (TEST COMPATIBLE)
  // ====================================================================

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

  // ====================================================================
  // FILTER CHIP (TEST COMPATIBLE)
  // ====================================================================

  Widget _buildFilterChip(String label, bool isDark, Color cardColor, Color textSecondary) {
    final bool isSelected = _selectedFilter == label;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1D4ED8) : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D4ED8) : (isDark ? Colors.white10 : Colors.black12),
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

  // ====================================================================
  // DYNAMIC FLOATING ACTION BUTTON
  // ====================================================================

  Widget? _buildDynamicFAB(BuildContext context) {
    if (_tabController.index == 0) {
      // Chats FAB
      return FloatingActionButton(
        backgroundColor: const Color(0xFF1D4ED8),
        onPressed: () => _showNewChatSheet(context),
        child: const Icon(Icons.chat_outlined, color: Colors.white),
      );
    } else if (_tabController.index == 1) {
      // Updates FAB: Camera & Text
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'text_status_fab',
            backgroundColor: AppTheme.getCardColor(context),
            onPressed: _openTextStatusCreator,
            child: const Icon(Icons.edit_rounded, color: Color(0xFF1D4ED8), size: 18),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'camera_status_fab',
            backgroundColor: const Color(0xFF1D4ED8),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Camera status capture initiated')),
              );
            },
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
          ),
        ],
      );
    } else if (_tabController.index == 2) {
      // Calls FAB
      return FloatingActionButton(
        backgroundColor: const Color(0xFF1D4ED8),
        onPressed: () => _showNewChatSheet(context),
        child: const Icon(Icons.add_call, color: Colors.white),
      );
    }
    return null;
  }
}
