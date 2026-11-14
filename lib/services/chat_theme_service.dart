import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a Chat Theme preset or custom configuration
class ChatThemeModel {
  final String id;
  final String name;
  final String category; // 'Featured', 'Nature', 'Live', 'Minimal', 'Doodle', 'Custom', 'AI'
  final Color outgoingBubbleColor;
  final Color outgoingTextColor;
  final Color incomingBubbleColor;
  final Color incomingTextColor;
  final Color? backgroundColor;
  final LinearGradient? backgroundGradient;
  final String? wallpaperUrl;
  final String? wallpaperFilePath;
  final bool hasDoodle;
  final double doodleOpacity;
  final bool hasBadgeIcon;
  final bool isLive;

  const ChatThemeModel({
    required this.id,
    required this.name,
    required this.category,
    required this.outgoingBubbleColor,
    this.outgoingTextColor = Colors.white,
    this.incomingBubbleColor = const Color(0xFF1E283D),
    this.incomingTextColor = Colors.white,
    this.backgroundColor,
    this.backgroundGradient,
    this.wallpaperUrl,
    this.wallpaperFilePath,
    this.hasDoodle = false,
    this.doodleOpacity = 0.10,
    this.hasBadgeIcon = false,
    this.isLive = false,
  });

  ChatThemeModel copyWith({
    String? id,
    String? name,
    String? category,
    Color? outgoingBubbleColor,
    Color? outgoingTextColor,
    Color? incomingBubbleColor,
    Color? incomingTextColor,
    Color? backgroundColor,
    LinearGradient? backgroundGradient,
    String? wallpaperUrl,
    String? wallpaperFilePath,
    bool? hasDoodle,
    double? doodleOpacity,
    bool? hasBadgeIcon,
    bool? isLive,
  }) {
    return ChatThemeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      outgoingBubbleColor: outgoingBubbleColor ?? this.outgoingBubbleColor,
      outgoingTextColor: outgoingTextColor ?? this.outgoingTextColor,
      incomingBubbleColor: incomingBubbleColor ?? this.incomingBubbleColor,
      incomingTextColor: incomingTextColor ?? this.incomingTextColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      wallpaperUrl: wallpaperUrl ?? this.wallpaperUrl,
      wallpaperFilePath: wallpaperFilePath ?? this.wallpaperFilePath,
      hasDoodle: hasDoodle ?? this.hasDoodle,
      doodleOpacity: doodleOpacity ?? this.doodleOpacity,
      hasBadgeIcon: hasBadgeIcon ?? this.hasBadgeIcon,
      isLive: isLive ?? this.isLive,
    );
  }
}

/// Service managing chat themes, persistence, and reactive updates
class ChatThemeService {
  static const String _prefActiveThemeId = 'connekt_active_chat_theme_id';
  static const String _prefCustomBubbleColor = 'connekt_custom_bubble_color';
  static const String _prefCustomWallpaperPath = 'connekt_custom_wallpaper_path';
  static const String _prefCustomBgColor = 'connekt_custom_bg_color';

  /// Default CONNEKT theme (Signature Clean Blue & White)
  static final ChatThemeModel defaultTheme = ChatThemeModel(
    id: 'default',
    name: 'Classic Blue & White',
    category: 'Featured',
    outgoingBubbleColor: const Color(0xFF1D4ED8), // CONNEKT Signature Royal Blue
    outgoingTextColor: Colors.white,
    incomingBubbleColor: const Color(0xFFE2E8F0), // Crisp Light Slate
    incomingTextColor: const Color(0xFF0F172A),
    backgroundColor: null, // Pure adaptive White / Slate
    hasDoodle: false,
    doodleOpacity: 0.08,
  );

  /// Reactive notifier for real-time rebuilds in chat screens
  static final ValueNotifier<ChatThemeModel> currentThemeNotifier =
      ValueNotifier<ChatThemeModel>(defaultTheme);

  /// Current active theme
  static ChatThemeModel get currentTheme => currentThemeNotifier.value;

  // ====================================================================
  // CURATED THEME PRESETS (Categorized exactly like WhatsApp)
  // ====================================================================

