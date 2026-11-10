import 'package:flutter/material.dart';

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
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color getBackgroundColor(BuildContext context) =>
      isDark(context) ? bgDark : bgLight;

  static Color getCardColor(BuildContext context) =>
      isDark(context) ? bgCard : bgCardLight;

  static Color getInputColor(BuildContext context) =>
      isDark(context) ? bgInput : bgInputLight;

  static Color getTextPrimary(BuildContext context) =>
      isDark(context) ? textPrimary : textPrimaryLight;

  static Color getTextSecondary(BuildContext context) =>
      isDark(context) ? textSecondary : textSecondaryLight;

  static Color getTextMuted(BuildContext context) =>
      isDark(context) ? textMuted : textMutedLight;

  static Color getBorderColor(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0);

  // 1. Dark Theme
  static ThemeData get darkTheme {
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
