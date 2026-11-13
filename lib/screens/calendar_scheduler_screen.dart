import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/reminder_model.dart';
import '../services/api_service.dart';

class ScheduledEventItem {
  final String id;
  final String title;
  final String time;
  final String category; // 'morning', 'afternoon', 'night'
  final String location;
  final Color dotColor;
  final bool hasStar;
  final bool isGreenTag;
  final bool isWaveform;
  final DateTime date;

  ScheduledEventItem({
    required this.id,
    required this.title,
    required this.time,
    required this.category,
    required this.location,
    required this.dotColor,
    this.hasStar = false,
    this.isGreenTag = false,
    this.isWaveform = false,
    required this.date,
  });
}

class CalendarSchedulerScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onOpenMeetings;
  final VoidCallback? onRemindersChanged;

  const CalendarSchedulerScreen({
    super.key,
    required this.user,
    this.onOpenMeetings,
    this.onRemindersChanged,
  });

  @override
  State<CalendarSchedulerScreen> createState() => _CalendarSchedulerScreenState();
}

class _CalendarSchedulerScreenState extends State<CalendarSchedulerScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  List<ScheduledEventItem> _events = [];
  List<ReminderModel> _reminders = [];

  @override
  void initState() {
    super.initState();
    _initDefaultMeetings();
    _loadReminders();
  }

  void _initDefaultMeetings() {
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _currentMonth = DateTime(now.year, now.month, 1);

    _events = [
      ScheduledEventItem(
        id: '1',
        title: 'Morning Sync & Architecture\n5h deep work',
        time: '08:00',
        category: 'morning',
        location: 'Focus Room Alpha',
        dotColor: const Color(0xFF22C55E),
        isGreenTag: true,
        date: _selectedDate,
      ),
      ScheduledEventItem(
        id: '2',
        title: 'VC Preparation & Team Sync\nA301 - meeting room',
        time: '11:00',
        category: 'morning',
        location: 'Room A301',
        dotColor: const Color(0xFF3B82F6),
        hasStar: true,
        date: _selectedDate,
      ),
      ScheduledEventItem(
        id: '3',
        title: 'CONNEKT Product & Ecosystem Sync',
        time: '14:00',
        category: 'afternoon',
        location: 'Executive Room Alpha',
        dotColor: const Color(0xFF0F3B82),
        date: _selectedDate,
      ),
      ScheduledEventItem(
        id: '4',
        title: 'Daily Wrap-up & Notes Review',
        time: '19:30',
        category: 'night',
        location: 'Personal Workspace',
        dotColor: const Color(0xFF06B6D4),
        date: _selectedDate,
      ),
    ];
  }

  Future<void> _loadReminders() async {
    try {
      final rawReminders = await ApiService.getReminders();
      if (mounted) {
        setState(() {
          _reminders = rawReminders.map((j) => ReminderModel.fromJson(j)).toList();
        });
      }
    } catch (_) {
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatFullDate(DateTime d) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekday = weekdays[d.weekday - 1];
    return '$weekday, ${d.day} ${_getMonthName(d.month)} ${d.year}';
  }

  String _formatDateShort(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  // ===========================================================================
  // REMINDER CRUD & MODALS
  // ===========================================================================

  void _showAddReminderDialog([DateTime? initialDate]) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime pickedDate = initialDate ?? _selectedDate;
    TimeOfDay pickedTime = const TimeOfDay(hour: 9, minute: 0);
    String repeatFrequency = 'none';
    String notificationPref = 'at_time';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF0F3B82), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Add Reminder to Calendar',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title Field
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: 'Reminder Title (e.g. Semester Exam, Doctor Sync)',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F3B82), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Description / Notes Field
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: 'Notes or description (optional)',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F3B82), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date & Time Selectors
                  Row(
                    children: [
                      // Date Picker
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: pickedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                            );
                            if (picked != null) {
                              setModalState(() => pickedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF0F3B82)),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDateShort(pickedDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F1E36)),
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
                              initialTime: pickedTime,
                            );
                            if (picked != null) {
                              setModalState(() => pickedTime = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0F3B82)),
                                const SizedBox(width: 6),
                                Text(
                                  pickedTime.format(context),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F1E36)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Repeat Frequency Selector
                  Row(
                    children: [
                      const Text('Repeat: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(width: 4),
                      _buildChip('None', isSelected: repeatFrequency == 'none', onTap: () => setModalState(() => repeatFrequency = 'none')),
                      const SizedBox(width: 4),
                      _buildChip('Daily', isSelected: repeatFrequency == 'daily', onTap: () => setModalState(() => repeatFrequency = 'daily')),
                      const SizedBox(width: 4),
                      _buildChip('Weekly', isSelected: repeatFrequency == 'weekly', onTap: () => setModalState(() => repeatFrequency = 'weekly')),
                      const SizedBox(width: 4),
                      _buildChip('Monthly', isSelected: repeatFrequency == 'monthly', onTap: () => setModalState(() => repeatFrequency = 'monthly')),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Notification Preference Selector
                  Row(
                    children: [
                      const Text('Notify: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(width: 4),
                      _buildChip('At time', isSelected: notificationPref == 'at_time', onTap: () => setModalState(() => notificationPref = 'at_time')),
                      const SizedBox(width: 4),
                      _buildChip('15m before', isSelected: notificationPref == '15_min_before', onTap: () => setModalState(() => notificationPref = '15_min_before')),
                      const SizedBox(width: 4),
                      _buildChip('1h before', isSelected: notificationPref == '1_hour_before', onTap: () => setModalState(() => notificationPref = '1_hour_before')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;

                        final dateStr = '${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                        final timeStr = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                        final dueDateTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );

                        // Optimistic local add
                        final localItem = ReminderModel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          description: descController.text.trim(),
                          dueDate: pickedDate,
                          dueTime: timeStr,
                          dueDateTime: dueDateTime,
                          repeatFrequency: repeatFrequency,
                          notificationPreference: notificationPref,
                          calendarSync: true,
                        );

                        setState(() {
                          _reminders.insert(0, localItem);
                          _selectedDate = pickedDate;
                        });
                        Navigator.pop(ctx);

                        widget.onRemindersChanged?.call();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reminder "$title" added and synced!'),
                            backgroundColor: const Color(0xFF0F3B82),
                          ),
                        );

                        // Sync to backend
                        final serverRes = await ApiService.createReminder(
                          title: title,
                          description: localItem.description,
                          dueDate: dateStr,
                          dueTime: timeStr,
                          repeatFrequency: repeatFrequency,
                          notificationPreference: notificationPref,
                          calendarSync: true,
                        );

                        if (serverRes != null && serverRes['id'] != null) {
                          final idx = _reminders.indexWhere((r) => r.id == localItem.id);
                          if (idx != -1) {
                            setState(() {
                              _reminders[idx] = ReminderModel.fromJson(serverRes);
                            });
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3B82),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Save & Add to Calendar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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

  void _showReminderDetailsSheet(ReminderModel rem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: rem.isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    rem.isCompleted ? Icons.check_circle_rounded : Icons.alarm_rounded,
                    color: rem.isCompleted ? const Color(0xFF16A34A) : const Color(0xFF0F3B82),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rem.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F1E36),
                          decoration: rem.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        rem.isCompleted ? 'Completed' : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: rem.isCompleted ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            if (rem.description.isNotEmpty) ...[
              const Text('Notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text(
                rem.description,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 14),
            ],

            // Details rows
            _buildDetailRow(Icons.calendar_today_rounded, 'Date', _formatFullDate(rem.dueDate)),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.access_time_rounded, 'Time', rem.dueTime),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.repeat_rounded, 'Repeat', rem.formattedRepeat),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.notifications_active_rounded, 'Notification', rem.formattedNotification),

            const SizedBox(height: 24),

            // Action buttons: Complete / Edit / Delete
            Row(
              children: [
                // Toggle complete
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(rem.isCompleted ? Icons.replay_rounded : Icons.check_rounded, size: 18),
                    label: Text(rem.isCompleted ? 'Mark Pending' : 'Complete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F3B82),
                      side: const BorderSide(color: Color(0xFF0F3B82)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() {
                        rem.isCompleted = !rem.isCompleted;
                      });
                      widget.onRemindersChanged?.call();
                      await ApiService.toggleReminderComplete(rem.id);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Edit Button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                    label: const Text('Edit', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3B82),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditReminderDialog(rem);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Delete Button
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _reminders.removeWhere((r) => r.id == rem.id);
                    });
                    widget.onRemindersChanged?.call();
                    await ApiService.deleteReminder(rem.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reminder removed from Calendar')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935), size: 22),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditReminderDialog(ReminderModel rem) {
    final titleEditController = TextEditingController(text: rem.title);
    final descEditController = TextEditingController(text: rem.description);
    DateTime editDate = rem.dueDate;
    TimeOfDay editTime = const TimeOfDay(hour: 9, minute: 0);

    if (rem.dueTime.contains(':')) {
      final parts = rem.dueTime.split(':');
      final h = int.tryParse(parts[0]) ?? 9;
      final m = int.tryParse(parts[1]) ?? 0;
      editTime = TimeOfDay(hour: h, minute: m);
    }

    String editRepeat = rem.repeatFrequency;
    String editNotif = rem.notificationPreference;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Edit Reminder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleEditController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descEditController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes / Description',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: modalCtx,
                              initialDate: editDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 60)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                            );
                            if (picked != null) setModalState(() => editDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF0F3B82)),
                                const SizedBox(width: 6),
                                Text(_formatDateShort(editDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: modalCtx,
                              initialTime: editTime,
                            );
                            if (picked != null) setModalState(() => editTime = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0F3B82)),
                                const SizedBox(width: 6),
                                Text(editTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Repeat selector
                  Row(
                    children: [
                      const Text('Repeat: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      _buildChip('None', isSelected: editRepeat == 'none', onTap: () => setModalState(() => editRepeat = 'none')),
                      const SizedBox(width: 4),
                      _buildChip('Daily', isSelected: editRepeat == 'daily', onTap: () => setModalState(() => editRepeat = 'daily')),
                      const SizedBox(width: 4),
                      _buildChip('Weekly', isSelected: editRepeat == 'weekly', onTap: () => setModalState(() => editRepeat = 'weekly')),
                      const SizedBox(width: 4),
                      _buildChip('Monthly', isSelected: editRepeat == 'monthly', onTap: () => setModalState(() => editRepeat = 'monthly')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Notification selector
                  Row(
                    children: [
                      const Text('Notify: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      _buildChip('At time', isSelected: editNotif == 'at_time', onTap: () => setModalState(() => editNotif = 'at_time')),
                      const SizedBox(width: 4),
                      _buildChip('15m', isSelected: editNotif == '15_min_before', onTap: () => setModalState(() => editNotif = '15_min_before')),
                      const SizedBox(width: 4),
                      _buildChip('1h', isSelected: editNotif == '1_hour_before', onTap: () => setModalState(() => editNotif = '1_hour_before')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newTitle = titleEditController.text.trim();
                        if (newTitle.isEmpty) return;

                        final dateStr = '${editDate.year.toString().padLeft(4, '0')}-${editDate.month.toString().padLeft(2, '0')}-${editDate.day.toString().padLeft(2, '0')}';
                        final timeStr = '${editTime.hour.toString().padLeft(2, '0')}:${editTime.minute.toString().padLeft(2, '0')}';

                        setState(() {
                          rem.title = newTitle;
                          rem.description = descEditController.text.trim();
                          rem.dueDate = editDate;
                          rem.dueTime = timeStr;
                          rem.dueDateTime = DateTime(editDate.year, editDate.month, editDate.day, editTime.hour, editTime.minute);
                          rem.repeatFrequency = editRepeat;
                          rem.notificationPreference = editNotif;
                        });

                        Navigator.pop(modalCtx);
                        widget.onRemindersChanged?.call();

                        await ApiService.updateReminder(rem.id, {
                          'title': rem.title,
                          'description': rem.description,
                          'dueDate': dateStr,
                          'dueTime': timeStr,
                          'repeatFrequency': rem.repeatFrequency,
                          'notificationPreference': rem.notificationPreference,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3B82),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Update Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36))),
      ],
    );
  }

  Widget _buildChip(String label, {required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F3B82) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF0F3B82) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _showAddMeetingDialog() {
    final titleController = TextEditingController();
    DateTime pickedDate = _selectedDate;
    TimeOfDay pickedTime = const TimeOfDay(hour: 15, minute: 0);
    String selectedCategory = 'morning';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Schedule New Meeting',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Meeting Title (e.g. Design Sync)',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F3B82), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: pickedTime,
                          );
                          if (t != null) {
                            setDialogState(() => pickedTime = t);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF0F3B82)),
                              const SizedBox(width: 8),
                              Text(
                                pickedTime.format(context),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedCategory,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'morning', child: Text('Morning')),
                        DropdownMenuItem(value: 'afternoon', child: Text('Afternoon')),
                        DropdownMenuItem(value: 'night', child: Text('Night')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCategory = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;

                      final newEvent = ScheduledEventItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        time: pickedTime.format(context),
                        category: selectedCategory,
                        location: 'CONNEKT Meeting Room',
                        dotColor: const Color(0xFF0F3B82),
                        hasStar: true,
                        date: pickedDate,
                      );

                      setState(() {
                        _events.add(newEvent);
                      });

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Meeting "$title" scheduled!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3B82),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Confirm Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Add to Calendar',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF0F3B82), size: 22),
              ),
              title: const Text('New Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Add tasks or alerts with date, time & recurring options'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddReminderDialog(_selectedDate);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFF0FDF4), shape: BoxShape.circle),
                child: const Icon(Icons.videocam_rounded, color: Color(0xFF16A34A), size: 22),
              ),
              title: const Text('Schedule Meeting', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Plan video conference with room code & agenda'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddMeetingDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      body: SafeArea(
        child: Column(
          children: [
            // TOP HEADER BAR
            _buildTopHeader(),

            // MAIN CONTENT: Month Calendar + Day Agenda
            Expanded(
              child: _buildMonthCalendarView(),
            ),

            // BOTTOM FLOATING ACTION BAR (< , Join Meeting, +)
            _buildBottomFloatingBar(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. TOP HEADER
  // ===========================================================================

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Screen Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F1E36),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                _getMonthName(_currentMonth.month),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Right: Refresh & Close Button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.sync_rounded, color: Color(0xFF0F3B82), size: 22),
                tooltip: 'Sync reminders',
                onPressed: _loadReminders,
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. MONTH CALENDAR & AGENDA VIEW
  // ===========================================================================

  Widget _buildMonthCalendarView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigation arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF475569)),
                    onPressed: () => _changeMonth(-1),
                    tooltip: 'Previous Month',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569)),
                    onPressed: () => _changeMonth(1),
                    tooltip: 'Next Month',
                  ),
                ],
              ),
            ],
          ),

          // Days of week header: M T W T F S S
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeekdayLabel('M'),
              _WeekdayLabel('T'),
              _WeekdayLabel('W'),
              _WeekdayLabel('T'),
              _WeekdayLabel('F'),
              _WeekdayLabel('S'),
              _WeekdayLabel('S'),
            ],
          ),
          const SizedBox(height: 6),

          // Calendar Grid with Reminder & Meeting indicators
          _buildCalendarGrid(),

          const SizedBox(height: 16),

          // Weather & Scenic Landscape Card
          _buildWeatherLandscapeCard(),

          const SizedBox(height: 18),

          // DAY AGENDA SECTION (Synchronized Reminders & Scheduled Meetings)
          _buildDayAgendaSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = _currentMonth.weekday; // 1 = Mon, 7 = Sun
    final prevMonthDays = DateTime(_currentMonth.year, _currentMonth.month, 0).day;

    final List<Widget> dayWidgets = [];

    // Previous month filler days
    for (int i = firstWeekday - 1; i > 0; i--) {
      dayWidgets.add(
        _buildCalendarDayCell(
          dayNumber: prevMonthDays - i + 1,
          isCurrentMonth: false,
          date: DateTime(_currentMonth.year, _currentMonth.month - 1, prevMonthDays - i + 1),
        ),
      );
    }

    // Current month days
    for (int d = 1; d <= daysInMonth; d++) {
      final cellDate = DateTime(_currentMonth.year, _currentMonth.month, d);
      dayWidgets.add(
        _buildCalendarDayCell(
          dayNumber: d,
          isCurrentMonth: true,
          date: cellDate,
        ),
      );
    }

    // Remaining filler days to complete grid
    final totalCells = (dayWidgets.length / 7).ceil() * 7;
    int nextMonthDay = 1;
    while (dayWidgets.length < totalCells) {
      dayWidgets.add(
        _buildCalendarDayCell(
          dayNumber: nextMonthDay,
          isCurrentMonth: false,
          date: DateTime(_currentMonth.year, _currentMonth.month + 1, nextMonthDay),
        ),
      );
      nextMonthDay++;
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 0.95,
      children: dayWidgets,
    );
  }

  Widget _buildCalendarDayCell({
    required int dayNumber,
    required bool isCurrentMonth,
    required DateTime date,
  }) {
    final isSelected = isCurrentMonth &&
        _selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day;

    // Check for synchronized reminders on this date
    final dateReminders = isCurrentMonth
        ? _reminders.where((r) => r.matchesDate(date)).toList()
        : <ReminderModel>[];
    final hasReminders = dateReminders.isNotEmpty;

    // Check for meetings on this date
    final dateMeetings = isCurrentMonth
        ? _events.where((e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList()
        : <ScheduledEventItem>[];
    final hasMeetings = dateMeetings.isNotEmpty;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Date number container (black oval pill if selected)
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isCurrentMonth ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // Event & Reminder status indicators
          if (isCurrentMonth && !isSelected)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Synchronized Reminder indicator dot (Vibrant Purple / Indigo)
                if (hasReminders)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B5CF6),
                      shape: BoxShape.circle,
                    ),
                  ),

                // Meeting indicator dot (Ocean Blue)
                if (hasMeetings)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            )
          else
            const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _buildWeatherLandscapeCard() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/weather_landscape.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5B8C85), Color(0xFFD4A373)],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Selected Date',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_selectedDate.day} ${_getMonthName(_selectedDate.month)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFullDate(_selectedDate),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. DAY AGENDA SECTION (Synchronized Reminders + Meetings)
  // ===========================================================================

  Widget _buildDayAgendaSection() {
    final dayReminders = _reminders.where((r) => r.matchesDate(_selectedDate)).toList();
    final dayMeetings = _events.where((e) =>
        e.date.year == _selectedDate.year &&
        e.date.month == _selectedDate.month &&
        e.date.day == _selectedDate.day).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Day Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                ),
                Text(
                  '${dayReminders.length} Reminders • ${dayMeetings.length} Meetings',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                ),
              ],
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _showAddSelectionSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3B82),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // SUBSECTION A: Synchronized Reminders
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_turned_in_rounded, size: 16, color: Color(0xFF8B5CF6)),
                SizedBox(width: 6),
                Text(
                  'Reminders',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                ),
              ],
            ),
            InkWell(
              onTap: () => _showAddReminderDialog(_selectedDate),
              child: const Text(
                '+ New Reminder',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F3B82)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (dayReminders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'No reminders for this date.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                ),
                TextButton(
                  onPressed: () => _showAddReminderDialog(_selectedDate),
                  child: const Text('Add Reminder', style: TextStyle(color: Color(0xFF0F3B82), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          )
        else
          ...dayReminders.map((rem) => _buildReminderCard(rem)),

        const SizedBox(height: 18),

        // SUBSECTION B: Scheduled Meetings
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.videocam_rounded, size: 16, color: Color(0xFF0F3B82)),
                SizedBox(width: 6),
                Text(
                  'Scheduled Meetings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                ),
              ],
            ),
            InkWell(
              onTap: _showAddMeetingDialog,
              child: const Text(
                '+ New Meeting',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F3B82)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (dayMeetings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'No meetings on this day.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                ),
                TextButton(
                  onPressed: _showAddMeetingDialog,
                  child: const Text('Schedule Meeting', style: TextStyle(color: Color(0xFF0F3B82), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          )
        else
          ...dayMeetings.map((event) => _buildMeetingCard(event)),
      ],
    );
  }

  Widget _buildReminderCard(ReminderModel rem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: rem.isCompleted ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rem.isCompleted ? const Color(0xFFE2E8F0) : const Color(0xFFDDD6FE),
          width: 1,
        ),
        boxShadow: rem.isCompleted
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: InkWell(
          onTap: () async {
            setState(() {
              rem.isCompleted = !rem.isCompleted;
            });
            widget.onRemindersChanged?.call();
            await ApiService.toggleReminderComplete(rem.id);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              rem.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: rem.isCompleted ? const Color(0xFF22C55E) : const Color(0xFF8B5CF6),
              size: 22,
            ),
          ),
        ),
        title: Text(
          rem.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: rem.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
            decoration: rem.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rem.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                rem.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 11, color: rem.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F3B82)),
                const SizedBox(width: 4),
                Text(
                  rem.dueTime,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: rem.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F3B82),
                  ),
                ),
                if (rem.repeatFrequency != 'none') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      rem.formattedRepeat,
                      style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        onTap: () => _showReminderDetailsSheet(rem),
      ),
    );
  }

  Widget _buildMeetingCard(ScheduledEventItem event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: event.dotColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F1E36)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.time} • ${event.location}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (event.hasStar)
            const Icon(Icons.star_rounded, size: 18, color: Color(0xFFEAB308)),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. BOTTOM FLOATING ACTION BAR (< , Join Meeting, +)
  // ===========================================================================

  Widget _buildBottomFloatingBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 14, top: 6),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Action Button: Back/Dismiss (<)
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_left_rounded, size: 22, color: Color(0xFF0F3B82)),
              ),
            ),

            const SizedBox(width: 8),

            // Middle Action: Join Meeting
            Expanded(
              child: InkWell(
                onTap: () {
                  widget.onOpenMeetings?.call();
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F3B82), Color(0xFF1E40AF)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Join Meeting',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Right Action Button: Add (+) Button -> Opens Schedule or Add Modal
            InkWell(
              onTap: _showAddSelectionSheet,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F3B82),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
