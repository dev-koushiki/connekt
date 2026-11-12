import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/safe_avatar.dart';

class LiveStreamScreen extends StatefulWidget {
  final String streamerName;
  final String subtitle;
  final String streamUrl;

  const LiveStreamScreen({
    super.key,
    required this.streamerName,
    required this.subtitle,
    required this.streamUrl,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final TextEditingController _commentController = TextEditingController();
  int _likesCount = 12500;
  bool _isLiked = false;

  final List<Map<String, String>> _comments = [
    {'user': 'LeoBeats', 'text': 'Vocals on point! 🔥 let\'s gooo'},
    {'user': 'Maya_Vibes', 'text': 'I love your setup! So cozy ✨'},
    {'user': 'DarkKnight22', 'text': 'This beat is hitting hard 🎶'},
    {'user': 'KoffeeKat', 'text': 'Your voice is pure magic 🎤'},
  ];

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.add({'user': 'You', 'text': text});
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Stream Video Simulation Background
          isValidHttpUrl(widget.streamUrl)
              ? Image.network(
                  widget.streamUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: AppTheme.bgDark),
                )
              : Container(color: AppTheme.bgDark),

          // Dark Vignette
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Top Header Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.sensors, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Live', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.visibility_outlined, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('100M', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // Right Side Floating Action Buttons
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                // Streamer Profile Pill
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=120',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentCoral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Likes Counter
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      _likesCount += _isLiked ? 1 : -1;
                    });
                  },
                  child: Column(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? AppTheme.accentCoral : Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_likesCount / 1000).toStringAsFixed(1)}K',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Comments Counter
                Column(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 30),
                    const SizedBox(height: 4),
                    Text(
                      '${_comments.length + 8960}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Share
                const Column(
                  children: [
                    Icon(Icons.share_outlined, color: Colors.white, size: 28),
                    SizedBox(height: 4),
                    Text('Share', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Comments Stream & Input
          Positioned(
            left: 16,
            right: 80,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Comments List
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final item = _comments[_comments.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${item['user']}: ',
                                  style: const TextStyle(
                                    color: AppTheme.accentCyan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                TextSpan(
                                  text: item['text'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Input Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                onSubmitted: (_) => _sendComment(),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Comment...',
                                  hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, color: AppTheme.accentCyan, size: 18),
                              onPressed: _sendComment,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.card_giftcard, color: AppTheme.accentAmber, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
