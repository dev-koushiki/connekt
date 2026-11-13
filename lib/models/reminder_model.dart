class ReminderModel {
  final String id;
  String title;
  String description;
  DateTime dueDate;
  String dueTime; // '09:00'
  DateTime? dueDateTime;
  String repeatFrequency; // 'none', 'daily', 'weekly', 'monthly'
  String notificationPreference; // 'at_time', '15_min_before', '1_hour_before', '1_day_before'
  bool isCompleted;
  bool calendarSync;
  DateTime? createdAt;
  DateTime? updatedAt;

  ReminderModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.dueTime = '09:00',
    this.dueDateTime,
    this.repeatFrequency = 'none',
    this.notificationPreference = 'at_time',
    this.isCompleted = false,
    this.calendarSync = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['due_date'] != null) {
      parsedDate = DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now();
    } else if (json['dueDate'] != null) {
      parsedDate = DateTime.tryParse(json['dueDate'].toString()) ?? DateTime.now();
    } else if (json['dueDateTime'] != null) {
      parsedDate = DateTime.tryParse(json['dueDateTime'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? parsedDueDateTime;
    if (json['due_datetime'] != null) {
      parsedDueDateTime = DateTime.tryParse(json['due_datetime'].toString());
    } else if (json['dueDateTime'] != null) {
      parsedDueDateTime = DateTime.tryParse(json['dueDateTime'].toString());
    }

    return ReminderModel(
      id: (json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      dueDate: parsedDate,
      dueTime: (json['due_time'] ?? json['dueTime'] ?? '09:00').toString(),
      dueDateTime: parsedDueDateTime,
      repeatFrequency: (json['repeat_frequency'] ?? json['repeatFrequency'] ?? 'none').toString(),
      notificationPreference: (json['notification_preference'] ?? json['notificationPreference'] ?? 'at_time').toString(),
      isCompleted: json['is_completed'] == true || json['isCompleted'] == true,
      calendarSync: json['calendar_sync'] != false && json['calendarSync'] != false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
      'due_time': dueTime,
      'due_datetime': dueDateTime?.toIso8601String(),
      'repeat_frequency': repeatFrequency,
      'notification_preference': notificationPreference,
      'is_completed': isCompleted,
      'calendar_sync': calendarSync,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Check whether this reminder should be shown on a particular date.
  /// Handles recurring reminders without duplicate database records.
  bool matchesDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (d.isBefore(start)) return false;

    final freq = repeatFrequency.toLowerCase();
    if (freq == 'daily') {
      return true;
    } else if (freq == 'weekly') {
      return d.weekday == start.weekday;
    } else if (freq == 'monthly') {
      return d.day == start.day;
    } else {
      // One-time reminder
      return d.year == start.year && d.month == start.month && d.day == start.day;
    }
  }

  String get formattedRepeat {
    switch (repeatFrequency.toLowerCase()) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return 'One-time';
    }
  }

  String get formattedNotification {
    switch (notificationPreference.toLowerCase()) {
      case '15_min_before':
        return '15 min before';
      case '1_hour_before':
        return '1 hour before';
      case '1_day_before':
        return '1 day before';
      default:
        return 'At time';
    }
  }
}
