import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/call_log_service.dart';
import '../services/api_service.dart';
import 'calendar_scheduler_screen.dart';

class ReminderItem {
  final String id;
  String title;
  DateTime? dueDateTime;
  bool isCompleted;

  ReminderItem({
    required this.id,
    required this.title,
    this.dueDateTime,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dueDateTime': dueDateTime?.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory ReminderItem.fromJson(Map<String, dynamic> json) => ReminderItem(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'] as String? ?? '',
    dueDateTime: json['dueDateTime'] != null ? DateTime.tryParse(json['dueDateTime'] as String) : null,
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}

class QuickNoteItem {
  final String id;
  String text;
  DateTime createdAt;

  QuickNoteItem({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory QuickNoteItem.fromJson(Map<String, dynamic> json) => QuickNoteItem(
    id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    text: json['text'] as String? ?? '',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}

class HomeScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<int>? onNavigateToTab;
  final ValueChanged<String>? onModeChanged;

  const HomeScreen({
    super.key,
    required this.user,
    this.onNavigateToTab,
    this.onModeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProfessional = false;
  List<QuickNoteItem> _quickNotes = [];
  List<ReminderItem> _reminders = [];
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _isProfessional = widget.user?.currentMode == 'professional';
    _loadLocalData();
    _fetchRemindersFromServer();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user?.currentMode != oldWidget.user?.currentMode) {
      setState(() {
        _isProfessional = widget.user?.currentMode == 'professional';
      });
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesRaw = prefs.getStringList('connekt_home_quick_notes_v2');
      final legacyNote = prefs.getString('connekt_home_quick_note');
      final remindersRaw = prefs.getStringList('connekt_home_reminders_v2');

      setState(() {
        if (notesRaw != null && notesRaw.isNotEmpty) {
          _quickNotes = notesRaw.map((s) {
            try {
              return QuickNoteItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return QuickNoteItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                text: s,
                createdAt: DateTime.now(),
              );
            }
          }).toList();
        } else if (legacyNote != null && legacyNote.trim().isNotEmpty) {
          _quickNotes = [
            QuickNoteItem(
              id: '1',
              text: legacyNote.trim(),
              createdAt: DateTime.now(),
            ),
          ];
        } else {
          _quickNotes = [
            QuickNoteItem(
              id: '1',
              text: 'Draft presentation for next week\'s product demo.\nSync with regional leads.',
              createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
          ];
        }

        if (remindersRaw != null && remindersRaw.isNotEmpty) {
          _reminders = remindersRaw.map((s) {
            try {
              return ReminderItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return ReminderItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: s,
              );
            }
          }).toList();
        } else {
          _reminders = [
            ReminderItem(
              id: '1',
              title: 'Review CONNEKT Architecture & Sync with Team',
              dueDateTime: DateTime.now().add(const Duration(hours: 3)),
            ),
          ];
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchRemindersFromServer() async {
    try {
      final serverReminders = await ApiService.getReminders();
      if (serverReminders.isNotEmpty && mounted) {
        setState(() {
          _reminders = serverReminders.map((m) => ReminderItem.fromJson(m)).toList();
        });
        _saveReminders();
      }
    } catch (_) {}
  }

  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = _reminders.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList('connekt_home_reminders_v2', rawList);
    } catch (_) {}
  }

  Future<void> _saveQuickNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = _quickNotes.map((n) => jsonEncode(n.toJson())).toList();
      await prefs.setStringList('connekt_home_quick_notes_v2', rawList);
      if (_quickNotes.isNotEmpty) {
        await prefs.setString('connekt_home_quick_note', _quickNotes.first.text);
      }
    } catch (_) {}
  }

  String get _connektEmail {
    final rawUsername = widget.user?.username.trim();
    if (rawUsername != null && rawUsername.isNotEmpty) {
      return '$rawUsername@connekt.net.in';
    }
    return 'user_id@connekt.net.in';
  }

  void _toggleProfessionalMode(bool value) {
    setState(() => _isProfessional = value);
    final newMode = value ? 'professional' : 'common';
    widget.onModeChanged?.call(newMode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Switched to Professional Mode' : 'Switched to Personal Mode',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0F3B82),
      ),
    );
  }

  // ===========================================================================
  // INTERACTIVE BOTTOM SHEETS & MODALS (Scheduler, World Clock, Reminders, Notes)
  // ===========================================================================

  void _showLanguageSheet(BuildContext context) {
    final languages = [
      {'name': 'English (US / UK)', 'code': 'en', 'selected': true},
      {'name': 'हिन्दी (Hindi)', 'code': 'hi', 'selected': false},
      {'name': 'বাংলা (Bengali)', 'code': 'bn', 'selected': false},
      {'name': 'తెలుగు (Telugu)', 'code': 'te', 'selected': false},
      {'name': 'मराठी (Marathi)', 'code': 'mr', 'selected': false},
      {'name': 'Español (Spanish)', 'code': 'es', 'selected': false},
      {'name': 'Français (French)', 'code': 'fr', 'selected': false},
      {'name': 'Deutsch (German)', 'code': 'de', 'selected': false},
      {'name': 'العربية (Arabic)', 'code': 'ar', 'selected': false},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.translate_rounded, color: Color(0xFF0F3B82), size: 22),
                SizedBox(width: 10),
                Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1E36),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: languages.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final lang = languages[i];
                  final isSel = lang['selected'] as bool;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      lang['name'] as String,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        color: isSel ? const Color(0xFF0F3B82) : Colors.black87,
                      ),
                    ),
                    trailing: isSel
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0F3B82))
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Language set to ${lang['name']}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorldClockSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final nowUtc = DateTime.now().toUtc();
        final cities = [
          {'city': 'New Delhi', 'country': 'India', 'offsetH': 5, 'offsetM': 30, 'code': 'IST'},
          {'city': 'London', 'country': 'United Kingdom', 'offsetH': 0, 'offsetM': 0, 'code': 'GMT'},
          {'city': 'New York', 'country': 'United States', 'offsetH': -5, 'offsetM': 0, 'code': 'EST'},
          {'city': 'Tokyo', 'country': 'Japan', 'offsetH': 9, 'offsetM': 0, 'code': 'JST'},
          {'city': 'San Francisco', 'country': 'United States', 'offsetH': -8, 'offsetM': 0, 'code': 'PST'},
        ];

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.access_time_rounded, color: Color(0xFF0F3B82), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'World Clock',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...cities.map((c) {
                final cTime = nowUtc.add(
                  Duration(hours: c['offsetH'] as int, minutes: c['offsetM'] as int),
                );
                final hour = cTime.hour % 12 == 0 ? 12 : cTime.hour % 12;
                final minute = cTime.minute.toString().padLeft(2, '0');
                final ampm = cTime.hour >= 12 ? 'PM' : 'AM';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['city'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F1E36)),
                            ),
                            Text(
                              '${c['country']} • ${c['code']}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Text(
                          '$hour:$minute $ampm',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F3B82),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  int get _activeReminderCount => _reminders.where((r) => !r.isCompleted).length;

  String _formatReminderDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(dt.year, dt.month, dt.day);

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];

    String datePart;
    if (targetDate == today) {
      datePart = 'Today';
    } else if (targetDate == tomorrow) {
      datePart = 'Tomorrow';
    } else {
      datePart = '$weekday, ${dt.day} $month';
    }

    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';

    return '$datePart • $hour12:$minute $ampm';
  }

  String _formatDateOnly(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final target = DateTime(d.year, d.month, d.day);

    if (target == today) return 'Today';
    if (target == tomorrow) return 'Tomorrow';

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  String _formatTimeOnly(TimeOfDay t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $ampm';
  }

  Widget _buildQuickDateChip(String label, {required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F3B82) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F3B82) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _showRemindersSheet(BuildContext context) {
    final textController = TextEditingController();
    DateTime? selectedDate = DateTime.now();
    TimeOfDay? selectedTime = const TimeOfDay(hour: 10, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final activeCount = _reminders.where((r) => !r.isCompleted).length;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF0F3B82), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Reminders',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: activeCount > 0 ? const Color(0xFFE53935) : const Color(0xFF64748B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Reminders list
                if (_reminders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No pending reminders! Tap below to add.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.35,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _reminders.length,
                      itemBuilder: (ctx, idx) {
                        final rem = _reminders[idx];
                        final isOverdue = rem.dueDateTime != null &&
                            rem.dueDateTime!.isBefore(DateTime.now()) &&
                            !rem.isCompleted;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: rem.isCompleted ? const Color(0xFFF8FAFC) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: rem.isCompleted ? const Color(0xFFE2E8F0) : const Color(0xFFD6E2F2),
                              width: 1,
                            ),
                            boxShadow: rem.isCompleted
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Completion Checkbox
                              InkWell(
                                onTap: () {
                                  setSheetState(() => rem.isCompleted = !rem.isCompleted);
                                  setState(() {});
                                  _saveReminders();
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    rem.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: rem.isCompleted ? const Color(0xFF22C55E) : const Color(0xFF0F3B82),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Title & Formatted Date/Time
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      rem.title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: rem.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                                        decoration: rem.isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    if (rem.dueDateTime != null) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.schedule_rounded,
                                            size: 12,
                                            color: isOverdue
                                                ? const Color(0xFFE53935)
                                                : (rem.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F3B82)),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatReminderDateTime(rem.dueDateTime!),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isOverdue
                                                ? const Color(0xFFE53935)
                                                : (rem.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                            ),
                                          ),
                                          if (isOverdue) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEE2E2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Overdue',
                                                style: TextStyle(
                                                  color: Color(0xFFE53935),
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Delete Icon
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  setSheetState(() => _reminders.removeAt(idx));
                                  setState(() {});
                                  _saveReminders();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 12),

                // Reminder Title input field
                TextField(
                  controller: textController,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: 'e.g. semester exam, doctor appointment...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0F3B82), width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Specific Date & Time Pickers + Add button row
                Row(
                  children: [
                    // Date Picker
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? now,
                            firstDate: now.subtract(const Duration(days: 30)),
                            lastDate: now.add(const Duration(days: 365 * 3)),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF0F3B82),
                                  onPrimary: Colors.white,
                                  onSurface: Color(0xFF1E293B),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EFF9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCFDCED)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFF0F3B82)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  selectedDate != null ? _formatDateOnly(selectedDate!) : 'Pick Date',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F3B82),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Time Picker
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF0F3B82),
                                  onPrimary: Colors.white,
                                  onSurface: Color(0xFF1E293B),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EFF9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCFDCED)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF0F3B82)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  selectedTime != null ? _formatTimeOnly(selectedTime!) : 'Pick Time',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F3B82),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Add Button
                    ElevatedButton(
                      onPressed: () {
                        final text = textController.text.trim();
                        if (text.isEmpty) return;

                        DateTime? due;
                        if (selectedDate != null) {
                          final time = selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
                          due = DateTime(
                            selectedDate!.year,
                            selectedDate!.month,
                            selectedDate!.day,
                            time.hour,
                            time.minute,
                          );
                        }

                        final item = ReminderItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: text,
                          dueDateTime: due,
                        );

                        setSheetState(() {
                          _reminders.insert(0, item);
                        });
                        setState(() {});
                        _saveReminders();
                        textController.clear();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3B82),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Quick presets row
                Row(
                  children: [
                    const Text(
                      'Quick: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                    ),
                    _buildQuickDateChip(
                      'Today',
                      isSelected: selectedDate != null &&
                          DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day) ==
                              DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                      onTap: () {
                        setSheetState(() => selectedDate = DateTime.now());
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildQuickDateChip(
                      'Tomorrow',
                      isSelected: selectedDate != null &&
                          DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day) ==
                              DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).add(const Duration(days: 1)),
                      onTap: () {
                        setSheetState(() => selectedDate = DateTime.now().add(const Duration(days: 1)));
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildQuickDateChip(
                      '+7 Days',
                      isSelected: false,
                      onTap: () {
                        setSheetState(() => selectedDate = DateTime.now().add(const Duration(days: 7)));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  void _showQuickNotesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickNotesSheetContent(
        initialNotes: _quickNotes,
        onNotesUpdated: (updatedList) {
          setState(() {
            _quickNotes = List.from(updatedList);
          });
          _saveQuickNotes();
        },
      ),
    );
  }

  void _showInviteFriendsSheet(BuildContext context) {
    final inviteLink = 'https://connekt.net.in/join?ref=${widget.user?.username ?? 'welcome'}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF4C85E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 12),
            const Text(
              'Invite Friends to CONNEKT',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Connect the unconnected. Share your personal invite link with friends and colleagues.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      inviteLink,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F3B82), fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF0F3B82)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteLink));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite link copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Primary Action: Open Contact List
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showInviteContactsSheet(context, inviteLink);
                },
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                label: const Text('Share Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C85E6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteContactsSheet(BuildContext context, String inviteLink) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _InviteContactsSheetContent(
        inviteLink: inviteLink,
        user: widget.user,
      ),
    );
  }

  void _showMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CONNEKT Quick Menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF0F3B82)),
              title: const Text('My Profile & Settings'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onNavigateToTab?.call(5); // Go to Profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_rounded, color: Color(0xFF0F3B82)),
              title: const Text('Social & Vibe Feed'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onNavigateToTab?.call(4); // Go to Social
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0F3B82)),
              title: const Text('All Conversations'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onNavigateToTab?.call(2); // Go to Chats
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded, color: Color(0xFF0F3B82)),
              title: const Text('Connekt Mail Inbox'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onNavigateToTab?.call(3); // Go to Mails
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: Color(0xFF0F3B82)),
              title: const Text('Instant Meetings & Schedule'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onNavigateToTab?.call(1); // Go to Meetings
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, color: Color(0xFF0F3B82), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                    ),
                  ],
                ),
                Text(
                  '2 NEW',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE53935)),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildNotificationItem(
              icon: Icons.chat_rounded,
              title: '2 Unread Messages in Chat',
              time: 'Just now',
              onTap: () {
                Navigator.pop(ctx);
                widget.onNavigateToTab?.call(2);
              },
            ),
            _buildNotificationItem(
              icon: Icons.mail_rounded,
              title: '4 New Mails in Connekt Mail',
              time: '15m ago',
              onTap: () {
                Navigator.pop(ctx);
                widget.onNavigateToTab?.call(3);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String time,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F3B82).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF0F3B82), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F1E36))),
      subtitle: Text(time, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  // ===========================================================================
  // MAIN BUILD METHOD (Matches Image 1 Layout & Visuals Exactly)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // -----------------------------------------------------------------
            // 1. TOP HEADER BANNER: High-Tech Cyber Network + CONNEKT + Language
            // -----------------------------------------------------------------
            _buildHeaderBanner(context),

            // -----------------------------------------------------------------
            // 2. SCROLLABLE BODY CONTENT (Widgets, Profile Card, Large Action Cards, Vibe)
            // -----------------------------------------------------------------
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // TOP WIDGETS ROW (Scheduler on Left + 3 Stacked Cards on Right)
                    _buildTopWidgetsSection(context),

                    const SizedBox(height: 12),

                    // MIDDLE USER PROFILE / CONNEKT CARD
                    _buildConnektUserCard(context),

                    const SizedBox(height: 12),

                    // MAIN MODULE ACTION CARDS (Chat, Mail, Meeting)
                    _buildMainActionCard(
                      icon: Icons.chat_bubble_rounded,
                      title: 'Chat',
                      badgeCount: 0,
                      onTap: () => widget.onNavigateToTab?.call(2), // Chats tab
                    ),
                    const SizedBox(height: 10),
                    _buildMainActionCard(
                      icon: Icons.mail_rounded,
                      title: 'Mail',
                      badgeCount: 0,
                      onTap: () => widget.onNavigateToTab?.call(3), // Mail tab
                    ),
                    const SizedBox(height: 10),
                    _buildMainActionCard(
                      icon: Icons.videocam_rounded,
                      title: 'Meeting',
                      badgeCount: 0,
                      onTap: () => widget.onNavigateToTab?.call(1), // Meetings tab
                    ),

                    const SizedBox(height: 12),

                    // "vibe" BANNER
                    _buildVibeBanner(context),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // -----------------------------------------------------------------
            // 3. BOTTOM NAVIGATION BAR (Profile, Notifications, Vibe, Menu)
            // -----------------------------------------------------------------
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // COMPONENT BUILDERS
  // ===========================================================================

  Widget _buildHeaderBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 76,
      decoration: const BoxDecoration(
        color: Color(0xFF071426),
        image: DecorationImage(
          image: AssetImage('assets/images/header_cyber_banner.png'),
          fit: BoxFit.cover,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: CONNEKT Brand & Subtitle
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONNEKT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  shadows: [
                    Shadow(
                      color: const Color(0xFF00D2FF).withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'CONNECTING THE UNCONNECTED',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                ),
              ),
            ],
          ),

          // Right: Circular Language / Translation Button
          GestureDetector(
            onTap: () => _showLanguageSheet(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 25,
                    ),
                    const Positioned(
                      top: 10,
                      child: Text(
                        'A文',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopWidgetsSection(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT COLUMN: "Scheduler" Card with Calendar Preview
          Expanded(
            flex: 11,
            child: _buildSchedulerCard(context),
          ),
          const SizedBox(width: 10),
          // RIGHT COLUMN: 3 Stacked Widgets (World Clock, Reminder, Quick Notes)
          Expanded(
            flex: 10,
            child: Column(
              children: [
                _buildWorldClockCard(context),
                const SizedBox(height: 8),
                _buildReminderCard(context),
                const SizedBox(height: 8),
                _buildQuickNotesCard(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulerCard(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final formattedTime = '${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm';
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthYearText = '${monthNames[now.month - 1]} ${now.year}';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => CalendarSchedulerScreen(
              user: widget.user,
              onOpenMeetings: () {
                widget.onNavigateToTab?.call(1);
              },
              onRemindersChanged: () {
                _fetchRemindersFromServer();
              },
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EFF9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD6E2F2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Schedule',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3B82).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 10, color: Color(0xFF0F3B82)),
                      const SizedBox(width: 3),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F3B82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Miniature Calendar Graphic (Live month and date)
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    children: [
                      // Spiral Binding Dots Representation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          10,
                          (i) => Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Month / Year Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${now.month}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          Text(
                            monthYearText,
                            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Day headers: S M T W T F S
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('S', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                          Text('M', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                          Text('T', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                          Text('W', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                          Text('T', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                          Text('F', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                          Text('S', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Mini calendar grid
                      Expanded(
                        child: _buildMiniCalendarGrid(now),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCalendarGrid(DateTime now) {
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday; // 1 = Mon, 7 = Sun
    final startOffset = firstWeekday % 7; // Sunday = 0, Monday = 1 ... Saturday = 6

    final List<List<String>> grid = [];
    List<String> currentRow = [];

    for (int i = 0; i < startOffset; i++) {
      currentRow.add('');
    }

    for (int day = 1; day <= daysInMonth; day++) {
      currentRow.add('$day');
      if (currentRow.length == 7) {
        grid.add(currentRow);
        currentRow = [];
      }
    }

    if (currentRow.isNotEmpty) {
      while (currentRow.length < 7) {
        currentRow.add('');
      }
      grid.add(currentRow);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: grid.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: row.map((date) {
            if (date.isEmpty) {
              return const SizedBox(width: 14, height: 13);
            }

            final dayNum = int.tryParse(date);
            final isToday = dayNum != null && dayNum == now.day;
            final hasReminder = dayNum != null &&
                _reminders.any((r) {
                  final dt = r.dueDateTime;
                  return dt != null &&
                      dt.year == now.year &&
                      dt.month == now.month &&
                      dt.day == dayNum &&
                      !r.isCompleted;
                });

            Color bgColor = Colors.transparent;
            Color textColor = const Color(0xFF334155);
            FontWeight fontWeight = FontWeight.w500;

            if (isToday) {
              bgColor = const Color(0xFF0F3B82);
              textColor = Colors.white;
              fontWeight = FontWeight.bold;
            } else if (hasReminder) {
              bgColor = const Color(0xFFE53935).withValues(alpha: 0.18);
              textColor = const Color(0xFFE53935);
              fontWeight = FontWeight.bold;
            }

            return Container(
              width: 14,
              height: 13,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 7.0,
                  fontWeight: fontWeight,
                  color: textColor,
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildWorldClockCard(BuildContext context) {
    return InkWell(
      onTap: () => _showWorldClockSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EFF9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6E2F2), width: 1),
        ),
        child: Row(
          children: [
            // Analog Clock Icon Representation
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155), width: 1.4),
                color: Colors.white,
              ),
              child: const Center(
                child: Icon(
                  Icons.access_time_filled,
                  size: 14,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'World Clock',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context) {
    return InkWell(
      onTap: () => _showRemindersSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EFF9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6E2F2), width: 1),
        ),
        child: Row(
          children: [
            // Checklist Icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Icon(
                Icons.checklist_rounded,
                size: 16,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Reminder',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            // Notification Badge
            if (_activeReminderCount > 0)
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$_activeReminderCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNotesCard(BuildContext context) {
    return InkWell(
      onTap: () => _showQuickNotesSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF08A), // Soft yellow sticky note
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Center(
              child: Text(
                'Quick Notes',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Caveat',
                  color: Color(0xFF713F12),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnektUserCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEAF1FB),
            Color(0xFFF7FAFD),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E2F2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Column: Brand Emblem + Email + Switch
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // CONNEKT Brandmark
                Row(
                  children: [
                    Image.asset(
                      'assets/icons/connekt_emblem.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.change_circle_rounded,
                        color: Color(0xFFE53935),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 6),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontFamily: 'Roboto',
                        ),
                        children: [
                          TextSpan(text: 'CONN', style: TextStyle(color: Color(0xFF0F3B82))),
                          TextSpan(text: 'E', style: TextStyle(color: Color(0xFFE53935))),
                          TextSpan(text: 'KT', style: TextStyle(color: Color(0xFF0F3B82))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                const Text(
                  'CONNECTING THE UNCONNECTED',
                  style: TextStyle(
                    fontSize: 6.8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                // User Email
                Text(
                  _connektEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                // Switch: "Switch to Professional"
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.72,
                      alignment: Alignment.centerLeft,
                      child: Switch(
                        value: _isProfessional,
                        activeThumbImage: null,
                        activeColor: const Color(0xFF0F3B82),
                        activeTrackColor: const Color(0xFF0F3B82).withValues(alpha: 0.35),
                        onChanged: _toggleProfessionalMode,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        _isProfessional ? 'Professional' : 'Switch to Professional',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right Column: Two Stacked Pill Buttons ("Your Profile" & "Invite Friends")
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. "Your Profile" Pill Button (Coral-red)
              InkWell(
                onTap: () => widget.onNavigateToTab?.call(5), // Profile Tab
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 128,
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE54D4D), Color(0xFFDC2626)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Your Profile',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Active Indicator Dot
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 2. "Invite Friends" Pill Button (Blue)
              InkWell(
                onTap: () => _showInviteFriendsSheet(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 128,
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4C85E6), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.people_alt_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Invite Friends',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionCard({
    required IconData icon,
    required String title,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Dark Navy Icon
            Icon(
              icon,
              color: const Color(0xFF1E3A8A),
              size: 28,
            ),
            const SizedBox(width: 18),
            // Title
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            // Red Notification Badge if count > 0
            if (badgeCount > 0)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVibeBanner(BuildContext context) {
    return InkWell(
      onTap: () => widget.onNavigateToTab?.call(4), // Social / Vibe tab
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 472 / 157,
          child: Image.asset(
            'assets/images/vibe_banner.png',
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackVibeBanner(),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackVibeBanner() {
    return Container(
      width: double.infinity,
      height: 105,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A192F), Color(0xFF1E3A8A)],
        ),
      ),
      child: const Row(
        children: [
          Text(
            'vibe',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Color(0xFFEF4444),
              letterSpacing: 1.5,
            ),
          ),
          Spacer(),
          Icon(Icons.sensors_rounded, color: Colors.white54, size: 40),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Profile Icon
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: Color(0xFF475569), size: 26),
            tooltip: 'Profile',
            onPressed: () => widget.onNavigateToTab?.call(5),
          ),
          // 2. Notification Bell Icon with Badge Dot
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569), size: 26),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            tooltip: 'Notifications',
            onPressed: () => _showNotificationsSheet(context),
          ),
          // 3. Vibe / Social Icon (Crown Cycle matching original mockup)
          IconButton(
            icon: Image.asset(
              'assets/images/nav_crown_cycle.png',
              width: 25,
              height: 25,
              color: const Color(0xFF475569),
            ),
            tooltip: 'Vibe Feed',
            onPressed: () => widget.onNavigateToTab?.call(4),
          ),
          // 4. Hamburger Menu Icon
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF475569), size: 26),
            tooltip: 'Menu',
            onPressed: () => _showMenuSheet(context),
          ),
        ],
      ),
    );
  }
}

class _InviteContactsSheetContent extends StatefulWidget {
  final String inviteLink;
  final UserModel? user;

  const _InviteContactsSheetContent({
    required this.inviteLink,
    required this.user,
  });

  @override
  State<_InviteContactsSheetContent> createState() => _InviteContactsSheetContentState();
}

class _InviteContactsSheetContentState extends State<_InviteContactsSheetContent> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _permissionDenied = false;
  List<Map<String, dynamic>> _allContacts = [];
  String _searchQuery = '';
  final Set<String> _invitedPhones = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts({bool requestPerm = true}) async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    List<Map<String, dynamic>> deviceContacts = [];
    try {
      deviceContacts = await CallLogService.fetchDeviceContacts(
        limit: 250,
        requestIfNeeded: requestPerm,
      );
      if (CallLogService.lastContactsPermissionGranted == false) {
        _permissionDenied = true;
      }
    } catch (_) {}

    List<Map<String, dynamic>> connektContacts = [];
    try {
      connektContacts = await ApiService.getContacts();
    } catch (_) {}

    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final c in deviceContacts) {
      final phone = (c['phone'] ?? '').toString().trim();
      final name = (c['name'] ?? c['full_name'] ?? phone).toString().trim();
      if (name.isEmpty && phone.isEmpty) continue;
      final key = phone.isNotEmpty ? phone : name;
      if (seen.add(key)) {
        merged.add({
          'name': name.isNotEmpty ? name : phone,
          'phone': phone,
          'is_connekt': false,
        });
      }
    }

    for (final c in connektContacts) {
      final name = (c['name'] ?? c['username'] ?? '').toString().trim();
      final phone = (c['phone'] ?? '').toString().trim();
      final key = phone.isNotEmpty ? phone : name;
      if (seen.add(key)) {
        merged.insert(0, {
          'name': name.isNotEmpty ? name : phone,
          'phone': phone,
          'is_connekt': true,
        });
      }
    }

    if (merged.isEmpty) {
      merged.addAll([
        {'name': 'Rahul Verma', 'phone': '+91 98368 12345', 'is_connekt': false},
        {'name': 'Priya Sen', 'phone': '+91 98301 23456', 'is_connekt': false},
        {'name': 'Alex Johnson', 'phone': '+91 98312 34567', 'is_connekt': false},
        {'name': 'Ananya Podder', 'phone': '+91 98323 45678', 'is_connekt': false},
        {'name': 'Subrata Roy', 'phone': '+91 98334 56789', 'is_connekt': false},
        {'name': 'Tanvi Sharma', 'phone': '+91 98345 67890', 'is_connekt': false},
      ]);
    }

    if (mounted) {
      setState(() {
        _allContacts = merged;
        _isLoading = false;
      });
    }
  }

  Future<void> _inviteContact(String name, String phone) async {
    final inviteMsg = 'Hey! Join me on CONNEKT: Connect the unconnected.\nDownload & join here: ${widget.inviteLink}';

    bool opened = false;
    if (phone.isNotEmpty) {
      try {
        opened = await CallLogService.openSmsInvite(
          phone: phone,
          message: inviteMsg,
        );
      } catch (_) {}
    }

    await Clipboard.setData(ClipboardData(text: inviteMsg));

    if (mounted) {
      setState(() {
        _invitedPhones.add(phone.isNotEmpty ? phone : name);
      });
      HapticFeedback.lightImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'SMS composer opened for $name ($phone)'
                : 'Invite link copied! Share with $name ($phone)',
          ),
          backgroundColor: const Color(0xFF0F3B82),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Color _getAvatarColor(String name) {
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
      Color(0xFFF97316),
      Color(0xFF06B6D4),
      Color(0xFFEC4899),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _allContacts
        : _allContacts.where((c) {
            final name = (c['name'] ?? '').toString().toLowerCase();
            final phone = (c['phone'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || phone.contains(_searchQuery);
          }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8EFF9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.contacts_rounded, color: Color(0xFF0F3B82), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Contact to Invite',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F1E36),
                          ),
                        ),
                        Text(
                          'Send CONNEKT invite link directly via SMS',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search contacts by name or phone...',
                  hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF0F3B82)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Quick Copy Link Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.inviteLink));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite link copied! Share via WhatsApp or any app.')),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.inviteLink,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Copy',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Contacts List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0F3B82)),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No contacts matching "$_searchQuery"'
                                      : 'No contacts found on device',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                ),
                                if (_permissionDenied) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Contacts permission is needed to view phone contacts.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: () => _loadContacts(requestPerm: true),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F3B82)),
                                    child: const Text('Grant Permission', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, index) {
                            final contact = filtered[index];
                            final name = (contact['name'] ?? 'Contact').toString();
                            final phone = (contact['phone'] ?? '').toString();
                            final isConnekt = contact['is_connekt'] == true;
                            final isInvited = _invitedPhones.contains(phone.isNotEmpty ? phone : name);

                            final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: _getAvatarColor(name),
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F1E36),
                                                ),
                                              ),
                                            ),
                                            if (isConnekt) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'CONNEKT',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF15803D),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          phone.isNotEmpty ? phone : 'Phone contact',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: isInvited ? null : () => _inviteContact(name, phone),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isInvited ? const Color(0xFF22C55E) : const Color(0xFF0F3B82),
                                      disabledBackgroundColor: const Color(0xFF22C55E),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isInvited ? Icons.check_rounded : Icons.sms_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isInvited ? 'Invited' : 'Invite',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
}

class _QuickNotesSheetContent extends StatefulWidget {
  final List<QuickNoteItem> initialNotes;
  final ValueChanged<List<QuickNoteItem>> onNotesUpdated;

  const _QuickNotesSheetContent({
    required this.initialNotes,
    required this.onNotesUpdated,
  });

  @override
  State<_QuickNotesSheetContent> createState() => _QuickNotesSheetContentState();
}

class _QuickNotesSheetContentState extends State<_QuickNotesSheetContent> {
  late List<QuickNoteItem> _notes;
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isAdding = false;
  QuickNoteItem? _editingNote;

  @override
  void initState() {
    super.initState();
    _notes = List.from(widget.initialNotes);
    if (_notes.isEmpty) {
      _isAdding = true;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startAddNote() {
    setState(() {
      _editingNote = null;
      _noteController.clear();
      _isAdding = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _startEditNote(QuickNoteItem note) {
    setState(() {
      _editingNote = note;
      _noteController.text = note.text;
      _isAdding = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _focusNode.requestFocus();
        _noteController.selection = TextSelection.fromPosition(
          TextPosition(offset: _noteController.text.length),
        );
      }
    });
  }

  void _saveNote() {
    final text = _noteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some text before saving.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (_editingNote != null) {
        _editingNote!.text = text;
        _editingNote!.createdAt = DateTime.now();
      } else {
        final newNote = QuickNoteItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          createdAt: DateTime.now(),
        );
        _notes.insert(0, newNote);
      }
      _isAdding = false;
      _editingNote = null;
      _noteController.clear();
    });

    FocusScope.of(context).unfocus();
    widget.onNotesUpdated(_notes);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quick Note saved!'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF854D0E),
      ),
    );
  }

  void _deleteNote(QuickNoteItem note) {
    setState(() {
      _notes.removeWhere((item) => item.id == note.id);
      if (_editingNote?.id == note.id) {
        _editingNote = null;
        _isAdding = false;
        _noteController.clear();
      }
    });
    widget.onNotesUpdated(_notes);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note deleted'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _copyNote(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note copied to clipboard!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _formatNoteDate(DateTime dt) {
    final now = DateTime.now();
    final isToday = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $ampm';

    if (isToday) {
      return 'Today, $timeStr';
    }
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.78,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFEF9C3), // Soft yellow sticky note theme
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCA8A04).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: Color(0xFF854D0E), size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Quick Notes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Caveat',
                            color: Color(0xFF713F12),
                          ),
                        ),
                        if (_notes.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF854D0E).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_notes.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF713F12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (keyboardInset > 0)
                          IconButton(
                            icon: const Icon(Icons.keyboard_hide_rounded, color: Color(0xFF854D0E), size: 20),
                            tooltip: 'Hide Keyboard',
                            onPressed: () => FocusScope.of(context).unfocus(),
                          ),
                        if (_isAdding) ...[
                          if (_notes.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _isAdding = false;
                                  _editingNote = null;
                                  _noteController.clear();
                                });
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Color(0xFF854D0E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: _saveNote,
                            icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                            label: const Text(
                              'Save Note',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF854D0E),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            onPressed: _startAddNote,
                            icon: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
                            label: const Text(
                              'Add Note',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF854D0E),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Body: Composer or Cards List
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  child: _isAdding ? _buildComposer() : _buildNotesList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_editingNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF854D0E)),
                const SizedBox(width: 6),
                Text(
                  'Editing note from ${_formatNoteDate(_editingNote!.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF854D0E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: _noteController,
          focusNode: _focusNode,
          minLines: 4,
          maxLines: 8,
          autofocus: true,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF422006),
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: const Color(0xFF854D0E),
          decoration: InputDecoration(
            hintText: 'Type your ideas, scratch notes or thoughts here...',
            hintStyle: TextStyle(
              color: const Color(0xFF854D0E).withValues(alpha: 0.5),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFDE047), width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFDE047), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCA8A04), width: 1.8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Saved locally on this device',
              style: TextStyle(fontSize: 11, color: Color(0xFF854D0E), fontStyle: FontStyle.italic),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => _noteController.clear(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 11.5, color: Color(0xFF854D0E))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF854D0E),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Save Note',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesList() {
    if (_notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.note_alt_outlined,
                  size: 28,
                  color: Color(0xFF854D0E),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No notes saved yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF713F12),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap "+ Add Note" to capture your quick thoughts.',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF854D0E).withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _startAddNote,
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('Create First Note', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF854D0E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ...List.generate(_notes.length, (index) {
          final note = _notes[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE047), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF854D0E).withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top meta & actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: Color(0xFF854D0E),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatNoteDate(note.createdAt),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF854D0E),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _copyNote(note.text),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.copy_rounded, size: 16, color: Color(0xFF854D0E)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _startEditNote(note),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF854D0E)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _deleteNote(note),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade400),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                  color: const Color(0xFFFDE047).withValues(alpha: 0.8),
                  height: 14,
                  thickness: 1,
                ),
                SelectableText(
                  note.text,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF422006),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
        InkWell(
          onTap: _startAddNote,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFCA8A04).withValues(alpha: 0.5),
                style: BorderStyle.solid,
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 18, color: Color(0xFF854D0E)),
                SizedBox(width: 6),
                Text(
                  'Add New Note',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF854D0E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
