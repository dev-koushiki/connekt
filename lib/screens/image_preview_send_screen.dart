import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_theme.dart';

class MediaItem {
  final String path;
  final bool isVideo;
  String caption;
  bool isHd;
  int rotationQuarterTurns;
  String filterName;
  String? overlayText;
  Color overlayTextColor;
  String? stickerEmoji;
  bool isMuted;

  MediaItem({
    required this.path,
    required this.isVideo,
    this.caption = '',
    this.isHd = false,
    this.rotationQuarterTurns = 0,
    this.filterName = 'None',
    this.overlayText,
    this.overlayTextColor = Colors.white,
    this.stickerEmoji,
    this.isMuted = false,
  });
}

class MultiMediaSendResult {
  final List<MediaItem> items;
  final String caption;
  final bool isViewOnce;

  const MultiMediaSendResult({
    required this.items,
    this.caption = '',
    this.isViewOnce = false,
  });
}

class ImagePreviewSendScreen extends StatefulWidget {
  final List<MediaItem> initialItems;
  final String contactName;

  const ImagePreviewSendScreen({
    super.key,
    required this.initialItems,
    required this.contactName,
  });

  @override
  State<ImagePreviewSendScreen> createState() => _ImagePreviewSendScreenState();
}

class _ImagePreviewSendScreenState extends State<ImagePreviewSendScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocus = FocusNode();
  final ImagePicker _picker = ImagePicker();

  late List<MediaItem> _items;
  int _currentIndex = 0;
  bool _isViewOnce = false;

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
  void initState() {
    super.initState();
    _items = List<MediaItem>.from(widget.initialItems);
    if (_items.isEmpty) {
      _items = [
        MediaItem(path: '', isVideo: false),
      ];
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  MediaItem get _currentItem => _items[_currentIndex.clamp(0, _items.length - 1)];

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
    setState(() => _currentItem.isHd = !_currentItem.isHd);
    _showSnack(_currentItem.isHd ? 'HD quality photo selected' : 'Standard quality photo selected');
  }

  void _rotateImage() {
    setState(() {
      _currentItem.rotationQuarterTurns = (_currentItem.rotationQuarterTurns + 1) % 4;
    });
  }

  void _toggleMute() {
    setState(() {
      _currentItem.isMuted = !_currentItem.isMuted;
    });
    _showSnack(_currentItem.isMuted ? 'Video audio muted' : 'Video audio unmuted');
  }

  void _deleteCurrentItem() {
    if (_items.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _items.removeAt(_currentIndex);
      if (_currentIndex >= _items.length) {
        _currentIndex = _items.length - 1;
      }
    });
    _showSnack('Removed item from batch');
  }

  Future<void> _addMoreMedia() async {
    try {
      final pickedList = await _picker.pickMultipleMedia(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedList.isNotEmpty) {
        setState(() {
          for (final xf in pickedList) {
            final isVid = _checkIfVideo(xf.path);
            _items.add(MediaItem(path: xf.path, isVideo: isVid));
          }
          _currentIndex = _items.length - 1;
        });
        _showSnack('Added ${pickedList.length} media item(s)');
      }
    } catch (e) {
      _showSnack('Unable to pick more media: $e');
    }
  }

  bool _checkIfVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.3gp');
  }

  void _openAddTextSheet() {
    final textCtrl = TextEditingController(text: _currentItem.overlayText ?? '');
    Color pickedColor = _currentItem.overlayTextColor;

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
                      if (_currentItem.overlayText != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _currentItem.overlayText = null);
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
                            _currentItem.overlayText = textCtrl.text.trim().isEmpty ? null : textCtrl.text.trim();
                            _currentItem.overlayTextColor = pickedColor;
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
                    if (_currentItem.stickerEmoji != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _currentItem.stickerEmoji = null);
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
                        setState(() => _currentItem.stickerEmoji = e);
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
                  final isSelected = _currentItem.filterName == opt['filter'];
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
                      setState(() => _currentItem.filterName = opt['filter'] as String);
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
    final result = MultiMediaSendResult(
      items: _items,
      caption: _captionController.text.trim(),
      isViewOnce: _isViewOnce,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final item = _currentItem;
    final filterMatrix = _filterMatrices[item.filterName] ?? _filterMatrices['None']!;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Center Image / Video Viewer
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.5,
                child: Center(
                  child: item.isVideo
                      ? _buildVideoCenterPreview(item)
                      : _buildImageCenterPreview(item, filterMatrix),
                ),
              ),
            ),

            // 2. Top Action Bar
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

                  // If Video: Mute Button
                  if (item.isVideo)
                    _buildTopActionButton(
                      icon: item.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      onTap: _toggleMute,
                      tooltip: item.isMuted ? 'Unmute' : 'Mute',
                      isActive: item.isMuted,
                    ),

                  // If Image: HD Toggle
                  if (!item.isVideo)
                    GestureDetector(
                      onTap: _toggleHd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: item.isHd ? AppTheme.brandBlue : Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: item.isHd ? AppTheme.brandBlue : Colors.white30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hd_rounded, color: item.isHd ? Colors.white : Colors.white70, size: 16),
                            if (item.isHd) ...[
                              const SizedBox(width: 4),
                              const Text('HD', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Rotate / Crop
                  if (!item.isVideo)
                    _buildTopActionButton(
                      icon: Icons.crop_rotate_rounded,
                      onTap: _rotateImage,
                      tooltip: 'Rotate',
                    ),

                  // Sticker / Emoji
                  if (!item.isVideo)
                    _buildTopActionButton(
                      icon: Icons.emoji_emotions_outlined,
                      onTap: _openEmojiStickerSheet,
                      tooltip: 'Stickers & Emoji',
                      isActive: item.stickerEmoji != null,
                    ),

                  // Text (Aa)
                  if (!item.isVideo)
                    _buildTopActionButton(
                      icon: Icons.title_rounded,
                      onTap: _openAddTextSheet,
                      tooltip: 'Text on Photo',
                      isActive: item.overlayText != null,
                    ),

                  // Pen / Filter
                  if (!item.isVideo)
                    _buildTopActionButton(
                      icon: Icons.tune_rounded,
                      onTap: _openAiEditSheet,
                      tooltip: 'Filters & Adjustments',
                      isActive: item.filterName != 'None',
                    ),

                  // Delete current item
                  if (_items.length > 1)
                    _buildTopActionButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: _deleteCurrentItem,
                      tooltip: 'Delete item',
                    ),
                ],
              ),
            ),

            // 3. Floating "Edit with AI" Pill (only for images)
            if (!item.isVideo)
              Positioned(
                bottom: _items.length > 1 ? 160 : 96,
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
                          if (item.filterName != 'None') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.brandBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                item.filterName,
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

            // 4. Bottom Thumbnail Strip + Input Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9), Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Horizontal Thumbnail Strip (WhatsApp style)
                    _buildThumbnailStrip(),

                    const SizedBox(height: 8),

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
                                '${widget.contactName} (${_items.length} media)',
                                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Caption input and send row
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
                                Icon(
                                  item.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
                                  color: Colors.white54,
                                  size: 20,
                                ),
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
                                    _showSnack(_isViewOnce ? 'Media set to view once' : 'View once turned off');
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

  Widget _buildThumbnailStrip() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length + 1, // +1 for "Add More" button
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            // Add More Button
            return GestureDetector(
              onTap: _addMoreMedia,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24, width: 1.2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, color: Colors.white70, size: 22),
                    SizedBox(height: 2),
                    Text('Add', style: TextStyle(color: Colors.white60, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }

          final it = _items[index];
          final isSelected = index == _currentIndex;

          return GestureDetector(
            onTap: () => setState(() => _currentIndex = index),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppTheme.brandBlue : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!it.isVideo && File(it.path).existsSync())
                      Image.file(File(it.path), fit: BoxFit.cover)
                    else
                      Container(
                        color: const Color(0xFF1E293B),
                        child: Icon(
                          it.isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                      ),
                    if (it.isVideo)
                      const Center(
                        child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageCenterPreview(MediaItem item, List<double> filterMatrix) {
    return Stack(
      alignment: Alignment.center,
      children: [
        RotatedBox(
          quarterTurns: item.rotationQuarterTurns,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(filterMatrix),
            child: File(item.path).existsSync()
                ? Image.file(
                    File(item.path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64),
                    ),
                  )
                : const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64)),
          ),
        ),

        // Text Overlay if added
        if (item.overlayText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              item.overlayText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: item.overlayTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),

        // Emoji Sticker if added
        if (item.stickerEmoji != null)
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
                item.stickerEmoji!,
                style: const TextStyle(fontSize: 54),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoCenterPreview(MediaItem item) {
    return Container(
      width: double.infinity,
      height: 360,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.brandBlue.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandBlue.withValues(alpha: 0.5),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 46),
              ),
              const SizedBox(height: 16),
              Text(
                item.path.split(Platform.pathSeparator).last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Video clip ready to send', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          if (item.isMuted)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.volume_off_rounded, color: Colors.redAccent, size: 18),
              ),
            ),
        ],
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
