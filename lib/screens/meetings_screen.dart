import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/call_log_service.dart';
import '../widgets/call_log_tile.dart';
import '../widgets/safe_avatar.dart';
import '../widgets/meetings_illustration.dart';
import 'meeting_call_screen.dart';

class MeetingsScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onBackToHome;

  const MeetingsScreen({super.key, this.user, this.onBackToHome});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  List<Map<String, dynamic>> _allContacts = [];
  bool _isLoadingContacts = false;

  // Recent call activity history
  // If empty, displays the empty-state illustration
  final List<Map<String, dynamic>> _recentCalls = [];
  String _callHistoryFilter = 'All';
  bool _isSyncingCallLogs = false;

  @override
  void initState() {
    super.initState();
    CallLogService.syncNotifier.addListener(_onCallSyncUpdated);
    _loadContacts();
    _loadRecentCallLogs();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    CallLogService.syncNotifier.removeListener(_onCallSyncUpdated);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onCallSyncUpdated() {
    _loadRecentCallLogs();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoadingContacts = true);
    try {
      final contacts = await ApiService.getContacts();
      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _isLoadingContacts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingContacts = false);
      }
    }

    // If database returned no contacts (or single user), provide registered CONNEKT ecosystem contacts
    if (_allContacts.isEmpty) {
      _allContacts = [
        {
          'id': 'c1',
          'username': 'niharika',
          'full_name': 'Niharika Chatterjee',
          'email': 'chatterjeeniharika8@gmail.com',
          'avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=160',
        },
        {
          'id': 'c2',
          'username': 'alexchen',
          'full_name': 'Alex Chen',
          'email': 'alex.chen@connekt.me',
          'avatar_url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=160',
        },
        {
          'id': 'c3',
          'username': 'sarah_j',
          'full_name': 'Sarah Jenkins',
          'email': 'sarah.j@connekt.me',
          'avatar_url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=160',
        },
        {
          'id': 'c4',
          'username': 'davidkim',
          'full_name': 'David Kim',
          'email': 'david.kim@connekt.me',
          'avatar_url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=160',
        },
        {
          'id': 'c5',
          'username': 'lena_rivers',
          'full_name': 'Lena Rivers',
          'email': 'lena.rivers@connekt.me',
          'avatar_url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=160',
        },
      ];
    }
  }

  Future<void> _loadRecentCallLogs() async {
    try {
      final logs = await CallLogService.loadCallLogs(limit: 50);
      if (!mounted) return;
      final localSessionCalls = _recentCalls.where((c) => c['isLocalCall'] == true).toList();
      if (logs.isEmpty && localSessionCalls.isEmpty) return;

      setState(() {
        _recentCalls
          ..clear()
          ..addAll(localSessionCalls);
        for (final l in logs) {
          final String type = (l['type'] ?? 'incoming').toString();
          _recentCalls.add({
            'name': (l['name'] ?? l['number'] ?? 'Contact').toString(),
            'number': (l['number'] ?? '').toString(),
            'email': (l['number'] ?? '').toString(),
            'avatar': '',
            'isVideo': false,
            'isMissed': type == 'missed' || type == 'rejected',
            'type': type,
            'duration': l['duration'] ?? 0,
            'formattedDuration': l['formattedDuration'] ?? '',
            'formattedTime': l['formattedTime'] ?? 'Recent',
            'time': l['formattedTime'] ?? 'Recent',
          });
        }
      });
    } catch (_) {}
  }

  Future<void> _syncCallLogsNow() async {
    if (_isSyncingCallLogs) return;
    setState(() => _isSyncingCallLogs = true);
    try {
      final res = await CallLogService.syncCallLogs(limit: 50);
      await _loadRecentCallLogs();
      if (!mounted) return;
      final bool ok = res['success'] == true;
      final String msg = (res['message'] ?? (ok ? 'Call logs synced.' : 'Unable to load call logs.')).toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? AppTheme.brandBlue : AppTheme.accentCoral,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingCallLogs = false);
      }
    }
  }

  void _startCall({
    required String contactName,
    required String contactEmail,
    required String avatarUrl,
    required bool isVideo,
  }) {
    // Record into recent history
    setState(() {
      _recentCalls.insert(0, {
        'name': contactName,
        'number': contactEmail,
        'email': contactEmail,
        'avatar': avatarUrl,
        'isVideo': isVideo,
        'isMissed': false,
        'isLocalCall': true,
        'type': 'outgoing',
        'formattedTime': 'Just now',
        'time': 'Just now',
      });
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeetingCallScreen(
          contactName: contactName,
          contactEmail: contactEmail,
          avatarUrl: avatarUrl,
          isVideoCall: isVideo,
        ),
      ),
    );
  }

  void _startInstantMeeting() {
    final rnd = Random();
    final roomCode = 'connekt-${rnd.nextInt(900) + 100}-${rnd.nextInt(900) + 100}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Asynchronously register the room on the server
    ApiService.createInstantMeeting(title: 'Instant Meeting').catchError((_) => <String, dynamic>{});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131724) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.brandBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppTheme.brandBlue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instant Meeting Ready',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Room code generated & ready for participants',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Room Code Display Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A202E) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MEETING ROOM CODE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roomCode,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: 'Copy Code',
                    color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: roomCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Meeting code "$roomCode" copied to clipboard!'),
                          backgroundColor: AppTheme.brandBlue,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Join Call Now Button
            ElevatedButton.icon(
              icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
              label: const Text('Join Call Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _startCall(
                  contactName: 'Instant Meeting ($roomCode)',
                  contactEmail: widget.user?.email ?? 'host@connekt.me',
                  avatarUrl: widget.user?.personalProfile?.avatarUrl ?? '',
                  isVideo: true,
                );
              },
            ),
            const SizedBox(height: 10),

            // Copy Invitation Button
            OutlinedButton.icon(
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share Meeting Details', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                foregroundColor: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                side: BorderSide(color: isDark ? const Color(0xFF2D3748) : const Color(0xFFBFDBFE)),
              ),
              onPressed: () {
                final inviteText = 'Join my CONNEKT meeting!\nMeeting Room Code: $roomCode\nApp: CONNEKT';
                Clipboard.setData(ClipboardData(text: inviteText));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Meeting invitation copied to clipboard!'),
                    backgroundColor: AppTheme.brandBlue,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleMeetingSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCtrl = TextEditingController(text: 'CONNEKT Team Sync');
    final agendaCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    int selectedDuration = 45;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131724) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final primaryColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
          final mutedColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 24,
              right: 24,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Schedule Meeting',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: mutedColor,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title Field
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Meeting Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date & Time Picker Tile
                  GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null && context.mounted) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (pickedTime != null) {
                          setSheetState(() {
                            selectedDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date & Start Time',
                                  style: TextStyle(fontSize: 11, color: mutedColor),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} at ${selectedDate.hour.toString().padLeft(2, '0')}:${selectedDate.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_calendar_outlined, size: 18, color: mutedColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Duration Selector
                  Text('Duration:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mutedColor)),
                  const SizedBox(height: 6),
                  Row(
                    children: [15, 30, 45, 60].map((mins) {
                      final isSelected = selectedDuration == mins;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () => setSheetState(() => selectedDuration = mins),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.brandBlue
                                    : (isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.brandBlue
                                      : (isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Text(
                                '$mins min',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Agenda Field
                  TextField(
                    controller: agendaCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Agenda / Description (optional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Schedule Button
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a meeting title'),
                                  backgroundColor: AppTheme.accentCoral,
                                ),
                              );
                              return;
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);

                            setSheetState(() => isSaving = true);

                            try {
                              await ApiService.scheduleMeeting(
                                title: title,
                                scheduledAt: selectedDate,
                                durationMinutes: selectedDuration,
                                agenda: agendaCtrl.text.trim(),
                              );
                            } catch (_) {
                              // If network error, still register into local state
                            }

                            if (mounted) {
                              setState(() {
                                _recentCalls.insert(0, {
                                  'name': title,
                                  'email': 'Scheduled for ${selectedDate.day}/${selectedDate.month} at ${selectedDate.hour.toString().padLeft(2, '0')}:${selectedDate.minute.toString().padLeft(2, '0')}',
                                  'avatar': '',
                                  'isVideo': true,
                                  'isMissed': false,
                                  'type': 'Scheduled Meeting ($selectedDuration min)',
                                  'time': 'Upcoming',
                                });
                              });
                            }

                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Meeting "$title" scheduled successfully!'),
                                backgroundColor: AppTheme.brandBlue,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Schedule Meeting',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _showNewCallBottomSheet() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(_allContacts);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131724),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Start a Call',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a CONNEKT contact to start an audio or video call',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                // Search in bottom sheet
                TextField(
                  controller: searchCtrl,
                  onChanged: (val) {
                    final q = val.trim().toLowerCase();
                    setSheetState(() {
                      filtered = _allContacts.where((c) {
                        final name = (c['full_name'] ?? c['username'] ?? '').toString().toLowerCase();
                        final email = (c['email'] ?? '').toString().toLowerCase();
                        return name.contains(q) || email.contains(q);
                      }).toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search people or email...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF1B2030),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CONNEKT CONTACTS',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoadingContacts
                      ? const Center(
                          child: CircularProgressIndicator(color: AppTheme.accentBlue),
                        )
                      : filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No contacts found',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, index) {
                            final c = filtered[index];
                            final name = c['full_name'] ?? c['username'] ?? 'User';
                            final email = c['email'] ?? '';
                            final avatar = c['avatar_url'] ?? '';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.accentBlue.withOpacity(0.2),
                                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                child: avatar.isEmpty
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
                              ),
                              subtitle: Text(
                                email,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.phone_outlined, color: AppTheme.accentBlue, size: 22),
                                    tooltip: 'Audio Call',
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _startCall(
                                        contactName: name,
                                        contactEmail: email,
                                        avatarUrl: avatar,
                                        isVideo: false,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.videocam_rounded, color: AppTheme.accentBlue, size: 24),
                                    tooltip: 'Video Call',
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _startCall(
                                        contactName: name,
                                        contactEmail: email,
                                        avatarUrl: avatar,
                                        isVideo: true,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.user?.personalProfile?.avatarUrl;
    final userInitial = widget.user?.personalProfile?.fullName.isNotEmpty == true
        ? widget.user!.personalProfile!.fullName[0].toUpperCase()
        : (widget.user?.username.isNotEmpty == true ? widget.user!.username[0].toUpperCase() : 'K');

    final searchResults = _searchQuery.isEmpty
        ? <Map<String, dynamic>>[]
        : _allContacts.where((c) {
            final q = _searchQuery.toLowerCase();
            final name = (c['full_name'] ?? c['username'] ?? '').toString().toLowerCase();
            final email = (c['email'] ?? '').toString().toLowerCase();
            return name.contains(q) || email.contains(q);
          }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF10131C) : const Color(0xFFF6F8FA);
    final searchBg = isDark ? const Color(0xFF1E222D) : const Color(0xFFEDF2F7);
    final iconColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ----------------------------------------------------
                // 1. TOP NAVIGATION AND SEARCH BAR (Matches Image 2)
                // ----------------------------------------------------
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 16, top: 10, bottom: 12),
                  child: Row(
                    children: [
                      // Back button (or Menu)
                      IconButton(
                        icon: Icon(
                          widget.onBackToHome != null ? Icons.arrow_back_rounded : Icons.menu_rounded,
                          color: iconColor,
                          size: 26,
                        ),
                        tooltip: widget.onBackToHome != null ? 'Back to Home' : 'Menu',
                        onPressed: () {
                          if (widget.onBackToHome != null) {
                            widget.onBackToHome!();
                          } else {
                            _scaffoldKey.currentState?.openDrawer();
                          }
                        },
                      ),
                      const SizedBox(width: 4),

                      // Large Rounded Search Bar (center)
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: searchBg,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  style: TextStyle(color: textColor, fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'Search contacts',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF9EACB9),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close, color: Color(0xFF9EACB9), size: 18),
                                            onPressed: () => _searchController.clear(),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              if (_searchQuery.isEmpty)
                                GestureDetector(
                                  onTap: () => _searchFocusNode.requestFocus(),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.keyboard_outlined,
                                      color: Color(0xFF9EACB9),
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // User Profile Picture (right) with Blue Ring
                      GestureDetector(
                        onTap: () {
                          // Show user quick profile card
                          _showUserQuickSheet();
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF5B8BF7),
                              width: 2.2,
                            ),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: resolveAvatarUrl(avatarUrl) != null
                                ? Image.network(
                                    resolveAvatarUrl(avatarUrl)!,
                                    headers: ApiConfig.mediaHeaders,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildUserAvatarFallback(userInitial),
                                  )
                                : _buildUserAvatarFallback(userInitial),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ----------------------------------------------------
                // Action Buttons: "start instant meeting" & "schedule meeting"
                // ----------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      // Button 1: Start Instant Meeting
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _startInstantMeeting,
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.brandBlue,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.brandBlue.withValues(alpha: isDark ? 0.35 : 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.video_call_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Start instant meeting',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Button 2: Schedule Meeting
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showScheduleMeetingSheet,
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2433) : const Color(0xFFEFF4FE),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2D3748) : const Color(0xFFBFDBFE),
                                  width: 1.2,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Schedule meeting',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppTheme.brandBlue,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // ----------------------------------------------------
                // 2. MAIN CONTENT AREA
                // ----------------------------------------------------
                Expanded(
                  child: _searchQuery.isNotEmpty
                      // A. Search Results List
                      ? _buildSearchResults(searchResults)
                      : _recentCalls.isNotEmpty
                          // B. Recent Activity History
                          ? _buildRecentActivityList()
                          // C. Empty State Illustration (Matches Image 2)
                          : _buildEmptyState(),
                ),
              ],
            ),

            // ----------------------------------------------------
            // 3. FLOATING "New call" BUTTON (Matches Image 2)
            // ----------------------------------------------------
            Positioned(
              bottom: 18,
              right: 18,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showNewCallBottomSheet,
                  borderRadius: BorderRadius.circular(16),
                  splashColor: Colors.white.withOpacity(0.2),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2752B3),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2752B3).withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.video_call_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'New call',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // EMPTY STATE (Pixel-accurate to Image 2)
  // ----------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Elegant vector illustration
          const MeetingsIllustration(width: 290, height: 200),
          const SizedBox(height: 28),
          // Subtitle message
          const Text(
            'Your latest activity will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E95A5),
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isSyncingCallLogs ? null : _syncCallLogsNow,
            icon: _isSyncingCallLogs
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue),
                  )
                : const Icon(Icons.sync_rounded, size: 17, color: AppTheme.accentBlue),
            label: Text(
              _isSyncingCallLogs ? 'Syncing Call Logs...' : 'Sync Phone Call Logs',
              style: const TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // RECENT CALL ACTIVITY LIST
  // ----------------------------------------------------
  Widget _buildRecentActivityList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF171B26) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : AppTheme.textPrimaryLight;
    final textSecondary = isDark ? const Color(0xFF8E95A5) : const Color(0xFF64748B);
    final filtered = filterCallLogs(_recentCalls, _callHistoryFilter);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: (filtered.isEmpty ? 1 : filtered.length) + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Call Logs & History',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isSyncingCallLogs ? null : _syncCallLogsNow,
                      icon: _isSyncingCallLogs
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue),
                            )
                          : const Icon(Icons.sync_rounded, size: 16, color: AppTheme.accentBlue),
                      label: Text(
                        _isSyncingCallLogs ? 'Syncing...' : 'Sync',
                        style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12.5, fontWeight: FontWeight.w600),
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
                  selectedFilter: _callHistoryFilter,
                  onSelected: (f) => setState(() => _callHistoryFilter = f),
                  activeColor: AppTheme.brandBlue,
                  isDark: isDark,
                ),
              ],
            ),
          );
        }

        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'No $_callHistoryFilter calls in your history.',
                style: TextStyle(color: textSecondary, fontSize: 13.5),
              ),
            ),
          );
        }

        final call = filtered[index - 1];
        final bool isVideo = call['isVideo'] == true;
        return CallLogTile(
          call: call,
          cardColor: cardColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          actionColor: AppTheme.accentBlue,
          onCallTap: () {
            _startCall(
              contactName: (call['name'] ?? 'Contact').toString(),
              contactEmail: (call['email'] ?? call['number'] ?? '').toString(),
              avatarUrl: (call['avatar'] ?? '').toString(),
              isVideo: isVideo,
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // SEARCH RESULTS
  // ----------------------------------------------------
  Widget _buildSearchResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'No contacts match "$_searchQuery"',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = results[index];
        final name = c['full_name'] ?? c['username'] ?? 'User';
        final email = c['email'] ?? '';
        final avatar = c['avatar_url'] ?? '';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF171B26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.accentBlue.withOpacity(0.2),
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      email,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone_outlined, color: AppTheme.accentBlue, size: 20),
                onPressed: () => _startCall(
                  contactName: name,
                  contactEmail: email,
                  avatarUrl: avatar,
                  isVideo: false,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.videocam_rounded, color: AppTheme.accentBlue, size: 22),
                onPressed: () => _startCall(
                  contactName: name,
                  contactEmail: email,
                  avatarUrl: avatar,
                  isVideo: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserAvatarFallback(String initial) {
    return Container(
      color: AppTheme.accentBlue,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
    );
  }

  void _showUserQuickSheet() {
    final user = widget.user;
    final name = user?.personalProfile?.fullName.isNotEmpty == true
        ? user!.personalProfile!.fullName
        : (user?.username ?? 'User');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171B26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            SafeAvatar(
              url: user?.personalProfile?.avatarUrl,
              fallbackText: name,
              size: 60,
              radius: 30,
            ),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(user?.email ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            const Divider(color: Colors.white10, height: 28),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.white70),
              title: const Text('Meetings Settings', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.white70),
              title: const Text('Privacy & Encryption', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final user = widget.user;
    final name = user?.personalProfile?.fullName.isNotEmpty == true
        ? user!.personalProfile!.fullName
        : (user?.username ?? 'User');

    return Drawer(
      backgroundColor: const Color(0xFF10131C),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('C', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('CONNEKT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  SafeAvatar(
                    url: user?.personalProfile?.avatarUrl,
                    fallbackText: name,
                    size: 40,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(user?.email ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.white70),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.white70),
              title: const Text('Privacy & Security', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.white70),
              title: const Text('Help & Feedback', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'CONNEKT v1.0.0 (Build 1)',
                style: TextStyle(color: AppTheme.textMuted.withOpacity(0.6), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
