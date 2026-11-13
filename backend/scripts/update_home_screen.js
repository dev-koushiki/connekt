const fs = require('fs');
const path = './connekt/lib/screens/home_screen.dart';

let content = fs.readFileSync(path, 'utf8');
const lines = content.split('\n');

const startIdx = lines.findIndex(l => l.includes('void _showRemindersSheet(BuildContext context) {'));
const endIdx = lines.findIndex(l => l.includes('void _showQuickNotesSheet(BuildContext context) {'));

if (startIdx === -1 || endIdx === -1) {
  console.error('Could not find start or end index');
  process.exit(1);
}

const newCode = `  void _showRemindersSheet(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    String repeatFrequency = 'none'; // 'none', 'daily', 'weekly', 'monthly'
    String notificationPref = 'at_time'; // 'at_time', '15_min_before', '1_hour_before', '1_day_before'
    bool showMoreOptions = false;

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
                            'Reminders & Calendar',
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
                          '$activeCount active',
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
                          'No reminders yet! Add one below to sync with Calendar.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.32,
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
                                  onTap: () async {
                                    setSheetState(() => rem.isCompleted = !rem.isCompleted);
                                    setState(() {});
                                    _saveReminders();
                                    await ApiService.toggleReminderComplete(rem.id);
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

                                // Title & Details
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
                                      if (rem.description.isNotEmpty) ...[
                                        const SizedBox(height: 1),
                                        Text(
                                          rem.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 3),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 2,
                                        children: [
                                          // Date & Time badge
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.schedule_rounded,
                                                size: 11,
                                                color: isOverdue ? const Color(0xFFE53935) : const Color(0xFF0F3B82),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '\${_formatDateOnly(rem.dueDate)} • \${rem.dueTime}',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: isOverdue ? const Color(0xFFE53935) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Repeat badge
                                          if (rem.repeatFrequency != 'none')
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFBFDBFE), width: 0.5),
                                              ),
                                              child: Text(
                                                rem.formattedRepeat,
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1D4ED8),
                                                ),
                                              ),
                                            ),
                                          // Notification badge
                                          if (rem.notificationPreference != 'at_time')
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3E8FF),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFDDD6FE), width: 0.5),
                                              ),
                                              child: Text(
                                                rem.formattedNotification,
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF7C3AED),
                                                ),
                                              ),
                                            ),
                                          if (isOverdue)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEE2E2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Overdue',
                                                style: TextStyle(
                                                  color: Color(0xFFE53935),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Edit button
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF64748B)),
                                  tooltip: 'Edit reminder',
                                  onPressed: () {
                                    _showEditReminderModal(context, rem, () {
                                      setSheetState(() {});
                                      setState(() {});
                                    });
                                  },
                                ),

                                // Delete button
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 17, color: Color(0xFF94A3B8)),
                                  tooltip: 'Delete reminder',
                                  onPressed: () async {
                                    final toDeleteId = rem.id;
                                    setSheetState(() => _reminders.removeAt(idx));
                                    setState(() {});
                                    _saveReminders();
                                    await ApiService.deleteReminder(toDeleteId);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  const Text(
                    'Add New Reminder',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                  ),
                  const SizedBox(height: 8),

                  // Title Input
                  TextField(
                    controller: titleController,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: 'Reminder Title (e.g. Doctor appointment, VC call)',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F3B82), width: 1.5)),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Optional Notes/Description
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: 'Notes or description (optional)',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F3B82), width: 1.5)),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Date and Time Pickers
                  Row(
                    children: [
                      // Date Picker
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: now.subtract(const Duration(days: 30)),
                              lastDate: now.add(const Duration(days: 365 * 3)),
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
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFF0F3B82)),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    _formatDateOnly(selectedDate),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F3B82)),
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
                              initialTime: selectedTime,
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
                              children: [
                                const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF0F3B82)),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    _formatTimeOnly(selectedTime),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F3B82)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Repeat Frequency Selector
                  Row(
                    children: [
                      const Text(
                        'Repeat: ',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('None', isSelected: repeatFrequency == 'none', onTap: () => setSheetState(() => repeatFrequency = 'none')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('Daily', isSelected: repeatFrequency == 'daily', onTap: () => setSheetState(() => repeatFrequency = 'daily')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('Weekly', isSelected: repeatFrequency == 'weekly', onTap: () => setSheetState(() => repeatFrequency = 'weekly')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('Monthly', isSelected: repeatFrequency == 'monthly', onTap: () => setSheetState(() => repeatFrequency = 'monthly')),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Notification Preference Selector
                  Row(
                    children: [
                      const Text(
                        'Notify: ',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('At time', isSelected: notificationPref == 'at_time', onTap: () => setSheetState(() => notificationPref = 'at_time')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('15m before', isSelected: notificationPref == '15_min_before', onTap: () => setSheetState(() => notificationPref = '15_min_before')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('1h before', isSelected: notificationPref == '1_hour_before', onTap: () => setSheetState(() => notificationPref = '1_hour_before')),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Add Reminder Button (Saves to backend + local list + syncs with Calendar)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 18),
                      label: const Text('Save & Sync with Calendar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;

                        final dateStr = '\${selectedDate.year.toString().padLeft(4, '0')}-\${selectedDate.month.toString().padLeft(2, '0')}-\${selectedDate.day.toString().padLeft(2, '0')}';
                        final timeStr = '\${selectedTime.hour.toString().padLeft(2, '0')}:\${selectedTime.minute.toString().padLeft(2, '0')}';
                        final dueDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        // Optimistic local update
                        final localItem = ReminderModel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          description: descController.text.trim(),
                          dueDate: selectedDate,
                          dueTime: timeStr,
                          dueDateTime: dueDateTime,
                          repeatFrequency: repeatFrequency,
                          notificationPreference: notificationPref,
                          calendarSync: true,
                        );

                        setSheetState(() {
                          _reminders.insert(0, localItem);
                        });
                        setState(() {});
                        _saveReminders();

                        titleController.clear();
                        descController.clear();

                        // Call Backend API
                        final serverCreated = await ApiService.createReminder(
                          title: title,
                          description: localItem.description,
                          dueDate: dateStr,
                          dueTime: timeStr,
                          repeatFrequency: repeatFrequency,
                          notificationPreference: notificationPref,
                          calendarSync: true,
                        );

                        if (serverCreated != null && serverCreated['id'] != null) {
                          final serverItem = ReminderModel.fromJson(serverCreated);
                          final idx = _reminders.indexWhere((r) => r.id == localItem.id);
                          if (idx != -1) {
                            _reminders[idx] = serverItem;
                            _saveReminders();
                            setState(() {});
                          }
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Reminder "\$title" synced with Calendar!'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: const Color(0xFF0F3B82),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3B82),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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

  Widget _buildMiniSelectChip(String label, {required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F3B82) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F3B82) : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _showEditReminderModal(BuildContext context, ReminderModel rem, VoidCallback onUpdated) {
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
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Edit Reminder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                  ),
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
                            if (picked != null) {
                              setModalState(() => editDate = picked);
                            }
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
                                Text(_formatDateOnly(editDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                            if (picked != null) {
                              setModalState(() => editTime = picked);
                            }
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
                                Text(_formatTimeOnly(editTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                      _buildMiniSelectChip('None', isSelected: editRepeat == 'none', onTap: () => setModalState(() => editRepeat = 'none')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('Daily', isSelected: editRepeat == 'daily', onTap: () => setModalState(() => editRepeat = 'daily')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('Weekly', isSelected: editRepeat == 'weekly', onTap: () => setModalState(() => editRepeat = 'weekly')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('Monthly', isSelected: editRepeat == 'monthly', onTap: () => setModalState(() => editRepeat = 'monthly')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Notification selector
                  Row(
                    children: [
                      const Text('Notify: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      _buildMiniSelectChip('At time', isSelected: editNotif == 'at_time', onTap: () => setModalState(() => editNotif = 'at_time')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('15m', isSelected: editNotif == '15_min_before', onTap: () => setModalState(() => editNotif = '15_min_before')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('1h', isSelected: editNotif == '1_hour_before', onTap: () => setModalState(() => editNotif = '1_hour_before')),
                      const SizedBox(width: 4),
                      _buildMiniSelectChip('1d', isSelected: editNotif == '1_day_before', onTap: () => setModalState(() => editNotif = '1_day_before')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newTitle = titleEditController.text.trim();
                        if (newTitle.isEmpty) return;

                        final dateStr = '\${editDate.year.toString().padLeft(4, '0')}-\${editDate.month.toString().padLeft(2, '0')}-\${editDate.day.toString().padLeft(2, '0')}';
                        final timeStr = '\${editTime.hour.toString().padLeft(2, '0')}:\${editTime.minute.toString().padLeft(2, '0')}';

                        rem.title = newTitle;
                        rem.description = descEditController.text.trim();
                        rem.dueDate = editDate;
                        rem.dueTime = timeStr;
                        rem.dueDateTime = DateTime(editDate.year, editDate.month, editDate.day, editTime.hour, editTime.minute);
                        rem.repeatFrequency = editRepeat;
                        rem.notificationPreference = editNotif;

                        _saveReminders();
                        onUpdated();
                        Navigator.pop(modalCtx);

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
`;

lines.splice(startIdx, endIdx - startIdx, newCode);
fs.writeFileSync(path, lines.join('\n'), 'utf8');
console.log('Successfully updated _showRemindersSheet in home_screen.dart');
