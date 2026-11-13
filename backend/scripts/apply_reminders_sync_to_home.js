const fs = require('fs');
const file = './connekt/lib/screens/home_screen.dart';
let content = fs.readFileSync(file, 'utf8');

// 1. Domain standardization in _connektEmail and inviteFriends
content = content.replace(/@connect\.net\.in/g, '@connekt.net.in');
content = content.replace(/https:\/\/connekt\.me\/join/g, 'https://connekt.net.in/join');

// 2. Import reminder_model.dart & replace ReminderItem with ReminderModel
const oldReminderItemRegex = /class ReminderItem\s*\{[\s\S]*?factory ReminderItem\.fromJson[\s\S]*?\};\s*\}/;
content = content.replace(
  oldReminderItemRegex,
  "typedef ReminderItem = ReminderModel;"
);
if (!content.includes("import '../models/reminder_model.dart';")) {
  content = content.replace(
    "import 'calendar_scheduler_screen.dart';",
    "import '../models/reminder_model.dart';\nimport 'calendar_scheduler_screen.dart';"
  );
}

// 3. Update reminders loading in _loadStoredData
const oldRemindersLoad = `        if (remindersRaw != null && remindersRaw.isNotEmpty) {
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
      });`;

const newRemindersLoad = `        if (remindersRaw != null && remindersRaw.isNotEmpty) {
          _reminders = remindersRaw.map((s) {
            try {
              return ReminderModel.fromJson(jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return ReminderModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: s,
                dueDate: DateTime.now(),
              );
            }
          }).toList();
        } else {
          _reminders = [
            ReminderModel(
              id: '1',
              title: 'Review CONNEKT Architecture & Sync with Team',
              dueDate: DateTime.now(),
              dueDateTime: DateTime.now().add(const Duration(hours: 3)),
            ),
          ];
        }
      });
      _fetchRemindersFromServer();`;

content = content.replace(oldRemindersLoad.replace(/\r\n/g, '\n'), newRemindersLoad);

// 4. Add _fetchRemindersFromServer right before _saveReminders
const oldSaveReminders = `  Future<void> _saveReminders() async {`;
const newSaveReminders = `  Future<void> _fetchRemindersFromServer() async {
    try {
      final serverReminders = await ApiService.getReminders();
      if (serverReminders.isNotEmpty && mounted) {
        setState(() {
          _reminders = serverReminders.map((m) => ReminderModel.fromJson(m)).toList();
        });
        _saveReminders();
      }
    } catch (_) {}
  }

  Future<void> _saveReminders() async {`;

content = content.replace(oldSaveReminders, newSaveReminders);

// 5. Update _buildSchedulerCard to pass onRemindersChanged and refresh on return
const oldSchedulerNav = `builder: (ctx) => CalendarSchedulerScreen(
              user: widget.user,
              onOpenMeetings: () {
                widget.onNavigateToTab?.call(1);
              },
            ),
          ),
        );`;

const newSchedulerNav = `builder: (ctx) => CalendarSchedulerScreen(
              user: widget.user,
              onOpenMeetings: () {
                widget.onNavigateToTab?.call(1);
              },
              onRemindersChanged: () {
                _fetchRemindersFromServer();
              },
            ),
          ),
        ).then((_) {
          _fetchRemindersFromServer();
        });`;

content = content.replace(oldSchedulerNav.replace(/\r\n/g, '\n'), newSchedulerNav);

fs.writeFileSync(file, content, 'utf8');
console.log('Phase 1 of home_screen.dart updates applied');
