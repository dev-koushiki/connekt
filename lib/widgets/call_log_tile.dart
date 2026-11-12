import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'safe_avatar.dart';

/// Filter chip bar for call history views ('All', 'Incoming', 'Outgoing', 'Missed').
class CallLogFilterBar extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onSelected;
  final Color activeColor;
  final bool isDark;

  static const List<String> filters = ['All', 'Incoming', 'Outgoing', 'Missed'];

  const CallLogFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onSelected,
    this.activeColor = AppTheme.brandBlue,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveBg = isDark ? const Color(0xFF171B26) : const Color(0xFFF1F5F9);
    final inactiveBorder = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final inactiveText = isDark ? AppTheme.textSecondary : const Color(0xFF475569);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: filters.map((filter) {
        final isSelected = selectedFilter == filter;
        return ChoiceChip(
          label: Text(
            filter,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : inactiveText,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => onSelected(filter),
          selectedColor: activeColor,
          backgroundColor: inactiveBg,
          side: BorderSide(color: isSelected ? activeColor : inactiveBorder),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}

/// Filter normalized call logs by display category ('All', 'Incoming', 'Outgoing', 'Missed').
List<Map<String, dynamic>> filterCallLogs(List<Map<String, dynamic>> logs, String filter) {
  final normalizedFilter = filter.toLowerCase();
  if (normalizedFilter == 'all') return logs;
  return logs.where((call) {
    final type = (call['type'] ?? '').toString().toLowerCase();
    if (normalizedFilter == 'missed') {
      return type.contains('missed') || type.contains('rejected') || call['isMissed'] == true;
    }
    return type.contains(normalizedFilter);
  }).toList();
}

/// Reusable card rendering a synced device or in-app call log entry.
class CallLogTile extends StatelessWidget {
  final Map<String, dynamic> call;
  final Color cardColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color actionColor;
  final VoidCallback onCallTap;

  const CallLogTile({
    super.key,
    required this.call,
    required this.cardColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    this.actionColor = const Color(0xFF10B981),
    required this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    final String name = (call['name'] ?? call['number'] ?? 'Unknown Caller').toString();
    final String number = (call['number'] ?? call['email'] ?? '').toString();
    final String rawType = (call['type'] ?? 'incoming').toString().toLowerCase();
    final bool isVideo = call['isVideo'] == true;
    final bool isRejected = rawType.contains('rejected');
    final bool isMissed = call['isMissed'] == true || rawType.contains('missed') || isRejected;
    final bool isIncoming = rawType.contains('incoming');
    final String formattedTime = (call['formattedTime'] ?? call['time'] ?? 'Recent').toString();
    final String formattedDuration = (call['formattedDuration'] ?? '').toString();
    final int duration = int.tryParse((call['duration'] ?? '0').toString()) ?? 0;

    final String typeLabel = isRejected
        ? 'Rejected'
        : isMissed
            ? 'Missed'
            : isIncoming
                ? 'Incoming'
                : rawType.contains('outgoing')
                    ? 'Outgoing'
                    : (rawType.isNotEmpty ? '${rawType[0].toUpperCase()}${rawType.substring(1)}' : 'Call');

    final IconData directionIcon = isRejected
        ? Icons.block_rounded
        : isMissed
            ? Icons.call_missed_rounded
            : isIncoming
                ? Icons.call_received_rounded
                : Icons.call_made_rounded;

    final Color statusColor = isMissed ? const Color(0xFFEF4444) : actionColor;
    final String? avatarUrl = call['avatar'] is String && (call['avatar'] as String).isNotEmpty
        ? call['avatar'] as String
        : null;
    final String detailsLine = duration > 0 && formattedDuration.isNotEmpty
        ? '$typeLabel • $formattedDuration • $formattedTime'
        : '$typeLabel • $formattedTime';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
          leading: SafeAvatar(
            url: avatarUrl,
            fallbackText: name,
            size: 44,
            radius: 22,
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(directionIcon, size: 14, color: statusColor),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      detailsLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMissed ? statusColor : textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (number.isNotEmpty && number != name)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 11),
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
              color: actionColor,
            ),
            tooltip: 'Call $name',
            onPressed: onCallTap,
          ),
        ),
      ),
    );
  }
}
