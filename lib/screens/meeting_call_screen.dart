import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class MeetingCallScreen extends StatefulWidget {
  final String contactName;
  final String contactEmail;
  final String avatarUrl;
  final bool isVideoCall;

  const MeetingCallScreen({
    super.key,
    required this.contactName,
    this.contactEmail = '',
    this.avatarUrl = '',
    this.isVideoCall = true,
  });

  @override
  State<MeetingCallScreen> createState() => _MeetingCallScreenState();
}

class _MeetingCallScreenState extends State<MeetingCallScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  int _secondsElapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _isVideoOff = !widget.isVideoCall;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedDuration {
    final mins = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D18),
      body: SafeArea(
        child: Stack(
          children: [
            // Video / Avatar Area
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentBlue.withOpacity(0.5),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentBlue.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: widget.avatarUrl.isNotEmpty
                          ? Image.network(
                              widget.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                            )
                          : _buildAvatarFallback(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.contactName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (widget.contactEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.contactEmail,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Top bar
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.isVideoCall ? Icons.videocam : Icons.phone,
                          color: AppTheme.accentBlue,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isVideoCall ? 'CONNEKT Video Call' : 'CONNEKT Audio Call',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white70, size: 22),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Switched camera source'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom In-Call Controls Bar
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute
                    _buildControlBtn(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      isActive: _isMuted,
                      activeColor: AppTheme.accentCoral,
                      onTap: () => setState(() => _isMuted = !_isMuted),
                    ),
                    // Video toggle
                    _buildControlBtn(
                      icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                      isActive: _isVideoOff,
                      activeColor: AppTheme.accentCoral,
                      onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                    ),
                    // Speaker
                    _buildControlBtn(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      isActive: _isSpeakerOn,
                      activeColor: AppTheme.accentBlue,
                      onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                    ),
                    // End Call
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final char = widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : 'C';
    return Container(
      color: AppTheme.accentBlue,
      child: Center(
        child: Text(
          char,
          style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
