import 'package:flutter/material.dart';
import 'config/api_config.dart';
import 'config/app_theme.dart';
import 'models/user_model.dart';
import 'services/api_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/meetings_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/mail_screen.dart';
import 'screens/profile_screen.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.loadHost();
  await ThemeService.init();
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
    // 1. Check local cache first for instant 0ms app launch
    try {
      final cached = await ApiService.getCachedUser();
      if (cached != null && mounted) {
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
      if (mounted) {
        setState(() {
          if (user != null) {
            _currentUser = user;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onAuthSuccess(UserModel user) {
    setState(() => _currentUser = user);
  }

  void _onLogout() async {
    await ApiService.logout();
    setState(() => _currentUser = null);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'CONNEKT',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          home: _isLoading
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: AppTheme.brandBlue),
                  ),
                )
              : _currentUser == null
                  ? AuthScreen(onAuthSuccess: _onAuthSuccess)
                  : MainNavigationShell(
                      user: _currentUser!,
                      onLogout: _onLogout,
                    ),
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

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  void _onModeChanged(String newMode) {
    setState(() {
      _user = UserModel(
        id: _user.id,
        phone: _user.phone,
        username: _user.username,
        email: _user.email,
        currentMode: newMode,
        role: _user.role,
        personalProfile: _user.personalProfile,
        professionalProfile: _user.professionalProfile,
        skills: _user.skills,
        experience: _user.experience,
        education: _user.education,
        privacySettings: _user.privacySettings,
      );
    });
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
      // Index 4: Profile Module
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
