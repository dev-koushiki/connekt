import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'home_screen.dart';

/// CONNEKT Home Dashboard
/// Replaces the legacy VIBELIVE social feed with the modern CONNEKT mobile dashboard.
class HomeFeedScreen extends StatelessWidget {
  final UserModel? user;
  final ValueChanged<String>? onModeChanged;
  final ValueChanged<int>? onNavigateToTab;

  const HomeFeedScreen({
    super.key,
    this.user,
    this.onModeChanged,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      user: user,
      onModeChanged: onModeChanged,
      onNavigateToTab: onNavigateToTab,
    );
  }
}
