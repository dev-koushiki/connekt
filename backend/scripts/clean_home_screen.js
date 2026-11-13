const fs = require('fs');
const file = './connekt/lib/screens/home_screen.dart';
let content = fs.readFileSync(file, 'utf8');

content = content.replace(/\s*bool showMoreOptions = false;\r?\n/, '\n');

const regexFormat = /String _formatReminderDateTime\(DateTime dt\) \{[\s\S]*?return '\$datePart • \$hour12:\$minute \$ampm';\r?\n\s*\}/;
content = content.replace(regexFormat, '');

const regexChip = /Widget _buildQuickDateChip\(String label, \{required bool isSelected, required VoidCallback onTap\}\) \{[\s\S]*?return InkWell\([\s\S]*?\r?\n\s*\}\r?\n\s*\}/;
content = content.replace(regexChip, '');

fs.writeFileSync(file, content, 'utf8');
console.log('Cleaned unused elements in home_screen.dart');
