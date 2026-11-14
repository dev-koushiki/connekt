import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/safe_avatar.dart';
import 'chat_screen.dart';

class WhatsAppLockedScreen extends StatefulWidget {
  final List<Map<String, dynamic>> lockedChats;
  final ValueChanged<Map<String, dynamic>> onUnlockChat;

  const WhatsAppLockedScreen({
    super.key,
    required this.lockedChats,
    required this.onUnlockChat,
  });

  @override
  State<WhatsAppLockedScreen> createState() => _WhatsAppLockedScreenState();
}

class _WhatsAppLockedScreenState extends State<WhatsAppLockedScreen> {
  bool _isAuthenticated = false;
  final TextEditingController _pinController = TextEditingController();
  late List<Map<String, dynamic>> _list;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.lockedChats);
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verifyPin(String pin) {
    if (pin == '1234' || pin == '0000') {
      setState(() {
        _isAuthenticated = true;
        _errorText = '';
      });
    } else {
      setState(() {
        _errorText = 'Incorrect PIN. Try 1234 or use fingerprint';
      });
    }
  }

  void _simulateBiometric() {
    setState(() {
      _isAuthenticated = true;
      _errorText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.getBackgroundColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    if (!_isAuthenticated) {
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
            'Locked Chats',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_rounded, size: 40, color: Color(0xFF1D4ED8)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Chat Lock',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep these chats secret and locked behind your PIN or biometric sensor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                ),
                const SizedBox(height: 28),

                // PIN Input
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      hintStyle: const TextStyle(color: AppTheme.textMuted, letterSpacing: 8),
                      filled: true,
                      fillColor: AppTheme.getInputColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _verifyPin,
                  ),
                ),

                if (_errorText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_errorText, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                ],

                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 18),
                  label: const Text('Unlock with PIN (1234)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _verifyPin(_pinController.text),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.fingerprint, color: Color(0xFF1D4ED8), size: 24),
                  label: const Text('Use Biometric Authentication', style: TextStyle(color: Color(0xFF1D4ED8))),
                  onPressed: _simulateBiometric,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Authenticated view
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
          'Locked Chats',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 54, color: textSecondary.withValues(alpha: 0.3)),
                  const SizedBox(height: 14),
                  Text('No locked chats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                  const SizedBox(height: 6),
                  Text('Long-press any chat on the home tab to lock it', style: TextStyle(fontSize: 13, color: textSecondary)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final chat = _list[index];
                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: SafeAvatar(
                      url: chat['avatar'] is String ? chat['avatar'] : null,
                      fallbackText: (chat['name'] ?? '').toString(),
                      size: 44,
                      radius: 22,
                    ),
                    title: Row(
                      children: [
                        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 6),
                        Text(
                          chat['name'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      chat['lastMessage'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.lock_open_rounded, color: textSecondary),
                      tooltip: 'Unlock chat',
                      onPressed: () {
                        widget.onUnlockChat(chat);
                        setState(() {
                          _list.removeAt(index);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${chat['name']} unlocked and returned to chats'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversationId: chat['id']?.toString(),
                            contactName: (chat['name'] ?? chat['target'] ?? '').toString(),
                            contactPhone: (chat['target'] ?? chat['phone'] ?? '').toString(),
                            avatarUrl: (chat['avatar'] ?? '').toString(),
                            showBackButton: true,
                            isGroup: chat['isGroup'] == true,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
