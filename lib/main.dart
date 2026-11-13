import 'dart:async';
import 'package:flutter/material.dart';
import 'config/api_config.dart';
import 'config/app_theme.dart';
import 'models/user_model.dart';
import 'services/api_service.dart';
import 'services/call_log_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/meetings_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/mail_screen.dart';
import 'screens/social_screen.dart';
import 'screens/profile_screen.dart';
import 'services/theme_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'i18n/app_localizations.dart';
import 'i18n/languages.dart';
import 'services/i18n_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.loadHost();
  await ThemeService.init();
  await I18nService.init();
  runApp(const ConnektApp());
}

class ConnektApp extends StatefulWidget {
  const ConnektApp({super.key});

  @override
  State<ConnektApp> createState() => _ConnektAppState();
}

class _ConnektAppState extends State<ConnektApp> {
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _showSplash = true;
  int _authEpoch = 0;

  @override
  void initState() {
    super.initState();
    // Safety Watchdog: Never let app remain stuck on loading screen for more than 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final epoch = _authEpoch;

    // 1. Check local cache first for instant 0ms app launch
    try {
      final cached = await ApiService.getCachedUser();
      if (!mounted || epoch != _authEpoch) return;
      if (cached != null) {
        I18nService.syncWithUser(cached.preferredLanguage);
        setState(() {
          _currentUser = cached;
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Verify / refresh with server (strict 2s timeout)
    try {
      final user = await ApiService.getMe().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (!mounted || epoch != _authEpoch) return;

      final hasToken = (await ApiService.getToken())?.isNotEmpty ?? false;
      if (!mounted || epoch != _authEpoch) return;

      setState(() {
        if (user != null) {
          I18nService.syncWithUser(user.preferredLanguage);
          _currentUser = user;
        } else if (!hasToken) {
          _currentUser = null;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && epoch == _authEpoch) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onAuthSuccess(UserModel user) {
    _authEpoch++;
    I18nService.syncWithUser(user.preferredLanguage);
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  Future<void> _onLogout() async {
    _authEpoch++;
    final token = await ApiService.getToken();
    await ApiService.clearToken();
    if (mounted) {
      setState(() {
        _currentUser = null;
        _isLoading = false;
      });
    }
    unawaited(ApiService.revokeSessionOnServer(token));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: I18nService.localeNotifier,
          builder: (context, currentLocale, _) {
            return MaterialApp(
              title: 'CONNEKT',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentThemeMode,
              locale: currentLocale,
              supportedLocales: AppLanguages.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: _showSplash
                  ? SplashScreen(
                      onFinish: () {
                        if (mounted) {
                          setState(() => _showSplash = false);
                        }
                      },
                    )
                  : _currentUser == null
                      ? AuthScreen(onAuthSuccess: _onAuthSuccess)
                      : MainNavigationShell(
                          key: ValueKey(_currentUser!.id),
                          user: _currentUser!,
                          onLogout: _onLogout,
                        ),
            );
          },
        );
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;

  const MainNavigationShell({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  late UserModel _user;
  Timer? _callSyncTimer;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _initCallLogSync();
  }

  @override
  void didUpdateWidget(covariant MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      setState(() => _user = widget.user);
    }
  }

  @override
  void dispose() {
    _callSyncTimer?.cancel();
    super.dispose();
  }

  void _initCallLogSync() {
    // 1. Sync device call logs once UI mounts (immediately reads logs if permission is allowed)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        CallLogService.syncCallLogs();
      }
    });

    // 2. Poll periodically (every 10s) to check if the website has requested a fresh sync
    _callSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      try {
        final requested = await ApiService.checkCallSyncRequested();
        if (requested && mounted) {
          await CallLogService.syncCallLogs();
        }
      } catch (_) {}
    });
  }

  void _onModeChanged(String newMode) {
    final updated = _user.copyWith(currentMode: newMode);
    setState(() => _user = updated);
    unawaited(ApiService.saveCachedUser(updated));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      // Index 0: Home Dashboard
      HomeScreen(
        user: _user,
        onModeChanged: _onModeChanged,
        onNavigateToTab: (index) {
          setState(() => _currentIndex = index);
        },
      ),
      // Index 1: Meetings Module
      MeetingsScreen(
        user: _user,
        onBackToHome: () => setState(() => _currentIndex = 0),
      ),
      // Index 2: Chats Module
      ChatsScreen(
        user: _user,
        onBackToHome: () => setState(() => _currentIndex = 0),
      ),
      // Index 3: Mails Module
      MailScreen(
        user: _user,
        onBackToHome: () => setState(() => _currentIndex = 0),
      ),
      // Index 4: Social Module (Social Mode, Professional Mode & Community)
      SocialScreen(
        user: _user,
        onBackToHome: () => setState(() => _currentIndex = 0),
      ),
      // Index 5: Profile Module
      ProfileScreen(
        user: _user,
        onLogout: widget.onLogout,
        onModeChanged: _onModeChanged,
        onUserUpdated: (updatedUser) {
          setState(() => _user = updatedUser);
        },
        onBackToHome: () => setState(() => _currentIndex = 0),
      ),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
    );
  }
}
