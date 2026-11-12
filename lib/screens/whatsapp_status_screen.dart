import 'package:flutter/material.dart';
import '../widgets/safe_avatar.dart';

/// Full-Screen WhatsApp Status / Story Viewer
class WhatsAppStatusViewer extends StatefulWidget {
  final String userName;
  final String userAvatar;
  final String timeAgo;
  final List<StatusItem> items;
  final VoidCallback? onComplete;

  const WhatsAppStatusViewer({
    super.key,
    required this.userName,
    required this.userAvatar,
    required this.timeAgo,
    required this.items,
    this.onComplete,
  });

  @override
  State<WhatsAppStatusViewer> createState() => _WhatsAppStatusViewerState();
}

class StatusItem {
  final String? text;
  final String? imageUrl;
  final Color backgroundColor;
  final String time;

  const StatusItem({
    this.text,
    this.imageUrl,
    this.backgroundColor = const Color(0xFF1E3A8A),
    this.time = 'Just now',
  });
}

class _WhatsAppStatusViewerState extends State<WhatsAppStatusViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _currentIndex = 0;
  final TextEditingController _replyController = TextEditingController();
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextItem();
      }
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _goToNextItem() {
    if (_currentIndex < widget.items.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _animController.reset();
      _animController.forward();
    } else {
      widget.onComplete?.call();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _goToPreviousItem() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _animController.reset();
      _animController.forward();
    } else {
      _animController.reset();
      _animController.forward();
    }
  }

  void _pause() {
    if (!_isPaused) {
      _isPaused = true;
      _animController.stop();
    }
  }

  void _resume() {
    if (_isPaused) {
      _isPaused = false;
      _animController.forward();
    }
  }

  void _sendReply(String reaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Replied to ${widget.userName}: $reaction'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1D4ED8),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.items.isNotEmpty
        ? widget.items[_currentIndex]
        : const StatusItem(text: 'No updates');

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (_) => _pause(),
          onTapUp: (details) {
            _resume();
            final width = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < width / 3) {
              _goToPreviousItem();
            } else if (details.globalPosition.dx > (2 * width / 3)) {
              _goToNextItem();
            }
          },
          onLongPressStart: (_) => _pause(),
          onLongPressEnd: (_) => _resume(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Status Background & Content
              Container(
                color: currentItem.backgroundColor,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: currentItem.imageUrl != null && currentItem.imageUrl!.isNotEmpty
                    ? Image.network(
                        currentItem.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _buildTextStatus(currentItem.text ?? ''),
                      )
                    : _buildTextStatus(currentItem.text ?? ''),
              ),

              // 2. Top Progress Indicators & Header
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Segmented Progress Bars
                    Row(
                      children: List.generate(widget.items.length, (index) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) {
                                double value = 0.0;
                                if (index < _currentIndex) {
                                  value = 1.0;
                                } else if (index == _currentIndex) {
                                  value = _animController.value;
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    minHeight: 2.5,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),

                    // User Header
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        SafeAvatar(
                          url: widget.userAvatar.isNotEmpty ? widget.userAvatar : null,
                          fallbackText: widget.userName,
                          size: 38,
                          radius: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                widget.timeAgo,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () {
                            _pause();
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: const Color(0xFF1F2937),
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.volume_off, color: Colors.white70),
                                      title: const Text('Mute status updates', style: TextStyle(color: Colors.white)),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _resume();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Muted updates from ${widget.userName}')),
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                                      title: const Text('Report status', style: TextStyle(color: Colors.redAccent)),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _resume();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ).then((_) => _resume());
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Bottom WhatsApp Reply Bar
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick Emoji Reactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['❤️', '😂', '😮', '😢', '🙏', '👏'].map((emoji) {
                        return GestureDetector(
                          onTap: () => _sendReply(emoji),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 20)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Reply TextField
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white30, width: 1),
                            ),
                            child: TextField(
                              controller: _replyController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              onTap: () => _pause(),
                              decoration: const InputDecoration(
                                hintText: 'Reply...',
                                hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
                                prefixIcon: Icon(Icons.arrow_upward_rounded, color: Colors.white70, size: 20),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF1D4ED8),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            onPressed: () {
                              final text = _replyController.text.trim();
                              if (text.isNotEmpty) {
                                _sendReply(text);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextStatus(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.35,
      ),
    );
  }
}

/// WhatsApp-style Text Status Creator
class WhatsAppTextStatusCreator extends StatefulWidget {
  final ValueChanged<StatusItem> onCreated;

  const WhatsAppTextStatusCreator({super.key, required this.onCreated});

  @override
  State<WhatsAppTextStatusCreator> createState() => _WhatsAppTextStatusCreatorState();
}

class _WhatsAppTextStatusCreatorState extends State<WhatsAppTextStatusCreator> {
  final TextEditingController _textController = TextEditingController();
  int _colorIndex = 0;

  static const List<Color> _palette = [
    Color(0xFF0F766E), // Teal
    Color(0xFF1E3A8A), // Indigo
    Color(0xFF7C2D12), // Amber/Rust
    Color(0xFF581C87), // Purple
    Color(0xFF831843), // Pink
    Color(0xFF14532D), // Emerald
    Color(0xFF18181B), // Dark Zinc
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _changeColor() {
    setState(() {
      _colorIndex = (_colorIndex + 1) % _palette.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _palette[_colorIndex];

    return Scaffold(
      backgroundColor: currentColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.color_lens_outlined, color: Colors.white),
                        tooltip: 'Change background',
                        onPressed: _changeColor,
                      ),
                      IconButton(
                        icon: const Icon(Icons.text_fields_rounded, color: Colors.white),
                        tooltip: 'Font style',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Middle Input
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: TextField(
                    controller: _textController,
                    autofocus: true,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Type a status...',
                      hintStyle: TextStyle(color: Colors.white60, fontSize: 26),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Post Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF1D4ED8),
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: () {
                    final text = _textController.text.trim();
                    if (text.isEmpty) return;
                    final item = StatusItem(
                      text: text,
                      backgroundColor: currentColor,
                      time: 'Just now',
                    );
                    widget.onCreated(item);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
