import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connekt/config/app_theme.dart';
import 'package:connekt/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ThemeService initializes and toggles between Dark Mood and Light Mood', () async {
    await ThemeService.init();
    expect(ThemeService.themeModeNotifier.value, ThemeMode.dark);

    // Toggle to Light Mood
    await ThemeService.toggleTheme();
    expect(ThemeService.themeModeNotifier.value, ThemeMode.light);

    // Toggle back to Dark Mood
    await ThemeService.toggleTheme();
    expect(ThemeService.themeModeNotifier.value, ThemeMode.dark);

    // Set to System mode
    await ThemeService.setThemeMode(ThemeMode.system);
    expect(ThemeService.themeModeNotifier.value, ThemeMode.system);

    // Set to Light mode
    await ThemeService.setThemeMode(ThemeMode.light);
    expect(ThemeService.themeModeNotifier.value, ThemeMode.light);
  });

  test('AppTheme exposes both lightTheme and darkTheme with matching contrast colors', () {
    final dark = AppTheme.darkTheme;
    final light = AppTheme.lightTheme;

    expect(dark.brightness, Brightness.dark);
    expect(light.brightness, Brightness.light);

    expect(dark.scaffoldBackgroundColor, AppTheme.bgDark);
    expect(light.scaffoldBackgroundColor, AppTheme.bgLight);

    expect(dark.colorScheme.primary, AppTheme.accentBlue);
    expect(light.colorScheme.primary, AppTheme.accentBlue);
  });
}
