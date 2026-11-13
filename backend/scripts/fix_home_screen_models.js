const fs = require('fs');
const file = './connekt/lib/screens/home_screen.dart';
let content = fs.readFileSync(file, 'utf8');

const lines = content.split(/\r?\n/);

// Replace lines 11 to 37 (the old class ReminderItem)
const classStart = lines.findIndex(l => l.startsWith('class ReminderItem {'));
const classEnd = lines.findIndex((l, i) => i > classStart && l.startsWith('class QuickNoteItem {'));

if (classStart !== -1 && classEnd !== -1) {
  lines.splice(classStart, classEnd - classStart, 'typedef ReminderItem = ReminderModel;\n');
  console.log('Replaced class ReminderItem with typedef ReminderItem = ReminderModel');
}

// In _loadStoredData, add dueDate to fallbacks and call _fetchRemindersFromServer
let newContent = lines.join('\n');

newContent = newContent.replace(
  `              return ReminderItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: s,
              );`,
  `              return ReminderItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: s,
                dueDate: DateTime.now(),
              );`
);

newContent = newContent.replace(
  `            ReminderItem(
              id: '1',
              title: 'Review CONNEKT Architecture & Sync with Team',
              dueDateTime: DateTime.now().add(const Duration(hours: 3)),
            ),`,
  `            ReminderItem(
              id: '1',
              title: 'Review CONNEKT Architecture & Sync with Team',
              dueDate: DateTime.now(),
              dueDateTime: DateTime.now().add(const Duration(hours: 3)),
            ),`
);

newContent = newContent.replace(
  `        }
      });
    } catch (_) {}`,
  `        }
      });
      _fetchRemindersFromServer();
    } catch (_) {}`
);

// Remove unused _formatReminderDateTime
const splitLines = newContent.split('\n');
const fmtStart = splitLines.findIndex(l => l.includes('String _formatReminderDateTime(DateTime dt) {'));
if (fmtStart !== -1) {
  const fmtEnd = splitLines.findIndex((l, i) => i > fmtStart && l.trim() === '}');
  if (fmtEnd !== -1) {
    splitLines.splice(fmtStart, fmtEnd - fmtStart + 1);
    console.log('Removed _formatReminderDateTime');
  }
}

// Remove unused _buildQuickDateChip
const chipStart = splitLines.findIndex(l => l.includes('Widget _buildQuickDateChip('));
if (chipStart !== -1) {
  const chipEnd = splitLines.findIndex((l, i) => i > chipStart && l.trim() === '}');
  if (chipEnd !== -1) {
    splitLines.splice(chipStart, chipEnd - chipStart + 1);
    console.log('Removed _buildQuickDateChip');
  }
}

fs.writeFileSync(file, splitLines.join('\n'), 'utf8');
console.log('fix_home_screen_models.js completed');