  /// Featured Themes
  static final List<ChatThemeModel> featuredThemes = [
    defaultTheme,
    const ChatThemeModel(
      id: 'featured_whatsapp_emerald',
      name: 'Emerald Garden',
      category: 'Featured',
      outgoingBubbleColor: Color(0xFF005C4B), // Classic dark emerald
      incomingBubbleColor: Color(0xFF1E283D),
      backgroundColor: Color(0xFF0B141B),
      hasDoodle: true,
      doodleOpacity: 0.12,
    ),
    const ChatThemeModel(
      id: 'featured_sky',
      name: 'Sky Breeze',
      category: 'Featured',
      outgoingBubbleColor: Color(0xFF1D4ED8),
      incomingBubbleColor: Color(0xFF1E283D),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3B82F6), Color(0xFF93C5FD), Color(0xFFF0FDF4)],
      ),
      hasBadgeIcon: true,
    ),
    const ChatThemeModel(
      id: 'featured_aurora',
      name: 'Cosmic Fluid',
      category: 'Featured',
      outgoingBubbleColor: Color(0xFF334155),
      incomingBubbleColor: Color(0xFF1E293B),
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0369A1)],
      ),
      hasBadgeIcon: true,
    ),
    const ChatThemeModel(
      id: 'featured_emerald_night',
      name: 'Emerald Night',
      category: 'Featured',
      outgoingBubbleColor: Color(0xFF059669),
      incomingBubbleColor: Color(0xFF064E3B),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF022C22), Color(0xFF065F46), Color(0xFF047857)],
      ),
      hasDoodle: true,
      doodleOpacity: 0.12,
    ),
  ];

  /// Nature Themes
  static final List<ChatThemeModel> natureThemes = [
    const ChatThemeModel(
      id: 'nature_canyon',
      name: 'Red Canyon',
      category: 'Nature',
      outgoingBubbleColor: Color(0xFF9F1239), // Rich rose burgundy
      incomingBubbleColor: Color(0xFF2E1065),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDA4AF), Color(0xFFFB7185), Color(0xFF881337)],
      ),
    ),
    const ChatThemeModel(
      id: 'nature_sunset',
      name: 'Solar Horizon',
      category: 'Nature',
      outgoingBubbleColor: Color(0xFFEA580C), // Sunset orange
      incomingBubbleColor: Color(0xFF3B1D11),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3C2A3E), Color(0xFFC2410C), Color(0xFF1F1626)],
      ),
    ),
    const ChatThemeModel(
      id: 'nature_ocean',
      name: 'Ocean Waves',
      category: 'Nature',
      outgoingBubbleColor: Color(0xFF0D9488), // Tropical teal
      incomingBubbleColor: Color(0xFF134E4A),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F766E), Color(0xFF0891B2), Color(0xFFCCFBF1)],
      ),
    ),
    const ChatThemeModel(
      id: 'nature_alpine',
      name: 'Alpine Forest',
      category: 'Nature',
      outgoingBubbleColor: Color(0xFF374151), // Slate
      incomingBubbleColor: Color(0xFF1F2937),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1F2937), Color(0xFF374151), Color(0xFF6B7280)],
      ),
    ),
  ];

  /// Live Themes (Dynamic/Mesmerizing Gradients)
  static final List<ChatThemeModel> liveThemes = [
    const ChatThemeModel(
      id: 'live_holographic',
      name: 'Holo Swirl',
      category: 'Live',
      outgoingBubbleColor: Color(0xFF7E22CE), // Purple
      incomingBubbleColor: Color(0xFF2E1065),
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE9D5FF), Color(0xFFC084FC), Color(0xFF67E8F9), Color(0xFFFBCFE8)],
      ),
      hasBadgeIcon: true,
      isLive: true,
    ),
    const ChatThemeModel(
      id: 'live_skyline',
      name: 'Skyline Dawn',
      category: 'Live',
      outgoingBubbleColor: Color(0xFF1E40AF), // Cobalt
      incomingBubbleColor: Color(0xFF172554),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF60A5FA), Color(0xFF93C5FD), Color(0xFFFEF9C3)],
      ),
      hasBadgeIcon: true,
      isLive: true,
    ),
    const ChatThemeModel(
      id: 'live_aurora_stream',
      name: 'Aurora Stream',
      category: 'Live',
      outgoingBubbleColor: Color(0xFF047857), // Emerald
      incomingBubbleColor: Color(0xFF064E3B),
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B0F19), Color(0xFF064E3B), Color(0xFF1E3A8A)],
      ),
      hasBadgeIcon: true,
      isLive: true,
    ),
    const ChatThemeModel(
      id: 'live_neon_curves',
      name: 'Neon Twilight',
      category: 'Live',
      outgoingBubbleColor: Color(0xFF4338CA), // Indigo
      incomingBubbleColor: Color(0xFF1E1B4B),
      backgroundGradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA), Color(0xFF0284C7)],
      ),
      hasBadgeIcon: true,
      isLive: true,
    ),
  ];

  /// Minimal Themes (Matte & OLED Sleek Palettes)
  static final List<ChatThemeModel> minimalThemes = [
    const ChatThemeModel(
      id: 'minimal_charcoal',
      name: 'Graphite Dark',
      category: 'Minimal',
      outgoingBubbleColor: Color(0xFF334155),
      incomingBubbleColor: Color(0xFF1E293B),
      backgroundColor: Color(0xFF0F172A),
    ),
    const ChatThemeModel(
      id: 'minimal_burgundy',
      name: 'Deep Burgundy',
      category: 'Minimal',
      outgoingBubbleColor: Color(0xFF881337),
      incomingBubbleColor: Color(0xFF280A12),
      backgroundColor: Color(0xFF130408),
    ),
    const ChatThemeModel(
      id: 'minimal_indigo',
      name: 'Royal Midnight',
      category: 'Minimal',
      outgoingBubbleColor: Color(0xFF6D28D9),
      incomingBubbleColor: Color(0xFF2E1065),
      backgroundColor: Color(0xFF0D0B1C),
    ),
    const ChatThemeModel(
      id: 'minimal_oled',
      name: 'OLED Pure Black',
      category: 'Minimal',
      outgoingBubbleColor: Color(0xFF2563EB), // Vibrant blue on pure pitch black
      incomingBubbleColor: Color(0xFF18181B),
      backgroundColor: Color(0xFF000000),
    ),
    const ChatThemeModel(
      id: 'minimal_forest_pine',
      name: 'Pine Obsidian',
      category: 'Minimal',
      outgoingBubbleColor: Color(0xFF065F46),
      incomingBubbleColor: Color(0xFF064E3B),
      backgroundColor: Color(0xFF021E17),
    ),
  ];

  /// Doodle Themes (Authentic WhatsApp Hand-drawn Doodles)
  static final List<ChatThemeModel> doodleThemes = [
    const ChatThemeModel(
      id: 'doodle_purple',
      name: 'Doodle Violet',
      category: 'Doodle',
      outgoingBubbleColor: Color(0xFF7C3AED),
      incomingBubbleColor: Color(0xFF1E283D),
      backgroundColor: Color(0xFF0F172A),
      hasDoodle: true,
      doodleOpacity: 0.16,
    ),
    const ChatThemeModel(
      id: 'doodle_blue',
      name: 'Doodle Sapphire',
      category: 'Doodle',
      outgoingBubbleColor: Color(0xFF2563EB),
      incomingBubbleColor: Color(0xFF1E283D),
      backgroundColor: Color(0xFF0B141B),
      hasDoodle: true,
      doodleOpacity: 0.16,
    ),
    const ChatThemeModel(
      id: 'doodle_pink',
      name: 'Doodle Magenta',
      category: 'Doodle',
      outgoingBubbleColor: Color(0xFFE11D48),
      incomingBubbleColor: Color(0xFF27131B),
      backgroundColor: Color(0xFF14080E),
      hasDoodle: true,
      doodleOpacity: 0.16,
    ),
    const ChatThemeModel(
      id: 'doodle_emerald',
      name: 'Doodle Emerald',
      category: 'Doodle',
      outgoingBubbleColor: Color(0xFF005C4B),
      incomingBubbleColor: Color(0xFF112922),
      backgroundColor: Color(0xFF071914),
      hasDoodle: true,
      doodleOpacity: 0.18,
    ),
  ];

  /// All catalog themes combined
  static List<ChatThemeModel> get allThemes => [
        ...featuredThemes,
        ...natureThemes,
        ...liveThemes,
        ...minimalThemes,
        ...doodleThemes,
      ];

  // ====================================================================
  // PERSISTENCE & INITIALIZATION
  // ====================================================================

  /// Initialize theme on app start
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefActiveThemeId);
      final customBubble = prefs.getInt(_prefCustomBubbleColor);
      final customWallpaper = prefs.getString(_prefCustomWallpaperPath);
      final customBg = prefs.getInt(_prefCustomBgColor);

      ChatThemeModel resolvedTheme = defaultTheme;

      // Migrate / reset legacy green defaults to clean Blue & White default
      if (savedId == null || savedId == 'default') {
        resolvedTheme = defaultTheme;
        if (customBubble == 0xFF005C4B) {
          await prefs.remove(_prefCustomBubbleColor);
        }
        if (customBg == 0xFF0B141B) {
          await prefs.remove(_prefCustomBgColor);
        }
      } else {
        final match = allThemes.where((t) => t.id == savedId);
        if (match.isNotEmpty) {
          resolvedTheme = match.first;
        } else if (savedId == 'custom') {
          resolvedTheme = defaultTheme.copyWith(
            id: 'custom',
            name: 'Custom Theme',
            category: 'Custom',
          );
        }

        if (customBubble != null && customBubble != 0xFF005C4B) {
          resolvedTheme = resolvedTheme.copyWith(outgoingBubbleColor: Color(customBubble));
        }
        if (customWallpaper != null && customWallpaper.isNotEmpty) {
          resolvedTheme = resolvedTheme.copyWith(wallpaperFilePath: customWallpaper);
        }
        if (customBg != null && customBg != 0xFF0B141B) {
          resolvedTheme = resolvedTheme.copyWith(backgroundColor: Color(customBg));
        }
      }

      currentThemeNotifier.value = resolvedTheme;
    } catch (_) {
      currentThemeNotifier.value = defaultTheme;
    }
  }

  /// Select and persist a specific theme preset
  static Future<void> setTheme(ChatThemeModel theme) async {
    currentThemeNotifier.value = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefActiveThemeId, theme.id);
      // Clean previous custom overrides so preset looks faithful
      if (theme.wallpaperFilePath == null) {
        await prefs.remove(_prefCustomWallpaperPath);
      }
    } catch (_) {}
  }

  /// Change outgoing chat bubble color independently
  static Future<void> setCustomBubbleColor(Color color) async {
    final updated = currentThemeNotifier.value.copyWith(
      outgoingBubbleColor: color,
    );
    currentThemeNotifier.value = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefCustomBubbleColor, color.toARGB32());
    } catch (_) {}
  }

  /// Change wallpaper to a custom image from gallery or solid color
  static Future<void> setCustomWallpaper({String? filePath, Color? solidColor}) async {
    ChatThemeModel updated = currentThemeNotifier.value;
    if (filePath != null) {
      updated = updated.copyWith(
        wallpaperFilePath: filePath,
        backgroundColor: null,
        backgroundGradient: null,
      );
    } else if (solidColor != null) {
      updated = updated.copyWith(
        wallpaperFilePath: null,
        backgroundColor: solidColor,
        backgroundGradient: null,
      );
    }
    currentThemeNotifier.value = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (filePath != null) {
        await prefs.setString(_prefCustomWallpaperPath, filePath);
      } else {
        await prefs.remove(_prefCustomWallpaperPath);
      }
      if (solidColor != null) {
        await prefs.setInt(_prefCustomBgColor, solidColor.toARGB32());
      }
    } catch (_) {}
  }

  /// Create and apply an AI-generated theme
  static Future<void> applyAiTheme({
    required String name,
    required Color bubbleColor,
    required List<Color> gradientColors,
  }) async {
    final aiTheme = ChatThemeModel(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: 'AI',
      outgoingBubbleColor: bubbleColor,
      incomingBubbleColor: const Color(0xFF1E283D),
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ),
      hasBadgeIcon: true,
      hasDoodle: true,
      doodleOpacity: 0.12,
    );

    currentThemeNotifier.value = aiTheme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefActiveThemeId, aiTheme.id);
      await prefs.setInt(_prefCustomBubbleColor, bubbleColor.toARGB32());
    } catch (_) {}
  }

  /// Reset to standard default theme
  static Future<void> resetToDefault() async {
    currentThemeNotifier.value = defaultTheme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefActiveThemeId);
      await prefs.remove(_prefCustomBubbleColor);
      await prefs.remove(_prefCustomWallpaperPath);
      await prefs.remove(_prefCustomBgColor);
    } catch (_) {}
  }
}
