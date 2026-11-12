import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class WhatsAppLinkedDevicesScreen extends StatefulWidget {
  const WhatsAppLinkedDevicesScreen({super.key});

  @override
  State<WhatsAppLinkedDevicesScreen> createState() => _WhatsAppLinkedDevicesScreenState();
}

class _WhatsAppLinkedDevicesScreenState extends State<WhatsAppLinkedDevicesScreen> {
  final List<Map<String, dynamic>> _devices = [
    {
      'id': 'dev_1',
      'browser': 'Google Chrome (Windows)',
      'status': 'Active',
      'lastActive': 'Active right now',
      'icon': Icons.desktop_windows_rounded,
    },
    {
      'id': 'dev_2',
      'browser': 'Safari (macOS)',
      'status': 'Inactive',
      'lastActive': 'Last active yesterday at 9:42 pm',
      'icon': Icons.laptop_mac_rounded,
    },
  ];

  void _showScanQrSheet() {
    showModalBottomSheet(
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
            Text(
              'Link a Device',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open web.connekt.me on your computer and point your camera to scan the QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            // Simulated QR Scanner Viewfinder
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981), width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, size: 100, color: Color(0xFF10B981)),
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Scanning for QR code...',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Simulate Successful Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _devices.add({
                    'id': 'dev_${DateTime.now().millisecondsSinceEpoch}',
                    'browser': 'Firefox (Linux)',
                    'status': 'Active',
                    'lastActive': 'Active right now',
                    'icon': Icons.computer_rounded,
                  });
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device successfully linked!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _logoutDevice(int index) {
    final dev = _devices[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text('Log out from ${dev['browser']}?'),
        content: const Text('Are you sure you want to log out from this session?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCoral),
            child: const Text('Log out', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _devices.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Logged out from ${dev['browser']}')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.getBackgroundColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Linked Devices',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Illustration & Link Device CTA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              color: cardColor,
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.devices_rounded, size: 36, color: Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Use Connekt on Web, Desktop, & other devices',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sync messages across all your screens in real time with end-to-end security.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'Link a Device',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _showScanQrSheet,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Device Status Heading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'DEVICE STATUS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: textSecondary,
                ),
              ),
            ),

            // Devices List
            if (_devices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No active devices linked', style: TextStyle(color: textSecondary)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _devices[index];
                  final bool isActive = item['status'] == 'Active';

                  return Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.getInputColor(context),
                        child: Icon(item['icon'] as IconData, color: const Color(0xFF10B981)),
                      ),
                      title: Text(
                        item['browser'],
                        style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 14),
                      ),
                      subtitle: Text(
                        item['lastActive'],
                        style: TextStyle(
                          color: isActive ? const Color(0xFF10B981) : textSecondary,
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout_rounded, color: AppTheme.textMuted, size: 20),
                        tooltip: 'Log out',
                        onPressed: () => _logoutDevice(index),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 28),
            // Privacy notice
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Your personal messages are end-to-end encrypted',
                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
