import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../i18n/app_localizations.dart';

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
  final Set<String> _lockedChatIds = {};
  final Set<String> _archivedChatIds = {};
  bool _isLoading = false;

  bool _isSameChat(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aId = (a['id']?.toString() ?? '').trim();
    final bId = (b['id']?.toString() ?? '').trim();
    if (aId.isNotEmpty && bId.isNotEmpty && aId == bId) return true;

    final aTarget = (a['target']?.toString() ?? '').trim();
    final bTarget = (b['target']?.toString() ?? '').trim();
    if (aTarget.isNotEmpty && bTarget.isNotEmpty && aTarget.toLowerCase() == bTarget.toLowerCase()) return true;

    final aName = (a['name']?.toString() ?? '').trim();
    final bName = (b['name']?.toString() ?? '').trim();
    if (aName.isNotEmpty && bName.isNotEmpty && aName.toLowerCase() == bName.toLowerCase()) return true;

    return false;
  }

  bool _isChatLocked(Map<String, dynamic> c) {
    if (c['isLocked'] == true) return true;
    final id = (c['id']?.toString() ?? '').trim();
    if (id.isNotEmpty && _lockedChatIds.contains(id)) return true;
    final target = (c['target']?.toString() ?? '').trim();
    if (target.isNotEmpty && _lockedChatIds.contains(target)) return true;
    final name = (c['name']?.toString() ?? '').trim();
    if (name.isNotEmpty && _lockedChatIds.contains(name)) return true;
    return _lockedConversations.any((lc) => _isSameChat(lc, c));
  }

  bool _isChatArchived(Map<String, dynamic> c) {
    if (c['isArchived'] == true) return true;
    final id = (c['id']?.toString() ?? '').trim();
    if (id.isNotEmpty && _archivedChatIds.contains(id)) return true;
    final target = (c['target']?.toString() ?? '').trim();
    if (target.isNotEmpty && _archivedChatIds.contains(target)) return true;
    final name = (c['name']?.toString() ?? '').trim();
    if (name.isNotEmpty && _archivedChatIds.contains(name)) return true;
    return _archivedConversations.any((ac) => _isSameChat(ac, c));
  }

  void _recordChatLocked(Map<String, dynamic> c) {
    final id = (c['id']?.toString() ?? '').trim();
    if (id.isNotEmpty) _lockedChatIds.add(id);
    final target = (c['target']?.toString() ?? '').trim();
    if (target.isNotEmpty) _lockedChatIds.add(target);
    final name = (c['name']?.toString() ?? '').trim();
    if (name.isNotEmpty) _lockedChatIds.add(name);
  }

  void _removeChatLocked(Map<String, dynamic> c) {
    final id = (c['id']?.toString() ?? '').trim();
    if (id.isNotEmpty) _lockedChatIds.remove(id);
    final target = (c['target']?.toString() ?? '').trim();
    if (target.isNotEmpty) _lockedChatIds.remove(target);
    final name = (c['name']?.toString() ?? '').trim();
    if (name.isNotEmpty) _lockedChatIds.remove(name);
  }

  void _recordChatArchived(Map<String, dynamic> c) {
    final id = (c['id']?.toString() ?? '').trim();
    if (id.isNotEmpty) _archivedChatIds.add(id);
    final target = (c['target']?.toString() ?? '').trim();
    if (target.isNotEmpty) _archivedChatIds.add(target);
    final name = (c['name']?.toString() ?? '').trim();
    if (name.isNotEmpty) _archivedChatIds.add(name);
  }

  void _removeChatArchived(Map<String, dynamic> c) {
    final id = (c['id']?.toString() ?? '').trim();
    if (id.isNotEmpty) _archivedChatIds.remove(id);
    final target = (c['target']?.toString() ?? '').trim();
    if (target.isNotEmpty) _archivedChatIds.remove(target);
    final name = (c['name']?.toString() ?? '').trim();
    if (name.isNotEmpty) _archivedChatIds.remove(name);
  }

  Future<void> _loadFolderState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locked = prefs.getStringList('connekt_locked_chat_ids') ?? [];
      final archived = prefs.getStringList('connekt_archived_chat_ids') ?? [];
      _lockedChatIds.addAll(locked.where((s) => s.trim().isNotEmpty));
      _archivedChatIds.addAll(archived.where((s) => s.trim().isNotEmpty));
    } catch (_) {}
  }

  Future<void> _saveFolderState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('connekt_locked_chat_ids', _lockedChatIds.toList());
      await prefs.setStringList('connekt_archived_chat_ids', _archivedChatIds.toList());
    } catch (_) {}
  }

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
    _loadFolderState().then((_) {
      if (mounted) _loadConversations();
    });
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
      await _loadFolderState();
      for (final lc in _lockedConversations) {
        _recordChatLocked(lc);
      }
      for (final ac in _archivedConversations) {
        _recordChatArchived(ac);
      }

      final list = await ApiService.getConversations();
      if (!mounted) return;

      final List<Map<String, dynamic>> activeList = [];
      final List<Map<String, dynamic>> newLocked = [];
      final List<Map<String, dynamic>> newArchived = [];

      for (final item in list) {
        if (_isChatLocked(item)) {
          item['isLocked'] = true;
          _recordChatLocked(item);
          newLocked.add(item);
        } else if (_isChatArchived(item)) {
          item['isArchived'] = true;
          _recordChatArchived(item);
          newArchived.add(item);
        } else {
          item['isLocked'] = false;
          item['isArchived'] = false;
          activeList.add(item);
        }
      }

      for (final lc in _lockedConversations) {
        if (!newLocked.any((nl) => _isSameChat(nl, lc))) {
          newLocked.add(lc);
        }
      }
      for (final ac in _archivedConversations) {
        if (!newArchived.any((na) => _isSameChat(na, ac))) {
          newArchived.add(ac);
        }
      }

      setState(() {
        _conversations
          ..clear()
          ..addAll(activeList);
        _lockedConversations
          ..clear()
          ..addAll(newLocked);
        _archivedConversations
          ..clear()
          ..addAll(newArchived);
        _isLoading = false;
      });

      _saveFolderState();
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get totalUnreadChats =>
      _conversations
          .where((item) => !_isChatLocked(item) && !_isChatArchived(item))
          .fold<int>(0, (sum, item) => sum + ((item['unread'] as int?) ?? 0));

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

    final bool isGroup = conv['isGroup'] == true || conv['type'] == 'group';
    final targetName = (isGroup ? (conv['name'] ?? conv['title'] ?? 'Group') : (conv['target'] ?? conv['name'] ?? 'Chat')).toString();
    final avatar = (conv['avatar'] ?? '').toString();
    final convId = conv['id']?.toString();
    final groupDesc = (conv['description'] ?? '').toString();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: convId,
          contactName: targetName,
          groupDescription: groupDesc,
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
    showModalBottomSheet<void>(
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
        final id = c['id']?.toString() ?? c['name']?.toString() ?? '';
        final target = c['target']?.toString() ?? '';
        return _selectedChatIds.contains(id) || (target.isNotEmpty && _selectedChatIds.contains(target));
      }).toList();

      for (final item in toArchive) {
        item['isArchived'] = true;
        _recordChatArchived(item);
        if (!_archivedConversations.any((ac) => _isSameChat(ac, item))) {
          _archivedConversations.add(item);
        }
        _conversations.removeWhere((c) => _isSameChat(c, item));
      }
      _exitSelectionMode();
    });
    _saveFolderState();
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
        final id = c['id']?.toString() ?? c['name']?.toString() ?? '';
        final target = c['target']?.toString() ?? '';
        return _selectedChatIds.contains(id) || (target.isNotEmpty && _selectedChatIds.contains(target));
      }).toList();

      for (final item in toLock) {
        item['isLocked'] = true;
        _recordChatLocked(item);
        if (!_lockedConversations.any((lc) => _isSameChat(lc, item))) {
          _lockedConversations.add(item);
        }
        _conversations.removeWhere((c) => _isSameChat(c, item));
      }
      _exitSelectionMode();
    });
    _saveFolderState();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat(s) moved to Locked Chats'),
        backgroundColor: Color(0xFF1D4ED8),
      ),
    );
  }

  void _lockSingleChat(Map<String, dynamic> conv) {
    setState(() {
      conv['isLocked'] = true;
      _recordChatLocked(conv);
      if (!_lockedConversations.any((lc) => _isSameChat(lc, conv))) {
        _lockedConversations.add(conv);
      }
      _conversations.removeWhere((c) => _isSameChat(c, conv));
    });
    _saveFolderState();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${conv['name'] ?? 'Chat'} moved to Locked Chats'),
        backgroundColor: const Color(0xFF1D4ED8),
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
              _removeChatArchived(chat);
              _archivedConversations.removeWhere((c) => _isSameChat(c, chat));
              chat['isArchived'] = false;
              _conversations.removeWhere((c) => _isSameChat(c, chat));
              _conversations.insert(0, chat);
            });
            _saveFolderState();
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
              _removeChatLocked(chat);
              _lockedConversations.removeWhere((c) => _isSameChat(c, chat));
              chat['isLocked'] = false;
              _conversations.removeWhere((c) => _isSameChat(c, chat));
              _conversations.insert(0, chat);
            });
            _saveFolderState();
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
                      _showContactInfoSheet(conv);
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

  void _showContactInfoSheet(Map<String, dynamic> conv) {
    final name = (conv['name'] ?? 'Contact').toString();
    final avatar = (conv['avatar'] ?? '').toString();
    final phone = (conv['target'] ?? conv['phone'] ?? name).toString();
    showModalBottomSheet<void>(
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
                _lockSingleChat(conv);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Add to Favourites'),
              subtitle: const Text('Display at top of list with favourites filter'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => conv['isFavourite'] = !(conv['isFavourite'] == true));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(conv['isFavourite'] == true ? 'Added to favourites' : 'Removed from favourites')),
                );
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

    showModalBottomSheet<void>(
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

  static String _normalizePhoneTail(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  Future<void> _showGroupDetailsDialog({
    required BuildContext parentContext,
    required String initialName,
    required List<String> selectedMembers,
    required Future<void> Function(String name, String description) onConfirm,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog<void>(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cardColor = AppTheme.getCardColor(ctx);
          final textPrimary = AppTheme.getTextPrimary(ctx);

          return AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.brandBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.groups_rounded, color: AppTheme.brandBlue, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Group Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedMembers.isNotEmpty) ...[
                      Text(
                        'Added Members (${selectedMembers.length}):',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: selectedMembers.take(8).map((m) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.brandBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            m,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.brandBlue),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Group Name *',
                        labelStyle: const TextStyle(fontSize: 13),
                        hintText: 'e.g. Project Team, Marketing',
                        filled: true,
                        fillColor: AppTheme.getInputColor(ctx),
                        prefixIcon: const Icon(Icons.title_rounded, color: AppTheme.brandBlue, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a group name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      maxLines: 3,
                      style: TextStyle(color: textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Group Description',
                        labelStyle: const TextStyle(fontSize: 13),
                        hintText: 'What is this group about? (Optional)',
                        filled: true,
                        fillColor: AppTheme.getInputColor(ctx),
                        prefixIcon: const Icon(Icons.description_outlined, color: AppTheme.brandBlue, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.brandBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.brandBlue.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.mark_email_read_rounded, color: AppTheme.brandBlue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'An invitation message will be sent to the added members. Once they accept the invitation, they can join and receive messages.',
                              style: TextStyle(fontSize: 11.5, color: textPrimary, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() == true) {
                          setDialogState(() => isSubmitting = true);
                          final groupName = nameController.text.trim();
                          final groupDesc = descController.text.trim();
                          Navigator.pop(dialogCtx);
                          await onConfirm(groupName, groupDesc);
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                label: Text(
                  isSubmitting ? 'Creating...' : 'Create & Send Invites',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showNewChatSheet(BuildContext context, {bool forceGroup = false}) {
    final contactController = TextEditingController();
    bool isGroup = forceGroup;
    bool isLoadingContacts = !isFlutterTestEnv;
    bool startedLoad = false;
    bool permissionDenied = CallLogService.lastContactsPermissionGranted == false;
    String searchQuery = '';
    List<Map<String, dynamic>> mergedContacts = List<Map<String, dynamic>>.from(
      CallLogService.cachedContacts.map((c) => {
            ...c,
            'has_connekt': c['has_connekt'] == true || c['source'] == 'connekt',
          }),
    );
    final Set<String> invitedKeys = {};
    final Set<String> sendingInviteKeys = {};
    final Set<String> selectedGroupMembers = {};

    Future<void> loadSheetContacts(StateSetter setSheetState, {bool requestPerm = false}) async {
      setSheetState(() => isLoadingContacts = true);
      List<Map<String, dynamic>> deviceContacts = List<Map<String, dynamic>>.from(CallLogService.cachedContacts);
      List<Map<String, dynamic>> connektUsers = [];
      bool denied = false;

      if (!isFlutterTestEnv) {
        try {
          deviceContacts = await CallLogService.fetchDeviceContacts(
            limit: 250,
            requestIfNeeded: requestPerm,
          );
          denied = CallLogService.lastContactsPermissionGranted == false;
        } catch (_) {}

        try {
          final phones = deviceContacts
              .map((c) => (c['phone'] ?? '').toString().trim())
              .where((p) => p.isNotEmpty)
              .toList();
          final results = await Future.wait([
            ApiService.getContacts(),
            ApiService.matchPhoneContacts(phones),
          ]);
          final byId = <String, Map<String, dynamic>>{};
          for (final u in [...results[1], ...results[0]]) {
            final uid = (u['id'] ?? u['username'] ?? u['phone'] ?? '').toString();
            if (uid.isNotEmpty) byId[uid] = u;
          }
          connektUsers = byId.values.toList();
        } catch (_) {}
      }

      // Build lookup indices for registered CONNEKT users
      final byPhoneTail = <String, Map<String, dynamic>>{};
      final byEmail = <String, Map<String, dynamic>>{};
      final byUsername = <String, Map<String, dynamic>>{};
      for (final u in connektUsers) {
        final tail = _normalizePhoneTail((u['phone'] ?? '').toString());
        if (tail.length >= 7) byPhoneTail[tail] = u;
        final email = (u['email'] ?? '').toString().trim().toLowerCase();
        if (email.isNotEmpty) byEmail[email] = u;
        final uname = (u['username'] ?? '').toString().trim().toLowerCase();
        if (uname.isNotEmpty) byUsername[uname] = u;
      }

      final combined = <Map<String, dynamic>>[];
      final seenKeys = <String>{};

      for (final c in deviceContacts) {
        final phone = (c['phone'] ?? '').toString().trim();
        final tail = _normalizePhoneTail(phone);
        final email = (c['email'] ?? '').toString().trim().toLowerCase();
        final name = (c['full_name'] ?? c['name'] ?? phone).toString().trim();
        final matched = (tail.length >= 7 ? byPhoneTail[tail] : null) ??
            (email.isNotEmpty ? byEmail[email] : null) ??
            byUsername[name.toLowerCase()];

        final dedupeKey = tail.length >= 7 ? 'p:$tail' : 'n:${name.toLowerCase()}';
        if (!seenKeys.add(dedupeKey)) continue;

        if (matched != null) {
          combined.add({
            'id': (matched['id'] ?? c['id'] ?? dedupeKey).toString(),
            'name': name.isNotEmpty ? name : (matched['full_name'] ?? matched['username'] ?? '').toString(),
            'username': (matched['username'] ?? '').toString(),
            'phone': phone.isNotEmpty ? phone : (matched['phone'] ?? '').toString(),
            'email': (matched['email'] ?? '').toString(),
            'avatar_url': (matched['avatar_url'] ?? '').toString(),
            'has_connekt': true,
          });
        } else {
          combined.add({
            'id': (c['id'] ?? dedupeKey).toString(),
            'name': name,
            'username': '',
            'phone': phone,
            'email': email,
            'avatar_url': (c['avatar_url'] ?? '').toString(),
            'has_connekt': c['has_connekt'] == true || c['source'] == 'connekt',
          });
        }
      }

      for (final u in connektUsers) {
        final tail = _normalizePhoneTail((u['phone'] ?? '').toString());
        final uname = (u['username'] ?? '').toString().trim().toLowerCase();
        final dedupeKey = tail.length >= 7 ? 'p:$tail' : 'u:$uname';
        if (!seenKeys.add(dedupeKey)) continue;
        combined.add({
          'id': (u['id'] ?? dedupeKey).toString(),
          'name': (u['display_name'] ?? u['full_name'] ?? u['username'] ?? '').toString(),
          'username': (u['username'] ?? '').toString(),
          'phone': (u['phone'] ?? '').toString(),
          'email': (u['email'] ?? '').toString(),
          'avatar_url': (u['avatar_url'] ?? '').toString(),
          'has_connekt': true,
        });
      }

      // Show CONNEKT users first, then non-CONNEKT phone contacts alphabetically
      combined.sort((a, b) {
        final aHas = a['has_connekt'] == true ? 0 : 1;
        final bHas = b['has_connekt'] == true ? 0 : 1;
        if (aHas != bHas) return aHas.compareTo(bHas);
        return (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase());
      });

      if (!context.mounted) return;
      setSheetState(() {
        mergedContacts = combined;
        permissionDenied = denied;
        isLoadingContacts = false;
      });
    }

    Future<void> handleInviteContact(
      BuildContext sheetCtx,
      StateSetter setSheetState,
      Map<String, dynamic> contact,
    ) async {
      final key = (contact['phone'] ?? contact['id'] ?? contact['name']).toString();
      final name = (contact['name'] ?? 'Friend').toString().trim();
      final phone = (contact['phone'] ?? '').toString().trim();
      if (phone.isEmpty || sendingInviteKeys.contains(key)) return;

      setSheetState(() => sendingInviteKeys.add(key));
      String inviteMsg = name.isNotEmpty
          ? 'Hi $name, join me on CONNEKT for chats, calls, meetings & mails! https://connekt.net.in'
          : 'Join me on CONNEKT for chats, calls, meetings & mails! https://connekt.net.in';
      bool sentViaGateway = false;

      if (!isFlutterTestEnv) {
        final res = await ApiService.sendAppInvite(phone: phone, name: name);
        sentViaGateway = res['dispatchedViaGateway'] == true;
        final serverMsg = (res['inviteMessage'] ?? '').toString().trim();
        if (serverMsg.isNotEmpty) inviteMsg = serverMsg;
      }

      bool openedSmsComposer = false;
      if (!sentViaGateway && !isFlutterTestEnv) {
        openedSmsComposer = await CallLogService.openSmsInvite(phone: phone, message: inviteMsg);
      }

      if (!sheetCtx.mounted) return;
      setSheetState(() {
        sendingInviteKeys.remove(key);
        invitedKeys.add(key);
      });

      if (!sentViaGateway && !openedSmsComposer && !isFlutterTestEnv) {
        await Clipboard.setData(ClipboardData(text: inviteMsg));
      }

      if (!mounted) return;
      final snackText = sentViaGateway
          ? 'Invitation message sent to $name ($phone)'
          : openedSmsComposer
              ? 'SMS invite ready for $name ($phone)'
              : 'Invitation message copied for $name ($phone)';
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(snackText)),
      );
    }

    final sheetFuture = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          if (!startedLoad) {
            startedLoad = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!isFlutterTestEnv) {
                loadSheetContacts(setSheetState, requestPerm: true);
              }
            });
          }

          final q = searchQuery.trim().toLowerCase();
          final filteredContacts = q.isEmpty || isGroup
              ? mergedContacts
              : mergedContacts.where((c) {
                  final name = (c['name'] ?? '').toString().toLowerCase();
                  final phone = (c['phone'] ?? '').toString().toLowerCase();
                  final uname = (c['username'] ?? '').toString().toLowerCase();
                  final email = (c['email'] ?? '').toString().toLowerCase();
                  return name.contains(q) || phone.contains(q) || uname.contains(q) || email.contains(q);
                }).toList();

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
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
                          color: AppTheme.getTextPrimary(sheetCtx),
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
                    onChanged: (val) => setSheetState(() => searchQuery = val),
                    style: TextStyle(color: AppTheme.getTextPrimary(sheetCtx), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isGroup ? 'Enter group name (e.g. Project Team)...' : 'Enter username, email or phone...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      prefixIcon: Icon(isGroup ? Icons.group_add_rounded : Icons.person_search_rounded, color: AppTheme.accentBlue),
                      filled: true,
                      fillColor: AppTheme.getInputColor(sheetCtx),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Middle Contacts Section: Fetched Device + CONNEKT Contacts (or Invite non-CONNEKT users)
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.getInputColor(sheetCtx),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.contacts_rounded, size: 16, color: AppTheme.brandBlue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isGroup
                                    ? 'Select Contacts (${selectedGroupMembers.length} added)'
                                    : 'Your Contacts (${filteredContacts.length})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.getTextPrimary(sheetCtx),
                                ),
                              ),
                            ),
                            if (permissionDenied && !isLoadingContacts)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => loadSheetContacts(setSheetState, requestPerm: true),
                                child: const Text('Allow Contacts', style: TextStyle(fontSize: 11.5, color: AppTheme.brandBlue)),
                              )
                            else if (isLoadingContacts)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandBlue),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (isLoadingContacts && filteredContacts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'Fetching your phone contacts...',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                              ),
                            ),
                          )
                        else if (filteredContacts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                permissionDenied
                                    ? 'Allow contacts access to pick friends or send an invite.'
                                    : (q.isNotEmpty
                                        ? 'No contacts match "$searchQuery"'
                                        : 'No phone contacts found yet.'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                              ),
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 210),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredContacts.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: AppTheme.textMuted.withValues(alpha: 0.14),
                              ),
                              itemBuilder: (_, idx) {
                                final c = filteredContacts[idx];
                                final name = (c['name'] ?? 'Contact').toString();
                                final username = (c['username'] ?? '').toString().trim();
                                final phone = (c['phone'] ?? '').toString().trim();
                                final avatarUrl = (c['avatar_url'] ?? '').toString();
                                final hasConnekt = c['has_connekt'] == true;
                                final key = (phone.isNotEmpty ? phone : (c['id'] ?? name)).toString();
                                final isInvited = invitedKeys.contains(key);
                                final isSendingInvite = sendingInviteKeys.contains(key);
                                final memberLabel = name.isNotEmpty ? name : (username.isNotEmpty ? username : phone);
                                final isSelectedForGroup = selectedGroupMembers.contains(memberLabel);

                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () async {
                                    if (hasConnekt) {
                                      if (isGroup) {
                                        setSheetState(() {
                                          if (isSelectedForGroup) {
                                            selectedGroupMembers.remove(memberLabel);
                                          } else {
                                            selectedGroupMembers.add(memberLabel);
                                          }
                                        });
                                        return;
                                      }
                                      final target = username.isNotEmpty ? username : (phone.isNotEmpty ? phone : name);
                                      Navigator.pop(ctx);
                                      await Navigator.of(this.context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            contactName: target,
                                            avatarUrl: avatarUrl,
                                            showBackButton: true,
                                          ),
                                        ),
                                      );
                                      _loadConversations();
                                    } else {
                                      await handleInviteContact(sheetCtx, setSheetState, c);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    child: Row(
                                      children: [
                                        SafeAvatar(
                                          url: avatarUrl,
                                          fallbackText: name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          size: 36,
                                          radius: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.getTextPrimary(sheetCtx),
                                                ),
                                              ),
                                              Text(
                                                hasConnekt
                                                    ? (username.isNotEmpty
                                                        ? '@$username${phone.isNotEmpty ? ' • $phone' : ''}'
                                                        : phone)
                                                    : '${phone.isNotEmpty ? '$phone • ' : ''}Not on CONNEKT',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (hasConnekt && isGroup)
                                          Icon(
                                            isSelectedForGroup ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                            color: AppTheme.brandBlue,
                                            size: 20,
                                          )
                                        else if (hasConnekt)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.brandBlue.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'CONNEKT',
                                              style: TextStyle(
                                                color: AppTheme.brandBlue,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          )
                                        else
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              backgroundColor: isInvited
                                                  ? AppTheme.brandBlue.withValues(alpha: 0.12)
                                                  : AppTheme.brandBlue,
                                              foregroundColor: isInvited ? AppTheme.brandBlue : Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            ),
                                            onPressed: isSendingInvite
                                                ? null
                                                : () => handleInviteContact(sheetCtx, setSheetState, c),
                                            icon: isSendingInvite
                                                ? const SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  )
                                                : Icon(
                                                    isInvited ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                                                    size: 14,
                                                  ),
                                            label: Text(
                                              isInvited ? 'Invited' : 'Invite',
                                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
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
                        final input = contactController.text.trim();
                        if (isGroup) {
                          if (selectedGroupMembers.isEmpty && input.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select contacts or enter a group name'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          final suggestedName = input.isNotEmpty
                              ? input
                              : (selectedGroupMembers.isNotEmpty
                                  ? selectedGroupMembers.take(3).join(', ')
                                  : 'New Group');

                          await _showGroupDetailsDialog(
                            parentContext: sheetCtx,
                            initialName: suggestedName,
                            selectedMembers: selectedGroupMembers.toList(),
                            onConfirm: (groupName, groupDesc) async {
                              final nav = Navigator.of(this.context);
                              Navigator.pop(ctx);

                              Map<String, dynamic>? createdGroup;
                              if (!isFlutterTestEnv) {
                                try {
                                  createdGroup = await ApiService.createGroupChat(
                                    groupName,
                                    selectedGroupMembers.toList(),
                                    description: groupDesc,
                                  );
                                } catch (_) {}
                              }

                              if (!mounted) return;

                              await nav.push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    conversationId: createdGroup?['id']?.toString(),
                                    contactName: groupName,
                                    groupDescription: groupDesc,
                                    avatarUrl: '',
                                    showBackButton: true,
                                    isGroup: true,
                                    initialMembers: selectedGroupMembers.isNotEmpty
                                        ? ['You', ...selectedGroupMembers]
                                        : const ['You', 'Soumo', 'Lena Rivers', 'David Kim'],
                                  ),
                                ),
                              );
                              _loadConversations();
                            },
                          );
                          return;
                        }

                        if (input.isEmpty) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a username, phone or select a contact'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        final target = input;

                        final nav = Navigator.of(this.context);
                        Navigator.pop(ctx);

                        if (!mounted) return;

                        await nav.push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              contactName: target,
                              avatarUrl: '',
                              showBackButton: true,
                              isGroup: false,
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
          );
        },
      ),
    );
    sheetFuture.whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        contactController.dispose();
      });
    });
  }

  // ====================================================================
  // CREATE CALL LINK SHEET (CALLS TAB)
  // ====================================================================

  void _showCreateCallLinkSheet() {
    final link = 'https://connekt.net.in/call/${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showModalBottomSheet<void>(
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
                          Text(context.tr('chats.title'), maxLines: 1, softWrap: false),
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
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.tr('chats.status'), maxLines: 1, softWrap: false),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.tr('chats.calls'), maxLines: 1, softWrap: false),
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
      if (_isChatLocked(c)) return false;
      if (_isChatArchived(c)) return false;

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
                                    conv['isArchived'] = true;
                                    _recordChatArchived(conv);
                                    _conversations.removeWhere((c) => _isSameChat(c, conv));
                                    if (!_archivedConversations.any((ac) => _isSameChat(ac, conv))) {
                                      _archivedConversations.add(conv);
                                    }
                                  });
                                  _saveFolderState();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Archived ${conv['name']}'),
                                      action: SnackBarAction(
                                        label: 'UNDO',
                                        onPressed: () {
                                          setState(() {
                                            _removeChatArchived(conv);
                                            conv['isArchived'] = false;
                                            _archivedConversations.removeWhere((c) => _isSameChat(c, conv));
                                            _conversations.insert(index.clamp(0, _conversations.length), conv);
                                          });
                                          _saveFolderState();
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
                                                  String formatted = rawLast;
                                                  if (rawLast.startsWith('{') && rawLast.endsWith('}')) {
                                                    try {
                                                      final data = jsonDecode(rawLast);
                                                      final type = data['type'];
                                                      if (type == 'sticker') {
                                                        formatted = '💟 Sticker';
                                                      } else if (type == 'image') {
                                                        formatted = '📷 Photo';
                                                      } else if (type == 'voice') {
                                                        formatted = '🎤 Voice message';
                                                      } else if (type == 'audio') {
                                                        formatted = '🎵 Audio';
                                                      } else if (type == 'file') {
                                                        formatted = '📄 Document';
                                                      } else if (type == 'location') {
                                                        formatted = '📍 Location';
                                                      } else if (type == 'contact') {
                                                        formatted = '👤 Contact';
                                                      }
                                                    } catch (_) {}
                                                  }
                                                  final displayLast = (formatted == 'This message was deleted' ||
                                                          formatted == 'You deleted this message' ||
                                                          formatted == 'Conversation started')
                                                      ? ''
                                                      : formatted;
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
