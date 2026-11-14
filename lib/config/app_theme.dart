import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AppTheme {
  // Professional Brand Colors (Red & Blue, clean corporate, no neon)
  static const Color brandBlue = Color(0xFF1D4ED8); // Refined professional blue
  static const Color brandBlueLight = Color(0xFF2563EB); // Crisp primary blue
  static const Color brandRed = Color(0xFFDC2626);  // Official CONNEKT brand red
  static const Color brandRedLight = Color(0xFFEF4444);

  // Dark Theme Palette (Deep Navy / Slate)
  static const Color bgDark = Color(0xFF0A0E1A);
  static const Color bgCard = Color(0xFF13192B);
  static const Color bgInput = Color(0xFF0E1424);

  // Light Theme Palette (Crisp Clean White / Slate)
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color bgCardLight = Color(0xFFFFFFFF);
  static const Color bgInputLight = Color(0xFFF1F5F9);

  // Midnight Gold Theme Palette (Cosmic Blue & Gold - Image 2)
  static const Color bgMidnightGold = Color(0xFF060E22);
  static const Color bgCardMidnightGold = Color(0xFF0E1E3D);
  static const Color bgInputMidnightGold = Color(0xFF0A152E);
  static const Color goldAccent = Color(0xFFE5C07B);
  static const Color goldAccentLight = Color(0xFFF5D061);
  static const Color goldBorder = Color(0x66D4AF37);

  // Luxury Gold Theme Palette (Obsidian Black & Gold - Image 3)
  static const Color bgLuxuryGold = Color(0xFF08080A);
  static const Color bgCardLuxuryGold = Color(0xFF141416);
  static const Color bgInputLuxuryGold = Color(0xFF111113);
  static const Color luxuryGoldAccent = Color(0xFFDFB76C);
  static const Color luxuryGoldBorder = Color(0x77C59B47);

  // Accents (Clean Red & Blue system)
  static const Color accentBlue = Color(0xFF1D4ED8);
  static const Color accentCyan = Color(0xFF2563EB);
  static const Color accentCoral = Color(0xFFDC2626);
  static const Color accentAmber = Color(0xFFD97706);

  // Dark Mode Typography Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Light Mode Typography Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF8E95A5);

  // Gold Typography Colors
  static const Color textGold = Color(0xFFF5D061);
  static const Color textGoldSubtle = Color(0xFFE5C07B);

  // Professional, subtle single-family blue gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient liveBadgeGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
  );

  // Dynamic Theme Helpers
  static bool isDark(BuildContext context) => ThemeService.isDark(context);

  static Color getBackgroundColor(BuildContext context) {
    if (ThemeService.isMidnightGold) return bgMidnightGold;
    if (ThemeService.isLuxuryGold) return bgLuxuryGold;
    return isDark(context) ? bgDark : bgLight;
  }

  static Color getCardColor(BuildContext context) {
    if (ThemeService.isMidnightGold) return bgCardMidnightGold;
    if (ThemeService.isLuxuryGold) return bgCardLuxuryGold;
    return isDark(context) ? bgCard : bgCardLight;
  }

  static Color getInputColor(BuildContext context) {
    if (ThemeService.isMidnightGold) return bgInputMidnightGold;
    if (ThemeService.isLuxuryGold) return bgInputLuxuryGold;
    return isDark(context) ? bgInput : bgInputLight;
  }

  static Color getTextPrimary(BuildContext context) {
    if (ThemeService.isGoldTheme) return Colors.white;
    return isDark(context) ? textPrimary : textPrimaryLight;
  }

  static Color getTextSecondary(BuildContext context) {
    if (ThemeService.isMidnightGold) return goldAccent;
    if (ThemeService.isLuxuryGold) return luxuryGoldAccent;
    return isDark(context) ? textSecondary : textSecondaryLight;
  }

  static Color getTextMuted(BuildContext context) {
    if (ThemeService.isGoldTheme) return const Color(0xFFB5A48B);
    return isDark(context) ? textMuted : textMutedLight;
  }

  static Color getBorderColor(BuildContext context) {
    if (ThemeService.isMidnightGold) return goldBorder;
    if (ThemeService.isLuxuryGold) return luxuryGoldBorder;
    return isDark(context) ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0);
  }

  static Color getAccentColor(BuildContext context) {
    if (ThemeService.isMidnightGold) return goldAccent;
    if (ThemeService.isLuxuryGold) return luxuryGoldAccent;
    return accentBlue;
  }

  // 1. Dark Theme
  static ThemeData get darkTheme {
    final visual = ThemeService.visualThemeNotifier.value;
    if (visual == AppVisualTheme.midnightGold) {
      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgMidnightGold,
        primaryColor: goldAccent,
        cardColor: bgCardMidnightGold,
        colorScheme: const ColorScheme.dark(
          primary: goldAccent,
          secondary: goldAccentLight,
          surface: bgCardMidnightGold,
          error: accentCoral,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgInputMidnightGold,
          hintStyle: const TextStyle(color: Color(0xFF8E9CB2), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: goldBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: goldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: goldAccentLight, width: 1.5),
          ),
        ),
      );
    }

    if (visual == AppVisualTheme.luxuryGold) {
      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgLuxuryGold,
        primaryColor: luxuryGoldAccent,
        cardColor: bgCardLuxuryGold,
        colorScheme: const ColorScheme.dark(
          primary: luxuryGoldAccent,
          secondary: goldAccentLight,
          surface: bgCardLuxuryGold,
          error: accentCoral,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgInputLuxuryGold,
          hintStyle: const TextStyle(color: Color(0xFF9E9589), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: luxuryGoldBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: luxuryGoldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: luxuryGoldAccent, width: 1.5),
          ),
        ),
      );
    }

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: accentBlue,
      cardColor: bgCard,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentCyan,
        surface: bgCard,
        error: accentCoral,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 1.5),
        ),
      ),
    );
  }

  // 2. Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      primaryColor: accentBlue,
      cardColor: bgCardLight,
      colorScheme: const ColorScheme.light(
        primary: accentBlue,
        secondary: accentCyan,
        surface: bgCardLight,
        error: accentCoral,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInputLight,
        hintStyle: const TextStyle(color: textMutedLight, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 1.5),
        ),
      ),
    );
  }
}
