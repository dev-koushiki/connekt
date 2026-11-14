import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_theme_service.dart';
import '../widgets/whatsapp_doodle_painter.dart';

/// WhatsApp Chat Theme Screen
/// Replicates WhatsApp's Chat Theme selector with Chat Bubble, Wallpaper, AI Studio,
/// and categorized Theme Cards (Featured, Nature, Live, Minimal, Doodle).
class ChatThemeScreen extends StatefulWidget {
  final String? chatId;
  final String? chatName;

  const ChatThemeScreen({
    super.key,
    this.chatId,
    this.chatName,
  });

  @override
  State<ChatThemeScreen> createState() => _ChatThemeScreenState();
}

class _ChatThemeScreenState extends State<ChatThemeScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatThemeModel>(
      valueListenable: ChatThemeService.currentThemeNotifier,
      builder: (context, activeTheme, _) {
        const bgDark = Color(0xFF0F172A);
        const cardBg = Color(0xFF1E283D);

        return Scaffold(
          backgroundColor: bgDark,
          appBar: AppBar(
            backgroundColor: bgDark,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Chat theme',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                color: cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (val) {
                  if (val == 'reset') {
                    ChatThemeService.resetToDefault();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Theme reset to default')),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'reset',
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                        SizedBox(width: 12),
                        Text('Reset to default', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Top Action Buttons (Chat bubble, Wallpaper)
                _buildTopActionRow(context, activeTheme),

                const SizedBox(height: 24),

                // 1. Featured Section
                _buildSectionHeader('Featured'),
                _buildThemeCardsList(ChatThemeService.featuredThemes, activeTheme),

                const SizedBox(height: 24),

                // 2. Nature Section
                _buildSectionHeader('Nature'),
                _buildThemeCardsList(ChatThemeService.natureThemes, activeTheme),

                const SizedBox(height: 24),

                // 3. Live Section
                _buildSectionHeader('Live'),
                _buildThemeCardsList(ChatThemeService.liveThemes, activeTheme),

                const SizedBox(height: 24),

                // 4. Minimal Section
                _buildSectionHeader('Minimal'),
                _buildThemeCardsList(ChatThemeService.minimalThemes, activeTheme),

                const SizedBox(height: 24),

                // 5. Doodle Section
                _buildSectionHeader('Doodle'),
                _buildThemeCardsList(ChatThemeService.doodleThemes, activeTheme),
              ],
            ),
          ),
        );
      },
    );
  }

  // ====================================================================
  // TOP ACTION BUTTONS (Chat bubble, Wallpaper, Use AI)
  // ====================================================================

  Widget _buildTopActionRow(BuildContext context, ChatThemeModel activeTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Chat bubble button
          _buildActionButton(
            label: 'Chat bubble',
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF1E283D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 1.5),
              ),
              child: Center(
                child: Container(
                  width: 26,
                  height: 20,
                  decoration: BoxDecoration(
                    color: activeTheme.outgoingBubbleColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            onTap: () => _showBubbleColorPickerSheet(context, activeTheme),
          ),

          // 2. Wallpaper button
          _buildActionButton(
            label: 'Wallpaper',
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF1E283D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 1.5),
              ),
              child: Center(
                child: activeTheme.wallpaperFilePath != null
                    ? ClipOval(
                        child: Image.file(
                          File(activeTheme.wallpaperFilePath!),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.wallpaper_rounded, color: Colors.white, size: 26),
              ),
            ),
            onTap: () => _showWallpaperOptionsSheet(context, activeTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          child,
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // CATEGORY SECTION HEADER & HORIZONTAL CARDS LIST
  // ====================================================================

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildThemeCardsList(List<ChatThemeModel> themes, ChatThemeModel activeTheme) {
    return SizedBox(
      height: 195,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: themes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final theme = themes[index];
          final isSelected = activeTheme.id == theme.id;
          return _buildThemeCard(theme, isSelected);
        },
      ),
    );
  }

  Widget _buildThemeCard(ChatThemeModel theme, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ChatThemeService.setTheme(theme);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Theme applied: ${theme.name}'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Preview',
              textColor: Colors.cyanAccent,
              onPressed: () => _showFullscreenPreview(theme),
            ),
          ),
        );
      },
      onLongPress: () => _showFullscreenPreview(theme),
      child: Container(
        width: 110,
        height: 185,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white10,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.4 : 0.2),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // 1. Background (Gradient, Solid Color, or File Wallpaper)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.backgroundColor ?? (theme.id == 'default' ? const Color(0xFFF8FAFC) : const Color(0xFF0B141B)),
                    gradient: theme.backgroundGradient,
                  ),
                  child: theme.wallpaperFilePath != null
                      ? Image.file(
                          File(theme.wallpaperFilePath!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),

              // 2. WhatsApp Doodle Pattern Overlay
              if (theme.hasDoodle)
                Positioned.fill(
                  child: WhatsAppDoodleBackground(
                    opacity: theme.doodleOpacity,
                    scale: 0.55,
                  ),
                ),

              // 3. Optional top-right subtle badge (e.g. sun / motion indicator)
              if (theme.hasBadgeIcon)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.blur_on_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ),
                ),

              // 4. Miniature Chat Bubbles Preview
              Positioned(
                top: 24,
                left: 10,
                child: _buildMiniBubble(
                  isIncoming: true,
                  color: theme.incomingBubbleColor,
                  width: 52,
                  height: 24,
                ),
              ),

              Positioned(
                top: 56,
                left: 24,
                child: _buildMiniBubble(
                  isIncoming: false,
                  color: theme.outgoingBubbleColor,
                  width: 52,
                  height: 24,
                ),
              ),

              // 5. Selected Checkmark Badge (White circle with checkmark)
              if (isSelected)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBubble({
    required bool isIncoming,
    required Color color,
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft: Radius.circular(isIncoming ? 2 : 8),
          bottomRight: Radius.circular(isIncoming ? 8 : 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // CHAT BUBBLE COLOR PICKER SHEET
  // ====================================================================

  void _showBubbleColorPickerSheet(BuildContext context, ChatThemeModel activeTheme) {
    final colors = [
      const Color(0xFF005C4B), // WhatsApp Emerald
      const Color(0xFF25D366), // Bright Green
      const Color(0xFF1D4ED8), // Royal Blue
      const Color(0xFF2563EB), // Electric Blue
      const Color(0xFF7C3AED), // Violet
      const Color(0xFF9333EA), // Purple
      const Color(0xFFDB2777), // Magenta / Pink
      const Color(0xFFE11D48), // Rose Red
      const Color(0xFFEA580C), // Sunset Orange
      const Color(0xFF0D9488), // Teal
      const Color(0xFF334155), // Slate
      const Color(0xFF1E293B), // Charcoal
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E283D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Chat Bubble Color',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Customize the color of your sent message bubbles.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: colors.map((col) {
                final isSel = activeTheme.outgoingBubbleColor.toARGB32() == col.toARGB32();
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ChatThemeService.setCustomBubbleColor(col);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel ? Colors.white : Colors.white24,
                        width: isSel ? 3.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: col.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: isSel
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // WALLPAPER OPTIONS SHEET
  // ====================================================================

  void _showWallpaperOptionsSheet(BuildContext context, ChatThemeModel activeTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E283D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Change Wallpaper',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF38BDF8)),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Pick any photo as your chat background', style: TextStyle(color: Colors.white60, fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  await ChatThemeService.setCustomWallpaper(filePath: picked.path);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Custom wallpaper applied!')),
                    );
                  }
                }
              },
            ),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.palette_rounded, color: Color(0xFF2DD4BF)),
              ),
              title: const Text('Solid Colors', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Pick a smooth minimalist background tone', style: TextStyle(color: Colors.white60, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showSolidColorsPicker(context);
              },
            ),

            if (activeTheme.wallpaperFilePath != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                ),
                title: const Text('Remove Custom Wallpaper', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ChatThemeService.setCustomWallpaper(filePath: null);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Custom wallpaper removed')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSolidColorsPicker(BuildContext context) {
    final solidColors = [
      const Color(0xFF0F172A), // Slate
      const Color(0xFF1E3A8A), // Blue
      const Color(0xFF064E3B), // Emerald
      const Color(0xFF4C1D95), // Deep Violet
      const Color(0xFF831843), // Pink Burgundy
      const Color(0xFF451A03), // Espresso
      const Color(0xFF18181B), // Dark Zinc
      const Color(0xFF000000), // Pure Black
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E283D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Solid Color',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: solidColors.map((c) {
                return GestureDetector(
                  onTap: () {
                    ChatThemeService.setCustomWallpaper(solidColor: c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // FULLSCREEN LIVE PREVIEW DIALOG
  // ====================================================================

  void _showFullscreenPreview(ChatThemeModel theme) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(theme.name, style: const TextStyle(color: Colors.white, fontSize: 18)),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ChatThemeService.setTheme(theme);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Theme "${theme.name}" applied to chat!')),
                  );
                },
                child: const Text('Apply', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.backgroundColor ?? (theme.id == 'default' ? const Color(0xFFF8FAFC) : const Color(0xFF0B141B)),
                    gradient: theme.backgroundGradient,
                  ),
                  child: theme.wallpaperFilePath != null
                      ? Image.file(File(theme.wallpaperFilePath!), fit: BoxFit.cover)
                      : null,
                ),
              ),

              if (theme.hasDoodle)
                Positioned.fill(
                  child: WhatsAppDoodleBackground(opacity: theme.doodleOpacity),
                ),

              // Realistic chat bubbles simulation
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Incoming bubble
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.incomingBubbleColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                        child: Text(
                          'Hey there! How do you like this ${theme.name} theme?',
                          style: TextStyle(color: theme.incomingTextColor, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Outgoing bubble
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.outgoingBubbleColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Text(
                          'It looks stunning! Absolutely love this style! 🔥✨',
                          style: TextStyle(color: theme.outgoingTextColor, fontSize: 14),
                        ),
                      ),
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
}
