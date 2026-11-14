import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class ImageSendResult {
  final String imagePath;
  final String caption;
  final bool isViewOnce;
  final bool isHd;
  final String filterName;
  final String? overlayText;
  final Color overlayTextColor;
  final String? stickerEmoji;
  final int rotationQuarterTurns;

  const ImageSendResult({
    required this.imagePath,
    this.caption = '',
    this.isViewOnce = false,
    this.isHd = false,
    this.filterName = 'None',
    this.overlayText,
    this.overlayTextColor = Colors.white,
    this.stickerEmoji,
    this.rotationQuarterTurns = 0,
  });
}

class ImagePreviewSendScreen extends StatefulWidget {
  final String imagePath;
  final String contactName;

  const ImagePreviewSendScreen({
    super.key,
    required this.imagePath,
    required this.contactName,
  });

  @override
  State<ImagePreviewSendScreen> createState() => _ImagePreviewSendScreenState();
}

class _ImagePreviewSendScreenState extends State<ImagePreviewSendScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocus = FocusNode();

  bool _isViewOnce = false;
  bool _isHd = false;
  int _rotationQuarterTurns = 0;
  String _selectedFilter = 'None';
  String? _overlayText;
  Color _overlayTextColor = Colors.white;
  String? _stickerEmoji;

  // Filter color matrices
  static const Map<String, List<double>> _filterMatrices = {
    'None': [
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'Vivid': [
      1.2, 0, 0, 0, 0,
      0, 1.2, 0, 0, 0,
      0, 0, 1.2, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'Warm': [
      1.15, 0, 0, 0, 10,
      0, 1.05, 0, 0, 5,
      0, 0, 0.9, 0, -10,
      0, 0, 0, 1, 0,
    ],
    'Cool': [
      0.9, 0, 0, 0, -5,
      0, 1.05, 0, 0, 5,
      0, 0, 1.2, 0, 15,
      0, 0, 0, 1, 0,
    ],
    'B&W': [
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'Dramatic': [
      1.35, 0, 0, 0, -25,
      0, 1.35, 0, 0, -25,
      0, 0, 1.35, 0, -25,
      0, 0, 0, 1, 0,
    ],
  };

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleHd() {
    setState(() => _isHd = !_isHd);
    _showSnack(_isHd ? 'HD quality photo selected' : 'Standard quality photo selected');
  }

  void _rotateImage() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _openAddTextSheet() {
    final textCtrl = TextEditingController(text: _overlayText ?? '');
    Color pickedColor = _overlayTextColor;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Text on Photo',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textCtrl,
                    autofocus: true,
                    style: TextStyle(color: pickedColor, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Type text overlay...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Color picker row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Colors.white,
                      Colors.amberAccent,
                      Colors.redAccent,
                      const Color(0xFF38BDF8),
                      const Color(0xFF4ADE80),
                      const Color(0xFFA855F7),
                    ].map((col) {
                      final isSel = pickedColor == col;
                      return GestureDetector(
                        onTap: () => setModalState(() => pickedColor = col),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: 2.5),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_overlayText != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _overlayText = null);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                        ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {
                            _overlayText = textCtrl.text.trim().isEmpty ? null : textCtrl.text.trim();
                            _overlayTextColor = pickedColor;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openEmojiStickerSheet() {
    const emojis = [
      '🔥', '❤️', '😂', '🎉', '👍', '🌟', '🚀', '😎',
      '💯', '✨', '👏', '🙌', '🥳', '💡', '😍', '🤩',
      '👀', '🎯', '💪', '🙏', '⚡', '☕', '🎂', '🐶',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Sticker Emoji',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (_stickerEmoji != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _stickerEmoji = null);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: emojis.map((e) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => _stickerEmoji = e);
                        Navigator.pop(ctx);
                      },
                      child: Text(e, style: const TextStyle(fontSize: 32)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAiEditSheet() {
    final aiOptions = [
      {'name': 'Auto-Enhance', 'filter': 'Vivid', 'icon': Icons.auto_awesome, 'desc': 'Auto-level contrast and vibrant tones'},
      {'name': 'Golden Warm', 'filter': 'Warm', 'icon': Icons.wb_sunny_rounded, 'desc': 'Soft golden sunset warmth'},
      {'name': 'Nordic Cool', 'filter': 'Cool', 'icon': Icons.ac_unit_rounded, 'desc': 'Clean crisp ambient blue tones'},
      {'name': 'Classic Noir', 'filter': 'B&W', 'icon': Icons.filter_b_and_w_rounded, 'desc': 'Timeless dramatic monochrome'},
      {'name': 'Cinematic', 'filter': 'Dramatic', 'icon': Icons.movie_filter_rounded, 'desc': 'High-impact movie contrast'},
      {'name': 'Original', 'filter': 'None', 'icon': Icons.refresh_rounded, 'desc': 'Reset to untouched camera photo'},
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.brandBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'CONNEKT AI Studio',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...aiOptions.map((opt) {
                  final isSelected = _selectedFilter == opt['filter'];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.brandBlue : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(opt['icon'] as IconData, color: isSelected ? Colors.white : Colors.white70, size: 20),
                    ),
                    title: Text(
                      opt['name'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      opt['desc'] as String,
                      style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                    ),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.brandBlue) : null,
                    onTap: () {
                      setState(() => _selectedFilter = opt['filter'] as String);
                      Navigator.pop(ctx);
                      _showSnack('✨ Applied ${opt['name']}');
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onSend() {
    final result = ImageSendResult(
      imagePath: widget.imagePath,
      caption: _captionController.text.trim(),
      isViewOnce: _isViewOnce,
      isHd: _isHd,
      filterName: _selectedFilter,
      overlayText: _overlayText,
      overlayTextColor: _overlayTextColor,
      stickerEmoji: _stickerEmoji,
      rotationQuarterTurns: _rotationQuarterTurns,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final filterMatrix = _filterMatrices[_selectedFilter] ?? _filterMatrices['None']!;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Fullscreen Preview Image with Zoom & Pan, Rotation, Filter, Text & Emoji
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.5,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RotatedBox(
                        quarterTurns: _rotationQuarterTurns,
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix(filterMatrix),
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64),
                            ),
                          ),
                        ),
                      ),

                      // Text Overlay if added
                      if (_overlayText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            _overlayText!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _overlayTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                      // Emoji Sticker if added
                      if (_stickerEmoji != null)
                        Positioned(
                          top: 80,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black38, blurRadius: 12),
                              ],
                            ),
                            child: Text(
                              _stickerEmoji!,
                              style: const TextStyle(fontSize: 54),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Top Action Bar (Close, HD, Crop/Rotate, Sticker, Text, AI Tools)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const Spacer(),

                  // HD Toggle
                  GestureDetector(
                    onTap: _toggleHd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _isHd ? AppTheme.brandBlue : Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _isHd ? AppTheme.brandBlue : Colors.white30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hd_rounded, color: _isHd ? Colors.white : Colors.white70, size: 16),
                          if (_isHd) ...[
                            const SizedBox(width: 4),
                            const Text('HD', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Rotate / Crop
                  _buildTopActionButton(
                    icon: Icons.crop_rotate_rounded,
                    onTap: _rotateImage,
                    tooltip: 'Rotate',
                  ),

                  // Sticker / Emoji
                  _buildTopActionButton(
                    icon: Icons.emoji_emotions_outlined,
                    onTap: _openEmojiStickerSheet,
                    tooltip: 'Stickers & Emoji',
                    isActive: _stickerEmoji != null,
                  ),

                  // Text (Aa)
                  _buildTopActionButton(
                    icon: Icons.title_rounded,
                    onTap: _openAddTextSheet,
                    tooltip: 'Text on Photo',
                    isActive: _overlayText != null,
                  ),

                  // Pen / Filter
                  _buildTopActionButton(
                    icon: Icons.tune_rounded,
                    onTap: _openAiEditSheet,
                    tooltip: 'Filters & Adjustments',
                    isActive: _selectedFilter != 'None',
                  ),
                ],
              ),
            ),

            // 3. Floating "Edit with AI" Pill (Matches user screenshot)
            Positioned(
              bottom: 96,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _openAiEditSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
                        const SizedBox(width: 7),
                        const Text(
                          'Edit with AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (_selectedFilter != 'None') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.brandBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _selectedFilter,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Bottom Input Bar with Caption, View Once & CONNEKT Send Button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85), Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Recipient indicator chip
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          margin: const EdgeInsets.only(left: 4, bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                widget.contactName,
                                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        // Caption input container
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                const Icon(Icons.image_outlined, color: Colors.white54, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _captionController,
                                    focusNode: _captionFocus,
                                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                                    decoration: const InputDecoration(
                                      hintText: 'Add a caption...',
                                      hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    maxLines: 4,
                                    minLines: 1,
                                  ),
                                ),

                                // View Once Button
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _isViewOnce = !_isViewOnce);
                                    _showSnack(_isViewOnce ? 'Photo set to view once' : 'View once turned off');
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: _isViewOnce ? AppTheme.brandBlue : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _isViewOnce ? AppTheme.brandBlue : Colors.white38,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '1',
                                      style: TextStyle(
                                        color: _isViewOnce ? Colors.white : Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // CONNEKT Send Button (Brand Blue)
                        GestureDetector(
                          onTap: _onSend,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x661D4ED8),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 21),
                          ),
                        ),
                      ],
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

  Widget _buildTopActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.brandBlue : Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: isActive ? AppTheme.brandBlue : Colors.transparent),
        ),
        child: Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 20),
      ),
    );
  }
}
