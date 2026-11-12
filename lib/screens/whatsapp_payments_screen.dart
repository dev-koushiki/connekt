import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class WhatsAppPaymentsScreen extends StatefulWidget {
  const WhatsAppPaymentsScreen({super.key});

  @override
  State<WhatsAppPaymentsScreen> createState() => _WhatsAppPaymentsScreenState();
}

class _WhatsAppPaymentsScreenState extends State<WhatsAppPaymentsScreen> {
  final List<Map<String, dynamic>> _history = [
    {
      'name': 'Lena Rivers',
      'amount': '\$24.50',
      'type': 'Sent',
      'time': 'Yesterday, 3:45 pm',
      'status': 'Completed',
    },
    {
      'name': 'David Kim',
      'amount': '\$60.00',
      'type': 'Received',
      'time': 'Oct 22, 10:15 am',
      'status': 'Completed',
    },
  ];

  void _showSendMoneySheet() {
    final toController = TextEditingController();
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Payment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: toController,
              decoration: const InputDecoration(
                hintText: 'Enter contact name or UPI ID / Phone...',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'Amount (\$ or ₹)...',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Send Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final to = toController.text.trim();
                  final amount = amountController.text.trim();
                  if (to.isEmpty || amount.isEmpty) return;
                  Navigator.pop(ctx);
                  setState(() {
                    _history.insert(0, {
                      'name': to,
                      'amount': '\$$amount',
                      'type': 'Sent',
                      'time': 'Just now',
                      'status': 'Completed',
                    });
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sent \$$amount to $to successfully!'),
                      backgroundColor: const Color(0xFF10B981),
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
          'Payments',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Connekt Pay Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Icon(Icons.contactless_rounded, color: Colors.white, size: 24),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '\$1,420.50',
                      style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F766E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Send Money', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _showSendMoneySheet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.qr_code_scanner, size: 16),
                            label: const Text('Scan QR', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Opening UPI QR camera scanner...')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Payment Methods
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                'PAYMENT METHODS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.8),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: ListTile(
                leading: const Icon(Icons.account_balance_rounded, color: Color(0xFF10B981)),
                title: Text('HDFC Bank •••• 4092', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('Default payment account', style: TextStyle(color: textSecondary, fontSize: 12)),
                trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
              ),
            ),

            const SizedBox(height: 16),

            // Payment History
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                'HISTORY',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.8),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _history[index];
                final isSent = item['type'] == 'Sent';

                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSent
                          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                          : const Color(0xFF10B981).withValues(alpha: 0.12),
                      child: Icon(
                        isSent ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                        color: isSent ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item['name'],
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(item['time'], style: TextStyle(color: textSecondary, fontSize: 12)),
                    trailing: Text(
                      '${isSent ? '-' : '+'}${item['amount']}',
                      style: TextStyle(
                        color: isSent ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
